#!/bin/bash
# 1.1.0: the shell's user units belong to hyprland-session.target.
#
# Up to 1.0.0, quickshell.service, wayvnc.service and xsettingsd.service were
# hooked into graphical-session.target - the target every desktop starts - so
# a Plasma or GNOME login on the same account got the Hyprland bar, lock
# screen and XSETTINGS daemon on top of its own. They are WantedBy=
# hyprland-session.target now, which only hypr/conf/autostart.lua starts.
#
# This moves the Wants symlinks over, keeping each choice as it was (wayvnc
# only if remote-desktop had been turned on), and, when it is not run from
# inside Hyprland, stops what the old hooks started in this login.
set -uo pipefail

U="$HOME/.config/systemd/user"
OLD="$U/graphical-session.target.wants"
NEW="$U/hyprland-session.target.wants"

had_wayvnc=0
for unit in quickshell.service wayvnc.service xsettingsd.service; do
    [[ -L "$OLD/$unit" || -e "$OLD/$unit" ]] || continue
    [[ $unit == wayvnc.service ]] && had_wayvnc=1
    rm -f "$OLD/$unit" && ok "$unit no longer hooked into graphical-session.target"
done
systemctl --user daemon-reload

# The shell. enable puts the symlink where the unit's [Install] now says.
if [[ -e "$U/quickshell.service" ]]; then
    systemctl --user enable quickshell.service >/dev/null 2>&1 \
        && ok "quickshell.service enabled under hyprland-session.target" \
        || warn "could not enable quickshell.service (./link, then ./bootstrap)"
fi
# XSETTINGS for Xwayland apps: a static unit, so add-wants rather than enable.
if command -v xsettingsd >/dev/null 2>&1; then
    systemctl --user add-wants hyprland-session.target xsettingsd.service >/dev/null 2>&1 \
        && ok "xsettingsd.service wanted by hyprland-session.target"
fi
# Remote desktop: only if it was on. The same plain symlink remote-desktop
# writes, to the resolved unit file (disable on a linked unit deletes it).
if [[ $had_wayvnc == 1 && -e "$U/wayvnc.service" ]]; then
    mkdir -p "$NEW" && ln -sfn "$(readlink -f "$U/wayvnc.service")" "$NEW/wayvnc.service" \
        && ok "wayvnc.service stays on from login, now under hyprland-session.target"
fi

# Run from another desktop (bootstrap under Plasma, say): the old hooks may
# have started these in this very login. Stop them; Hyprland starts its own.
if [[ "${XDG_CURRENT_DESKTOP:-}" != *Hyprland* ]]; then
    for unit in quickshell.service wayvnc.service xsettingsd.service; do
        systemctl --user is-active --quiet "$unit" 2>/dev/null || continue
        systemctl --user stop "$unit" 2>/dev/null && ok "$unit stopped (this is not a Hyprland session)"
    done
fi
exit 0
