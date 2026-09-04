"""Audio panel (formerly volpop).

    [speaker] ─────●──── 75%   HyperX Cloud III ▾
    [mic]     ───●────── 60%   HyperX Cloud III ▾
    Apps ▸   (per-stream rows: icon, name, slider, mute, device ▾)

Reads and writes PulseAudio/PipeWire through pactl's JSON output, and follows
`pactl subscribe` so a volume key or a new stream updates the sliders live.
Device choice is an inline list under the row, not a combo box.

Each app row's `device ▾` routes that stream somewhere other than the default
sink, for one of three lifetimes (this stream / this app until logout / this
app always) - see routing.py; the `barpop watch` daemon applies the app rules
to streams as they appear.
"""
from __future__ import annotations

import json
import subprocess

from .. import routing
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
        w.relabel(self.mute_btn, self.icon_for(pct, muted))
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


def rebuild_list(box: Gtk.Box, rows: dict, choices: list[tuple], current, on_pick) -> None:
    """Keep `box` showing `choices` [(key, label)] with `current` ticked.
    Widgets are reused when the keys are unchanged (only the tick moves),
    recreated otherwise."""
    # Compare against what was last built, not the dict's keys: PipeWire can
    # list one sink name twice (stale HDMI nodes), which would make the two
    # never match and rebuild - and flicker - on every refresh.
    keys = [k for k, _ in choices]
    if getattr(box, "_built_keys", None) != keys:
        box._built_keys = keys
        w.clear(box)
        rows.clear()
        for key, text in choices:
            if key in rows:
                continue   # a duplicate name: one row is enough, pactl addresses by name
            row = Gtk.Button()
            w.klass(row, "device-row")
            inner = w.hbox(8)
            check = w.label(" ", "device-check")
            inner.pack_start(check, False, False, 0)
            inner.pack_start(w.label(text, "device-name", ellipsize=True), True, True, 0)
            row.add(inner)
            row.connect("clicked", lambda _b, k=key: on_pick(k))
            box.pack_start(row, False, False, 0)
            rows[key] = (row, check)
        box.show_all()
    for key, (row, check) in rows.items():
        here = key == current
        w.set_class(row, "current", here)
        check.set_text("󰄬" if here else " ")


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
        self.rows: dict[str, tuple[Gtk.Button, Gtk.Label]] = {}

    def toggle(self):
        self.revealer.set_reveal_child(not self.revealer.get_reveal_child())

    def update(self, devices: list[dict], current: str):
        """Refreshes arrive on every pactl event; the list is only rebuilt when
        the set of devices changed. Rebuilding under the pointer would destroy
        the hovered button and make it flicker."""
        self.devices, self.current = devices, current
        cur = next((d for d in devices if d["name"] == current), None)
        w.relabel(self.button, (short_name(cur.get("description", cur["name"])) if cur else "—") + "  ▾")
        choices = [(d["name"], short_name(d.get("description", d["name"]))) for d in devices]
        rebuild_list(self.list, self.rows, choices, current, self._pick)

    def _pick(self, name: str):
        self.revealer.set_reveal_child(False)
        if name != self.current:
            self.on_pick(name)


class RoutePicker:
    """`Device ▾` on an app row, revealing: how long the choice should hold,
    then where to send the stream. on_pick(sink_or_None, scope)."""

    SCOPES = [("This stream", "stream"), ("This app, until logout", "session"), ("This app, always", "always")]
    GLYPH = {"session": "󰔛", "always": "󰐃"}

    def __init__(self, on_pick):
        self.on_pick = on_pick
        self.scope = "stream"
        self.button = w.pill_button("", self.toggle, "device-btn", "route-btn")
        body = w.vbox(4, "route-body")
        self.seg = w.Segmented(self.SCOPES, self.scope, self._set_scope)
        body.pack_start(self.seg, False, False, 0)
        self.list = w.vbox(2, "device-list")
        body.pack_start(self.list, False, False, 0)
        self.revealer = w.revealer(body)
        self.current: str | None = None
        self.rows: dict = {}

    def toggle(self):
        self.revealer.set_reveal_child(not self.revealer.get_reveal_child())

    def _set_scope(self, scope: str):
        self.scope = scope
        self.seg.set_current(scope)

    def update(self, devices: list[dict], sink_name: str, default_name: str, rule, pinned: bool):
        """rule is (sink, scope) from routing.rules() or None."""
        if rule:
            self.current = rule[0]
            dev = next((d for d in devices if d["name"] == rule[0]), None)
            text = f"{self.GLYPH[rule[1]]} " + (short_name(dev.get("description", dev["name"])) if dev
                                                 else "(device off)")
            if rule[1] != self.scope:
                self._set_scope(rule[1])
        elif pinned and sink_name != default_name:
            self.current = sink_name
            dev = next((d for d in devices if d["name"] == sink_name), None)
            text = short_name(dev.get("description", dev["name"])) if dev else sink_name
        else:
            self.current = None
            text = "Default"
        w.relabel(self.button, text + "  ▾")
        choices = [(None, "Default (follows the output above)")] + [
            (d["name"], short_name(d.get("description", d["name"]))) for d in devices]
        rebuild_list(self.list, self.rows, choices, self.current, self._pick)

    def _pick(self, name):
        self.revealer.set_reveal_child(False)
        self.on_pick(name, self.scope)


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

        self.app_rows: dict[int, Gtk.Box] = {}   # idx -> box(row, route revealer)
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
        sinks = pactl_json("sinks")
        by_index = {s["index"]: s["name"] for s in sinks}
        default_name = pactl("get-default-sink").strip()
        rules = routing.rules()
        pinned = routing.pinned_ids()
        seen = set()
        for si in inputs:
            idx = si["index"]
            seen.add(idx)
            props = si.get("properties", {})
            box = self.app_rows.get(idx)
            if box is None:
                icon, name = self._identify(props)
                box = self._app_row(idx, name or f"stream {idx}", icon, routing.app_key(props))
                self.app_rows[idx] = box
                self.apps_box.pack_start(box, False, False, 0)
                box.show_all()
            box.row.set_state(volume_pct(si), si.get("mute", False))
            box.route.update(sinks, by_index.get(si.get("sink"), ""), default_name,
                             rules.get(routing.app_key(props)), idx in pinned)
        for idx in list(self.app_rows):
            if idx not in seen:
                self.apps_box.remove(self.app_rows.pop(idx))
        n = len(self.app_rows)
        w.relabel(self.apps_toggle, ("󰅀" if self.apps_revealer.get_reveal_child() else "󰅂") + f"  Apps ({n})")

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

    def _app_row(self, idx: int, name: str, icon_name: str | None, key: str) -> Gtk.Box:
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
        route = RoutePicker(lambda sink, scope: self._route(idx, key, sink, scope))
        row.pack_end(route.button, False, False, 0)
        box = w.vbox(0, "app-entry")
        box.pack_start(row, False, False, 0)
        box.pack_start(route.revealer, False, False, 0)
        box.row, box.route = row, route
        return box

    def _route(self, idx: int, key: str, sink: str | None, scope: str):
        """Send stream idx (and, for app scopes, its siblings) to `sink`;
        None means back to the default output."""
        siblings = [si["index"] for si in pactl_json("sink-inputs")
                    if routing.app_key(si.get("properties", {})) == key] if scope != "stream" else [idx]
        if sink is None:
            if scope != "stream":
                routing.clear_rule(key)
            for i in siblings:
                routing.unpin(i)
        else:
            if scope != "stream":
                routing.set_rule(key, sink, scope)
            for i in siblings:
                routing.move(i, sink)
        self.refresh()

    # ── actions ──
    def _set_sink(self, name: str):
        # Streams without an explicit target follow the default and are moved
        # by WirePlumber; the routed ones (app rule or pinned stream) stay put
        # on purpose. Moving them by hand here would pin every stream, which
        # is what used to make later default changes fail to carry them.
        pactl("set-default-sink", name)
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
