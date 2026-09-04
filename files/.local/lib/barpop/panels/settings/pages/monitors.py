"""Monitors: what is connected, and a button to nwg-displays, which owns
monitors.lua. A placeholder page: the intent is an in-house layout tool that
writes monitors.lua itself and plugs in here."""
from __future__ import annotations

from .... import hypr
from .... import widgets as w
from . import Page
from gi.repository import Gtk  # noqa: E402


class MonitorsPage(Page):
    def __init__(self):
        super().__init__("Monitors", "󰍹", 70, "Hardware")

    def build(self, panel):
        body = w.vbox(6)
        head = w.hbox(8)
        head.pack_start(w.label(self.title, "settings-title"), True, True, 0)
        head.pack_end(w.pill_button("Arrange in nwg-displays", lambda: self._nwg(panel), "small"), False, False, 0)
        body.pack_start(head, False, False, 0)

        grid = Gtk.Grid(row_spacing=6, column_spacing=18)
        w.klass(grid, "settings-page", "about-grid")
        for col, title in enumerate(("output", "mode", "scale", "position", "workspace")):
            grid.attach(w.label(title, "settings-section"), col, 0, 1, 1)
        for row, m in enumerate(hypr.monitors(), start=1):
            cells = (
                f"{m.get('name', '?')}  {m.get('description', '')[:28]}",
                f"{m.get('width')}x{m.get('height')} @ {m.get('refreshRate', 0):.0f} Hz",
                str(m.get("scale")),
                f"{m.get('x')}, {m.get('y')}",
                str((m.get("activeWorkspace") or {}).get("name", "")),
            )
            for col, text in enumerate(cells):
                grid.attach(w.label(text, "setting-name" if col == 0 else "detail"), col, row, 1, 1)
        body.pack_start(grid, False, False, 0)
        note = w.label("Layout, modes and scale are edited in nwg-displays, which writes "
                       "~/.config/hypr/monitors.lua.", "setting-desc")
        note.set_margin_start(6)
        body.pack_start(note, False, False, 0)
        return body

    def _nwg(self, panel) -> None:
        w.run_detached("nwg-displays")
        panel.shell.quit()


PAGE = MonitorsPage()
