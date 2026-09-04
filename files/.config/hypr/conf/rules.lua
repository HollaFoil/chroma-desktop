-- Window, workspace and layer rules.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Layout profile, written by ~/.local/bin/relayout. Read here so the window
-- rules below survive a `hyprctl reload` (matugen fires one on every wallpaper
-- change, and reload drops anything injected with `hyprctl eval`).
local LP = { dash_ws = 1, work_ws = 2, stash_ws = "special:magic",
             used_re = "^(Spotify|slack|vesktop|layout-sysmon|homelab-dash)$",
             guard_re = "negative:^(Spotify|slack|vesktop|layout-sysmon|homelab-dash|cheatsheet|hyprland-run)$",
             -- last-resort fallback only: one machine's monitors. state/monitors.json
             -- (written by `gen-monitors`) replaces it, and relayout overrides both.
             ws_home = { [1] = "HDMI-A-1", [2] = "HDMI-A-1", [3] = "HDMI-A-1",
                         [4] = "HDMI-A-1", [5] = "HDMI-A-1",
                         [6] = "DP-2",     [7] = "DP-2",     [8] = "DP-2",
                         [9] = "HDMI-A-2", [10] = "HDMI-A-2" } }

-- Which monitor owns which workspace, most specific source first:
--
--   1. ~/.cache/relayout-state.lua   relayout, for machines that opted into it
--   2. state/monitors.json           this machine's monitors (`gen-monitors`)
--   3. the table above               the reference machine's three
--
-- Whatever wins, a rule naming a monitor that is not connected is dropped: on
-- a laptop that has run none of the above, workspaces 6-10 would otherwise be
-- pinned to monitors that do not exist. hl.get_monitors() is empty during the
-- very first config load (outputs come up after the config is read), and then
-- nothing is filtered - the same rules as before, corrected on the first
-- reload.
do
    local json = require("lib.json")
    local f = io.open(os.getenv("HOME") .. "/.config/hypr/state/monitors.json", "r")
    if f then
        local raw = f:read("a")
        f:close()
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == "table" and type(data.ws_home) == "table" then
            local map = {}
            for ws, mon in pairs(data.ws_home) do map[tonumber(ws)] = mon end
            LP.ws_home = map
        end
    end

    local ok, res = pcall(dofile, os.getenv("HOME") .. "/.cache/relayout-state.lua")
    if ok and type(res) == "table" and res.dash_ws then
        res.ws_home = res.ws_home or LP.ws_home
        LP = res
    end
end

--- Connected monitor names, or nil when the compositor has not enumerated them
--- yet (first load), which means "do not filter".
local function connected()
    local ok, mons = pcall(hl.get_monitors)
    if not ok or type(mons) ~= "table" or #mons == 0 then return nil end
    local set = {}
    for _, m in ipairs(mons) do
        local got, name = pcall(function() return m.name end)
        if got and name then set[name] = true end
    end
    if next(set) == nil then return nil end
    return set
end
local LIVE = connected()

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
--   HDMI-A-1  1 = dashboard slot, 2 = work, 3-5 spare
--   DP-2      6 = dashboard slot, 7 = work, 8 spare
--   HDMI-A-2  9, 10
--
-- and on a one-monitor machine (after `gen-monitors`) as all ten on it.
local function known(mon) return mon and (LIVE == nil or LIVE[mon]) end

for ws = 1, 10 do
    local mon = LP.ws_home and LP.ws_home[ws]
    if known(mon) then hl.workspace_rule({ workspace = tostring(ws), monitor = mon }) end
end

-- Which workspace each monitor shows when it first appears: its lowest one,
-- derived from the same map so the two can never disagree.
local seen = {}
for ws = 1, 10 do
    local mon = LP.ws_home and LP.ws_home[ws]
    if known(mon) and not seen[mon] then
        seen[mon] = true
        hl.workspace_rule({ workspace = tostring(ws), monitor = mon, default = true })
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

-- Frosted popups: blur the wallpaper behind the bar, the swaync panels and
-- the barpop menus. Their stylesheets paint translucent @surface so the blur
-- shows through; ignore_alpha keeps the fully transparent parts of the
-- surfaces (swaync's screen-wide window, barpop's click-away backdrop) from
-- being blurred as well.
for _, r in ipairs({
    { name = "frosted-waybar",  ns = "^waybar$",                      popups = true },
    { name = "frosted-swaync",  ns = "^swaync-control-center$" },
    { name = "frosted-notifs",  ns = "^swaync-notification-window$" },
    { name = "frosted-barpop",  ns = "^barpop$" },
    { name = "frosted-wallstrip", ns = "^wallstrip$" },
    { name = "frosted-cheatsheet", ns = "^cheatsheet$" },
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
