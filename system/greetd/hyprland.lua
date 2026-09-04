-- Hyprland config for the login screen: greetd runs this as the `greeter`
-- user and it runs wallgreet (/usr/local/bin, from system/greetd/wallgreet),
-- then exits when wallgreet does. Installed to /etc/greetd/hyprland.lua by
-- ./greeter.
--
-- /etc/greetd/theme is written by greeter-sync (a matugen post_hook, so it
-- runs on every setwall): the user's monitors.lua and colors.lua, a copy of
-- the wallpaper and the rendered wallgreet.css. Each is optional: without
-- monitors.lua Hyprland auto-configures the outputs, without colors.lua the
-- backdrop behind wallgreet's surfaces is a neutral dark grey.
local THEME = "/etc/greetd/theme"

pcall(dofile, THEME .. "/monitors.lua")

local ok, C = pcall(dofile, THEME .. "/colors.lua")
if not ok or type(C) ~= "table" or not C.surface then C = { surface = "141414" } end

hl.env("XCURSOR_SIZE", "24")

hl.config({
    misc = {
        disable_hyprland_logo         = true,
        disable_splash_rendering      = true,
        disable_hyprland_guiutils_check = true,
        force_default_wallpaper       = 0,
        -- shows only until wallgreet has covered every monitor
        background_color              = "rgb(" .. C.surface .. ")",
    },
    general    = { border_size = 0, gaps_in = 0, gaps_out = 0 },
    decoration = { rounding = 0 },
    animations = { enabled = false },
})

hl.on("hyprland.start", function()
    -- wallgreet covers every monitor with a layer-shell surface itself, so
    -- there is nothing to place. When it exits, greetd has the session.
    hl.exec_cmd("wallgreet; hyprctl dispatch 'hl.dsp.exit()'")
end)
