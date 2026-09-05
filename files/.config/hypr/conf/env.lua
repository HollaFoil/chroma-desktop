-- Environment variables. Permission changes and env need a Hyprland restart,
-- not a reload. See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- PATH for everything Hyprland starts. A login shell used to add these (fish's
-- fish_user_paths) when the display manager ran the session through it; greetd
-- sources only sh's profile, so ~/.local/bin (setwall, greeter-sync)
-- and ~/.spicetify (spicetify watch/refresh) have to be put back here.
local HOME = os.getenv("HOME")
hl.env("PATH", HOME .. "/.local/bin:" .. HOME .. "/.spicetify:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))

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
