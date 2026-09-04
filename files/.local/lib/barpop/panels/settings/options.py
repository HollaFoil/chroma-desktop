"""Hyprland options as rows, typed from `hyprctl descriptions`.

    name            ●  ↺         [switch | pills | ──●── 12 | entry]
    description in small dim text

The schema entry decides the control: bool -> switch, int with a `map` ->
pills, int/float with min/max -> slider, css gaps ("5 5 5 5") -> one int
slider for all four sides, other strings -> entry. Colours and lists are shown
read-only: the palette owns the colours (conf/look.lua) and there is no good
inline editor for a list. A change is applied live and written to
state/settings.json (hypr.set_option); the dot marks an option with an
override, ↺ removes it and reloads so the conf/*.lua value comes back.
"""
from __future__ import annotations

import re
from collections.abc import Callable

from ... import hypr
from ... import widgets as w
from gi.repository import Gtk, Pango  # noqa: E402

GAP_RE = re.compile(r"^\s*-?\d+(\s+-?\d+){0,3}\s*$")
COLOR_RE = re.compile(r"^[0-9a-fA-F]{8}( .*)?$")
COLOR_NAME_RE = re.compile(r"(^|[:._])col(or)?([._]|$)")   # col.x, x_color, background_color

# Sliders for numbers whose schema has no range: (lo, hi, step) by option.
FALLBACK_RANGE = {
    "int": (0, 100, 1),
    "float": (0.0, 1.0, 0.01),
    "gap": (0, 60, 1),
}


def kind(entry: dict) -> str:
    """bool, enum, color, int, float, percent (a 0..1 float), gap, str, list.
    getoption's type (`vtype`) is authoritative when present: descriptions
    gives active_opacity the default `1`, which JSON makes an int."""
    d = entry.get("default")
    vt = entry.get("vtype")
    if entry.get("map"):
        return "enum"
    if COLOR_NAME_RE.search(entry["name"]) or vt == "gradient" or (isinstance(d, str) and COLOR_RE.match(d)):
        return "color"   # ints too: misc:background_color is an argb int
    if vt == "bool" or (vt is None and isinstance(d, bool)):
        return "bool"
    if vt == "float" or (vt is None and isinstance(d, float)):
        return "percent" if entry.get("min") == 0 and entry.get("max") == 1 else "float"
    if vt == "int" or (vt is None and isinstance(d, int)):
        return "int"
    if vt == "css" or (isinstance(d, str) and GAP_RE.match(d) and "gap" in entry["name"]):
        return "gap"
    if vt == "str" or isinstance(d, str):
        return "choice" if str_choices(entry) else "str"
    return "list"


def gap_value(text) -> int:
    try:
        return int(str(text).split()[0])
    except (ValueError, IndexError):
        return 0


def sentence(text: str) -> str:
    """Capitalise the first letter, leave the rest alone (acronyms, names)."""
    return text[:1].upper() + text[1:] if text else text


def pretty(name: str) -> str:
    """'decoration:blur:enabled' -> 'Blur enabled'"""
    parts = name.split(":")[1:] or name.split(":")
    return sentence(" ".join(parts).replace("_", " ").replace(".", " "))


def enum_options(entry: dict) -> list[tuple[str, int]]:
    pairs = []
    for item in entry.get("map") or []:
        for text, value in item.items():
            pairs.append((sentence(text.replace("_", " ")), value))
    return sorted(pairs, key=lambda p: p[1])


CHOICES_RE = re.compile(r"\[([a-z0-9_]+(?:/[a-z0-9_]+)+)(?:/[^\]]*)?\]")


def str_choices(entry: dict) -> list[tuple[str, str]]:
    """'which layout to use. [dwindle/master/scrolling/monocle/lua:<name>]'
    -> the plain words as pills; anything with a placeholder is left out."""
    m = CHOICES_RE.search(entry.get("description", ""))
    if not m:
        return []
    return [(c, c) for c in m.group(1).split("/")]


class Schema:
    """One `hyprctl descriptions` call, shared by every page of a panel."""

    def __init__(self):
        self.entries: dict[str, dict] = {}
        self.refresh()

    def refresh(self) -> None:
        self.entries = {e["name"]: e for e in hypr.descriptions()}
        self.overrides = set(hypr.settings()["options"])

    def get(self, name: str) -> dict | None:
        return self.entries.get(name)

    def names(self) -> list[str]:
        return list(self.entries)


class OptionRow(Gtk.Box):
    def __init__(self, schema: Schema, name: str, on_changed: Callable[[], object] | None = None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        w.klass(self, "setting-row")
        self.schema, self.name, self.on_changed = schema, name, on_changed
        entry = schema.get(name) or {"name": name, "description": "(unknown option)", "default": ""}
        self.kind = kind(entry)
        self.entry = entry

        top = w.hbox(8)
        head = w.hbox(6)
        head.pack_start(w.label(pretty(name), "setting-name"), False, False, 0)
        self.dot = w.label("●", "override-dot")
        self.dot.set_no_show_all(True)
        head.pack_start(self.dot, False, False, 0)
        self.reset_btn = w.icon_button("󰦛", self._reset, "small", "action", "reset-btn")
        self.reset_btn.set_no_show_all(True)
        head.pack_start(self.reset_btn, False, False, 0)
        top.pack_start(head, True, True, 0)

        self.control = self._build_control(entry)
        if self.control is not None:
            self.control.set_valign(Gtk.Align.CENTER)
            top.pack_end(self.control, False, False, 0)
        self.pack_start(top, False, False, 0)

        desc = w.label(sentence(entry.get("description", "")), "setting-desc")
        desc.set_line_wrap(True)
        desc.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        desc.set_max_width_chars(60)
        self.pack_start(desc, False, False, 0)

        self.status = w.status()
        self.pack_start(self.status, False, False, 0)
        self.refresh()

    # ── controls ──
    def _build_control(self, entry: dict):
        cur = entry.get("current")
        k = self.kind
        if k == "bool":
            return w.switch(bool(cur), self._set)
        if k in ("enum", "choice"):
            self.seg = w.Segmented(enum_options(entry) if k == "enum" else str_choices(entry), cur, self._set)
            return self.seg
        if k == "percent":   # a 0..1 float shown as 0..100 %
            self.slider = w.Slider(0, 100, 1, round((cur or 0) * 100), self._set, suffix="%")
            return self.slider
        if k in ("int", "float", "gap"):
            lo, hi = entry.get("min"), entry.get("max")
            if lo is None or hi is None or hi <= lo:
                lo, hi, step = FALLBACK_RANGE[k]
            else:
                step = 1 if k != "float" else max(round((hi - lo) / 100, 2), 0.01)
            digits = 2 if k == "float" else 0
            value = gap_value(cur) if k == "gap" else (cur or 0)
            self.slider = w.Slider(lo, hi, step, value, self._set, digits=digits)
            return self.slider
        if k == "str":
            self.text = w.entry(str(cur or ""), self._set_text)
            return self.text
        return w.label(self._readonly_text(cur), "setting-readonly", ellipsize=True, max_chars=28)

    def _readonly_text(self, cur) -> str:
        if self.kind == "color":
            if isinstance(cur, int):          # argb packed int
                return f"#{cur & 0xFFFFFF:06x}  (from the palette)"
            return f"{cur}  (from the palette)"
        return str(cur)

    # ── state ──
    def refresh(self) -> None:
        entry = self.schema.get(self.name) or self.entry
        cur = entry.get("current")
        k = self.kind
        if k == "bool":
            w.switch_set(self.control, bool(cur))
        elif k in ("enum", "choice"):
            self.seg.set_current(cur)
        elif k == "percent":
            self.slider.set_value(round((cur or 0) * 100))
        elif k in ("int", "float", "gap"):
            self.slider.set_value(gap_value(cur) if k == "gap" else (cur or 0))
        elif k == "str":
            self.text.set_text(str(cur or ""))
        else:
            self.control.set_text(self._readonly_text(cur))
        overridden = self.name in self.schema.overrides
        self.dot.set_visible(overridden)
        self.reset_btn.set_visible(overridden)

    def _set(self, value) -> None:
        if self.kind in ("int", "gap", "enum"):
            value = int(value)
        elif self.kind == "percent":
            value = round(value / 100, 2)
        elif self.kind == "float":
            value = float(value)
        err = hypr.set_option(self.name, value)
        w.set_status(self.status, err or "", error=bool(err))
        if not err:
            self.schema.overrides.add(self.name)
            self.dot.set_visible(True)
            self.reset_btn.set_visible(True)
            if self.on_changed:
                self.on_changed()

    def _set_text(self, text: str) -> None:
        if text != str(self.entry.get("current", "")):
            self._set(text)

    def _reset(self) -> None:
        hypr.reset_option(self.name)
        self.schema.refresh()
        self.refresh()
        w.set_status(self.status, "")
        if self.on_changed:
            self.on_changed()


def option_list(schema: Schema, spec: list, on_changed=None) -> Gtk.Box:
    """A page body: spec items are option names, or ("Section title", None)
    tuples that start a section. Unknown option names are skipped, so a page
    keeps working across Hyprland versions."""
    box = w.vbox(6, "settings-page")
    first = True
    for item in spec:
        if isinstance(item, tuple):
            title = w.label(item[0], "settings-section")
            if not first:
                title.set_margin_top(10)
            box.pack_start(title, False, False, 0)
            first = False
            continue
        if schema.get(item) is None:
            continue
        box.pack_start(OptionRow(schema, item, on_changed), False, False, 0)
        first = False
    return box


def page_body(title: str, content: Gtk.Widget, max_height: int = 620) -> Gtk.Box:
    """Title over a scrolling body; what every page returns."""
    box = w.vbox(6)
    box.pack_start(w.label(title, "settings-title"), False, False, 0)
    box.pack_start(w.scrolled(content, max_height), True, True, 0)
    return box
