"""The top-left Arch menu: a list of actions and a row of power buttons."""
from __future__ import annotations

from pathlib import Path

from .. import widgets as w  # requires the Gtk 3 version before the import below
from . import Panel, register
from gi.repository import Gtk  # noqa: E402

HOME = Path.home()

# (glyph, label, action). An action is a shell command string, or a panel name
# prefixed with "panel:" to swap the popup's content instead of closing it.
# Audio and network are not listed: they open from their own bar modules and
# live as pages inside Settings.
ITEMS = [
    ("󰀻", "Applications",  f"{HOME}/.local/bin/rofi-launcher"),
    ("󰅌", "Clipboard",     f"{HOME}/.local/bin/rofi-cliphist"),
    ("󰹑", "Screenshot",    'grim -g "$(slurp)" - | wl-copy'),
    ("󰂚", "Notifications", "swaync-client -t -sw"),
    ("󰒓", "Settings",      "panel:settings"),
]

POWER = [
    ("󰌾", "Lock",     "hyprlock"),
    ("󰤄", "Suspend",  "systemctl suspend"),
    ("󰍃", "Log out",  "hyprctl dispatch 'hl.dsp.exit()'"),
    ("󰜉", "Reboot",   "systemctl reboot"),
    ("󰐥", "Shut down", "systemctl poweroff"),
]


@register
class Launcher(Panel):
    name = "launcher"

    def __init__(self, shell):
        super().__init__(shell)
        for glyph, text, action in ITEMS:
            self.pack_start(self._item(glyph, text, action), False, False, 0)

        self.pack_start(w.divider(), False, False, 0)

        row = w.hbox(4, "power-row")
        row.set_homogeneous(True)
        for glyph, text, cmd in POWER:
            btn = Gtk.Button()
            w.klass(btn, "power-btn")
            box = w.vbox(2)
            box.pack_start(w.label(glyph, "power-icon", xalign=0.5), False, False, 0)
            box.pack_start(w.label(text, "power-label", xalign=0.5), False, False, 0)
            btn.add(box)
            btn.connect("clicked", lambda _b, c=cmd: self._run(c))
            row.pack_start(btn, True, True, 0)
        self.pack_start(row, False, False, 0)

    def _item(self, glyph: str, text: str, action: str) -> Gtk.Button:
        btn = Gtk.Button()
        w.klass(btn, "item")
        box = w.hbox(12)
        box.pack_start(w.label(glyph, "item-icon"), False, False, 0)
        box.pack_start(w.label(text, "item-label"), True, True, 0)
        if action.startswith("panel:"):
            box.pack_end(w.label("󰅂", "item-chevron"), False, False, 0)
        btn.add(box)
        btn.connect("clicked", lambda *_: self._run(action))
        return btn

    def _run(self, action: str) -> None:
        if action.startswith("panel:"):
            self.shell.show_panel(action[6:])
            return
        w.run_detached(action)
        self.shell.quit()
