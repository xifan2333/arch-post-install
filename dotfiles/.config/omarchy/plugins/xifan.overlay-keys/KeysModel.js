// Read, parse, and serialize ~/.config/screenrecord/keys.conf.
// Mirrors TitleModel.js patterns; the key-vs-title config only differ in keys.

function parseConfig(rawText) {
  var cfg = {
    fontSize: 18,
    fontFamily: "monospace",
    textColor: "#ffffff",
    anchorX: "right",
    anchorY: "bottom",
    marginX: 36,
    marginY: 150
  }

  var lines = String(rawText || "").split("\n")
  var inKeys = false
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "" || line.charAt(0) === "#" || line.charAt(0) === ";") continue
    if (line.charAt(0) === "[" && line.charAt(line.length - 1) === "]") {
      inKeys = (line === "[keys]")
      continue
    }
    if (!inKeys) continue
    var eq = line.indexOf("=")
    if (eq === -1) continue
    var key = line.slice(0, eq).trim()
    var val = line.slice(eq + 1).trim()

    switch (key) {
      case "font_size": cfg.fontSize = Number(val) || cfg.fontSize; break
      case "font_family": cfg.fontFamily = val; break
      case "text_color": cfg.textColor = val; break
      case "anchor_x": if (["left", "right", "center"].indexOf(val) !== -1) cfg.anchorX = val; break
      case "anchor_y": if (["top", "bottom", "center"].indexOf(val) !== -1) cfg.anchorY = val; break
      case "margin_x": cfg.marginX = Math.max(0, Number(val) || 0); break
      case "margin_y": cfg.marginY = Math.max(0, Number(val) || 0); break
      default: break
    }
  }

  return cfg
}

function serializeConfig(cfg) {
  var lines = [
    "[keys]",
    "font_size = " + (Math.round(cfg.fontSize) || 18),
    "font_family = " + (cfg.fontFamily || "monospace"),
    "text_color = " + (cfg.textColor || "#ffffff"),
    "anchor_x = " + (cfg.anchorX || "right"),
    "anchor_y = " + (cfg.anchorY || "bottom"),
    "margin_x = " + (Math.round(cfg.marginX) || 36),
    "margin_y = " + (Math.round(cfg.marginY) || 150)
  ]
  return lines.join("\n") + "\n"
}
