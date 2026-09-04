-- Option overrides written by the settings UI (barpop settings).
--
-- state/settings.json looks like
--
--   { "options": { "general:gaps_in": 8, "decoration:blur:enabled": false } }
--
-- Keys are the names `hyprctl descriptions` uses, values are already the
-- type hl.config wants (the UI knows the schema; this side does not). apply()
-- runs last in hyprland.lua, so a value set in the UI wins over conf/*.lua and
-- user/*.lua; deleting the key from the file (the UI's reset button) and
-- reloading brings the hand-written value back.
local json = require("lib.json")

local M = {}

M.path = os.getenv("HOME") .. "/.config/hypr/state/settings.json"

local cache

local function notify(text)
    if hl and hl.notification then
        hl.notification.create({ text = text, timeout = 8000 })
    end
end

--- The parsed file ({ options = {} } when missing or broken).
function M.get()
    if cache then return cache end
    cache = { options = {} }
    local f = io.open(M.path, "r")
    if not f then return cache end
    local raw = f:read("a")
    f:close()
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then
        notify("settings.json is not valid JSON, ignoring it: " .. tostring(data))
        return cache
    end
    if type(data.options) == "table" then cache.options = data.options end
    return cache
end

--- "general:col.active_border" -> { general = { ["col.active_border"] = v } }
local function nested(name, value)
    local root, cur = {}, nil
    local parts = {}
    for part in name:gmatch("[^:]+") do parts[#parts + 1] = part end
    cur = root
    for i, part in ipairs(parts) do
        if i == #parts then
            cur[part] = value
        else
            cur[part] = {}
            cur = cur[part]
        end
    end
    return root
end

--- Push every override into Hyprland. Each key is applied on its own so one
--- bad entry (an option that no longer exists) does not take the rest down.
function M.apply()
    local bad = {}
    for name, value in pairs(M.get().options) do
        local ok, err = pcall(hl.config, nested(name, value))
        if not ok then bad[#bad + 1] = name .. " (" .. tostring(err) .. ")" end
    end
    if #bad > 0 then
        notify("settings.json: could not apply " .. table.concat(bad, ", "))
    end
end

return M
