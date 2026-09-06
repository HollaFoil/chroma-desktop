import QtQuick
// Tiling: what the layouts do with new windows, and how the mouse focuses.
OptionsPage {
    title: "Windows"
    subtitle: "How windows are laid out, spaced and focused"
    spec: [
        { group: "Layout" },
        "general:layout", "general:gaps_in", "general:gaps_out", "general:border_size", "general:resize_on_border",
        { group: "Focus", hint: "What makes a window take focus" },
        "input:follow_mouse", "misc:focus_on_activate", "input:focus_on_close", "misc:mouse_move_focuses_monitor", "input:float_switch_override_focus",
        { group: "Floating windows", hint: "Snapping while a floating window is dragged" },
        "general:snap:enabled", "general:snap:window_gap", "general:snap:monitor_gap", "general:snap:border_overlap",
        { group: "Dwindle layout", advanced: true },
        "dwindle:preserve_split", "dwindle:force_split", "dwindle:smart_split", "dwindle:smart_resizing",
        "dwindle:split_width_multiplier", "dwindle:default_split_ratio", "dwindle:special_scale_factor",
        { group: "Master layout", advanced: true },
        "master:new_status", "master:new_on_top", "master:orientation", "master:mfact",
        "master:slave_count_for_center_master", "master:special_scale_factor",
        { group: "Scrolling layout", advanced: true },
        "scrolling:fullscreen_on_one_column", "scrolling:column_width", "scrolling:focus_fit_method", "scrolling:follow_focus",
        { group: "More", advanced: true },
        "general:extend_border_grab_area", "general:no_focus_fallback", "general:gaps_workspaces", "input:follow_mouse_threshold", "input:mouse_refocus",
        "misc:initial_workspace_tracking", "binds:movefocus_cycles_fullscreen", "binds:window_direction_monitor_fallback", "binds:focus_preferred_method"
    ]
}
