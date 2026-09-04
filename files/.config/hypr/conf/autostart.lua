-- What starts with the session. Fires once at launch, not on reload.
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    -- Chained with && inside ONE exec_cmd on purpose: exec_cmd is async, so as
    -- separate lines the environment import races the services that need it.
    --
    -- xdg-desktop-portal picks its backends from XDG_CURRENT_DESKTOP when it
    -- starts and caches that choice for its lifetime. Started before the import
    -- (anything requesting a portal will D-Bus activate it), it comes up with
    -- only the gtk backend, which provides no ScreenCast on Hyprland — so
    -- screen sharing silently has no interface to call. Restarting it here
    -- makes it pick up xdg-desktop-portal-hyprland.
    -- HYPRLAND_INSTANCE_SIGNATURE is imported for waybar: its hyprland/*
    -- modules find the compositor's IPC socket at
    -- $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock. Launched
    -- by Hyprland it inherited that; started by systemd it does not, and the
    -- workspace and submap modules come up empty without it.
    --
    -- waybar.service hangs off graphical-session.target (Requisite= and
    -- WantedBy=), but that target sets RefuseManualStart and can only be
    -- reached as a dependency - hence hyprland-session.target, which BindsTo it.
    -- Starting ours pulls graphical-session.target up and waybar with it, and
    -- brings both down when the session ends. Nothing else is enabled there.
    --
    -- `restart`, not `start`, and this is load-bearing. Nothing tears the
    -- target down when Hyprland goes away: the compositor dies (or is killed,
    -- or crashes - there is no exit hook that survives all three) and the
    -- target is simply left active. On the next login `start` then sees an
    -- already-active target, does nothing, and never re-runs its dependencies,
    -- so a waybar left in failed/start-limit-hit by the previous teardown stays
    -- down for the whole session with no bar and no error. `restart` stops the
    -- target first, which pulls graphical-session.target down through BindsTo
    -- and every PartOf unit with it, then brings the lot back against the
    -- WAYLAND_DISPLAY just imported. reset-failed clears the previous session's
    -- wreckage so the fresh start is not refused by a still-live rate limit.
    -- Reconciling on the way in rather than hooking the way out is deliberate:
    -- a crash skips shutdown hooks, but login always happens.
    --
    -- reset-failed comes before either restart because a unit that tripped its
    -- start limit on the way out refuses to start on the way back in: systemd
    -- answers "Start request repeated too quickly" and the restart below is a
    -- no-op. hyprpolkitagent is in the list for exactly that reason - it aborts
    -- in Qt's DBus thread when the compositor disappears, burns its five
    -- restarts in under a second, and was still inside its rate-limit window
    -- when the next session asked for it, leaving the session with no polkit
    -- agent and so no authentication prompts at all.
    -- The agent and portal restarts are deliberately not && -chained into the
    -- target start: on a machine without hyprpolkitagent or the portal
    -- installed, a failed restart there would otherwise leave the session
    -- target (and so waybar) never started at all.
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE; systemctl --user reset-failed hyprpolkitagent xdg-desktop-portal waybar.service hyprland-session.target 2>/dev/null; systemctl --user restart hyprpolkitagent xdg-desktop-portal 2>/dev/null; systemctl --user restart hyprland-session.target")
    hl.exec_cmd("swaync")
    -- waybar runs as a systemd user unit rather than a bare exec_cmd: it
    -- segfaults in its mpris module when a player (Chrome) goes away, and
    -- Restart=on-failure brings it straight back instead of leaving no bar.
    -- Started above via graphical-session.target; `journalctl --user -u waybar`
    -- now has its output, which a fire-and-forget exec_cmd threw away.
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hypridle")
    -- Spotify's colours come from a matugen-generated color.ini in the Text
    -- theme folder. Rewriting that file is not enough on its own: `spicetify
    -- refresh` updates the client's files but leaves a running Spotify painted
    -- with the old scheme, and `spicetify apply` would restart it and stop
    -- playback. `watch -s` sees the color.ini change and reloads the running
    -- client in place, which is the only path that repaints without a restart.
    hl.exec_cmd("spicetify watch -s")
    -- relayout --boot launches every dashboard app that is not already
    -- running and waits for it to map. Launching them here as well raced
    -- with that check and produced duplicate kitty windows.
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/relayout --boot")
end)
