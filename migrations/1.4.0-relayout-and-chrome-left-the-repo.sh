#!/bin/bash
# 1.4.0: relayout and chrome-flags.conf left the repo; games get their own rules.
#
# relayout (one person's dashboard of apps on one person's monitors) and
# chrome-flags.conf (workarounds for a browser this desktop never set up) were
# the maintainer's, not the desktop's, and are gone from files/. The links
# ./link made for them now point at nothing, so:
#   ~/.local/bin/relayout          removed, if it is that dangling link
#   ~/.config/chrome-flags.conf    removed, if it is that dangling link
# A relayout of your own (a real file, or a link elsewhere) is not touched,
# and neither are ~/.config/relayout/ or ~/.cache/relayout-*: they are yours.
#
# MangoHud (files/.config/MangoHud/MangoHud.conf, new in the manifest) writes
# its CSV logs to ~/.local/share/mangohud-logs and does not create the
# directory itself; without it Shift_L+F2 silently logs nothing.
set -uo pipefail

for rel in .local/bin/relayout .config/chrome-flags.conf; do
    p="$HOME/$rel"
    [[ -L "$p" && ! -e "$p" ]] || continue          # only a dangling link
    case "$(readlink "$p")" in
        */files/$rel) rm -f "$p" && ok "~/$rel: dangling link removed (the file left the repo)" ;;
    esac
done

if command -v mangohud >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/share/mangohud-logs" && ok "~/.local/share/mangohud-logs exists (MangoHud logs there)"
fi
exit 0
