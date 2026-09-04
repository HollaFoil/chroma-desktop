-- Everything a key can do, with its default bind. Rebinding happens in the
-- settings UI (Arch button > Settings > Keybinds) and lands in
-- state/keybinds.json; the ids below are what that file refers to, so rename
-- one and its override is orphaned. See lib/actions.lua for the fields.
-- Binds reference: https://wiki.hypr.land/Configuring/Basics/Binds/
local A = require("lib.actions")

local HOME = os.getenv("HOME")
local terminal    = "kitty"
local fileManager = "nemo"
local menu        = HOME .. "/.local/bin/rofi-launcher"

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

A.categories({ "Apps", "Windows", "Workspaces", "Utilities", "Session", "Media" })

------------------
----   APPS   ----
------------------

A.define({ id = "app.terminal", name = "Terminal (kitty)", category = "Apps",
           keys = { mainMod .. " + Q" }, run = hl.dsp.exec_cmd(terminal) })
A.define({ id = "app.files", name = "File manager (nemo)", category = "Apps",
           keys = { mainMod .. " + E" }, run = hl.dsp.exec_cmd(fileManager) })
A.define({ id = "app.launcher", name = "App launcher", category = "Apps",
           keys = { mainMod .. " + R" }, run = hl.dsp.exec_cmd(menu) })

------------------
----  WINDOWS ----
------------------

A.define({ id = "win.close", name = "Close window", category = "Windows",
           keys = { mainMod .. " + C" }, run = hl.dsp.window.close() })
A.define({ id = "win.float", name = "Toggle floating", category = "Windows",
           keys = { mainMod .. " + V" }, run = hl.dsp.window.float({ action = "toggle" }) })
A.define({ id = "win.pseudo", name = "Pseudo-tile", category = "Windows",
           keys = { mainMod .. " + P" }, run = hl.dsp.window.pseudo() })

-- "Fake" fullscreen: the client is TOLD it is fullscreen (so it drops its own
-- chrome and renders a fullscreen layout) while Hyprland leaves the window at
-- its normal tiled geometry. Verified live: size stayed [961, 671] with
-- fullscreenClient going 0 -> 2.
--
-- Not the old `fakefullscreen` dispatcher, which is gone in 0.56. The API is
-- fullscreen_state{ internal, client } where both are REQUIRED and take the
-- mode ints 0 = none, 1 = maximized, 2 = fullscreen. internal = 0 is what
-- keeps the window its current size; client = 2 is the lie the app is told.
-- action = "toggle" makes the one bind flip both ways.
--
-- SUPER + SHIFT + F is real fullscreen, for when you do want the whole screen.
A.define({ id = "win.fake_fullscreen", name = "Fake fullscreen (window keeps its size)", category = "Windows",
           keys = { mainMod .. " + F" },
           run = hl.dsp.window.fullscreen_state({ internal = 0, client = 2, action = "toggle" }) })
A.define({ id = "win.fullscreen", name = "Real fullscreen", category = "Windows",
           keys = { mainMod .. " + SHIFT + F" },
           run = hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }) })
A.define({ id = "win.togglesplit", name = "Toggle split direction", category = "Windows",
           keys = { mainMod .. " + J" }, run = hl.dsp.layout("togglesplit") })    -- dwindle only

local ARROWS = { "left", "right", "up", "down" }
A.define({ id = "win.focus", name = "Move focus", category = "Windows",
           params = ARROWS, params_label = "Arrows", keys = { mainMod },
           run = function(dir) return hl.dsp.focus({ direction = dir }) end })
A.define({ id = "win.move", name = "Move window", category = "Windows",
           params = ARROWS, params_label = "Arrows", keys = { mainMod .. " + SHIFT" },
           run = function(dir) return hl.dsp.window.move({ direction = dir }) end })

-- Cycle windows on the current workspace (there was no alt-tab bind at all).
-- Forward only: cycle_next accepts "prev" / { prev = true } / { last = true }
-- without complaining but ignores every one of them and always steps forward
-- (checked against a known cycle order with four windows), so a reverse bind
-- would silently do the wrong thing. SUPER + arrows moves focus spatially.
A.define({ id = "win.cycle", name = "Cycle windows on this workspace", category = "Windows",
           keys = { mainMod .. " + TAB", "ALT + TAB" }, run = hl.dsp.window.cycle_next() })

-- Move/resize windows with mainMod + LMB/RMB and dragging
A.define({ id = "win.drag", name = "Move window (drag)", category = "Windows",
           keys = { mainMod .. " + mouse:272" }, keys_label = mainMod .. " + LMB drag",
           run = hl.dsp.window.drag(), flags = { mouse = true } })
A.define({ id = "win.resize_drag", name = "Resize window (drag)", category = "Windows",
           keys = { mainMod .. " + mouse:273" }, keys_label = mainMod .. " + RMB drag",
           run = hl.dsp.window.resize(), flags = { mouse = true } })

-- lock: without it the translucent-all rule is re-applied on every focus
-- change and fights the prop (visible as flicker while hovering)
A.define({ id = "win.opaque", name = "Toggle window opaque (for video)", category = "Windows",
           keys = { mainMod .. " + T" },
           run = hl.dsp.window.set_prop({ prop = "opaque", value = "toggle", lock = true }) })

--------------------
----  WORKSPACES ----
--------------------

-- Switch workspaces with mainMod + [0-9]; move the active window with SHIFT.
-- 10 maps to key 0.
local WS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
local function ws_key(i) return tostring(i % 10) end
A.define({ id = "ws.focus", name = "Switch to workspace", category = "Workspaces",
           params = WS, key_of = ws_key, params_label = "1-0", keys = { mainMod },
           run = function(i) return hl.dsp.focus({ workspace = i }) end })
A.define({ id = "ws.move", name = "Move window to workspace", category = "Workspaces",
           params = WS, key_of = ws_key, params_label = "1-0", keys = { mainMod .. " + SHIFT" },
           run = function(i) return hl.dsp.window.move({ workspace = i }) end })

-- Scroll through existing workspaces with mainMod + scroll
A.define({ id = "ws.scroll", name = "Cycle workspaces", category = "Workspaces",
           params = { "mouse_down", "mouse_up" }, params_label = "Scroll", keys = { mainMod },
           run = function(wheel)
               return hl.dsp.focus({ workspace = wheel == "mouse_down" and "e+1" or "e-1" })
           end })

-- Special workspace (scratchpad); relayout parks Spotify there.
A.define({ id = "ws.special", name = "Toggle scratchpad (Spotify parks here)", category = "Workspaces",
           keys = { mainMod .. " + S" }, run = hl.dsp.workspace.toggle_special("magic") })
A.define({ id = "ws.to_special", name = "Send window to scratchpad", category = "Workspaces",
           keys = { mainMod .. " + ALT + S" }, run = hl.dsp.window.move({ workspace = "special:magic" }) })

-------------------
----  UTILITIES ----
-------------------

A.define({ id = "util.screenshot", name = "Screenshot region to clipboard", category = "Utilities",
           keys = { mainMod .. " + SHIFT + S" }, run = hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy') })
A.define({ id = "util.notifications", name = "Toggle notification panel", category = "Utilities",
           keys = { mainMod .. " + SHIFT + N" }, run = hl.dsp.exec_cmd("swaync-client -t -sw") })
A.define({ id = "util.clipboard", name = "Clipboard history", category = "Utilities",
           keys = { mainMod .. " + SHIFT + C" }, run = hl.dsp.exec_cmd(HOME .. "/.local/bin/rofi-cliphist") })
-- relayout places a fixed dashboard of apps on a fixed monitor: it only means
-- anything once you have said which monitors and which apps, so it is an
-- offering rather than a default. Both actions are always listed in Settings >
-- Keybinds (bind them there if you want them anyway), but they come with keys
-- only after you opt in by writing ~/.config/relayout/config.sh - start from
-- examples/relayout.config.sh in the repo. conf/autostart.lua gates
-- `relayout --boot` on the same file.
local relayout_keys = { {}, {} }
do
    local f = io.open(HOME .. "/.config/relayout/config.sh", "r")
    if f then
        f:close()
        relayout_keys = { { mainMod .. " + SHIFT + R" }, { mainMod .. " + ALT + R" } }
    end
end

A.define({ id = "util.relayout", name = "Re-apply the dashboard layout", category = "Utilities",
           keys = relayout_keys[1], run = hl.dsp.exec_cmd(HOME .. "/.local/bin/relayout") })
A.define({ id = "util.relayout_toggle", name = "Move dashboard to the other monitor", category = "Utilities",
           keys = relayout_keys[2], run = hl.dsp.exec_cmd(HOME .. "/.local/bin/relayout toggle") })
A.define({ id = "util.wallpaper", name = "Wallpaper picker", category = "Utilities",
           keys = { mainMod .. " + W" }, run = hl.dsp.exec_cmd(HOME .. "/.local/bin/wallstrip") })
A.define({ id = "util.settings", name = "Settings", category = "Utilities",
           keys = { mainMod .. " + comma" }, run = hl.dsp.exec_cmd(HOME .. "/.local/bin/barpop settings") })
A.define({ id = "util.cheatsheet", name = "This cheatsheet", category = "Utilities",
           keys = { mainMod .. " + slash" }, run = hl.dsp.exec_cmd(HOME .. "/.local/bin/cheatsheet") })

-----------------
----  SESSION ----
-----------------

A.define({ id = "session.exit", name = "Exit Hyprland", category = "Session",
           keys = { mainMod .. " + M" },
           run = hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'") })
A.define({ id = "session.lock", name = "Lock screen", category = "Session",
           keys = { mainMod .. " + L" }, run = hl.dsp.exec_cmd("hyprlock") })

---------------
----  MEDIA ----
---------------

-- Laptop multimedia keys for volume and LCD brightness. Off the cheatsheet:
-- the keycaps say what they do.
local media = { locked = true, repeating = true }
A.define({ id = "media.volume_up", name = "Volume up", category = "Media", cheatsheet = false,
           keys = { "XF86AudioRaiseVolume" }, flags = media,
           run = hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+") })
A.define({ id = "media.volume_down", name = "Volume down", category = "Media", cheatsheet = false,
           keys = { "XF86AudioLowerVolume" }, flags = media,
           run = hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") })
A.define({ id = "media.mute", name = "Mute", category = "Media", cheatsheet = false,
           keys = { "XF86AudioMute" }, flags = media,
           run = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") })
A.define({ id = "media.mic_mute", name = "Mute microphone", category = "Media", cheatsheet = false,
           keys = { "XF86AudioMicMute" }, flags = media,
           run = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") })
A.define({ id = "media.brightness_up", name = "Brightness up", category = "Media", cheatsheet = false,
           keys = { "XF86MonBrightnessUp" }, flags = media,
           run = hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+") })
A.define({ id = "media.brightness_down", name = "Brightness down", category = "Media", cheatsheet = false,
           keys = { "XF86MonBrightnessDown" }, flags = media,
           run = hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-") })

-- Requires playerctl
A.define({ id = "media.next", name = "Next track", category = "Media", cheatsheet = false,
           keys = { "XF86AudioNext" }, flags = { locked = true }, run = hl.dsp.exec_cmd("playerctl next") })
A.define({ id = "media.play_pause", name = "Play / pause", category = "Media", cheatsheet = false,
           keys = { "XF86AudioPause", "XF86AudioPlay" }, flags = { locked = true },
           run = hl.dsp.exec_cmd("playerctl play-pause") })
A.define({ id = "media.previous", name = "Previous track", category = "Media", cheatsheet = false,
           keys = { "XF86AudioPrev" }, flags = { locked = true }, run = hl.dsp.exec_cmd("playerctl previous") })
