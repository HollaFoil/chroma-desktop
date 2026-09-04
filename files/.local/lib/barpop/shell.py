"""The overlay every panel is shown in, plus the CLI.

    barpop <panel> [--anchor left|right|center] [--offset PX]

Running it for the panel that is already open closes it (waybar click =
toggle); running it for a different panel swaps the content in place.
"""
from __future__ import annotations

import argparse
import os
import re
import signal
import sys
import time
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, Gio, GLib, Gtk, GtkLayerShell  # noqa: E402

from . import panels  # noqa: E402

HERE = Path(__file__).resolve().parent
COLORS = Path.home() / ".config/waybar/colors.css"
WAYBAR_CONFIG = Path.home() / ".config/waybar/config.jsonc"
STYLE = HERE / "style.css"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
PIDFILE = RUNTIME / "barpop.pid"        # "<pid>\n<panel>"
SWITCH_FILE = RUNTIME / "barpop.switch"  # panel name a running instance should swap to
GAP = 6                                  # between the bar and the card


def bar_height() -> int:
    """waybar's "height" (falls back to 37 if the config is unreadable)."""
    try:
        m = re.search(r'"height"\s*:\s*(\d+)', WAYBAR_CONFIG.read_text())
        return int(m.group(1)) if m else 37
    except OSError:
        return 37


_provider: Gtk.CssProvider | None = None


def load_css() -> None:
    """(Re)load colors.css + style.css; a second call swaps the provider so
    every widget retints in place."""
    global _provider
    css = (COLORS.read_text() if COLORS.exists() else "") + STYLE.read_text()
    provider = Gtk.CssProvider()
    provider.load_from_data(css.encode())
    screen = Gdk.Screen.get_default()
    if _provider is not None:
        Gtk.StyleContext.remove_provider_for_screen(screen, _provider)
    Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    _provider = provider


def watch_colors(on_change) -> Gio.FileMonitor:
    """Call on_change once per rewrite of colors.css (setwall while a popup is
    open, e.g. from the Wallpapers page). The monitor must be kept referenced."""
    monitor = Gio.File.new_for_path(str(COLORS)).monitor_file(Gio.FileMonitorFlags.NONE, None)
    pending = {"id": None}

    def fire():
        pending["id"] = None
        on_change()
        return False

    def changed(*_):
        if pending["id"] is None:
            pending["id"] = GLib.timeout_add(200, fire)

    monitor.connect("changed", changed)
    return monitor


class Overlay(Gtk.Window):
    """Transparent full-output layer surface; the card sits under the bar at the
    chosen edge, a click on the backdrop or Escape closes it."""

    def __init__(self, panel_name: str, anchor: str, offset: int, page: str | None = None):
        super().__init__(title="barpop")
        self.set_decorated(False)
        self.set_resizable(False)
        self.panel: panels.Panel | None = None
        self.anchor = anchor
        self.page = page  # a hint for panels with pages (settings --page look)

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_namespace(self, "barpop")
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.RIGHT,
                     GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_exclusive_zone(self, -1)

        # Close on key *release*: quitting while Escape is still held would
        # make the compositor's keyboard-enter to the window underneath list
        # the key as pressed, and GTK apps replay that as a fresh keypress.
        self._close_on_release = False
        # A panel recording a keybind sets this to a callable(event) -> bool;
        # while set, every key event goes to it and nothing else (so Escape
        # cancels the recording instead of closing the popup).
        self.key_grab = None
        self.connect("key-press-event", self._key_press)
        self.connect("key-release-event", self._key_release)

        backdrop = Gtk.EventBox()
        backdrop.set_visible_window(False)
        backdrop.connect("button-press-event", lambda *_: self.quit() or True)
        self.add(backdrop)

        self.card = Gtk.EventBox()  # swallows clicks so the backdrop never sees them
        self.card.set_visible_window(False)
        self.card.connect("button-press-event", lambda *_: True)
        self.offset = offset
        backdrop.add(self.card)

        self.frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.frame.get_style_context().add_class("popup")
        self.card.add(self.frame)

        self.show_panel(panel_name)

    def _place(self, placement: str) -> None:
        """Where the card sits: "bar" hangs under the bar at the anchored edge
        (menus), "center" floats in the middle of the output (the settings
        window). Re-applied on every panel swap since the launcher can hand
        over to either kind."""
        card = self.card
        card.set_margin_start(0)
        card.set_margin_end(0)
        if placement == "center":
            card.set_halign(Gtk.Align.CENTER)
            card.set_valign(Gtk.Align.CENTER)
            card.set_margin_top(0)
            return
        card.set_valign(Gtk.Align.START)
        card.set_margin_top(bar_height() + GAP)
        if self.anchor == "left":
            card.set_halign(Gtk.Align.START)
            card.set_margin_start(self.offset)
        elif self.anchor == "center":
            card.set_halign(Gtk.Align.CENTER)
        else:
            card.set_halign(Gtk.Align.END)
            card.set_margin_end(self.offset)

    # ── panels ──
    def show_panel(self, name: str) -> None:
        if self.panel is not None:
            self.panel.close()
            self.frame.remove(self.panel)
            self.frame.get_style_context().remove_class(f"popup-{self.panel.name}")
        cls = panels.get(name)
        self._place(cls.placement)
        self.frame.get_style_context().add_class(f"popup-{name}")
        self.panel = cls(self)
        self.frame.pack_start(self.panel, True, True, 0)
        self.panel.show_all()
        PIDFILE.write_text(f"{os.getpid()}\n{name}\n")

    # ── keys ──
    def _key_press(self, _w, ev):
        if self.key_grab is not None:
            return bool(self.key_grab(ev))
        if ev.keyval == Gdk.KEY_Escape:
            self._close_on_release = True
            return True
        return False

    def _key_release(self, _w, ev):
        if self.key_grab is not None:
            return True
        if self._close_on_release and ev.keyval == Gdk.KEY_Escape:
            self.quit()
            return True
        return False

    def colors_changed(self) -> None:
        """colors.css was rewritten: the CSS is already swapped; tell the panel
        so anything that read colour values (not tokens) can refresh."""
        hook = getattr(self.panel, "colors_changed", None)
        if hook:
            try:
                hook()
            except Exception as e:
                print(f"barpop: {type(self.panel).__name__}.colors_changed: {e}", file=sys.stderr)

    def quit(self) -> None:
        panel, self.panel = self.panel, None
        if panel is not None:
            try:
                panel.close()
            except Exception as e:  # never let teardown keep the overlay on screen
                print(f"barpop: {type(panel).__name__}.close: {e}", file=sys.stderr)
        Gtk.main_quit()


# ── single instance / toggle ─────────────────────────────────────────────────

def running() -> tuple[int, str] | None:
    try:
        pid_s, name = PIDFILE.read_text().split("\n")[:2]
        pid = int(pid_s)
        os.kill(pid, 0)
        return pid, name
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        PIDFILE.unlink(missing_ok=True)
        return None


def stop(pid: int) -> None:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    for _ in range(50):  # wait for it to release the pidfile
        time.sleep(0.01)
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            break
    PIDFILE.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="barpop", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("panel", nargs="?", help="one of: " + ", ".join(panels.names())
                    + "; or 'watch' to run the notification watcher (see watch.py)")
    ap.add_argument("--anchor", choices=("left", "right", "center"), default="right")
    ap.add_argument("--offset", type=int, default=10, help="px from the anchored edge")
    ap.add_argument("--page", help="for panels with pages (settings): the page to open")
    ap.add_argument("--list", action="store_true", help="list panels and exit")
    args = ap.parse_args(argv)

    if args.list or not args.panel:
        print("\n".join(panels.names()))
        return 0
    if args.panel == "watch":
        from .watch import main as watch_main
        return watch_main()
    if args.panel not in panels.names():
        print(f"barpop: no panel '{args.panel}' (have: {', '.join(panels.names())})", file=sys.stderr)
        return 2

    inst = running()
    if inst:
        pid, name = inst
        if name == args.panel:      # same panel -> toggle off
            stop(pid)
            return 0
        SWITCH_FILE.write_text(args.panel)  # different panel -> ask it to swap
        try:
            os.kill(pid, signal.SIGUSR1)
            return 0
        except ProcessLookupError:
            SWITCH_FILE.unlink(missing_ok=True)

    load_css()
    win = Overlay(args.panel, args.anchor, args.offset, args.page)
    win.show_all()
    win.present()

    def on_switch(*_):
        try:
            name = SWITCH_FILE.read_text().strip()
            SWITCH_FILE.unlink(missing_ok=True)
        except OSError:
            return True
        if name in panels.names():
            win.show_panel(name)
        return True

    def on_colors():
        load_css()
        win.colors_changed()

    monitor = watch_colors(on_colors)  # noqa: F841  (kept alive for the loop's lifetime)
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, on_switch)
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda *_: win.quit() or True)
    try:
        Gtk.main()
    finally:
        PIDFILE.unlink(missing_ok=True)
    return 0
