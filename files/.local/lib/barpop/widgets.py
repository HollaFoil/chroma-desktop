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
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk, Pango  # noqa: E402


def klass(widget: Gtk.Widget, *classes: str) -> Gtk.Widget:
    ctx = widget.get_style_context()
    for c in classes:
        ctx.add_class(c)
    return widget


def relabel(btn: Gtk.Button, text: str) -> None:
    """set_label only on change: Gtk.Button.set_label rebuilds its child label
    every call, which under a refresh loop shows as flicker."""
    if btn.get_label() != text:
        btn.set_label(text)


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


def check(active: bool, on_toggle: Callable[[bool], object], text: str = "") -> Gtk.CheckButton:
    """A Gtk.CheckButton with the same re-entrancy guard as switch()."""
    cb = Gtk.CheckButton(label=text)
    cb.set_active(active)
    cb._quiet = False  # type: ignore[attr-defined]
    klass(cb, "check")

    def toggled(w):
        if not w._quiet:
            on_toggle(w.get_active())

    cb.connect("toggled", toggled)
    return cb


def check_set(cb: Gtk.CheckButton, active: bool) -> None:
    cb._quiet = True  # type: ignore[attr-defined]
    cb.set_active(active)
    cb._quiet = False  # type: ignore[attr-defined]


class Slider(Gtk.Box):
    """`──●──── 12` : a scale with its value beside it. on_change(value) is
    debounced so a drag does not fire once per pixel; set_value() from a
    refresh does not call it at all."""

    def __init__(self, lo: float, hi: float, step: float, value: float,
                 on_change: Callable[[float], object], digits: int = 0, width: int = 190,
                 suffix: str = ""):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.digits, self.suffix = digits, suffix
        self._quiet = False
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, lo, hi, step)
        self.scale.set_draw_value(False)
        self.scale.set_size_request(width, -1)
        self.scale.set_value(value)
        self.value_label = label(self._fmt(value), "pct", xalign=1.0)
        self.pack_start(self.scale, True, True, 0)
        self.pack_start(self.value_label, False, False, 0)
        self._emit = Debounce(lambda: on_change(self.get_value()), 80)
        self.scale.connect("value-changed", self._changed)
        self.scale.connect("scroll-event", self._scroll)

    def _fmt(self, v: float) -> str:
        return (f"{v:.{self.digits}f}" if self.digits else str(int(round(v)))) + self.suffix

    def get_value(self) -> float:
        v = self.scale.get_value()
        return round(v, self.digits) if self.digits else int(round(v))

    def set_value(self, v: float) -> None:
        self._quiet = True
        self.scale.set_value(v)
        self.value_label.set_text(self._fmt(v))
        self._quiet = False

    def _changed(self, scale):
        self.value_label.set_text(self._fmt(scale.get_value()))
        if not self._quiet:
            self._emit()

    def _scroll(self, _w, event):
        step = self.scale.get_adjustment().get_step_increment()
        if event.direction == Gdk.ScrollDirection.UP:
            self.scale.set_value(self.scale.get_value() + step)
        elif event.direction == Gdk.ScrollDirection.DOWN:
            self.scale.set_value(self.scale.get_value() - step)
        elif event.direction == Gdk.ScrollDirection.SMOOTH:
            self.scale.set_value(self.scale.get_value() - event.delta_y * step)
        return True


class Segmented(Gtk.Box):
    """A row of pills, one lit: the layer-surface stand-in for a combo box."""

    def __init__(self, options: list[tuple[str, object]], current, on_pick: Callable[[object], object]):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        klass(self, "segmented")
        self.buttons: dict[object, Gtk.Button] = {}
        for text, value in options:
            btn = pill_button(text, lambda v=value: on_pick(v), "small", "seg")
            self.buttons[value] = btn
            self.pack_start(btn, False, False, 0)
        self.set_current(current)

    def set_current(self, current) -> None:
        for value, btn in self.buttons.items():
            set_class(btn, "on", value == current)


def entry(text: str, on_commit: Callable[[str], object], width_chars: int = 18) -> Gtk.Entry:
    """Commits on Enter or focus-out."""
    ent = Gtk.Entry()
    ent.set_text(text)
    ent.set_width_chars(width_chars)
    ent.connect("activate", lambda e: on_commit(e.get_text()))
    ent.connect("focus-out-event", lambda e, _ev: on_commit(e.get_text()) and False)
    return ent
