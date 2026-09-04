"""A grid of wallpaper previews; click one to run setwall. Same files and
thumbnail cache as the SUPER+W strip (~/.local/lib/wallthumbs.py)."""
from __future__ import annotations

import threading

import wallthumbs  # ~/.local/lib, on sys.path via bin/barpop

from .... import hypr
from .... import widgets as w
from . import Page
from .keybinds import pretty_combo
from gi.repository import GdkPixbuf, GLib, Gtk  # noqa: E402

TILE_W, TILE_H = 200, 112  # 16:9, four per row in the settings window


class WallpapersPage(Page):
    def __init__(self):
        super().__init__("Wallpapers", "󰸉", 60)

    def build(self, panel):
        body = w.vbox(6)
        head = w.hbox(8)
        head.pack_start(w.label(self.title, "settings-title"), True, True, 0)
        # the strip's actual bind, from the config's export (it may be rebound)
        keys = next((a.get("keys") or [] for a in hypr.export().get("actions", []) if a["id"] == "util.wallpaper"), [])
        hint = f"  ({pretty_combo(keys[0])})" if keys else ""
        head.pack_end(w.pill_button(f"Open strip{hint}", lambda: self._open_strip(panel), "small"), False, False, 0)
        body.pack_start(head, False, False, 0)

        self.flow = Gtk.FlowBox()
        self.flow.set_selection_mode(Gtk.SelectionMode.NONE)
        self.flow.set_max_children_per_line(4)
        self.flow.set_min_children_per_line(2)
        self.flow.set_row_spacing(8)
        self.flow.set_column_spacing(8)
        self.flow.set_homogeneous(True)
        self.flow.set_valign(Gtk.Align.START)
        w.klass(self.flow, "wall-grid")

        self.status = w.status("loading previews…")
        body.pack_start(self.status, False, False, 0)
        body.pack_start(w.scrolled(self.flow, 560), True, True, 0)

        self.current = wallthumbs.current_wallpaper()
        self.tiles: dict[str, Gtk.Button] = {}
        threading.Thread(target=self._load, daemon=True).start()
        return body

    # ── loading ──
    def _load(self) -> None:
        walls = wallthumbs.list_wallpapers()
        if not walls:
            GLib.idle_add(lambda: w.set_status(self.status, f"no images in {wallthumbs.WALL_DIR}", True) or False)
            return
        for path in walls:
            pb = wallthumbs.thumb_for(path)
            if pb is None:
                continue
            small = pb.scale_simple(TILE_W, TILE_H, GdkPixbuf.InterpType.BILINEAR)
            GLib.idle_add(self._add_tile, path, small)
        GLib.idle_add(lambda: w.set_status(self.status, "") or False)

    def _add_tile(self, path, pixbuf) -> bool:
        btn = Gtk.Button()
        w.klass(btn, "thumb")
        box = w.vbox(2)
        img = Gtk.Image.new_from_pixbuf(pixbuf)
        box.pack_start(img, False, False, 0)
        name = w.label(path.stem, "thumb-name", xalign=0.5, ellipsize=True, max_chars=22)
        box.pack_start(name, False, False, 0)
        btn.add(box)
        btn.connect("clicked", lambda *_: self._pick(path))
        self.tiles[str(path)] = btn
        w.set_class(btn, "current", self.current is not None and path.resolve() == self.current.resolve())
        self.flow.add(btn)
        btn.show_all()
        return False

    # ── actions ──
    def _pick(self, path) -> None:
        wallthumbs.apply(path)
        self.current = path
        for p, btn in self.tiles.items():
            w.set_class(btn, "current", p == str(path))
        w.set_status(self.status, f"applying {path.name}…")

    def _open_strip(self, panel) -> None:
        w.run_detached(str(wallthumbs.SETWALL.parent / "wallstrip"))
        panel.shell.quit()


PAGE = WallpapersPage()
