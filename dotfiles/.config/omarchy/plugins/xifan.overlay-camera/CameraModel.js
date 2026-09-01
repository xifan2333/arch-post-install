// Read, parse, and serialize ~/.config/screenrecord/camera.conf.
// Also pick a V4L2 camera / capture format the way the old GTK overlay did.

const ASPECTS = ["1:1", "4:3", "16:9", "3:4", "9:16"];

function parseAspect(val, fallback) {
  const s = String(val || "");
  return ASPECTS.indexOf(s) !== -1 ? s : fallback || "4:3";
}

function nextAspect(current) {
  let i = ASPECTS.indexOf(current);
  if (i < 0) i = 1;
  return ASPECTS[(i + 1) % ASPECTS.length];
}

function aspectParts(aspect) {
  const p = String(aspect || "4:3").split(":");
  return { w: Number(p[0]) || 4, h: Number(p[1]) || 3 };
}

function sizeForAspect(aspect, widthHint, minSide, maxSide) {
  const p = aspectParts(aspect);
  let nw = Math.round(widthHint);
  let nh = Math.round((nw * p.h) / p.w);
  if (nh > maxSide || nh < minSide) {
    nh = Math.max(minSide, Math.min(maxSide, nh));
    nw = Math.round((nh * p.w) / p.h);
  }
  nw = Math.max(minSide, Math.min(maxSide, nw));
  nh = Math.round((nw * p.h) / p.w);
  nh = Math.max(minSide, Math.min(maxSide, nh));
  return { width: nw, height: nh };
}

function parseConfig(rawText) {
  const cfg = {
    device: "auto",
    width: 200,
    height: 150,
    captureWidth: 640,
    captureHeight: 480,
    fps: 30,
    aspect: "4:3",
    anchorX: "right",
    anchorY: "bottom",
    marginX: 0,
    marginY: 0,
    borderWidth: 1.5,
  };

  const lines = String(rawText || "").split("\n");
  let inCamera = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line === "" || line.charAt(0) === "#" || line.charAt(0) === ";") continue;
    if (line.charAt(0) === "[" && line.charAt(line.length - 1) === "]") {
      inCamera = line === "[camera]";
      continue;
    }
    if (!inCamera) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    const val = line.slice(eq + 1).trim();

    switch (key) {
      case "device":
        cfg.device = val || "auto";
        break;
      case "width":
        cfg.width = Math.max(80, Number(val) || cfg.width);
        break;
      case "height":
        cfg.height = Math.max(60, Number(val) || cfg.height);
        break;
      case "capture_width":
        cfg.captureWidth = Math.max(160, Number(val) || cfg.captureWidth);
        break;
      case "capture_height":
        cfg.captureHeight = Math.max(120, Number(val) || cfg.captureHeight);
        break;
      case "fps":
        cfg.fps = Math.max(1, Number(val) || cfg.fps);
        break;
      case "anchor_x":
        if (["left", "right", "center"].indexOf(val) !== -1) cfg.anchorX = val;
        break;
      case "anchor_y":
        if (["top", "bottom", "center"].indexOf(val) !== -1) cfg.anchorY = val;
        break;
      case "margin_x":
        cfg.marginX = Math.max(0, Number(val) || 0);
        break;
      case "margin_y":
        cfg.marginY = Math.max(0, Number(val) || 0);
        break;
      case "border_width":
        cfg.borderWidth = Math.max(0, Number(val) || 0);
        break;
      case "aspect":
        cfg.aspect = parseAspect(val, cfg.aspect);
        break;
      default:
        break;
    }
  }

  return cfg;
}

function serializeConfig(cfg) {
  const lines = [
    "[camera]",
    "device = " + (cfg.device || "auto"),
    "width = " + (Math.round(cfg.width) || 200),
    "height = " + (Math.round(cfg.height) || 150),
    "capture_width = " + (Math.round(cfg.captureWidth) || 640),
    "capture_height = " + (Math.round(cfg.captureHeight) || 480),
    "fps = " + (Math.round(cfg.fps) || 30),
    "anchor_x = " + (cfg.anchorX || "right"),
    "anchor_y = " + (cfg.anchorY || "bottom"),
    "margin_x = " + (Math.round(cfg.marginX) || 0),
    "margin_y = " + (Math.round(cfg.marginY) || 0),
    "border_width = " + (cfg.borderWidth === 0 ? "0" : cfg.borderWidth || 1.5),
    "aspect = " + parseAspect(cfg.aspect, "4:3"),
  ];
  return lines.join("\n") + "\n";
}

function maxPixels(dev) {
  const formats = (dev && dev.videoFormats) || [];
  let best = 0;
  for (let i = 0; i < formats.length; i++) {
    const r = formats[i].resolution;
    if (!r) continue;
    const px = r.width * r.height;
    if (px > best) best = px;
  }
  return best;
}

function pickDevice(inputs, want) {
  if (!inputs || inputs.length === 0) return null;
  const needle = String(want || "auto");
  if (needle && needle !== "auto") {
    for (let i = 0; i < inputs.length; i++) {
      const d = inputs[i];
      const id = String(d.id || "");
      const desc = String(d.description || "");
      if (id === needle || id.indexOf(needle) !== -1 || desc.indexOf(needle) !== -1) return d;
    }
  }
  let best = inputs[0];
  let bestPx = maxPixels(best);
  for (let j = 1; j < inputs.length; j++) {
    const px = maxPixels(inputs[j]);
    if (px > bestPx) {
      best = inputs[j];
      bestPx = px;
    }
  }
  return best;
}

function pickFormat(dev, wantW, wantH, wantFps) {
  const formats = (dev && dev.videoFormats) || [];
  if (formats.length === 0) return null;
  let best = formats[0];
  let bestScore = -1;
  for (let i = 0; i < formats.length; i++) {
    const f = formats[i];
    const r = f.resolution;
    if (!r) continue;
    let score = 0;
    if (r.width === wantW && r.height === wantH) score += 1000000;
    score += Math.min(r.width * r.height, wantW * wantH);
    if (f.maxFrameRate >= wantFps) score += 1000;
    score += f.maxFrameRate;
    if (score > bestScore) {
      bestScore = score;
      best = f;
    }
  }
  return best;
}
