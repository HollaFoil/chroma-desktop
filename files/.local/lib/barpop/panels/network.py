"""Network panel: Wi-Fi, hotspot, wired, Bluetooth, Tailscale.

Each block is a `Section`; a section whose `available()` is False is simply
not shown (no Bluetooth adapter, no tailscale binary...). Plugins can add
their own via NETWORK_SECTIONS in ~/.config/barpop/plugins/*.py. The sections
are hosted by a NetworkHost: here all of them in the bar's popup, and one or
two at a time on the settings pages (Wi-Fi, Bluetooth, Connections).

Wi-Fi and the hotspot go through libnm (GObject introspection, live signals);
Bluetooth talks to BlueZ over the system bus; Tailscale is its CLI.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import time
from pathlib import Path

import gi

from .. import widgets as w
from . import Panel, plugin_network_sections, register

gi.require_version("NM", "1.0")
from gi.repository import Gio, GLib, GObject, Gtk, NM  # noqa: E402

Mode = getattr(NM, "80211Mode")                 # PyGObject cannot spell digit-first names
ApFlags = getattr(NM, "80211ApFlags")
SecFlags = getattr(NM, "80211ApSecurityFlags")

INTENT_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "barpop.intent"
SCAN_SECONDS = 15

WIFI_ICONS = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
# row actions are glyphs, not words: link / link-off / plus / refresh / delete
CONNECT, DISCONNECT, PAIR, SCAN, FORGET = "󰌷", "󰌸", "󰐕", "󰑐", "󰆴"
BT_ICONS = {
    "audio-headset": "󰋋", "audio-headphones": "󰋋", "audio-card": "󰓃",
    "input-mouse": "󰍽", "input-keyboard": "󰌌", "input-gaming": "󰊴",
    "phone": "󰄜", "computer": "󰇅",
}


def wifi_icon(strength: int) -> str:
    return WIFI_ICONS[min(4, max(0, (strength + 12) // 25))]


def ssid_of(ap_or_bytes) -> str:
    data = ap_or_bytes.get_ssid() if hasattr(ap_or_bytes, "get_ssid") else ap_or_bytes
    if not data:
        return ""
    return NM.utils_ssid_to_utf8(data.get_data()) or ""


class Section(Gtk.Box):
    """One block of the panel. `panel.nm` is the shared NM.Client; call
    `panel.refresh_soon()` from any change signal."""

    @classmethod
    def available(cls, panel) -> bool:
        return True

    def __init__(self, panel):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        w.klass(self, "section")
        self.panel = panel
        self.nm: NM.Client = panel.nm
        self.status = w.status()

    def refresh(self) -> None:
        pass

    def close(self) -> None:
        pass

    # helpers
    def wifi_device(self):
        return next((d for d in self.nm.get_devices() if d.get_device_type() == NM.DeviceType.WIFI), None)

    def active_for(self, connection) -> NM.ActiveConnection | None:
        uuid = connection.get_uuid()
        return next((a for a in self.nm.get_active_connections() if a.get_uuid() == uuid), None)

    def done(self, finish, what: str):
        """Async-callback factory: `finish` is the bound *_finish method of the
        object the call was made on; libnm errors land on the status line."""
        def cb(_src, res):
            try:
                finish(res)
                w.set_status(self.status, "")
            except GLib.Error as e:
                w.set_status(self.status, f"{what}: {e.message}", error=True)
            self.panel.refresh_soon()
        return cb

    @staticmethod
    def intend(uuid: str) -> None:
        """Record that *we* are about to change this connection, so the watcher
        (`barpop watch`) does not announce it as an outside event."""
        try:
            with INTENT_FILE.open("a") as f:
                f.write(f"{time.time():.0f} {uuid}\n")
        except OSError:
            pass


# ── Wi-Fi ────────────────────────────────────────────────────────────────────

class Wifi(Section):
    @classmethod
    def available(cls, panel) -> bool:
        return any(d.get_device_type() == NM.DeviceType.WIFI for d in panel.nm.get_devices())

    def __init__(self, panel):
        super().__init__(panel)
        self.switch = w.switch(self.nm.wireless_get_enabled(), self._set_enabled)
        self.pack_start(w.header("󰖩", "Wi-Fi", self.switch), False, False, 0)
        self.notice = w.status()
        self.pack_start(self.notice, False, False, 0)

        self.list = w.vbox(2, "ap-list")
        self.list_scroll = w.scrolled(self.list, 240)
        self.list_scroll.set_no_show_all(True)
        self.pack_start(self.list_scroll, False, False, 0)

        self.prompt_for: str | None = None        # ssid awaiting a password
        self.prompt = w.hbox(6, "prompt")
        self.entry = Gtk.Entry()
        self.entry.set_visibility(False)
        self.entry.set_placeholder_text("password")
        self.entry.set_hexpand(True)
        self.entry.connect("activate", lambda *_: self._join())
        self.prompt.pack_start(self.entry, True, True, 0)
        self.prompt.pack_start(w.icon_button(CONNECT, self._join, "small"), False, False, 0)
        self.prompt.pack_start(w.icon_button("󰅖", self._cancel_prompt, "small"), False, False, 0)
        self.prompt_rev = w.revealer(self.prompt)
        self.pack_start(self.prompt_rev, False, False, 0)
        self.pack_start(self.status, False, False, 0)

        self.dev = self.wifi_device()
        self._sigs = []
        if self.dev:
            for sig in ("access-point-added", "access-point-removed", "notify::active-access-point",
                        "notify::mode", "state-changed"):
                self._sigs.append(self.dev.connect(sig, self._changed))
            self.dev.request_scan_async(None, lambda *_: None)
            self._scan_id = GLib.timeout_add_seconds(12, self._rescan)
        self.refresh()

    def _changed(self, dev, *args):
        # state-changed carries (new, old, reason); explain a failed attempt
        if len(args) == 3 and args[0] == NM.DeviceState.FAILED:
            reason = NM.DeviceStateReason(args[2]).value_nick.replace("-", " ")
            w.set_status(self.status, f"connection failed ({reason})", error=True)
        self.panel.refresh_soon()

    def _rescan(self):
        if self.dev and self.dev.get_mode() != Mode.AP and self.nm.wireless_get_enabled():
            self.dev.request_scan_async(None, lambda *_: None)
        return True

    def refresh(self):
        w.switch_set(self.switch, self.nm.wireless_get_enabled())
        self.list_scroll.hide()
        if not self.dev or not self.nm.wireless_get_enabled():
            w.clear(self.list)
            self._sig = None
            w.set_status(self.notice, "Wi-Fi is off")
            return
        if self.dev.get_mode() == Mode.AP:
            w.clear(self.list)
            self._sig = None
            w.set_status(self.notice, "hotspot is using the radio — turn it off to join a network")
            return
        w.set_status(self.notice, "")
        self.list_scroll.show()

        saved = {}
        for con in self.nm.get_connections():
            s = con.get_setting_wireless()
            if s and s.get_mode() != "ap":
                saved[ssid_of(s.get_ssid())] = con
        active_ap = self.dev.get_active_access_point()
        active_ssid = ssid_of(active_ap) if active_ap else ""

        best: dict[str, NM.AccessPoint] = {}
        for ap in self.dev.get_access_points():
            ssid = ssid_of(ap)
            if ssid and (ssid not in best or ap.get_strength() > best[ssid].get_strength()):
                best[ssid] = ap
        aps = sorted(best.values(), key=lambda a: (ssid_of(a) != active_ssid,
                                                   ssid_of(a) not in saved, -a.get_strength()))
        # Rebuild only when something visible changed (strength in 5-step
        # buckets): recreating the rows under the pointer flickers the hover.
        sig = tuple((ssid_of(a), ssid_of(a) == active_ssid, ssid_of(a) in saved, a.get_strength() // 5)
                    for a in aps)
        if sig == getattr(self, "_sig", None) and self.list.get_children():
            return
        self._sig = sig
        w.clear(self.list)
        if not aps:
            self.list.pack_start(w.label("scanning…", "empty"), False, False, 0)
        for ap in aps:
            self.list.pack_start(self._ap_row(ap, ssid_of(ap) == active_ssid, saved.get(ssid_of(ap))),
                                 False, False, 0)
        self.list.show_all()

    def _ap_row(self, ap, active: bool, saved) -> Gtk.Box:
        ssid = ssid_of(ap)
        secured = bool(ap.get_flags() & ApFlags.PRIVACY) or ap.get_wpa_flags() or ap.get_rsn_flags()
        row = w.hbox(8, "row", "ap-row")
        w.set_class(row, "active", active)
        row.pack_start(w.label(wifi_icon(ap.get_strength()), "ap-icon"), False, False, 0)
        row.pack_start(w.label(ssid, "ap-name", ellipsize=True), True, True, 0)
        if secured:
            row.pack_start(w.label("󰌾", "ap-lock"), False, False, 0)
        if active:
            row.pack_end(w.icon_button(DISCONNECT, lambda: self._disconnect(), "small", "action"), False, False, 0)
        else:
            row.pack_end(w.icon_button(CONNECT, lambda: self._connect(ap, saved, bool(secured)), "small", "action"),
                         False, False, 0)
        if saved is not None:
            row.pack_end(w.icon_button(FORGET, lambda: self._forget(saved), "small", "danger"), False, False, 0)
        return row

    # actions
    def _set_enabled(self, on: bool):
        self.nm.dbus_set_property(NM.DBUS_PATH, NM.DBUS_INTERFACE, "WirelessEnabled",
                                  GLib.Variant("b", on), -1, None, None, None)

    def _connect(self, ap, saved, secured: bool):
        self._cancel_prompt()
        if saved is not None:
            w.set_status(self.status, f"connecting to {ssid_of(ap)}…")
            self.intend(saved.get_uuid())
            self.nm.activate_connection_async(saved, self.dev, ap.get_path(), None,
                                              self.done(self.nm.activate_connection_finish, "connect"))
        elif secured:
            self.prompt_for = ssid_of(ap)
            self._prompt_ap = ap
            self.entry.set_text("")
            self.prompt_rev.set_reveal_child(True)
            self.entry.grab_focus()
        else:
            self._add_and_activate(ap, None)

    def _join(self):
        if self.prompt_for and self.entry.get_text():
            self._add_and_activate(self._prompt_ap, self.entry.get_text())
            self._cancel_prompt()

    def _cancel_prompt(self):
        self.prompt_for = None
        self.prompt_rev.set_reveal_child(False)

    def _add_and_activate(self, ap, psk: str | None):
        ssid = ssid_of(ap)
        con = NM.SimpleConnection.new()
        s_con = NM.SettingConnection(id=ssid, type="802-11-wireless", uuid=NM.utils_uuid_generate())
        s_wifi = NM.SettingWireless(ssid=GLib.Bytes.new(ssid.encode()), mode="infrastructure")
        con.add_setting(s_con)
        con.add_setting(s_wifi)
        if psk is not None:
            rsn = ap.get_rsn_flags()
            sae_only = (rsn & SecFlags.KEY_MGMT_SAE) and not (rsn & SecFlags.KEY_MGMT_PSK)
            con.add_setting(NM.SettingWirelessSecurity(key_mgmt="sae" if sae_only else "wpa-psk", psk=psk))
        w.set_status(self.status, f"connecting to {ssid}…")
        self.intend(s_con.get_uuid())
        self.nm.add_and_activate_connection_async(
            con, self.dev, ap.get_path(), None,
            self.done(self.nm.add_and_activate_connection_finish, "connect"))

    def _disconnect(self):
        active = self.dev.get_active_connection()
        if active:
            self.intend(active.get_uuid())
        self.dev.disconnect_async(None, self.done(self.dev.disconnect_finish, "disconnect"))

    def _forget(self, con):
        con.delete_async(None, self.done(con.delete_finish, "forget"))

    def close(self):
        if self.dev:
            for s in self._sigs:  # NM.Device.disconnect() is the *network* disconnect
                GObject.signal_handler_disconnect(self.dev, s)
            GLib.source_remove(self._scan_id)


# ── Hotspot ──────────────────────────────────────────────────────────────────

class Hotspot(Section):
    """Toggles the saved AP-mode connection (there is one: `hotspot`)."""

    @classmethod
    def available(cls, panel) -> bool:
        return cls.connection(panel.nm) is not None and Wifi.available(panel)

    @staticmethod
    def connection(nm):
        for con in nm.get_connections():
            s = con.get_setting_wireless()
            if s and s.get_mode() == "ap":
                return con
        return None

    def __init__(self, panel):
        super().__init__(panel)
        self.con = self.connection(self.nm)
        self.switch = w.switch(self.active_for(self.con) is not None, self._toggle)
        self.pack_start(w.header("󱜠", "Hotspot", self.switch), False, False, 0)
        self.detail = w.label("", "detail", ellipsize=True)
        self.pack_start(self.detail, False, False, 0)
        self.pack_start(self.status, False, False, 0)
        self._tick = GLib.timeout_add_seconds(5, self._poll)
        self.refresh()

    def _poll(self):
        self.refresh()
        return True

    def refresh(self):
        active = self.active_for(self.con)
        w.switch_set(self.switch, active is not None)
        ssid = ssid_of(self.con.get_setting_wireless().get_ssid())
        if active is None:
            self.detail.set_text(f"{ssid} · off")
            return
        dev = self.wifi_device()
        clients = 0
        if dev:
            out = subprocess.run(["iw", "dev", dev.get_iface(), "station", "dump"],
                                 capture_output=True, text=True).stdout
            clients = out.count("Station ")
        self.detail.set_text(f"{ssid} · {clients} client{'s' if clients != 1 else ''}")

    def _toggle(self, on: bool):
        active = self.active_for(self.con)
        self.intend(self.con.get_uuid())
        if on and active is None:
            w.set_status(self.status, "starting hotspot…")
            self.nm.activate_connection_async(self.con, self.wifi_device(), None, None,
                                              self.done(self.nm.activate_connection_finish, "hotspot"))
        elif not on and active is not None:
            self.nm.deactivate_connection_async(active, None,
                                                self.done(self.nm.deactivate_connection_finish, "hotspot"))

    def close(self):
        GLib.source_remove(self._tick)


# ── Wired ────────────────────────────────────────────────────────────────────

class Wired(Section):
    """Read-only: each managed ethernet device with its state and address."""

    @staticmethod
    def devices(nm):
        return [d for d in nm.get_devices()
                if d.get_device_type() == NM.DeviceType.ETHERNET and d.get_state() != NM.DeviceState.UNMANAGED]

    @classmethod
    def available(cls, panel) -> bool:
        return bool(cls.devices(panel.nm))

    def __init__(self, panel):
        super().__init__(panel)
        self.rows = w.vbox(2)
        self.pack_start(self.rows, False, False, 0)
        self.refresh()

    def refresh(self):
        w.clear(self.rows)
        for dev in self.devices(self.nm):
            up = dev.get_state() == NM.DeviceState.ACTIVATED
            ip = dev.get_ip4_config()
            addr = next((a.get_address() for a in ip.get_addresses()), "") if (up and ip) else ""
            text = f"{dev.get_iface()} · {addr}" if addr else f"{dev.get_iface()} · {dev.get_state().value_nick}"
            row = w.header("󰈀", "Wired", w.label(text, "detail"))
            w.set_class(row, "inactive", not up)
            self.rows.pack_start(row, False, False, 0)
        self.rows.show_all()


# ── Bluetooth (BlueZ over D-Bus) ─────────────────────────────────────────────

BLUEZ = "org.bluez"


class Bluetooth(Section):
    @classmethod
    def available(cls, panel) -> bool:
        return panel.bus is not None and cls.adapter_path(panel.bus) is not None

    @staticmethod
    def objects(bus) -> dict:
        try:
            res = bus.call_sync(BLUEZ, "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
                                None, GLib.VariantType("(a{oa{sa{sv}}})"), Gio.DBusCallFlags.NONE, 2000, None)
            return res.unpack()[0]
        except GLib.Error:
            return {}

    @classmethod
    def adapter_path(cls, bus) -> str | None:
        for path, ifaces in cls.objects(bus).items():
            if "org.bluez.Adapter1" in ifaces:
                return path
        return None

    def __init__(self, panel):
        super().__init__(panel)
        self.bus: Gio.DBusConnection = panel.bus
        self.adapter = self.adapter_path(self.bus)
        self.discovering = False

        self.switch = w.switch(False, self._set_powered)
        self.scan_btn = w.icon_button(SCAN, self._scan, "small", "action")
        trailing = w.hbox(4)
        trailing.pack_start(self.scan_btn, False, False, 0)
        trailing.pack_start(self.switch, False, False, 0)
        self.pack_start(w.header("󰂯", "Bluetooth", trailing), False, False, 0)

        self.list = w.vbox(2, "bt-list")
        self.pack_start(w.scrolled(self.list, 200), False, False, 0)
        self.pack_start(self.status, False, False, 0)

        self._subs = [
            self.bus.signal_subscribe(BLUEZ, "org.freedesktop.DBus.Properties", "PropertiesChanged", None,
                                      None, Gio.DBusSignalFlags.NONE, self._signal),
            self.bus.signal_subscribe(BLUEZ, "org.freedesktop.DBus.ObjectManager", None, "/", None,
                                      Gio.DBusSignalFlags.NONE, self._signal),
        ]
        self._scan_stop = None
        self.refresh()

    def _signal(self, *_):
        self.panel.refresh_soon()

    def refresh(self):
        objs = self.objects(self.bus)
        ad = objs.get(self.adapter, {}).get("org.bluez.Adapter1", {})
        powered = bool(ad.get("Powered", False))
        self.discovering = bool(ad.get("Discovering", False))
        w.switch_set(self.switch, powered)
        w.set_class(self.scan_btn, "busy", self.discovering)   # pulses while scanning
        self.scan_btn.set_sensitive(powered)

        if not powered:
            if getattr(self, "_sig", None) != "off":
                self._sig = "off"
                w.clear(self.list)
                self.list.pack_start(w.label("Bluetooth is off", "empty"), False, False, 0)
                self.list.show_all()
            return
        devices = [(p, i["org.bluez.Device1"]) for p, i in objs.items() if "org.bluez.Device1" in i]
        # Paired devices always (connected on top). Strangers only while a scan
        # is running, and only named ones - a dorm has hundreds of nameless
        # beacons. BlueZ keeps everything it has ever seen until it times out,
        # so _stop_scan() purges the unpaired ones explicitly.
        devices = [(p, d) for p, d in devices
                   if d.get("Paired") or (self.discovering and d.get("Name"))]
        devices.sort(key=lambda pd: (not pd[1].get("Connected"), not pd[1].get("Paired"),
                                     -(pd[1].get("RSSI") or -100), pd[1].get("Alias", "")))
        # RSSI ticks in every second during discovery; only a change in what
        # the rows show (not their order by signal) is worth rebuilding for.
        sig = tuple((p, bool(d.get("Connected")), bool(d.get("Paired")), d.get("Alias"),
                     d.get("Battery Percentage")) for p, d in devices)
        if sig == getattr(self, "_sig", None):
            return
        self._sig = sig
        w.clear(self.list)
        if not devices:
            self.list.pack_start(w.label("no paired devices — Scan to find one", "empty"), False, False, 0)
        for path, d in devices:
            self.list.pack_start(self._device_row(path, d), False, False, 0)
        self.list.show_all()

    def _device_row(self, path: str, d: dict) -> Gtk.Box:
        connected, paired = bool(d.get("Connected")), bool(d.get("Paired"))
        row = w.hbox(8, "row", "bt-row")
        w.set_class(row, "active", connected)
        row.pack_start(w.label(BT_ICONS.get(d.get("Icon", ""), "󰂯"), "bt-icon"), False, False, 0)
        row.pack_start(w.label(d.get("Alias") or d.get("Address", "?"), "bt-name", ellipsize=True), True, True, 0)
        # same shape as the Wi-Fi rows: one action glyph, trash for saved ones
        if connected:
            pct = d.get("Battery Percentage")
            if pct is not None:
                row.pack_start(w.label(f"{pct}%", "ap-state"), False, False, 0)
            row.pack_end(w.icon_button(DISCONNECT, lambda: self._call(path, "Disconnect"), "small", "action"),
                         False, False, 0)
        elif paired:
            row.pack_end(w.icon_button(CONNECT, lambda: self._call(path, "Connect"), "small", "action"),
                         False, False, 0)
        else:
            row.pack_end(w.icon_button(PAIR, lambda: self._pair(path), "small", "action"), False, False, 0)
        if paired:
            row.pack_end(w.icon_button(FORGET, lambda: self._remove(path), "small", "danger"), False, False, 0)
        return row

    # actions
    def _set_prop(self, path: str, iface: str, name: str, value: GLib.Variant):
        self.bus.call(BLUEZ, path, "org.freedesktop.DBus.Properties", "Set",
                      GLib.Variant("(ssv)", (iface, name, value)), None, Gio.DBusCallFlags.NONE, -1, None,
                      self._finished(f"set {name}"))

    def _call(self, path: str, method: str, then=None):
        w.set_status(self.status, f"{method.lower()}ing…")
        self.bus.call(BLUEZ, path, "org.bluez.Device1", method, None, None, Gio.DBusCallFlags.NONE,
                      30000, None, self._finished(method.lower(), then))

    def _finished(self, what: str, then=None):
        def cb(bus, res):
            try:
                bus.call_finish(res)
                w.set_status(self.status, "")
                if then:
                    then()
            except GLib.Error as e:
                msg = e.message.split(":")[-1].strip()
                w.set_status(self.status, f"{what}: {msg}", error=True)
            self.panel.refresh_soon()
        return cb

    def _set_powered(self, on: bool):
        self._set_prop(self.adapter, "org.bluez.Adapter1", "Powered", GLib.Variant("b", on))

    def _scan(self):
        if self.discovering:
            return
        self.bus.call(BLUEZ, self.adapter, "org.bluez.Adapter1", "StartDiscovery", None, None,
                      Gio.DBusCallFlags.NONE, -1, None, self._finished("scan"))
        self._scan_stop = GLib.timeout_add_seconds(SCAN_SECONDS, self._stop_scan)

    def _stop_scan(self):
        self._scan_stop = None
        if self.discovering:
            self.bus.call(BLUEZ, self.adapter, "org.bluez.Adapter1", "StopDiscovery", None, None,
                          Gio.DBusCallFlags.NONE, -1, None, lambda *_: self._purge_strangers())
        return False

    def _purge_strangers(self):
        """Forget every unpaired device BlueZ cached during the scan."""
        for path, ifaces in self.objects(self.bus).items():
            d = ifaces.get("org.bluez.Device1")
            if d and not d.get("Paired") and not d.get("Connected"):
                self.bus.call(BLUEZ, self.adapter, "org.bluez.Adapter1", "RemoveDevice",
                              GLib.Variant("(o)", (path,)), None, Gio.DBusCallFlags.NONE, -1, None,
                              lambda *_: None)

    def _pair(self, path: str):
        # pair -> trust (so it reconnects on its own) -> connect
        def trust_and_connect():
            self._set_prop(path, "org.bluez.Device1", "Trusted", GLib.Variant("b", True))
            self._call(path, "Connect")
        self._call(path, "Pair", trust_and_connect)

    def _remove(self, path: str):
        self.bus.call(BLUEZ, self.adapter, "org.bluez.Adapter1", "RemoveDevice", GLib.Variant("(o)", (path,)),
                      None, Gio.DBusCallFlags.NONE, -1, None, self._finished("remove"))

    def close(self):
        for s in self._subs:
            self.bus.signal_unsubscribe(s)
        if self._scan_stop:
            GLib.source_remove(self._scan_stop)
        self._stop_scan()


# ── Tailscale ────────────────────────────────────────────────────────────────

class Tailscale(Section):
    @classmethod
    def available(cls, panel) -> bool:
        return shutil.which("tailscale") is not None

    def __init__(self, panel):
        super().__init__(panel)
        self.switch = w.switch(False, self._toggle)
        self.pack_start(w.header("󰖂", "Tailscale", self.switch), False, False, 0)
        self.detail = w.label("", "detail", ellipsize=True)
        self.pack_start(self.detail, False, False, 0)
        self.pack_start(self.status, False, False, 0)
        self.refresh()

    def refresh(self):
        w.run_async(["tailscale", "status", "--json"], self._got_status)

    def _got_status(self, rc: int, out: str, err: str):
        import json
        if rc != 0:
            w.switch_set(self.switch, False)
            self.detail.set_text((err.strip() or "tailscaled not running").splitlines()[-1])
            return
        st = json.loads(out)
        up = st.get("BackendState") == "Running"
        w.switch_set(self.switch, up)
        me = st.get("Self") or {}
        ips = me.get("TailscaleIPs") or []
        name = (me.get("DNSName") or "").rstrip(".").split(".")[0]
        peers = sum(1 for p in (st.get("Peer") or {}).values() if p.get("Online"))
        self.detail.set_text(f"{name} · {ips[0]} · {peers} peers online" if up and ips
                             else st.get("BackendState", "").lower())

    def _toggle(self, on: bool):
        w.set_status(self.status, "tailscale up…" if on else "tailscale down…")

        def done(rc, out, err):
            if rc != 0:
                hint = "  (allow: sudo tailscale set --operator=$USER)" if "permission" in err.lower() or "access denied" in err.lower() else ""
                w.set_status(self.status, (err.strip().splitlines() or ["failed"])[-1] + hint, error=True)
            else:
                w.set_status(self.status, "")
            self.refresh()
        w.run_async(["tailscale", "up" if on else "down"], done)


# ── panel ────────────────────────────────────────────────────────────────────

# top to bottom: the cable, the radio it shares with the hotspot, then the rest
BUILTIN_SECTIONS = [Wired, Wifi, Hotspot, Bluetooth, Tailscale]


class NetworkHost:
    """What the sections need from their surroundings: the shared NM.Client,
    the system bus, and a debounced refresh() over the sections it holds. The
    bar's Network panel hosts all of them in one card; the settings pages host
    one or two each (Wi-Fi, Bluetooth, Connections)."""

    def __init__(self):
        self.nm = NM.Client.new(None)
        try:
            self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        except GLib.Error:
            self.bus = None
        self._debounce = w.Debounce(self.refresh, 150)
        self.sections: list[Section] = []
        self._nm_sigs = [self.nm.connect(sig, self.refresh_soon) for sig in (
            "notify::wireless-enabled", "notify::active-connections", "device-added", "device-removed",
            "connection-added", "connection-removed", "notify::connectivity", "notify::state")]

    def build(self, classes) -> list[Section]:
        """Instantiate the available ones of `classes`, in order."""
        out = []
        for cls in classes:
            try:
                if not cls.available(self):
                    continue
                sec = cls(self)
            except Exception as e:  # one broken section must not hide the rest
                print(f"barpop: network section {cls.__name__} failed: {e}", flush=True)
                continue
            self.sections.append(sec)
            out.append(sec)
        return out

    def refresh_soon(self, *_):
        self._debounce()

    def refresh(self):
        for sec in self.sections:
            try:
                sec.refresh()
            except Exception as e:
                print(f"barpop: refresh {type(sec).__name__}: {e}", flush=True)

    def close(self):
        self._debounce.cancel()
        for s in self._nm_sigs:
            self.nm.disconnect(s)
        self._nm_sigs = []
        for sec in self.sections:
            sec.close()
        self.sections = []


def advanced_editor(shell) -> None:
    """nm-connection-editor, or nmtui in a terminal; closes the popup."""
    if shutil.which("nm-connection-editor"):
        w.run_detached("nm-connection-editor")
    else:
        w.run_detached("kitty --title nmtui sh -c 'sleep 0.1; nmtui'")
    shell.quit()


@register
class Network(Panel):
    name = "network"

    def __init__(self, shell):
        super().__init__(shell)
        self.host = NetworkHost()
        for sec in self.host.build(BUILTIN_SECTIONS + plugin_network_sections()):
            if self.get_children():
                self.pack_start(w.divider(), False, False, 0)
            self.pack_start(sec, False, False, 0)

        self.pack_start(w.divider(), False, False, 0)
        adv = w.pill_button("󰒓  All connections…", lambda: advanced_editor(self.shell), "apps-toggle")
        adv.set_halign(Gtk.Align.START)
        self.pack_start(adv, False, False, 0)

    def close(self):
        self.host.close()
