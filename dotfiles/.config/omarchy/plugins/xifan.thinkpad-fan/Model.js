const FAN_LEVELS = ["auto", "1", "2", "3", "4", "5", "6", "7", "max"];

function levelToIndex(level) {
  const s = String(level || "auto").toLowerCase();
  if (s === "disengaged" || s === "64" || s === "full-speed" || s === "max") return 8;
  const idx = FAN_LEVELS.indexOf(s);
  return idx >= 0 ? idx : 0;
}

function indexToLevel(idx) {
  const i = Math.max(0, Math.min(FAN_LEVELS.length - 1, Math.round(idx)));
  return FAN_LEVELS[i];
}

function stepLevel(currentLevel, steps) {
  const curIdx = levelToIndex(currentLevel);
  const nextIdx = Math.max(0, Math.min(FAN_LEVELS.length - 1, curIdx + steps));
  return FAN_LEVELS[nextIdx];
}

// Weather Icons Beaufort wind scale and wind symbols from Nerd Fonts
function fanIcon(level) {
  const idx = levelToIndex(level);
  if (idx === 0) return "\ue31e"; // weather-windy 
  if (idx === 8) return "\ue34b"; // weather-strong_wind 
  return String.fromCharCode(0xe3af + idx); // \ue3b0 .. \ue3b6 (Beaufort 1..7)
}

function levelOsdText(level) {
  const idx = levelToIndex(level);
  if (idx === 0) return "Auto";
  if (idx === 8) return "MAX";
  return "Level " + idx;
}

function levelDisplayName(level) {
  const idx = levelToIndex(level);
  if (idx === 0) return "BIOS Smart Curve";
  if (idx === 8) return "MAX Turbo Boost";
  return "Manual Level " + idx;
}

if (typeof module !== "undefined") {
  module.exports = {
    FAN_LEVELS,
    levelToIndex,
    indexToLevel,
    stepLevel,
    fanIcon,
    levelOsdText,
    levelDisplayName,
  };
}
