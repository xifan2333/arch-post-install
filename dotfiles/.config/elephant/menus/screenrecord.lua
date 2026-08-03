--
-- Screenrecord overlay suite menu for Elephant/Walker
-- Toggles camera/captions/keys/title overlays.
-- (record audio mix is managed by the livestream streaming flow, not this menu)
--
Name = "screenrecord"
NamePretty = "Screenrecord Overlays"
HideFromProviderlist = true

local function running(pattern)
  local handle = io.popen("pgrep -f '" .. pattern .. "' 2>/dev/null")
  if not handle then
    return false
  end
  local out = handle:read("*l")
  handle:close()
  return out ~= nil and out ~= ""
end

local function state(on)
  return on and "● Running" or "○ Stopped"
end

function GetEntries()
  local camera = running("python3.*screenrecord-overlay-camera")
  local captions = running("python3.*screenrecord-overlay-captions")
  local keys = running("python3.*screenrecord-overlay-keys")
  local title = running("python3 .*/screenrecord-overlay-title$")
  return {
    {
      Text = "󰄀  Camera Overlay",
      Subtext = state(camera),
      Actions = { activate = "screenrecord-overlay-camera-toggle" },
    },
    {
      Text = "󰨜  Captions Overlay",
      Subtext = state(captions),
      Actions = { activate = "screenrecord-overlay-captions-toggle" },
    },
    {
      Text = "󰌌  Keys Overlay",
      Subtext = state(keys),
      Actions = { activate = "screenrecord-overlay-keys-toggle" },
    },
    {
      Text = "󰗊  Title Overlay",
      Subtext = state(title),
      Actions = { activate = "screenrecord-overlay-title-toggle" },
    },
    {
      Text = "󰏫  Edit Title Overlay",
      Subtext = "Text / font / color / position",
      Actions = { activate = "screenrecord-overlay-title-edit" },
    },
  }
end
