// Model logic for livestream configuration (bitrates and multi-platform targets).

const DEFAULT_VIDEO_BITRATE = 6000;
const DEFAULT_AUDIO_BITRATE = 160;
const DEFAULT_LAN_VIDEO_BITRATE = 12000;

function boundedInt(value, fallback, minVal, maxVal) {
  const num = parseInt(value, 10);
  if (isNaN(num)) return fallback;
  return Math.max(minVal, Math.min(maxVal, num));
}

function parseConfig(rawText) {
  const result = {
    videoBitrate: DEFAULT_VIDEO_BITRATE,
    audioBitrate: DEFAULT_AUDIO_BITRATE,
    lanBitrate: DEFAULT_LAN_VIDEO_BITRATE,
    platforms: [],
  };

  if (!rawText || !String(rawText).trim()) return result;

  let data = null;
  try {
    data = JSON.parse(rawText);
  } catch (_e) {
    return result;
  }

  if (!data || typeof data !== "object") return result;

  result.videoBitrate = boundedInt(
    data.bitrate || data.video_bitrate,
    DEFAULT_VIDEO_BITRATE,
    100,
    50000,
  );
  result.audioBitrate = boundedInt(data.audio_bitrate, DEFAULT_AUDIO_BITRATE, 32, 320);
  result.lanBitrate = boundedInt(
    data.lan_bitrate || data.lan_video_bitrate,
    DEFAULT_LAN_VIDEO_BITRATE,
    1000,
    80000,
  );

  const items = Array.isArray(data.platforms) ? data.platforms : [];
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (!item || typeof item !== "object") continue;

    let aspect = String(item.aspect_ratio || "16:9")
      .trim()
      .toLowerCase();
    if (aspect !== "9:16" && aspect !== "16:9") aspect = "16:9";

    result.platforms.push({
      enabled: item.enabled !== false,
      name: String(item.name || item.platform || "").trim(),
      server: String(item.server || "").trim(),
      key: String(item.key || item.stream_key || "").trim(),
      aspect_ratio: aspect,
      showKey: false,
    });
  }

  return result;
}

function serializeConfig(model) {
  const payload = {
    bitrate: boundedInt(model.videoBitrate, DEFAULT_VIDEO_BITRATE, 100, 50000),
    audio_bitrate: boundedInt(model.audioBitrate, DEFAULT_AUDIO_BITRATE, 32, 320),
    lan_bitrate: boundedInt(model.lanBitrate, DEFAULT_LAN_VIDEO_BITRATE, 1000, 80000),
    platforms: [],
  };

  const platforms = Array.isArray(model.platforms) ? model.platforms : [];
  for (let i = 0; i < platforms.length; i++) {
    const p = platforms[i];
    if (!p) continue;
    const name = String(p.name || "").trim();
    if (!name && !p.server) continue;

    let aspect = String(p.aspect_ratio || "16:9")
      .trim()
      .toLowerCase();
    if (aspect !== "9:16" && aspect !== "16:9") aspect = "16:9";

    payload.platforms.push({
      enabled: p.enabled !== false,
      name: name,
      server: String(p.server || "").trim(),
      key: String(p.key || "").trim(),
      aspect_ratio: aspect,
    });
  }

  return JSON.stringify(payload, null, 2) + "\n";
}

function createEmptyPlatform() {
  return {
    enabled: true,
    name: "",
    server: "",
    key: "",
    aspect_ratio: "16:9",
    showKey: false,
  };
}
