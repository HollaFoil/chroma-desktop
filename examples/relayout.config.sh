# ~/.config/relayout/config.sh -- your machine's values for relayout.
# Plain bash, sourced after the defaults in ~/.local/bin/relayout; set only
# what differs. Monitor names: `hyprctl monitors -j | jq -r '.[].name'`.

# The monitor the dashboard lives on with SUPER+SHIFT+R, and its workspaces.
MAIN_MON="DP-1"
MAIN_DASH_WS=1
MAIN_WORK_WS=2
# "class x y w h" in percent of the monitor below the bar; x+w and y+h reach 100.
MAIN_LAYOUT=(
    "Spotify         0   0  40 100"
    "vesktop        40   0  60  60"
    "layout-sysmon  40  60  60  40"
)

# Second profile (SUPER+ALT+R toggles). Point it at the same monitor if you
# only have one.
ALT_MON="HDMI-A-1"
ALT_DASH_WS=6
ALT_WORK_WS=7
ALT_LAYOUT=(
    "vesktop         0   0 100  60"
    "layout-sysmon   0  60 100  40"
)

# Which monitor owns each workspace; relayout writes this into the Lua state
# that hyprland.lua turns into workspace rules.
WS_HOME=(
    "1 DP-1" "2 DP-1" "3 DP-1" "4 DP-1" "5 DP-1"
    "6 HDMI-A-1" "7 HDMI-A-1" "8 HDMI-A-1" "9 HDMI-A-1" "10 HDMI-A-1"
)

# Every app any profile may place, and how to start it. Anything whose command
# is not installed is silently left out.
ALL_APPS=(Spotify vesktop layout-sysmon)
LAUNCH_CMD[Spotify]="spotify-launcher"
LAUNCH_CMD[vesktop]="vesktop"
LAUNCH_CMD[layout-sysmon]="kitty --class layout-sysmon -o font_size=9 -e btop"
