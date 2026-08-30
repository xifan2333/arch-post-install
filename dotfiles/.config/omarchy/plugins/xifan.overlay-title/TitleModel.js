// Parse the INI-ish extra format from ~/.config/screenrecord/title.conf raw text.
// Returns a plain object with the same defaults the old Python script used.
function parseConfig(rawText) {
  var cfg = {
    text: "Recording",
    fontFamily: "sans-serif",
    fontSize: 36,
    fontWeight: 700,
    textColor: "#ffffff",
    background: "#000000",
    opacity: 0.55,
    anchorX: "left",
    anchorY: "top",
    marginX: 24,
    marginY: 24,
    paddingX: 16,
    paddingY: 10,
    maxWidth: 900
  }

  var lines = String(rawText || "").split("\n")
  var inTitle = false
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") continue
    if (line.charAt(0) === "#") continue
    if (line.charAt(0) === "[" && line.charAt(line.length - 1) === "]") {
      inTitle = (line === "[title]")
      continue
    }
    if (!inTitle) continue
    var eq = line.indexOf("=")
    if (eq === -1) continue
    var key = line.slice(0, eq).trim()
    var val = line.slice(eq + 1).trim()

    switch (key) {
      case "text": cfg.text = val; break
      case "font_family": cfg.fontFamily = val; break
      case "font_size": cfg.fontSize = Number(val) || cfg.fontSize; break
      case "font_weight": cfg.fontWeight = Number(val) || cfg.fontWeight; break
      case "text_color": cfg.textColor = val; break
      case "background":
        // Accept "rgba(r,g,b,a)" or "#rrggbb" or "#rrggbbaa".
        cfg.background = val
        var m = val.match(/^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$/)
        if (m) {
          var r = Number(m[1]), g = Number(m[2]), b = Number(m[3]), a = Number(m[4])
          cfg.background = "#" + [r, g, b].map(function(n) {
            return ("0" + Math.max(0, Math.min(255, n)).toString(16)).slice(-2)
          }).join("")
          cfg.opacity = a
        } else if (val.charAt(0) === "#" && val.length === 9) {
          cfg.background = val.slice(0, 7)
          cfg.opacity = parseInt(val.slice(7, 9), 16) / 255
        }
        break
      case "opacity": cfg.opacity = Number(val) || cfg.opacity; break
      case "anchor_x": if (["left", "right", "center"].indexOf(val) !== -1) cfg.anchorX = val; break
      case "anchor_y": if (["top", "bottom", "center"].indexOf(val) !== -1) cfg.anchorY = val; break
      case "margin_x": cfg.marginX = Number(val) || cfg.marginX; break
      case "margin_y": cfg.marginY = Number(val) || cfg.marginY; break
      case "padding_x": cfg.paddingX = Number(val) || cfg.paddingX; break
      case "padding_y": cfg.paddingY = Number(val) || cfg.paddingY; break
      case "max_width": cfg.maxWidth = Number(val) || cfg.maxWidth; break
      // text_shadow is ignored for now (QML uses Qt Quick drop shadow below).
      default: break
    }
  }

  return cfg
}
