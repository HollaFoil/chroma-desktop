-- Named actions instead of bare hl.bind calls.
--
-- conf/actions.lua (and user/*.lua) describe what can be done and what it is
-- bound to by default; state/keybinds.json, written by the settings UI, says
-- what it is actually bound to and whether the cheatsheet lists it. bind_all()
-- merges the two and registers the binds, export() writes the merged table to
-- ~/.cache/hypr/binds.json for the cheatsheet and the settings UI, which is
-- how those two never parse Lua.
--
--   local A = require("lib.actions")
--   A.categories({ "Apps", "Windows", ... })          -- cheatsheet section order
--   A.define({
--       id       = "app.terminal",                    -- stable; the JSON files key on it
--       name     = "Terminal (kitty)",
--       category = "Apps",
--       keys     = { "SUPER + Q" },                   -- default binds, {} for none
--       run      = hl.dsp.exec_cmd("kitty"),          -- dispatcher, or a lua function
--       flags    = { repeating = true },              -- optional, passed to hl.bind
--       cheatsheet = true,                            -- optional, default true
--       keys_label = "SUPER + LMB drag",              -- optional cheatsheet text
--   })
--
-- A parametrised action is one row that expands to a bind per param; its keys
-- are prefixes and the UI rebinds the prefix:
--
--   A.define({
--       id = "ws.focus", name = "Switch to workspace", category = "Workspaces",
--       params = { 1, 2, 3 }, key_of = tostring, params_label = "1-3",
--       keys = { "SUPER" },                           -- SUPER + 1, SUPER + 2, ...
--       run = function(i) return hl.dsp.focus({ workspace = i }) end,
--   })
--
-- Defining an id twice replaces the first definition in place, so a user file
-- can override a built-in action without touching conf/actions.lua.
local json = require("lib.json")

local HOME = os.getenv("HOME")
local CACHE = (os.getenv("XDG_CACHE_HOME") or (HOME .. "/.cache")) .. "/hypr"

local M = {
    state_path  = HOME .. "/.config/hypr/state/keybinds.json",
    export_path = CACHE .. "/binds.json",
    list  = {},   -- definition order
    by_id = {},
    cats  = {},
}

local function notify(text)
    if hl and hl.notification then
        hl.notification.create({ text = text, timeout = 8000 })
    end
end

function M.categories(list)
    M.cats = list
end

function M.define(a)
    assert(type(a) == "table" and a.id and a.name and a.category,
           "actions.define: id, name and category are required")
    a.keys = a.keys or {}
    if a.cheatsheet == nil then a.cheatsheet = true end
    if a.params and type(a.run) ~= "function" then
        error("actions.define(" .. a.id .. "): a parametrised action needs run = function(param)")
    end
    if a.params and not a.key_of then a.key_of = tostring end
    local old = M.by_id[a.id]
    if old then
        for i, x in ipairs(M.list) do
            if x == old then M.list[i] = a end
        end
    else
        M.list[#M.list + 1] = a
    end
    M.by_id[a.id] = a
    return a
end

--- state/keybinds.json, or an empty state when it is missing or broken.
function M.state()
    local st = { binds = {}, custom = {} }
    local f = io.open(M.state_path, "r")
    if not f then return st end
    local raw = f:read("a")
    f:close()
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then
        notify("keybinds.json is not valid JSON, using the defaults: " .. tostring(data))
        return st
    end
    if type(data.binds) == "table" then st.binds = data.binds end
    if type(data.custom) == "table" then st.custom = data.custom end
    return st
end

local function combo(prefix, key)
    if prefix == nil or prefix == "" then return key end
    return prefix .. " + " .. key
end

--- Register every bind. Called once, after all define()s.
function M.bind_all()
    local st = M.state()

    -- "Run a command" actions created in the UI live only in the JSON.
    for _, c in ipairs(st.custom) do
        if c.id and c.name and c.command then
            M.define({
                id = c.id, name = c.name, category = c.category or "Utilities",
                keys = c.keys or {}, cheatsheet = c.cheatsheet,
                run = hl.dsp.exec_cmd(c.command), custom = true, command = c.command,
            })
        end
    end

    local failed = {}
    for _, a in ipairs(M.list) do
        local o = st.binds[a.id] or {}
        a.effective_keys = o.keys or a.keys
        a.effective_cheatsheet = a.cheatsheet
        if o.cheatsheet ~= nil then a.effective_cheatsheet = o.cheatsheet end

        for _, key in ipairs(a.effective_keys) do
            local targets = {}
            if a.params then
                for _, p in ipairs(a.params) do
                    targets[#targets + 1] = { combo(key, a.key_of(p)), a.run(p) }
                end
            else
                targets[1] = { key, a.run }
            end
            for _, t in ipairs(targets) do
                local flags = {}
                for k, v in pairs(a.flags or {}) do flags[k] = v end
                flags.description = a.id
                local ok, err = pcall(hl.bind, t[1], t[2], flags)
                if not ok then failed[#failed + 1] = a.id .. " [" .. t[1] .. "]: " .. tostring(err) end
            end
        end
    end
    if #failed > 0 then
        notify("keybinds: " .. table.concat(failed, "; "))
    end

    -- A near-empty submap: while the settings UI records a combo it switches
    -- here, so SUPER + anything reaches the UI instead of running a bind. A
    -- submap with no binds is not registered at all, and Escape is the one
    -- bind it should have anyway: it leaves the submap even if the UI died
    -- mid-capture, and non_consuming lets the UI see the same Escape to
    -- cancel its recording. `hyprctl dispatch 'hl.dsp.submap("reset")'` by hand
    -- works too.
    hl.define_submap("capture", function()
        hl.bind("Escape", hl.dsp.submap("reset"), { non_consuming = true, description = "capture.escape" })
    end)
end

--- The cheatsheet's two columns: categories assigned to whichever side makes
--- the column heights closest, each side keeping the declared category
--- order. Computed here, on every (re)load, so opening the sheet is a read.
--- A category costs its rows plus two (title, spacing), matching the sheet.
--- Brute force over the 2^(n-1) assignments (the first category anchors the
--- left column); n is the handful of categories that have visible rows, and
--- past 16 a greedy fill takes over. Ties go to the assignment with the
--- fewest changes of side along the declared order, i.e. the one that looks
--- most like the plain list cut in two. The taller column is always the left
--- one.
local function columns(cats, heights)
    local n = #cats
    if n == 0 then return { {}, {} } end
    if n > 16 then
        local l, r, hl_, hr = {}, {}, 0, 0
        for _, c in ipairs(cats) do
            if hl_ <= hr then l[#l + 1] = c; hl_ = hl_ + heights[c]
            else r[#r + 1] = c; hr = hr + heights[c] end
        end
        if hr > hl_ then l, r = r, l end
        return { l, r }
    end
    local total = 0
    for _, c in ipairs(cats) do total = total + heights[c] end
    local best, best_diff, best_flips
    for mask = 0, (1 << (n - 1)) - 1 do
        local left, flips, prev = heights[cats[1]], 0, true
        for i = 2, n do
            local on_left = (mask >> (i - 2)) & 1 == 1
            if on_left then left = left + heights[cats[i]] end
            if on_left ~= prev then flips = flips + 1 end
            prev = on_left
        end
        local diff = math.abs(left - (total - left))
        if not best or diff < best_diff or (diff == best_diff and flips < best_flips) then
            best, best_diff, best_flips = mask, diff, flips
        end
    end
    local l, r, hl_, hr = { cats[1] }, {}, heights[cats[1]], 0
    for i = 2, n do
        if (best >> (i - 2)) & 1 == 1 then
            l[#l + 1] = cats[i]; hl_ = hl_ + heights[cats[i]]
        else
            r[#r + 1] = cats[i]; hr = hr + heights[cats[i]]
        end
    end
    if hr > hl_ then l, r = r, l end   -- the taller column goes left
    return { l, r }
end

local function cheatsheet_columns()
    local rows, order, seen = {}, {}, {}
    for _, c in ipairs(M.cats) do order[#order + 1] = c; seen[c] = true end
    for _, a in ipairs(M.list) do
        local keys = a.effective_keys or a.keys
        if a.effective_cheatsheet ~= false and #keys > 0 then
            if not seen[a.category] then order[#order + 1] = a.category; seen[a.category] = true end
            rows[a.category] = (rows[a.category] or 0) + 1
        end
    end
    local cats, heights = {}, {}
    for _, c in ipairs(order) do
        if rows[c] then
            cats[#cats + 1] = c
            heights[c] = rows[c] + 2   -- title and spacing, as the sheet lays it out
        end
    end
    return columns(cats, heights)
end

--- Write the merged table for the cheatsheet and the settings UI.
function M.export()
    local out = { categories = M.cats, actions = {}, columns = cheatsheet_columns() }
    for _, a in ipairs(M.list) do
        local param_keys
        if a.params then
            param_keys = {}
            for _, p in ipairs(a.params) do param_keys[#param_keys + 1] = a.key_of(p) end
        end
        out.actions[#out.actions + 1] = {
            id = a.id, name = a.name, category = a.category,
            keys = a.effective_keys or a.keys, default_keys = a.keys,
            cheatsheet = a.effective_cheatsheet,
            keys_label = a.keys_label, params_label = a.params_label,
            parametrised = a.params ~= nil, param_keys = param_keys,
            custom = a.custom or false, command = a.command,
        }
    end
    os.execute("mkdir -p '" .. CACHE .. "'")
    local tmp = M.export_path .. ".tmp"
    local f, err = io.open(tmp, "w")
    if not f then
        notify("could not write " .. M.export_path .. ": " .. tostring(err))
        return
    end
    f:write(json.encode(out))
    f:close()
    os.rename(tmp, M.export_path)
end

return M
