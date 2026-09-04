-- Which monitor owns which workspace, and each monitor's own 1..5.
--
-- Workspaces are global in Hyprland - there can only be one "1" - so
-- per-monitor numbering is done with banks of ten: the primary monitor owns
-- 1-5, the next one 11-15, the third 21-25. Nothing types 11, though:
-- SUPER+1..5 means "the Nth workspace of the monitor under the cursor"
-- (conf/actions.lua), and the bar relabels each bank 1-5, so every workspace
-- is two keys away and SUPER+6..0 is not needed at all.
--
-- Where the map comes from, most specific first:
--
--   1. ~/.cache/relayout-state.lua   relayout, on machines that opted into it
--   2. state/monitors.json           written by `gen-monitors`
--   3. hl.get_monitors()             derived from whatever is plugged in now
--   4. FALLBACK below                the reference machine, first load only
--
-- 3 is what makes this work on a machine that has run nothing: the same split
-- gen-monitors would write, computed live. It is only unavailable during the
-- very first config load of a session, before the outputs exist - and a
-- reload (matugen does one per wallpaper) replaces it with the real thing.
local json = require("lib.json")

local M = {}

M.PER_MON = 5     -- workspaces per monitor, and so the SUPER+N range
M.BANK    = 10    -- stride between monitors: 1-5, 11-15, 21-25

-- The reference machine. Same shape gen-monitors writes, kept only for the
-- first load on a machine whose monitors are not up yet.
local FALLBACK = {
    [1] = "HDMI-A-1", [2] = "HDMI-A-1", [3] = "HDMI-A-1", [4] = "HDMI-A-1", [5] = "HDMI-A-1",
    [11] = "DP-2",    [12] = "DP-2",    [13] = "DP-2",    [14] = "DP-2",    [15] = "DP-2",
    [21] = "HDMI-A-2", [22] = "HDMI-A-2", [23] = "HDMI-A-2", [24] = "HDMI-A-2", [25] = "HDMI-A-2",
}

local HOME = os.getenv("HOME")
local cached_map, cached_relayout, relayout_read

--- Monitor names of everything connected, or nil before the outputs exist.
function M.connected()
    local ok, mons = pcall(hl.get_monitors)
    if not ok or type(mons) ~= "table" or #mons == 0 then return nil end
    local set, n = {}, 0
    for _, m in ipairs(mons) do
        local got, name = pcall(function() return m.name end)
        if got and name then set[name] = true; n = n + 1 end
    end
    if n == 0 then return nil end
    return set
end

--- relayout's state file (it owns the map when someone opted into it), or nil.
function M.relayout()
    if relayout_read then return cached_relayout end
    relayout_read = true
    local ok, res = pcall(dofile, HOME .. "/.cache/relayout-state.lua")
    if ok and type(res) == "table" and res.dash_ws then cached_relayout = res end
    return cached_relayout
end

--- state/monitors.json, or nil.
local function from_state()
    local f = io.open(HOME .. "/.config/hypr/state/monitors.json", "r")
    if not f then return nil end
    local raw = f:read("a")
    f:close()
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" or type(data.ws_home) ~= "table" then return nil end
    local map, n = {}, 0
    for ws, mon in pairs(data.ws_home) do
        local id = tonumber(ws)
        if id then map[id] = mon; n = n + 1 end
    end
    if n == 0 then return nil end
    return map
end

--- Deal banks out over the connected monitors: biggest one first (ties to the
--- leftmost), the rest left to right - the same order gen-monitors uses, so
--- running it later does not renumber anything.
function M.derive()
    local ok, mons = pcall(hl.get_monitors)
    if not ok or type(mons) ~= "table" or #mons == 0 then return nil end

    local list = {}
    for _, m in ipairs(mons) do
        local got, name = pcall(function() return m.name end)
        if got and name then
            local w = tonumber(m.width) or 0
            local h = tonumber(m.height) or 0
            list[#list + 1] = { name = name, area = w * h, x = tonumber(m.x) or 0 }
        end
    end
    if #list == 0 then return nil end

    table.sort(list, function(a, b) return a.x < b.x end)
    local primary = 1
    for i = 2, #list do
        if list[i].area > list[primary].area then primary = i end
    end

    local order = { list[primary] }
    for i, m in ipairs(list) do
        if i ~= primary then order[#order + 1] = m end
    end

    local map = {}
    for slot, m in ipairs(order) do
        for n = 1, M.PER_MON do map[(slot - 1) * M.BANK + n] = m.name end
    end
    return map
end

--- workspace id -> monitor name.
function M.map()
    if cached_map then return cached_map end
    local rl = M.relayout()
    cached_map = (rl and type(rl.ws_home) == "table" and next(rl.ws_home) and rl.ws_home)
        or from_state()
        or M.derive()
        or FALLBACK
    return cached_map
end

--- Every workspace on one monitor, lowest first.
function M.list(monitor)
    local out = {}
    for ws, mon in pairs(M.map()) do
        if mon == monitor then out[#out + 1] = ws end
    end
    table.sort(out)
    return out
end

--- The monitor the pointer is over, falling back to the focused one.
local function pointed_monitor()
    for _, get in ipairs({ hl.get_monitor_at_cursor, hl.get_active_monitor }) do
        local ok, mon = pcall(get)
        if ok and mon then
            local got, name = pcall(function() return mon.name end)
            if got and name then return name end
        end
    end
    return nil
end

--- The Nth workspace of the monitor under the pointer, or nil if it has none.
--- This is what SUPER+N and SUPER+SHIFT+N resolve through.
function M.nth_pointed(n)
    local mon = pointed_monitor()
    if not mon then return nil end
    return M.list(mon)[n]
end

return M
