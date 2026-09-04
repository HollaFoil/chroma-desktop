"""`barpop watch` - announce network changes that did not come from the menu.

Runs as a user service. Follows NetworkManager's active connections and posts
a desktop notification when a Wi-Fi, wired or hotspot connection comes or
goes - unless barpop itself asked for it moments ago (the panel appends
"<epoch> <uuid>" to $XDG_RUNTIME_DIR/barpop.intent before every activate /
deactivate). This replaces kded's networkmanagement popups, which fire for
everything and cannot tell who did it.
"""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import gi

gi.require_version("NM", "1.0")
from gi.repository import Gio, GLib, NM  # noqa: E402

INTENT_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "barpop.intent"
INTENT_TTL = 20            # seconds an intent stays valid
SETTLE_MS = 700            # let activate->deactivate->activate flaps collapse

# connection type -> (label, icon). Anything else (tun, bridge, veth...) is
# plumbing that comes and goes on its own and is not announced.
KINDS = {
    "802-11-wireless": ("Wi-Fi", "network-wireless-symbolic"),
    "802-3-ethernet": ("Wired", "network-wired-symbolic"),
    "hotspot": ("Hotspot", "network-wireless-hotspot-symbolic"),
}


def describe(ac: NM.ActiveConnection) -> tuple[str, str] | None:
    """(kind, display name) or None for connection types we do not announce.
    Wireless ones are named by SSID rather than the profile id."""
    t = ac.get_connection_type()
    if t not in KINDS:
        return None
    name = ac.get_id()
    if t == "802-11-wireless":
        con = ac.get_connection()
        s = con.get_setting_wireless() if con else None
        if s:
            if s.get_ssid():
                name = NM.utils_ssid_to_utf8(s.get_ssid().get_data()) or name
            if s.get_mode() == "ap":
                t = "hotspot"
    return t, name


class Watcher:
    def __init__(self):
        self.nm = NM.Client.new(None)
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.known = self.snapshot()
        self._settle = None
        self.nm.connect("notify::active-connections", self.changed)

    def snapshot(self) -> dict[str, tuple[str, str]]:
        """uuid -> (kind, id) for the active connections we care about, only
        once they are fully up (ACTIVATING flickers during a reconnect)."""
        out = {}
        for ac in self.nm.get_active_connections():
            desc = describe(ac)
            if desc and ac.get_state() == NM.ActiveConnectionState.ACTIVATED:
                out[ac.get_uuid()] = desc
        return out

    def changed(self, *_):
        if self._settle is None:
            self._settle = GLib.timeout_add(SETTLE_MS, self.diff)

    def diff(self):
        self._settle = None
        now = self.snapshot()
        intents = self.read_intents()
        for uuid, (kind, name) in now.items():
            if uuid not in self.known and uuid not in intents:
                self.notify(kind, name, up=True)
        for uuid, (kind, name) in self.known.items():
            if uuid not in now and uuid not in intents:
                self.notify(kind, name, up=False)
        self.known = now
        return False

    @staticmethod
    def read_intents() -> set[str]:
        """Recent intents; the file is rewritten with only the live ones."""
        try:
            lines = INTENT_FILE.read_text().splitlines()
        except OSError:
            return set()
        cutoff = time.time() - INTENT_TTL
        live = []
        for line in lines:
            try:
                ts, uuid = line.split()
                if float(ts) >= cutoff:
                    live.append((ts, uuid))
            except ValueError:
                continue
        try:
            INTENT_FILE.write_text("".join(f"{ts} {u}\n" for ts, u in live))
        except OSError:
            pass
        return {u for _, u in live}

    def notify(self, kind: str, name: str, up: bool):
        label, icon = KINDS[kind]
        if kind == "hotspot":
            summary, body = f"Hotspot {'on' if up else 'off'}", name
        else:
            summary = f"{label} {'connected' if up else 'disconnected'}"
            body = name if kind == "802-11-wireless" else ""
        hints = {"urgency": GLib.Variant("y", 1), "category": GLib.Variant("s", "network"),
                 "transient": GLib.Variant("b", True)}
        try:
            self.bus.call_sync(
                "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                "org.freedesktop.Notifications", "Notify",
                GLib.Variant("(susssasa{sv}i)", ("barpop", 0, icon, summary, body, [], hints, 4000)),
                None, Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error as e:
            print(f"barpop watch: notify failed: {e.message}", file=sys.stderr)


def main() -> int:
    Watcher()
    GLib.MainLoop().run()
    return 0
