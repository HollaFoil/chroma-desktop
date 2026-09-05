import QtQuick
OptionsPage {
    title: "Windows"
    spec: [
        { section: "Layout" }, "general:layout", "general:gaps_in", "general:gaps_out", "general:gaps_workspaces", "general:border_size",
        "general:resize_on_border", "general:extend_border_grab_area", "general:no_focus_fallback",
        { section: "Snapping (floating windows)" }, "general:snap:enabled", "general:snap:window_gap", "general:snap:monitor_gap", "general:snap:border_overlap",
        { section: "Dwindle" }, "dwindle:preserve_split", "dwindle:force_split", "dwindle:smart_split", "dwindle:smart_resizing",
        "dwindle:split_width_multiplier", "dwindle:default_split_ratio", "dwindle:special_scale_factor",
        { section: "Master" }, "master:new_status", "master:new_on_top", "master:orientation", "master:mfact",
        "master:slave_count_for_center_master", "master:special_scale_factor",
        { section: "Scrolling" }, "scrolling:fullscreen_on_one_column", "scrolling:column_width", "scrolling:focus_fit_method", "scrolling:follow_focus",
        { section: "Focus" }, "misc:focus_on_activate", "input:focus_on_close", "misc:mouse_move_focuses_monitor", "misc:initial_workspace_tracking"
    ]
}
