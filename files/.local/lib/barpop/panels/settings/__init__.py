"""Settings: a window in the middle of the screen, opened from the Arch menu
(or `barpop settings`, SUPER + comma).

    ┌──────────┬──────────────────────────────┐
    │ Keybinds │  page title                  │
    │ Windows  │  section                     │
    │ Look     │   option ..... [control]     │
    │ Input    │   option ..... [control]     │
    │ ...      │                              │
    └──────────┴──────────────────────────────┘

Every page is a module in pages/ exporting PAGE: a `title`, `glyph`, `order`,
`group` (the nav caption it sits under, see pages.GROUPS) and a
build(panel) -> Gtk.Widget. Pages are built when first shown and kept; the
widget's shown()/hidden() are called on nav changes, close() on teardown.
Hyprland option pages are lists of option names rendered by options.OptionRow
from `hyprctl descriptions`, so adding an option to a page is one line.
"""
from __future__ import annotations

import importlib
import pkgutil
import sys

from ... import widgets as w
from .. import Panel, register
from gi.repository import Gtk  # noqa: E402

from . import pages as _pages_pkg


def load_pages() -> list:
    out = []
    for info in pkgutil.iter_modules(_pages_pkg.__path__):
        try:
            mod = importlib.import_module(f"{_pages_pkg.__name__}.{info.name}")
        except Exception as e:  # one broken page must not hide the rest
            print(f"barpop settings: page {info.name} failed to import: {e}", file=sys.stderr)
            continue
        page = getattr(mod, "PAGE", None)
        if page is not None:
            out.append(page)
    return sorted(out, key=lambda p: p.order)


@register
class Settings(Panel):
    name = "settings"
    placement = "center"

    def __init__(self, shell):
        super().__init__(shell)
        self.set_orientation(Gtk.Orientation.HORIZONTAL)
        self.set_spacing(0)
        self.pages = load_pages()
        self.built: dict[str, object] = {}
        self.current = None

        nav = w.vbox(2, "settings-nav")
        self.nav_buttons: dict[str, Gtk.Button] = {}
        groups = _pages_pkg.GROUPS + sorted({p.group for p in self.pages} - set(_pages_pkg.GROUPS))
        by_group = {g: [p for p in self.pages if p.group == g] for g in groups}
        for group in groups:
            if not by_group[group]:
                continue
            cap = w.label(group, "nav-group")
            if nav.get_children():
                cap.set_margin_top(10)
            nav.pack_start(cap, False, False, 0)
            for page in by_group[group]:
                nav.pack_start(self._nav_button(page), False, False, 0)
        self.pack_start(nav, False, False, 0)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(120)
        self.stack.set_hexpand(True)
        w.klass(self.stack, "settings-body")
        self.pack_start(self.stack, True, True, 0)

        wanted = (getattr(shell, "page", None) or "").lower()
        start = next((p for p in self.pages if p.title.lower().startswith(wanted)), None) if wanted else None
        if start or self.pages:
            self.show_page(start or self.pages[0])

    def _nav_button(self, page) -> Gtk.Button:
        btn = Gtk.Button()
        w.klass(btn, "item", "nav-item")
        box = w.hbox(12)
        box.pack_start(w.label(page.glyph, "item-icon"), False, False, 0)
        box.pack_start(w.label(page.title, "item-label"), True, True, 0)
        btn.add(box)
        btn.connect("clicked", lambda _b, p=page: self.show_page(p))
        self.nav_buttons[page.title] = btn
        return btn

    def show_page(self, page) -> None:
        if self.current is not None and self.current is not page:
            hook = getattr(self.built.get(self.current.title), "hidden", None)
            if hook:
                hook()
        if page.title not in self.built:
            widget = page.build(self)
            widget.show_all()
            self.stack.add_named(widget, page.title)
            self.built[page.title] = widget
        self.stack.set_visible_child_name(page.title)
        hook = getattr(self.built[page.title], "shown", None)
        if hook:
            hook()
        for title, btn in self.nav_buttons.items():
            w.set_class(btn, "on", title == page.title)
        self.current = page

    def colors_changed(self) -> None:
        for widget in self.built.values():
            hook = getattr(widget, "colors_changed", None)
            if hook:
                hook()

    def close(self) -> None:
        for widget in self.built.values():
            closer = getattr(widget, "close", None)
            if closer:
                closer()
