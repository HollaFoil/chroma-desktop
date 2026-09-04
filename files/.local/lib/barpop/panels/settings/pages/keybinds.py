"""Keybinds: every action from the config, what it is bound to, and whether
the cheatsheet lists it.

    Apps
      Terminal (kitty)          [SUPER + Q] [+]        ↺   ☑ sheet
      Switch to workspace       [SUPER + 1-0] [+]          ☑ sheet
    ...                                              [+ Add command]

Click a key chip (or +) and press the combination: the chip pulses, Hyprland
is switched to the empty "capture" submap so SUPER + anything reaches us
instead of running a bind, and the shell's key_grab routes the keys here.
Escape cancels. A click on the pulsing chip with a mouse button and a modifier
held records a mouse bind (mouse:272 ...). For a parametrised action (SUPER +
1-0) only the modifiers are kept - press SUPER + 1 to record "SUPER".

Every change rewrites state/keybinds.json and reloads Hyprland, then the page
is rebuilt from the config's fresh export (hypr.save_keybinds), so what is
shown is always what the compositor has. "Run a command" actions created here
live in the same file; conf/actions.lua never changes.
"""
from __future__ import annotations

import secrets

from .... import hypr
from .... import widgets as w
from . import Page
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

MODS = (
    (Gdk.ModifierType.MOD4_MASK, "SUPER"),
    (Gdk.ModifierType.CONTROL_MASK, "CTRL"),
    (Gdk.ModifierType.MOD1_MASK, "ALT"),
    (Gdk.ModifierType.SHIFT_MASK, "SHIFT"),
)
MODIFIER_KEYS = {
    "Shift_L", "Shift_R", "Control_L", "Control_R", "Alt_L", "Alt_R", "Meta_L", "Meta_R",
    "Super_L", "Super_R", "Hyper_L", "Hyper_R", "ISO_Level3_Shift", "ISO_Level5_Shift",
    "Caps_Lock", "Num_Lock", "Scroll_Lock", "Mode_switch",
}
MOUSE_BUTTONS = {1: "mouse:272", 3: "mouse:273", 2: "mouse:274", 8: "mouse:275", 9: "mouse:276"}

# What a chip shows for a key whose keysym name is not self-explanatory. The
# stored bind keeps the keysym; this is display only. XF86* are the dedicated
# media/brightness keys a keyboard sends.
KEY_LABELS = {
    "XF86AudioRaiseVolume": "󰝝 Volume up key", "XF86AudioLowerVolume": "󰝞 Volume down key",
    "XF86AudioMute": "󰝟 Mute key", "XF86AudioMicMute": "󰍭 Mic mute key",
    "XF86MonBrightnessUp": "󰃠 Brightness up key", "XF86MonBrightnessDown": "󰃞 Brightness down key",
    "XF86AudioPlay": "󰐊 Play key", "XF86AudioPause": "󰏤 Pause key",
    "XF86AudioNext": "󰒭 Next key", "XF86AudioPrev": "󰒮 Previous key", "XF86AudioStop": "󰓛 Stop key",
    "mouse:272": "Left click", "mouse:273": "Right click", "mouse:274": "Middle click",
    "mouse:275": "Mouse button 4", "mouse:276": "Mouse button 5",
    "mouse_down": "Scroll down", "mouse_up": "Scroll up",
    "slash": "/", "comma": ",", "period": ".", "semicolon": ";", "apostrophe": "'",
    "bracketleft": "[", "bracketright": "]", "minus": "-", "equal": "=", "grave": "`", "backslash": "\\",
    "Return": "Enter", "space": "Space", "Escape": "Esc", "Print": "PrtSc", "TAB": "Tab",
}


def pretty_combo(combo: str) -> str:
    """'SUPER + slash' -> 'SUPER + /'; only the key part is translated."""
    parts = [p.strip() for p in combo.split("+")]
    if parts and parts[-1] in KEY_LABELS:
        parts[-1] = KEY_LABELS[parts[-1]]
    return " + ".join(parts)


def mods_of(state) -> list[str]:
    return [name for mask, name in MODS if state & mask]


def base_keysym(ev) -> str | None:
    """The key's unshifted name from its keycode, so SHIFT + 1 is "1", not
    "exclam"; letters uppercase as Hyprland writes them."""
    keymap = Gdk.Keymap.get_for_display(Gdk.Display.get_default())
    ok, keys, keyvals = keymap.get_entries_for_keycode(ev.hardware_keycode)
    keyval = ev.keyval
    if ok:
        for key, kv in zip(keys, keyvals):
            if key.level == 0 and key.group == ev.group:
                keyval = kv
                break
    name = Gdk.keyval_name(keyval)
    if not name or name in MODIFIER_KEYS:
        return None
    if len(name) == 1 and name.isalpha():
        return name.upper()
    return name


def normalise(combo: str) -> tuple:
    parts = [p.strip() for p in combo.split("+")]
    mods = sorted(p.upper() for p in parts[:-1])
    return (tuple(mods), parts[-1].upper() if parts and parts[-1] else "")


def expanded(action: dict) -> set[tuple]:
    """Every concrete combo an action occupies, normalised."""
    out = set()
    for key in action.get("keys") or []:
        if action.get("parametrised"):
            for pk in action.get("param_keys") or []:
                out.add(normalise(f"{key} + {pk}" if key else pk))
        else:
            out.add(normalise(key))
    return out


class KeybindsPage(Page):
    def __init__(self):
        super().__init__("Keybinds", "󰌌", 10)

    # ── build ──
    def build(self, panel):
        self.panel = panel
        self.capture = None            # (action, index, chip) while recording
        self.export = hypr.export()

        body = w.vbox(6)
        head = w.hbox(8)
        head.pack_start(w.label(self.title, "settings-title"), True, True, 0)
        self.add_btn = w.pill_button("󰐕  Add command", self._toggle_form, "small")
        head.pack_end(self.add_btn, False, False, 0)
        body.pack_start(head, False, False, 0)

        self.form = self._build_form()
        self.form_rev = w.revealer(self.form)
        body.pack_start(self.form_rev, False, False, 0)

        self.status = w.status()
        body.pack_start(self.status, False, False, 0)

        self.list = w.vbox(4, "settings-page")
        body.pack_start(w.scrolled(self.list, 560), True, True, 0)
        self._fill()
        body.close = self.close  # the panel calls it on teardown
        return body

    def _fill(self) -> None:
        w.clear(self.list)
        by_cat: dict[str, list[dict]] = {}
        for a in self.export.get("actions", []):
            by_cat.setdefault(a["category"], []).append(a)
        order = [c for c in self.export.get("categories", []) if c in by_cat]
        order += [c for c in by_cat if c not in order]
        first = True
        for cat in order:
            title = w.label(cat, "settings-section")
            if not first:
                title.set_margin_top(10)
            first = False
            self.list.pack_start(title, False, False, 0)
            for a in by_cat[cat]:
                self.list.pack_start(self._row(a), False, False, 0)
        self.list.show_all()

    def _row(self, a: dict) -> Gtk.Box:
        row = w.hbox(8, "setting-row", "bind-row")
        names = w.vbox(0)
        names.pack_start(w.label(a["name"], "setting-name", ellipsize=True, max_chars=34), False, False, 0)
        if a.get("custom"):
            names.pack_start(w.label(a.get("command", ""), "setting-desc", ellipsize=True, max_chars=40),
                             False, False, 0)
        names.set_size_request(280, -1)
        row.pack_start(names, False, False, 0)

        chips = w.hbox(4, "chips")
        for i, key in enumerate(a.get("keys") or []):
            chips.pack_start(self._chip(a, i, key), False, False, 0)
        plus = w.icon_button("󰐕", lambda a=a: self._begin_capture(a, None, None), "small", "action", "chip-add")
        chips.pack_start(plus, False, False, 0)
        row.pack_start(chips, True, True, 0)

        overridden = a["id"] in hypr.keybinds()["binds"]
        if overridden and not a.get("custom"):
            row.pack_end(w.icon_button("󰦛", lambda a=a: self._reset(a), "small", "action"), False, False, 0)
        if a.get("custom"):
            row.pack_end(w.icon_button("󰆴", lambda a=a: self._delete_custom(a), "small", "danger"), False, False, 0)
        sheet = w.check(bool(a.get("cheatsheet", True)), lambda on, a=a: self._set_cheatsheet(a, on), "sheet")
        row.pack_end(sheet, False, False, 0)
        return row

    def _chip(self, a: dict, index: int, key: str) -> Gtk.Box:
        box = w.hbox(0, "key-chip")
        text = pretty_combo(key) if key else "(none)"
        if a.get("parametrised"):
            text = f"{key} + " if key else ""
        btn = Gtk.Button(label=text)
        w.klass(btn, "chip-key")
        btn.connect("clicked", lambda *_: self._begin_capture(a, index, box))
        btn.connect("button-press-event", lambda _b, ev: self._chip_press(a, index, box, ev))
        box.pack_start(btn, False, False, 0)
        if a.get("parametrised"):
            box.pack_start(w.label(a.get("params_label", ""), "chip-param"), False, False, 0)
        box.pack_start(w.icon_button("󰅖", lambda: self._remove_key(a, index), "small", "action", "chip-x"),
                       False, False, 0)
        return box

    # ── capture ──
    def _begin_capture(self, a: dict, index: int | None, chip: Gtk.Box | None) -> None:
        if self.capture is not None:
            self._end_capture()
        self.capture = (a, index, chip)
        if chip is not None:
            w.set_class(chip, "capturing", True)
        hypr.dispatch('hl.dsp.submap("capture")')
        self.panel.shell.key_grab = self._key
        hint = "press the modifiers and a key" if a.get("parametrised") else "press a key combination"
        w.set_status(self.status, f"{a['name']}: {hint} · Escape cancels · click the chip with a mouse button for a mouse bind")

    def _end_capture(self) -> None:
        if self.capture and self.capture[2] is not None:
            w.set_class(self.capture[2], "capturing", False)
        self.capture = None
        self.panel.shell.key_grab = None
        hypr.dispatch('hl.dsp.submap("reset")')
        w.set_status(self.status, "")

    def _key(self, ev) -> bool:
        if ev.type != Gdk.EventType.KEY_PRESS:
            return True
        if ev.keyval == Gdk.KEY_Escape:
            self._end_capture()
            return True
        key = base_keysym(ev)
        if key is None:
            return True  # a modifier alone; wait for the key
        self._record(mods_of(ev.state), key)
        return True

    def _chip_press(self, a, index, chip, ev) -> bool:
        if self.capture is None or self.capture[2] is not chip:
            return False  # a normal click: "clicked" starts the capture
        if ev.button == 1 and not mods_of(ev.state):
            return False  # plain click on the pulsing chip -> clicked -> restarts, harmless
        self._record(mods_of(ev.state), MOUSE_BUTTONS.get(ev.button, f"mouse:{271 + ev.button}"))
        return True

    def _record(self, mods: list[str], key: str) -> None:
        a, index, _chip = self.capture
        combo = " + ".join(mods) if a.get("parametrised") else " + ".join(mods + [key])
        self._end_capture()
        keys = list(a.get("keys") or [])
        if index is None:
            keys.append(combo)
        else:
            keys[index] = combo
        self._save_keys(a, keys)
        # after the rebuild, point out anything else on the same combination
        probe = dict(a, keys=[combo])
        used = expanded(probe)
        clashes = [o["name"] for o in self.export.get("actions", [])
                   if o["id"] != a["id"] and expanded(o) & used]
        if clashes:
            w.set_status(self.status, f"{combo} is also bound to: {', '.join(clashes)} (both will run)", error=True)

    # ── writes ──
    def _save(self, data: dict) -> None:
        self.export = hypr.save_keybinds(data)
        self._fill()

    def _save_keys(self, a: dict, keys: list[str]) -> None:
        data = hypr.keybinds()
        if a.get("custom"):
            for c in data["custom"]:
                if c["id"] == a["id"]:
                    c["keys"] = keys
        else:
            entry = data["binds"].setdefault(a["id"], {})
            if keys == (a.get("default_keys") or []):
                entry.pop("keys", None)
            else:
                entry["keys"] = keys
            if not entry:
                del data["binds"][a["id"]]
        self._save(data)

    def _remove_key(self, a: dict, index: int) -> None:
        keys = list(a.get("keys") or [])
        if 0 <= index < len(keys):
            del keys[index]
            self._save_keys(a, keys)

    def _set_cheatsheet(self, a: dict, on: bool) -> None:
        data = hypr.keybinds()
        if a.get("custom"):
            for c in data["custom"]:
                if c["id"] == a["id"]:
                    c["cheatsheet"] = on
        else:
            entry = data["binds"].setdefault(a["id"], {})
            entry["cheatsheet"] = on
        self._save(data)

    def _reset(self, a: dict) -> None:
        data = hypr.keybinds()
        data["binds"].pop(a["id"], None)
        self._save(data)

    def _delete_custom(self, a: dict) -> None:
        data = hypr.keybinds()
        data["custom"] = [c for c in data["custom"] if c["id"] != a["id"]]
        data["binds"].pop(a["id"], None)
        self._save(data)

    # ── "Run a command" form ──
    def _build_form(self) -> Gtk.Box:
        form = w.vbox(6, "add-form")
        row1 = w.hbox(8)
        self.f_name = Gtk.Entry(placeholder_text="name, as shown on the cheatsheet")
        self.f_name.set_hexpand(True)
        row1.pack_start(self.f_name, True, True, 0)
        form.pack_start(row1, False, False, 0)
        row2 = w.hbox(8)
        self.f_cmd = Gtk.Entry(placeholder_text="command, run with sh -c")
        self.f_cmd.set_hexpand(True)
        row2.pack_start(self.f_cmd, True, True, 0)
        form.pack_start(row2, False, False, 0)
        row3 = w.hbox(8)
        cats = [(c, c) for c in self.export.get("categories", []) or ["Utilities"]]
        self.f_cat = cats[0][1]

        def pick(c):
            self.f_cat = c
            self.f_seg.set_current(c)

        self.f_seg = w.Segmented(cats, self.f_cat, pick)
        row3.pack_start(self.f_seg, True, True, 0)
        row3.pack_end(w.pill_button("Add", self._add_custom, "small"), False, False, 0)
        form.pack_start(row3, False, False, 0)
        return form

    def _toggle_form(self) -> None:
        self.form_rev.set_reveal_child(not self.form_rev.get_reveal_child())
        if self.form_rev.get_reveal_child():
            self.f_name.grab_focus()

    def _add_custom(self) -> None:
        name, cmd = self.f_name.get_text().strip(), self.f_cmd.get_text().strip()
        if not name or not cmd:
            w.set_status(self.status, "a command action needs a name and a command", error=True)
            return
        data = hypr.keybinds()
        data["custom"].append({"id": f"custom.{secrets.token_hex(3)}", "name": name, "category": self.f_cat,
                               "command": cmd, "keys": [], "cheatsheet": True})
        self.f_name.set_text("")
        self.f_cmd.set_text("")
        self.form_rev.set_reveal_child(False)
        self._save(data)
        w.set_status(self.status, f"added {name}: click 󰐕 on its row to bind a key")

    def close(self) -> None:
        if self.capture is not None:
            self._end_capture()


PAGE = KeybindsPage()
