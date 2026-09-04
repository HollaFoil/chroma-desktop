-- Environment variables. Permission changes and env need a Hyprland restart,
-- not a reload. See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Qt apps: qt6ct applies the Breeze style and the palette matugen writes to
-- ~/.config/qt6ct/colors/matugen.conf (see qt6ct/qt6ct.conf). KDE apps also
-- read kdeglobals. "kde" would need plasma-integration and with it the whole
-- Plasma workspace.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Permissions: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
