// Intel HD Graphics frequency governor domain logic.
// Follows the same discrete-step architecture as xifan.thinkpad-fan.

const GPU_LEVELS = ["auto", "650", "750", "850", "950", "1050", "1150", "1250", "max"];

function levelToIndex(level) {
  const s = String(level || "auto").toLowerCase();
  if (s === "max" || s === "1300" || s === "boost" || s === "performance") return 8;
  if (s === "auto" || s === "dynamic" || s === "default") return 0;
  const num = parseInt(s, 10);
  if (isFinite(num)) {
    // Snap to nearest discrete level
    let closestIdx = 1;
    let minDiff = 9999;
    for (let i = 1; i < GPU_LEVELS.length; i++) {
      const target = GPU_LEVELS[i] === "max" ? 1300 : parseInt(GPU_LEVELS[i], 10);
      const diff = Math.abs(num - target);
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }
    return closestIdx;
  }
  const idx = GPU_LEVELS.indexOf(s);
  return idx >= 0 ? idx : 0;
}

function indexToLevel(idx) {
  const i = Math.max(0, Math.min(GPU_LEVELS.length - 1, Math.round(idx)));
  return GPU_LEVELS[i];
}

function stepLevel(currentLevel, steps) {
  const curIdx = levelToIndex(currentLevel);
  const nextIdx = Math.max(0, Math.min(GPU_LEVELS.length - 1, curIdx + steps));
  return GPU_LEVELS[nextIdx];
}

// Microchip icon for normal/dynamic, Bolt icon for MAX turbo
// Nerd Fonts: nf-fa-microchip (U+F2DB), nf-fa-bolt (U+F0E7)
function gpuIcon(level) {
  const idx = levelToIndex(level);
  if (idx === 8) return "\uf0e7"; // nf-fa-bolt 
  return "\uf2db"; // nf-fa-microchip 
}

function levelOsdText(level) {
  const idx = levelToIndex(level);
  if (idx === 0) return "Auto";
  if (idx === 8) return "MAX (1300)";
  return GPU_LEVELS[idx] + " MHz";
}

function levelDisplayName(level) {
  const idx = levelToIndex(level);
  if (idx === 0) return "BIOS Dynamic Curve";
  if (idx === 8) return "MAX Turbo Boost";
  return "Manual " + GPU_LEVELS[idx] + " MHz Floor";
}

if (typeof module !== "undefined") {
  module.exports = {
    GPU_LEVELS,
    levelToIndex,
    indexToLevel,
    stepLevel,
    gpuIcon,
    levelOsdText,
    levelDisplayName,
  };
}
