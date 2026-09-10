-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- [DEPRECATED / MIGRATION]: External Omarchy bootstrap layer.
-- Planned for replacement with self-contained native config / River 0.4 session.
local omarchy_bootstrap = (os.getenv("OMARCHY_PATH") or "/usr/share/omarchy")
  .. "/default/hypr/bootstrap.lua"
local f = io.open(omarchy_bootstrap, "r")
if f then
  f:close()
  dofile(omarchy_bootstrap)
  pcall(require, "default.hypr.omarchy")
  pcall(require, "default.hypr.toggles")
end

-- Personal configuration modules
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("hypr.windows")
