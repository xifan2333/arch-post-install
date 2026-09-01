// Read, parse, and serialize ~/.config/screenrecord/title.conf.

function parseConfig(rawText) {
  const cfg = {
    text: "直播标题",
    fontFamily: "sans-serif",
    fontSize: 36,
    fontWeight: 700,
    textColor: "#ffffff",
    background: "rgba(0, 0, 0, 0.55)",
    opacity: 0.55,
    anchorX: "left",
    anchorY: "top",
    marginX: 24,
    marginY: 24,
  };

  const lines = String(rawText || "").split("\n");
  let inTitle = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line === "" || line.charAt(0) === "#" || line.charAt(0) === ";") continue;
    if (line.charAt(0) === "[" && line.charAt(line.length - 1) === "]") {
      inTitle = line === "[title]";
      continue;
    }
    if (!inTitle) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    const val = line.slice(eq + 1).trim();

    switch (key) {
      case "text":
        cfg.text = val;
        break;
      case "font_family":
        cfg.fontFamily = val;
        break;
      case "font_size":
        cfg.fontSize = Number(val) || cfg.fontSize;
        break;
      case "font_weight":
        cfg.fontWeight = Number(val) || cfg.fontWeight;
        break;
      case "text_color":
        cfg.textColor = val;
        break;
      case "background":
        cfg.background = val;
        break;
      case "opacity":
        cfg.opacity = Number(val) || cfg.opacity;
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
      default:
        break;
    }
  }

  return cfg;
}

function serializeConfig(cfg) {
  const lines = [
    "[title]",
    "text = " + (cfg.text || ""),
    "font_family = " + (cfg.fontFamily || "sans-serif"),
    "font_size = " + (Math.round(cfg.fontSize) || 36),
    "font_weight = " + (Math.round(cfg.fontWeight) || 700),
    "text_color = " + (cfg.textColor || "#ffffff"),
    "background = " + (cfg.background || "rgba(0, 0, 0, 0.55)"),
    "anchor_x = " + (cfg.anchorX || "left"),
    "anchor_y = " + (cfg.anchorY || "top"),
    "margin_x = " + (Math.round(cfg.marginX) || 24),
    "margin_y = " + (Math.round(cfg.marginY) || 24),
  ];
  return lines.join("\n") + "\n";
}
