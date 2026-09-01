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
  const s = String(level || "auto").toLowerCase();
  if (s === "auto") return "\ue31e"; // weather-windy 
  if (s === "disengaged" || s === "64" || s === "full-speed" || s === "max") return "\ue34b"; // weather-strong_wind 
  const num = parseInt(s, 10);
  if (!isNaN(num) && num >= 1 && num <= 7) {
    return String.fromCharCode(0xe3af + num); // \ue3b0 .. \ue3b6 (Beaufort 1..7)
  }
  return "\ue31e";
}

function levelBadgeText(level) {
  const s = String(level || "auto").toLowerCase();
  if (s === "auto") return "Auto";
  if (s === "disengaged" || s === "64" || s === "full-speed" || s === "max") return "MAX";
  return "L" + s;
}

function levelOsdText(level) {
  const s = String(level || "auto").toLowerCase();
  if (s === "auto") return "Auto";
  if (s === "disengaged" || s === "64" || s === "full-speed" || s === "max") return "MAX";
  return "Level " + s;
}

function levelDisplayName(level) {
  const s = String(level || "auto").toLowerCase();
  if (s === "auto") return "BIOS Smart Curve";
  if (s === "disengaged" || s === "64" || s === "full-speed" || s === "max")
    return "MAX Turbo Boost";
  return "Manual Level " + s;
}

function isMax(level) {
  const s = String(level || "").toLowerCase();
  return s === "disengaged" || s === "64" || s === "full-speed" || s === "max";
}

if (typeof module !== "undefined") {
  module.exports = {
    FAN_LEVELS,
    levelToIndex,
    indexToLevel,
    stepLevel,
    fanIcon,
    levelBadgeText,
    levelOsdText,
    levelDisplayName,
    isMax,
  };
}
