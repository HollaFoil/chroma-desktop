#!/bin/bash
# 1.4.1: hypridle.conf turns the displays off in Lua.
#
# Since Hyprland 0.56 with a Lua config, `hyprctl dispatch` evaluates Lua, so
# the classic `hyprctl dispatch dpms off` in hypridle.conf fails with
# "expected a dispatcher" and the displays never go off (the lock listener,
# `loginctl lock-session`, was unaffected). The seed and Settings > Power now
# write `hyprctl dispatch 'hl.dsp.dpms({action = "off"})'`; your own
# ~/.config/hypr/hypridle.conf (a copy since 1.2.0) still has the old lines,
# so they are rewritten in place and hypridle is restarted to pick them up.
set -uo pipefail

CONF="$HOME/.config/hypr/hypridle.conf"
[[ -f "$CONF" ]] || exit 0
grep -qE 'hyprctl dispatch dpms (on|off)\b' "$CONF" || exit 0

# `hyprctl dispatch dpms on|off`, whatever the option's name, quoted or not
sed -i -E \
    -e "s|hyprctl dispatch ['\"]?dpms (on\|off)['\"]?|hyprctl dispatch 'hl.dsp.dpms({action = \"\\1\"})'|g" \
    "$CONF" || { warn "could not rewrite ~${CONF#"$HOME"}"; exit 1; }
ok "~${CONF#"$HOME"}: dpms on/off is now hl.dsp.dpms(...) (Lua dispatch)"

if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle
    setsid hypridle >/dev/null 2>&1 < /dev/null &
    ok "hypridle restarted"
fi
exit 0
