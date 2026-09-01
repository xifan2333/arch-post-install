// Read, parse, and serialize ~/.config/screenrecord/captions.conf.

function parseConfig(rawText) {
  const cfg = {
    fontSize: 24,
    fontFamily: "monospace",
    textColor: "#ffffff",
    anchorY: "bottom",
    marginBottom: 46,
  };

  const lines = String(rawText || "").split("\n");
  let inCaptions = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line === "" || line.charAt(0) === "#" || line.charAt(0) === ";") continue;
    if (line.charAt(0) === "[" && line.charAt(line.length - 1) === "]") {
      inCaptions = line === "[captions]";
      continue;
    }
    if (!inCaptions) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    const val = line.slice(eq + 1).trim();

    switch (key) {
      case "font_size":
        cfg.fontSize = Number(val) || cfg.fontSize;
        break;
      case "font_family":
        cfg.fontFamily = val;
        break;
      case "text_color":
        cfg.textColor = val;
        break;
      case "anchor_y":
        if (["top", "bottom", "center"].indexOf(val) !== -1) cfg.anchorY = val;
        break;
      case "margin_bottom":
        cfg.marginBottom = Math.max(0, Number(val) || 0);
        break;
      default:
        break;
    }
  }

  return cfg;
}

function serializeConfig(cfg) {
  const lines = [
    "[captions]",
    "font_size = " + (Math.round(cfg.fontSize) || 24),
    "font_family = " + (cfg.fontFamily || "monospace"),
    "text_color = " + (cfg.textColor || "#ffffff"),
    "anchor_y = " + (cfg.anchorY || "bottom"),
    "margin_bottom = " + (Math.round(cfg.marginBottom) || 46),
  ];
  return lines.join("\n") + "\n";
}
