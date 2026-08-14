--
-- Screenrecord overlay suite menu for Elephant/Walker
-- Status and toggles both go through capture-router so process detection stays shared.
--
Name = "screenrecord"
NamePretty = "Screenrecord Overlays"
HideFromProviderlist = true

local function running(name)
  local handle = io.popen("capture-router overlay pid " .. name .. " 2>/dev/null")
  if not handle then
    return false
  end
  local out = handle:read("*l")
  handle:close()
  return out ~= nil and out:match("%S") ~= nil
end

local function state(on)
  return on and "● Running" or "○ Stopped"
end

function GetEntries()
  local camera = running("camera")
  local captions = running("captions")
  local keys = running("keys")
  local title = running("title")
  return {
    {
      Text = "󰄀  Camera Overlay",
      Subtext = state(camera),
      Actions = { activate = "capture-router overlay camera" },
    },
    {
      Text = "󰨜  Captions Overlay",
      Subtext = state(captions),
      Actions = { activate = "capture-router overlay captions" },
    },
    {
      Text = "󰌌  Keys Overlay",
      Subtext = state(keys),
      Actions = { activate = "capture-router overlay keys" },
    },
    {
      Text = "󰗊  Title Overlay",
      Subtext = state(title),
      Actions = { activate = "capture-router overlay title" },
    },
    {
      Text = "󰏫  Edit Title Overlay",
      Subtext = "Text / font / color / position",
      Actions = { activate = "capture-router overlay edit" },
    },
  }
end
