"""Audio panel (formerly volpop).

    [speaker] ─────●──── 75%   HyperX Cloud III ▾
    [mic]     ───●────── 60%   HyperX Cloud III ▾
    Apps ▸   (per-stream rows: icon, name, slider, mute)

Reads and writes PulseAudio/PipeWire through pactl's JSON output, and follows
`pactl subscribe` so a volume key or a new stream updates the sliders live.
Device choice is an inline list under the row, not a combo box.
"""
from __future__ import annotations

import json
import subprocess

from .. import widgets as w
from . import Panel, register
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

# Modded clients report their own names; show the real product instead.
# Keys are matched case-insensitively against application.name, the process
# binary and node.name; values are (icon-theme name, label).
APP_OVERRIDES = {
    "spotify": ("spotify-launcher", "Spotify"),   # spicetify'd client, icon from spotify-launcher
    "vesktop": ("discord", "Discord"),
    "webcord": ("discord", "Discord"),
    "armcord": ("discord", "Discord"),
}

SPEAKER_ICONS = ["󰕿", "󰖀", "󰕾"]
SPEAKER_MUTED = "󰝟"
MIC_ICON = "󰍬"
MIC_MUTED = "󰍭"


# ── pactl ────────────────────────────────────────────────────────────────────

def pactl(*args: str) -> str:
    return subprocess.run(["pactl", *args], capture_output=True, text=True).stdout


def pactl_json(kind: str) -> list[dict]:
    try:
        return json.loads(pactl("-f", "json", "list", kind) or "[]")
    except json.JSONDecodeError:
        return []


def volume_pct(obj: dict) -> int:
    chans = obj.get("volume", {}).values()
    vals = [int(c["value_percent"].rstrip("%")) for c in chans if "value_percent" in c]
    return max(vals) if vals else 0


def speaker_icon(pct: int, muted: bool) -> str:
    if muted or pct == 0:
        return SPEAKER_MUTED
    return SPEAKER_ICONS[min(2, pct * 3 // 101)]


def short_name(desc: str) -> str:
    """'GP102 HDMI Audio Controller Digital Stereo (HDMI) [LG QHD]' -> 'LG QHD'."""
    if "[" in desc and desc.endswith("]"):
        return desc[desc.rindex("[") + 1:-1]
    for suffix in (" Analog Stereo", " Digital Stereo", " Stereo", " Mono"):
        desc = desc.replace(suffix, "")
    return desc.strip()


# ── widgets ──────────────────────────────────────────────────────────────────

class VolumeRow(Gtk.Box):
    """icon-button · slider · percent  (+ optional trailing widget)."""

    def __init__(self, on_toggle_mute, on_volume, icon_for):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        w.klass(self, "row")
        self.on_toggle_mute = on_toggle_mute
        self.on_volume = on_volume
        self.icon_for = icon_for
        self._updating = False
        self._pending: int | None = None
        self._flush_id = None

        self.mute_btn = w.icon_button("", self.on_toggle_mute)

        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.scale.set_draw_value(False)
        self.scale.set_hexpand(True)
        self.scale.connect("value-changed", self._changed)
        self.scale.connect("scroll-event", self._scroll)

        self.pct = w.label("", "pct", xalign=1.0)

        self.pack_start(self.mute_btn, False, False, 0)
        self.pack_start(self.scale, True, True, 0)
        self.pack_start(self.pct, False, False, 0)

    def set_state(self, pct: int, muted: bool):
        self._updating = True
        self.scale.set_value(pct)
        self._updating = False
        self.pct.set_text(f"{pct}%")
        self.mute_btn.set_label(self.icon_for(pct, muted))
        w.set_class(self, "muted", muted)
        w.set_class(self.mute_btn, "muted", muted)

    def _scroll(self, _w, event):
        step = 5
        if event.direction == Gdk.ScrollDirection.UP:
            self.scale.set_value(self.scale.get_value() + step)
        elif event.direction == Gdk.ScrollDirection.DOWN:
            self.scale.set_value(self.scale.get_value() - step)
        elif event.direction == Gdk.ScrollDirection.SMOOTH:
            self.scale.set_value(self.scale.get_value() - event.delta_y * step)
        return True

    def _changed(self, scale):
        v = int(round(scale.get_value()))
        self.pct.set_text(f"{v}%")
        if self._updating:
            return
        self._pending = v  # coalesce drags into one pactl call per frame-ish
        if self._flush_id is None:
            self._flush_id = GLib.timeout_add(40, self._flush)

    def _flush(self):
        self._flush_id = None
        if self._pending is not None:
            self.on_volume(self._pending)
            self._pending = None
        return False


class DevicePicker:
    """A `Name ▾` button on the row plus an inline list of devices revealed
    under it. `on_pick(name)` is called with the pactl device name."""

    def __init__(self, on_pick):
        self.on_pick = on_pick
        self.button = w.pill_button("", self.toggle, "device-btn")
        self.list = w.vbox(2, "device-list")
        self.revealer = w.revealer(self.list)
        self.devices: list[dict] = []
        self.current = ""

    def toggle(self):
        self.revealer.set_reveal_child(not self.revealer.get_reveal_child())

    def update(self, devices: list[dict], current: str):
        self.devices, self.current = devices, current
        cur = next((d for d in devices if d["name"] == current), None)
        self.button.set_label((short_name(cur.get("description", cur["name"])) if cur else "—") + "  ▾")
        w.clear(self.list)
        for d in devices:
            row = Gtk.Button()
            w.klass(row, "device-row")
            w.set_class(row, "current", d["name"] == current)
            box = w.hbox(8)
            box.pack_start(w.label("󰄬" if d["name"] == current else " ", "device-check"), False, False, 0)
            box.pack_start(w.label(short_name(d.get("description", d["name"])), "device-name",
                                   ellipsize=True), True, True, 0)
            row.add(box)
            row.connect("clicked", lambda _b, n=d["name"]: self._pick(n))
            self.list.pack_start(row, False, False, 0)
        self.list.show_all()

    def _pick(self, name: str):
        self.revealer.set_reveal_child(False)
        if name != self.current:
            self.on_pick(name)


# ── panel ────────────────────────────────────────────────────────────────────

@register
class Audio(Panel):
    name = "audio"

    def __init__(self, shell):
        super().__init__(shell)

        self.sink_pick = DevicePicker(self._set_sink)
        self.sink_row = VolumeRow(self._toggle_sink_mute, self._set_sink_volume, speaker_icon)
        self.sink_row.pack_end(self.sink_pick.button, False, False, 0)
        self.pack_start(self.sink_row, False, False, 0)
        self.pack_start(self.sink_pick.revealer, False, False, 0)

        self.source_pick = DevicePicker(self._set_source)
        self.source_row = VolumeRow(self._toggle_source_mute, self._set_source_volume,
                                    lambda _p, m: MIC_MUTED if m else MIC_ICON)
        self.source_row.pack_end(self.source_pick.button, False, False, 0)
        self.pack_start(self.source_row, False, False, 0)
        self.pack_start(self.source_pick.revealer, False, False, 0)

        self.pack_start(w.divider(), False, False, 0)

        # per-app streams, collapsed by default
        self.apps_toggle = w.pill_button("󰅂  Apps", self._toggle_apps, "apps-toggle")
        self.apps_toggle.set_halign(Gtk.Align.START)
        self.pack_start(self.apps_toggle, False, False, 0)
        self.apps_box = w.vbox(4)
        self.apps_revealer = w.revealer(self.apps_box, 180)
        self.pack_start(self.apps_revealer, False, False, 0)

        self.app_rows: dict[int, VolumeRow] = {}
        self.refresh()
        self._subscribe()

    # ── state ──
    def refresh(self):
        sinks = pactl_json("sinks")
        sources = [s for s in pactl_json("sources") if not s["name"].endswith(".monitor")]
        default_sink = pactl("get-default-sink").strip()
        default_source = pactl("get-default-source").strip()

        sink = next((s for s in sinks if s["name"] == default_sink), sinks[0] if sinks else None)
        if sink:
            self.sink_row.set_state(volume_pct(sink), sink.get("mute", False))
        self.sink_pick.update(sinks, default_sink)

        source = next((s for s in sources if s["name"] == default_source), sources[0] if sources else None)
        if source:
            self.source_row.set_state(volume_pct(source), source.get("mute", False))
        self.source_pick.update(sources, default_source)

        self._refresh_apps()

    def _refresh_apps(self):
        inputs = pactl_json("sink-inputs")
        seen = set()
        for si in inputs:
            idx = si["index"]
            seen.add(idx)
            props = si.get("properties", {})
            row = self.app_rows.get(idx)
            if row is None:
                icon, name = self._identify(props)
                row = self._app_row(idx, name or f"stream {idx}", icon)
                self.app_rows[idx] = row
                self.apps_box.pack_start(row, False, False, 0)
                row.show_all()
            row.set_state(volume_pct(si), si.get("mute", False))
        for idx in list(self.app_rows):
            if idx not in seen:
                self.apps_box.remove(self.app_rows.pop(idx))
        n = len(self.app_rows)
        self.apps_toggle.set_label(("󰅀" if self.apps_revealer.get_reveal_child() else "󰅂")
                                   + f"  Apps ({n})")

    @staticmethod
    def _identify(props: dict) -> tuple[str | None, str | None]:
        """(icon name, label) for a stream, honouring APP_OVERRIDES."""
        keys = (props.get("application.name"), props.get("application.process.binary"),
                props.get("node.name"))
        for k in keys:
            if k and k.lower() in APP_OVERRIDES:
                return APP_OVERRIDES[k.lower()]
        return (props.get("application.icon_name") or props.get("application.process.binary"),
                props.get("application.name") or props.get("media.name"))

    def _app_row(self, idx: int, name: str, icon_name: str | None) -> VolumeRow:
        row = VolumeRow(lambda: self._toggle_input_mute(idx),
                        lambda v: pactl("set-sink-input-volume", str(idx), f"{v}%"),
                        speaker_icon)
        lbl = w.label(name, "app-name", ellipsize=True, max_chars=14)
        lbl.set_width_chars(12)
        theme = Gtk.IconTheme.get_default()
        if not (icon_name and theme.has_icon(icon_name)):
            icon_name = "audio-x-generic-symbolic"
        img = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
        img.set_pixel_size(16)
        w.klass(img, "app-icon")
        row.pack_start(img, False, False, 0)
        row.reorder_child(img, 1)
        row.pack_start(lbl, False, False, 0)
        row.reorder_child(lbl, 2)
        return row

    # ── actions ──
    def _set_sink(self, name: str):
        pactl("set-default-sink", name)
        for idx in self.app_rows:  # move live streams so the change is audible now
            pactl("move-sink-input", str(idx), name)
        self.refresh()

    def _set_source(self, name: str):
        pactl("set-default-source", name)
        self.refresh()

    def _toggle_sink_mute(self):
        pactl("set-sink-mute", "@DEFAULT_SINK@", "toggle")
        self.refresh()

    def _toggle_source_mute(self):
        pactl("set-source-mute", "@DEFAULT_SOURCE@", "toggle")
        self.refresh()

    def _toggle_input_mute(self, idx: int):
        pactl("set-sink-input-mute", str(idx), "toggle")
        self.refresh()

    def _set_sink_volume(self, v: int):
        pactl("set-sink-volume", "@DEFAULT_SINK@", f"{v}%")

    def _set_source_volume(self, v: int):
        pactl("set-source-volume", "@DEFAULT_SOURCE@", f"{v}%")

    def _toggle_apps(self):
        self.apps_revealer.set_reveal_child(not self.apps_revealer.get_reveal_child())
        self._refresh_apps()

    # ── live updates ──
    def _subscribe(self):
        self.sub = subprocess.Popen(["pactl", "subscribe"], stdout=subprocess.PIPE, text=True)
        self._debounced = w.Debounce(self.refresh, 80)
        self._watch = GLib.io_add_watch(self.sub.stdout, GLib.IO_IN | GLib.IO_HUP, self._on_event)

    def _on_event(self, stream, cond):
        if cond & GLib.IO_HUP:
            return False
        stream.readline()
        self._debounced()
        return True

    def close(self):
        self._debounced.cancel()
        try:
            self.sub.terminate()
        except Exception:
            pass
