import QtQuick
// Colours are not here: the palette in conf/look.lua follows the wallpaper.
OptionsPage {
    title: "Look"
    spec: [
        { section: "Windows" }, "decoration:rounding", "decoration:rounding_power", "decoration:active_opacity", "decoration:inactive_opacity",
        "decoration:fullscreen_opacity", "decoration:dim_inactive", "decoration:dim_strength", "decoration:dim_special",
        { section: "Blur" }, "decoration:blur:enabled", "decoration:blur:size", "decoration:blur:passes", "decoration:blur:vibrancy",
        "decoration:blur:noise", "decoration:blur:contrast", "decoration:blur:brightness", "decoration:blur:xray", "decoration:blur:popups",
        { section: "Shadow" }, "decoration:shadow:enabled", "decoration:shadow:range", "decoration:shadow:render_power", "decoration:shadow:sharp",
        { section: "Motion" }, "animations:enabled", "animations:workspace_wraparound", "misc:animate_manual_resizes", "misc:animate_mouse_windowdragging",
        { section: "Rendering" }, "render:new_render_scheduling", "misc:vrr", "render:direct_scanout", "misc:disable_hyprland_logo",
        "misc:disable_splash_rendering", "misc:background_color"
    ]
}
