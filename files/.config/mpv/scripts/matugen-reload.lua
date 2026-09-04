-- Retint a running mpv when the wallpaper changes.
--
-- matugen rewrites ~/.config/mpv/script-opts/modernz.conf on every setwall.
-- ModernZ only reads that file at start, but it registers its options with
-- mp.options and a change callback, which mpv fires whenever the
-- `script-opts` property changes. So: watch the file's mtime, and when it
-- moves, push every `key=value` in it as `modernz-key` into script-opts.
-- ModernZ then rebuilds its styles in place; nothing restarts.
local utils = require "mp.utils"

local path = mp.command_native({ "expand-path", "~~/script-opts/modernz.conf" })

local function mtime()
    local info = utils.file_info(path)
    return info and info.mtime
end

local function apply()
    local f = io.open(path, "r")
    if not f then return end
    local opts = mp.get_property_native("script-opts") or {}
    for line in f:lines() do
        if not line:match("^%s*#") then
            local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if k then opts["modernz-" .. k] = v end
        end
    end
    f:close()
    mp.set_property_native("script-opts", opts)
end

local last = mtime()
mp.add_periodic_timer(2, function()
    local m = mtime()
    if m and m ~= last then
        last = m
        apply()
    end
end)
