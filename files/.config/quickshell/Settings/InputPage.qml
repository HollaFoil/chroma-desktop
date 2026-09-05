import QtQuick
OptionsPage {
    title: "Input"
    spec: [
        { section: "Keyboard" }, "input:kb_layout", "input:kb_variant", "input:kb_options", "input:repeat_rate", "input:repeat_delay",
        "input:numlock_by_default", "input:resolve_binds_by_sym",
        { section: "Mouse" }, "input:follow_mouse", "input:follow_mouse_threshold", "input:mouse_refocus", "input:sensitivity", "input:accel_profile",
        "input:force_no_accel", "input:left_handed", "input:scroll_method", "input:scroll_factor", "input:natural_scroll", "input:float_switch_override_focus",
        { section: "Touchpad" }, "input:touchpad:disable_while_typing", "input:touchpad:natural_scroll", "input:touchpad:scroll_factor",
        "input:touchpad:tap-to-click", "input:touchpad:tap-and-drag", "input:touchpad:drag_lock", "input:touchpad:clickfinger_behavior",
        "input:touchpad:middle_button_emulation",
        { section: "Binds" }, "binds:workspace_back_and_forth", "binds:allow_workspace_cycles", "binds:workspace_center_on", "binds:focus_preferred_method",
        "binds:movefocus_cycles_fullscreen", "binds:window_direction_monitor_fallback", "binds:scroll_event_delay",
        { section: "Cursor" }, "cursor:no_hardware_cursors", "cursor:inactive_timeout", "cursor:hide_on_key_press", "cursor:hide_on_touch",
        "cursor:zoom_factor", "cursor:zoom_rigid"
    ]
}
