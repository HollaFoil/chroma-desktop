#!/bin/bash
# 1.2.0: what the Settings app writes is yours, and lives outside the repo.
#
# Up to 1.1.0 these were symlinks into the checkout, so the Settings app,
# gen-monitors and nwg-displays wrote straight into tracked files: your
# option overrides, keybinds, monitors and idle timeouts showed up in git
# status, a pull that touched them refused to run, and the maintainer's
# values shipped as everyone's defaults.
#
#   ~/.config/hypr/state/        -> a real directory (settings.json, keybinds.json, monitors.json)
#   ~/.config/hypr/monitors.lua  -> your own file
#   ~/.config/hypr/hypridle.conf -> your own file (a "seed" in manifest.txt from now on)
#   Desktop/layout.json          -> ~/.local/state/quickshell/layout.json
#
# Every value you had is copied over first. Then the tracked files in the
# checkout are put back to what git has, so the working tree is clean; what
# they held is also kept in a backup under ~/.local/state/chroma-desktop/.
# The tracked copies themselves (files/.config/hypr/state/*.json,
# files/.config/hypr/monitors.lua) stay in git for good: nothing reads them,
# but deleting or editing them upstream would make git refuse the pull on any
# machine whose Settings app wrote to them before this migration ran - and
# a machine can jump from 1.0.0 straight to any later version.
set -uo pipefail

HYPR="$HOME/.config/hypr"
QS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
BACKUP="${STATE_DIR:-$HOME/.local/state/chroma-desktop}/backup-1.2.0"
FILES="$REPO/files"

# A symlink into the repo becomes a copy of what it pointed at. The copy is
# made beside it and renamed over the link in one step: Hyprland reloads the
# moment a config file it loaded changes, and an rm-then-cp gave it a reload
# with monitors.lua missing (outputs back to 60 Hz and the default layout),
# after which it no longer watched the path and never saw the new file.
own() {
    local path="$1" target tmp
    [[ -L "$path" ]] || return 0
    target="$(readlink -f "$path")"
    tmp="$path.migrate-$$"
    if [[ -d "$target" ]]; then
        mkdir -p "$tmp" && cp -a "$target"/. "$tmp"/
    elif [[ -f "$target" ]]; then
        cp "$target" "$tmp"
    else
        rm -f "$path"; return 0
    fi
    if [[ -d "$tmp" ]]; then
        # rename(2) will not put a directory over a symlink; swap the two
        # (coreutils >= 9.5), or fall back to the shortest possible gap
        if mv --exchange -T "$tmp" "$path" 2>/dev/null; then rm -f "$tmp"
        else rm -f "$path" && mv -T "$tmp" "$path"; fi
    else
        mv -T "$tmp" "$path"
    fi || { rm -rf "$tmp"; warn "could not replace ${path/#$HOME/~}"; return 1; }
    ok "${path/#$HOME/~} is your own copy now"
}

own "$HYPR/state"
mkdir -p "$HYPR/state"
own "$HYPR/monitors.lua"
own "$HYPR/hypridle.conf"

mkdir -p "$QS_STATE"
if [[ ! -e "$QS_STATE/layout.json" && -f "$FILES/.config/quickshell/Desktop/layout.json" ]]; then
    cp "$FILES/.config/quickshell/Desktop/layout.json" "$QS_STATE/layout.json"
    ok "desktop widget layout copied to ~/.local/state/quickshell/layout.json"
fi

# The checkout: back up and restore what the tools wrote through the links.
if git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    for rel in .config/hypr/state/settings.json .config/hypr/state/keybinds.json \
               .config/hypr/monitors.lua .config/hypr/hypridle.conf .config/quickshell/Desktop/layout.json; do
        f="files/$rel"
        git -C "$REPO" ls-files --error-unmatch "$f" >/dev/null 2>&1 || continue
        git -C "$REPO" diff --quiet -- "$f" 2>/dev/null && continue
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp "$REPO/$f" "$BACKUP/$rel"
        git -C "$REPO" checkout -- "$f" && ok "$f: repo copy restored (yours was copied out; backup in ${BACKUP/#$HOME/~})"
    done
fi
# monitors.json in the checkout is gitignored and now lives in ~/.config/hypr/state
rm -f "$FILES/.config/hypr/state/monitors.json"
exit 0
