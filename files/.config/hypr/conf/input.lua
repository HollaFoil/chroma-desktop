-- Keyboard, mouse, touchpad, gestures. Overridable from the settings UI.
hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Per-device config. Names as `hyprctl devices` lists them (lowercase, dashes).
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

-- The DualSense's touchpad shows up as a third mouse. Any tap or click on it
-- sends pointer events, which games read as keyboard+mouse input and drop
-- controller inputs while they switch. Nobody wants it as a mouse on a desktop,
-- so it is off. Steam still sees it via hidraw if a Steam Input layout maps it.
for _, name in ipairs({
    "sony-interactive-entertainment-dualsense-wireless-controller-touchpad", -- USB
    "dualsense-wireless-controller-touchpad",                                -- Bluetooth
    "sony-interactive-entertainment-dualsense-edge-wireless-controller-touchpad",
    "dualsense-edge-wireless-controller-touchpad",
}) do
    hl.device({ name = name, enabled = false })
end
