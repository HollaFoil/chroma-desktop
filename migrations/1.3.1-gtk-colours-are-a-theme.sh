#!/bin/bash
# 1.3.1: the GTK3 colours are a theme of their own, so Nemo repaints live.
#
# Up to 1.2.0 matugen rendered the palette to ~/.config/gtk-3.0/colors.css and
# a linked ~/.config/gtk-3.0/gtk.css imported it. GTK3 parses that user file
# once, at startup, and never again: the gtk-theme bounce in the post_hook
# reloads the *theme*, not the user CSS, and a user-level @define-color
# outranks the theme's for the life of the process. So an open Nemo kept the
# old colours until it was relaunched. Now the palette lands in
# ~/.local/share/themes/adw-gtk3-matugen/gtk-3.0/colors.css, next to a gtk.css
# (linked from the repo) that imports adw-gtk3-dark and then the colours, and
# the bounce re-reads the lot in every open GTK3 window.
#
#   ~/.config/gtk-3.0/gtk.css     the link into the checkout goes (the file is gone upstream);
#                                 it must not come back with the palette in it
#   ~/.config/gtk-3.0/colors.css  moved into the theme, so it has colours before the next setwall
#   gtk-theme                     adw-gtk3-matugen: gsettings, the GTK settings.ini files,
#                                 and xsettingsd re-reads its (linked) xsettingsd.conf
set -uo pipefail

GTK3="$HOME/.config/gtk-3.0"
THEME="$HOME/.local/share/themes/adw-gtk3-matugen/gtk-3.0"
SRC="$REPO/files/.local/share/themes/adw-gtk3-matugen/gtk-3.0/gtk.css"

# the old user CSS: only if it is (or was) our link, a file of your own stays
if [[ -L "$GTK3/gtk.css" ]]; then
    case "$(readlink "$GTK3/gtk.css")" in
        */files/.config/gtk-3.0/gtk.css) rm -f "$GTK3/gtk.css" && ok "~/.config/gtk-3.0/gtk.css: old link removed" ;;
    esac
fi

# the theme: ./link makes the gtk.css link too, this just does not wait for it
mkdir -p "$THEME"
[[ -e "$THEME/gtk.css" || ! -f "$SRC" ]] || { ln -s "$SRC" "$THEME/gtk.css" && ok "linked: .local/share/themes/adw-gtk3-matugen/gtk-3.0/gtk.css"; }
if [[ -f "$GTK3/colors.css" ]]; then
    if [[ -e "$THEME/colors.css" ]]; then
        rm -f "$GTK3/colors.css"          # setwall already rendered the new location
    else
        mv "$GTK3/colors.css" "$THEME/colors.css" && ok "gtk-3.0/colors.css moved into the adw-gtk3-matugen theme"
    fi
fi

# select it: where the old name was in use, not over a theme you picked yourself
if command -v gsettings >/dev/null 2>&1; then
    cur="$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")"
    case "$cur" in
        adw-gtk3-matugen) ;;
        adw-gtk3*|"") gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-matugen && ok "gtk-theme: adw-gtk3-matugen (was ${cur:-unset})" ;;
        *) warn "gtk-theme is $cur, left alone; setwall selects adw-gtk3-matugen at the next wallpaper change" ;;
    esac
fi
for ini in "$GTK3/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [[ -f "$ini" ]] && grep -qE '^gtk-theme-name=adw-gtk3(-dark|-light)?$' "$ini" || continue
    sed -i 's/^gtk-theme-name=.*/gtk-theme-name=adw-gtk3-matugen/' "$ini" && ok "${ini/#$HOME/~}: gtk-theme-name=adw-gtk3-matugen"
done
pkill -HUP -x xsettingsd 2>/dev/null   # Xwayland apps: Net/ThemeName from the linked xsettingsd.conf
exit 0
