-- swayimg: image viewer. Runs after the built-in defaults (see
-- /usr/share/swayimg/example.lua for everything that can be set), so only
-- what differs is here. Colours come from colors.lua, written by matugen on
-- every wallpaper change; the fallback palette below covers the first start.
local function palette()
  local ok, res = pcall(dofile, os.getenv("HOME") .. "/.config/swayimg/colors.lua")
  return (ok and type(res) == "table") and res or {
    surface = "101418", on_surface = "e1e2e8", on_surface_variant = "c2c7cf",
    primary = "9fcafc", primary_container = "004a77", surface_container_high = "272a2f",
    tertiary = "d6bee5", outline = "8c9199",
  }
end
local function argb(hex, alpha) return tonumber((alpha or "ff") .. hex, 16) end

-- Everything that carries a colour, in one function so it can run again:
-- setwall's matugen post_hook sends SIGUSR1 to running viewers (bound below)
-- and they retint with the wallpaper.
local function paint()
  local C = palette()
  swayimg.viewer.set_window_background(argb(C.surface))
  swayimg.viewer.set_image_chessboard(20, argb(C.surface_container_high), argb(C.surface))
  swayimg.slideshow.set_window_background(argb(C.surface))
  swayimg.viewer.mark_color = argb(C.tertiary)
  swayimg.text.color = argb(C.on_surface)
  swayimg.text.background = argb(C.surface, "99")
  swayimg.gallery.border_color = argb(C.primary)
  swayimg.gallery.selected_color = argb(C.primary_container)
  swayimg.gallery.unselected_color = argb(C.surface_container_high)
  swayimg.gallery.window_color = argb(C.surface)
  swayimg.gallery.mark_color = argb(C.tertiary)
end
paint()
for _, mode in ipairs({ swayimg.viewer, swayimg.slideshow, swayimg.gallery }) do
  mode.on_signal("USR1", paint)
end

-- window: no title bar (Hyprland draws no decorations anyway; conf/rules.lua
-- floats and centres the window)
swayimg.decoration = false

-- overlay text: quiet, one line per corner, gone after a few seconds
swayimg.text.font = "Noto Sans"
swayimg.text.size = 14
swayimg.text.padding = 14
swayimg.text.shadow = 0x00000000
swayimg.text.timeout = 3
swayimg.viewer.set_text("topleft", { "{name}" })
swayimg.viewer.set_text("topright", { "{list.index} / {list.total}" })
swayimg.viewer.set_text("bottomleft", { "{frame.width} × {frame.height}   {scale}" })
swayimg.viewer.set_text("bottomright", {})

-- gallery (Enter): thumbnails on the surface, the current one ringed in primary
swayimg.gallery.thumb_size = 220
swayimg.gallery.padding_size = 12
swayimg.gallery.border_size = 3

-- browse the whole folder when opened on one file
swayimg.imagelist.adjacent = true
