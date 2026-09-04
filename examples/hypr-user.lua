-- Machine-local Hyprland extras. Copy to ~/.config/hypr/user/init.lua (the
-- user/ directory is not in the manifest, so it is yours and never versioned).
-- hyprland.lua loads it after conf/*.lua and before the settings UI's
-- overrides; a Lua error here is reported as a notification, not a dead config.
local A = require("lib.actions")

-- A new action: shows up in Settings > Keybinds and on the cheatsheet, and
-- can be rebound there like the built-ins.
A.define({
    id = "user.browser", name = "Browser", category = "Apps",
    keys = { "SUPER + B" },
    run = hl.dsp.exec_cmd("firefox"),
})

-- Change a built-in: same id replaces the definition in place.
A.define({
    id = "app.terminal", name = "Terminal (foot)", category = "Apps",
    keys = { "SUPER + Q" },
    run = hl.dsp.exec_cmd("foot"),
})

-- Plain config is fine too (anything set in the settings UI still wins).
hl.config({ general = { gaps_out = 12 } })
