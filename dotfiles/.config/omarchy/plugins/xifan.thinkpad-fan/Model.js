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
    levelDisplayName,
    isMax,
  };
}
