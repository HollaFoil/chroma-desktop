-- Window, workspace and layer rules.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Layout profile, written by ~/.local/bin/relayout. Read here so the window
-- rules below survive a `hyprctl reload` (matugen fires one on every wallpaper
-- change, and reload drops anything injected with `hyprctl eval`).
local WS = require("lib.workspaces")

local LP = { dash_ws = 1, work_ws = 2, stash_ws = "special:magic",
             used_re = "^(Spotify|slack|vesktop|layout-sysmon|homelab-dash)$",
             guard_re = "negative:^(Spotify|slack|vesktop|layout-sysmon|homelab-dash|cheatsheet|hyprland-run)$" }
local rl = WS.relayout()
if rl then LP = rl end

-- The workspace -> monitor map (lib/workspaces.lua explains where it comes
-- from). A rule naming a monitor that is not connected is dropped: without
-- that, a laptop running the reference map would pin workspaces to outputs
-- that do not exist. Before the outputs come up - the very first config load
-- of a session - there is nothing to filter against and every rule is
-- emitted, which is what happened before this existed anyway; the first
-- reload corrects it.
local LIVE = WS.connected()

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- Ordinary windows tile normally on whatever workspace they open on, so
-- several can share one and be cycled with SUPER+TAB. The only workspace
-- that is protected is the one the dashboard currently occupies.
--
-- Rule order matters: later rules win, so the guard is declared first and
-- the dashboard apps re-claim the workspace after it.

-- The guard skips the dashboard apps themselves and deliberate overlays such
-- as the cheatsheet, which are supposed to appear on top of whatever is on
-- screen. Hyprland's matcher has no boolean negation; the "negative:" prefix
-- on the value is what inverts the match.
hl.window_rule({
    name  = "relayout-dash-guard",
    match = { workspace = tostring(LP.dash_ws), class = LP.guard_re },
    -- deliberately not "silent": you should see the window you just opened
    workspace = tostring(LP.work_ws),
})

hl.window_rule({
    name  = "relayout-dash-apps",
    match = { class = LP.used_re },
    workspace = LP.dash_ws .. " silent",
    float = true,
})

if LP.parked_re then
    hl.window_rule({
        name  = "relayout-dash-parked",
        match = { class = LP.parked_re },
        workspace = LP.stash_ws .. " silent",
        float = true,
    })
end

-- Every window is translucent; no per-app exceptions. When one needs to be
-- solid for a while (a video, a colour-sensitive image), SUPER+T toggles the
-- focused window's opaque flag, which wins over this rule until toggled back
-- or the window closes.
hl.window_rule({
    name  = "translucent-all",
    match = { class = ".*" },
    opacity = "0.95 override 0.85 override 1.0 override",
})

-- Bind every workspace to a monitor.
--
-- The r[N-M] range selector is accepted by the parser but never actually
-- matches: workspaces kept being created on whichever monitor happened to be
-- focused. Verified by focusing HDMI-A-2 and switching to ws2 — it was created
-- on HDMI-A-2 under the range rule, and on HDMI-A-1 once ws2 was named
-- explicitly. So enumerate them.
--
-- On the reference machine that comes out as
--
--   HDMI-A-1  1-5    (1 = dashboard slot, 2 = work)
--   DP-2      11-15  (11 = dashboard slot, 12 = work)
--   HDMI-A-2  21-25
--
-- and on a one-monitor machine as 1-5 on it. Nobody types the tens digit:
-- SUPER+1..5 goes to the bank of whichever monitor the pointer is over.
--
-- The lowest workspace of each monitor is also its default, derived from the
-- same map so the two cannot disagree.
local function known(mon) return mon and (LIVE == nil or LIVE[mon]) end

local map = WS.map()
local ids = {}
for ws in pairs(map) do ids[#ids + 1] = ws end
table.sort(ids)

local seen = {}
for _, ws in ipairs(ids) do
    local mon = map[ws]
    if known(mon) then
        hl.workspace_rule({ workspace = tostring(ws), monitor = mon })
        if not seen[mon] then
            seen[mon] = true
            hl.workspace_rule({ workspace = tostring(ws), monitor = mon, default = true })
        end
    end
end

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Frosted surfaces: blur the wallpaper behind the shell's bar, popups and
-- notifications. They paint translucent surface colour so the blur shows
-- through; ignore_alpha keeps the fully transparent parts (the click-away
-- backdrops) from being blurred.
for _, r in ipairs({
    { name = "frosted-wallstrip", ns = "^wallstrip$" },
    { name = "frosted-cheatsheet", ns = "^cheatsheet$" },
    -- Quickshell surfaces (the bar blurs its own popups too)
    { name = "frosted-qs-bar",     ns = "^qs-bar$", popups = true },
    { name = "frosted-qs-overlay", ns = "^qs-overlay$" },
    { name = "frosted-qs-notif",   ns = "^qs-notif$" },
    { name = "frosted-qs-osd",     ns = "^qs-osd$" },
}) do
    hl.layer_rule({
        name         = r.name,
        match        = { namespace = r.ns },
        blur         = true,
        blur_popups  = r.popups or false,
        ignore_alpha = 0.2,
    })
end

-- Viewers float in the middle of the screen at a comfortable size instead of
-- taking a tile: swayimg (images) and mpv (video; autofit in mpv.conf keeps
-- the aspect ratio inside this box). Fully opaque, declared after
-- translucent-all so it wins: pictures are the one thing that should not
-- have the wallpaper bleeding through.
for _, r in ipairs({
    { name = "float-swayimg", class = "^(swayimg)$", size = "70% 75%" },
    { name = "float-mpv",     class = "^(mpv)$",     size = "72% 72%" },
}) do
    hl.window_rule({
        name  = r.name,
        match = { class = r.class },
        float = true,
        center = true,
        size = r.size,
        opacity = "1.0 override 1.0 override 1.0 override",
    })
end

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
