"""Shared building blocks so every panel looks the same. Nothing here opens a
GTK popup (menus, combos, tooltips): popups attached to a layer surface only
repaint when the compositor happens to redraw the bar, which is the lag this
whole program exists to avoid. Choices are inline lists in a Gtk.Revealer."""
from __future__ import annotations

import subprocess
import threading
from collections.abc import Callable

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk, Pango  # noqa: E402


def klass(widget: Gtk.Widget, *classes: str) -> Gtk.Widget:
    ctx = widget.get_style_context()
    for c in classes:
        ctx.add_class(c)
    return widget


def set_class(widget: Gtk.Widget, name: str, on: bool) -> None:
    ctx = widget.get_style_context()
    (ctx.add_class if on else ctx.remove_class)(name)


def label(text: str = "", *classes: str, xalign: float = 0.0, ellipsize: bool = False,
          max_chars: int | None = None) -> Gtk.Label:
    lbl = Gtk.Label(label=text)
    lbl.set_xalign(xalign)
    if ellipsize:
        lbl.set_ellipsize(Pango.EllipsizeMode.END)
    if max_chars:
        lbl.set_max_width_chars(max_chars)
    return klass(lbl, *classes)


def markup(text: str, *classes: str, xalign: float = 0.0) -> Gtk.Label:
    lbl = label("", *classes, xalign=xalign)
    lbl.set_markup(text)
    return lbl


def icon_button(glyph: str, on_click: Callable[[], object] | None = None, *classes: str) -> Gtk.Button:
    btn = Gtk.Button(label=glyph)
    klass(btn, "icon-btn", *classes)
    if on_click:
        btn.connect("clicked", lambda *_: on_click())
    return btn


def pill_button(text: str, on_click: Callable[[], object] | None = None, *classes: str) -> Gtk.Button:
    btn = Gtk.Button(label=text)
    klass(btn, "pill", *classes)
    if on_click:
        btn.connect("clicked", lambda *_: on_click())
    return btn


def switch(active: bool, on_toggle: Callable[[bool], object]) -> Gtk.Switch:
    """A Gtk.Switch whose handler is not re-entered when set_active() is called
    from a refresh (guard flag on the widget)."""
    sw = Gtk.Switch()
    sw.set_active(active)
    sw.set_valign(Gtk.Align.CENTER)
    sw._quiet = False  # type: ignore[attr-defined]

    def changed(w, _pspec):
        if not w._quiet:
            on_toggle(w.get_active())

    sw.connect("notify::active", changed)
    return sw


def switch_set(sw: Gtk.Switch, active: bool) -> None:
    sw._quiet = True  # type: ignore[attr-defined]
    sw.set_active(active)
    sw._quiet = False  # type: ignore[attr-defined]


def hbox(spacing: int = 8, *classes: str) -> Gtk.Box:
    return klass(Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=spacing), *classes)


def vbox(spacing: int = 4, *classes: str) -> Gtk.Box:
    return klass(Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=spacing), *classes)


def divider() -> Gtk.Box:
    return klass(Gtk.Box(), "divider")


def header(glyph: str, title: str, trailing: Gtk.Widget | None = None) -> Gtk.Box:
    """`glyph  Title ............ [trailing]` - the first row of every section."""
    row = hbox(10, "row", "section-header")
    row.pack_start(label(glyph, "section-icon"), False, False, 0)
    row.pack_start(label(title, "section-title"), True, True, 0)
    if trailing is not None:
        row.pack_end(trailing, False, False, 0)
    return row


def status(text: str = "") -> Gtk.Label:
    """Dim one-liner for state/errors under a section; empty text hides it."""
    lbl = label(text, "status", ellipsize=True)
    lbl.set_no_show_all(True)
    lbl.set_visible(bool(text))
    return lbl


def set_status(lbl: Gtk.Label, text: str, error: bool = False) -> None:
    lbl.set_text(text)
    lbl.set_visible(bool(text))
    set_class(lbl, "error", error)


def clear(box: Gtk.Container) -> None:
    for child in box.get_children():
        box.remove(child)


def revealer(child: Gtk.Widget, duration: int = 160) -> Gtk.Revealer:
    rev = Gtk.Revealer(transition_type=Gtk.RevealerTransitionType.SLIDE_DOWN,
                       transition_duration=duration)
    rev.add(child)
    return rev


def scrolled(child: Gtk.Widget, max_height: int) -> Gtk.ScrolledWindow:
    """Grows with its content up to max_height, then scrolls."""
    sw = Gtk.ScrolledWindow()
    sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    sw.set_propagate_natural_height(True)
    sw.set_max_content_height(max_height)
    sw.add(child)
    return sw


def run_detached(cmd: str | list[str]) -> None:
    """Fire-and-forget, detached from the popup's lifetime."""
    subprocess.Popen(cmd, shell=isinstance(cmd, str), stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def run_async(cmd: list[str], done: Callable[[int, str, str], object]) -> None:
    """Run cmd in a thread; `done(returncode, stdout, stderr)` on the GTK loop."""
    def work():
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            res = (p.returncode, p.stdout, p.stderr)
        except (OSError, subprocess.TimeoutExpired) as e:
            res = (127, "", str(e))
        GLib.idle_add(lambda: done(*res) and False)

    threading.Thread(target=work, daemon=True).start()


class Debounce:
    """Collapse a burst of change signals into one refresh."""

    def __init__(self, fn: Callable[[], object], ms: int = 120):
        self.fn, self.ms, self._id = fn, ms, None

    def __call__(self, *_args) -> None:
        if self._id is None:
            self._id = GLib.timeout_add(self.ms, self._fire)

    def _fire(self) -> bool:
        self._id = None
        self.fn()
        return False

    def cancel(self) -> None:
        if self._id is not None:
            GLib.source_remove(self._id)
            self._id = None
