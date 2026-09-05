-- Hyprland config for the login screen: greetd runs this as the `greeter`
-- user and it runs the shell's greeter (quickshell, from the copy of the
-- config at /etc/greetd/quickshell), then exits when the greeter does.
-- Installed to /etc/greetd/hyprland.lua by ./greeter.
--
-- /etc/greetd/theme is written by greeter-sync (a matugen post_hook, so it
-- runs on every setwall): the user's monitors.lua and colors.lua, a copy of
-- the wallpaper (background) and the palette as colors.json. Each is
-- optional: without monitors.lua Hyprland auto-configures the outputs,
-- without colors.lua the backdrop behind the surfaces is a neutral dark grey.
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
        -- shows only until the greeter has covered every monitor
        background_color              = "rgb(" .. C.surface .. ")",
    },
    general    = { border_size = 0, gaps_in = 0, gaps_out = 0 },
    decoration = { rounding = 0 },
    animations = { enabled = false },
})

hl.on("hyprland.start", function()
    -- The greeter covers every monitor with a layer surface itself, so there
    -- is nothing to place. When it exits, greetd has the session.
    hl.exec_cmd("env QS_COLORS=" .. THEME .. "/colors.json QS_GREETER_THEME=" .. THEME
        .. " qs -p /etc/greetd/quickshell/greeter.qml; hyprctl dispatch 'hl.dsp.exit()'")
end)
