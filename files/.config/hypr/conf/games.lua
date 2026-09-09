-- Games: tag them, then strip everything the compositor would otherwise do to
-- a fullscreen frame. Loaded after conf/rules.lua on purpose: translucent-all
-- (opacity 0.95 on every window) has to lose to these, and later rules win.
--
-- Why this matters: a fullscreen window that is fully opaque, undecorated and
-- alone on its monitor becomes a "solitary" client, and with direct scanout
-- Hyprland stops rendering it at all and flips the game's buffer straight to
-- the display. Translucent (0.95) means a blur + blend pass on every frame
-- instead. `hyprctl monitors -j` shows .solitary and .directScanoutTo while a
-- game runs; both non-zero is the goal.
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/

-- Proton/Steam windows are steam_app_<appid>; gamescope wraps anything.
-- Extend the list for native games that do not run through Steam.
local GAME_CLASSES = "^(steam_app_\\d+|gamescope|cs2|dota2|Minecraft.*)$"

hl.window_rule({
    name  = "game-tag-by-class",
    match = { class = GAME_CLASSES },
    tag   = "+game",
})

-- Anything that announces itself as a game (wp-content-type: gamescope,
-- SDL3, Proton's Wayland driver) gets the tag as well.
hl.window_rule({
    name  = "game-tag-by-content",
    match = { content = "game" },
    tag   = "+game",
})

hl.window_rule({
    name  = "game-render",
    match = { tag = "game" },

    -- Undo translucent-all: solid, and force opaque even if the client sends
    -- an alpha channel (XWayland games often do).
    opacity = "1.0 override 1.0 override 1.0 override",
    opaque  = true,

    no_blur   = true,
    no_shadow = true,
    no_anim   = true,
    no_dim    = true,

    -- Marks the surface as game content, which is what render:direct_scanout
    -- = 2 keys on (see below).
    content = "game",

    -- Never blank or lock mid-match.
    idle_inhibit = "fullscreen",

    -- Tearing: lets the game present immediately instead of waiting for
    -- vblank; lowest latency, but visible tear lines, and on NVIDIA it is
    -- hit and miss (fine on AMD). Needs general.allow_tearing = true
    -- (conf/look.lua) as well. Off until measured (~/.local/bin/framelog).
    -- immediate = true,
})

-- Direct scanout only for windows with content type "game" (the rule above
-- sets it). 1 would do it for every fullscreen window, including video
-- players, where flicker has been reported on NVIDIA; AMD is fine either
-- way. Set to 0 if a game shows glitches or a black screen in fullscreen.
hl.config({ render = { direct_scanout = 2 } })
