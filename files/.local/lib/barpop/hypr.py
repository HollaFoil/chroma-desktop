"""Talking to Hyprland and to the config's state files, for the settings panel.

Two channels, both used for every change so it is immediate *and* survives a
reload: `hyprctl eval 'hl.config{...}'` applies an option live, and the value
is written to ~/.config/hypr/state/settings.json, which lib/settings.lua
re-applies whenever hyprland.lua runs (matugen reloads it on every wallpaper
change). Keybinds have no live path - state/keybinds.json is rewritten and
Hyprland is reloaded, then ~/.cache/hypr/binds.json (written by the config's
lib/actions.lua at the end of every load) is read back for the new truth.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import time
from pathlib import Path

HYPR = Path.home() / ".config/hypr"
STATE = HYPR / "state"
SETTINGS = STATE / "settings.json"
KEYBINDS = STATE / "keybinds.json"
EXPORT = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "hypr/binds.json"


# ── hyprctl ──────────────────────────────────────────────────────────────────

def hyprctl(*args: str) -> str:
    p = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=10)
    return p.stdout


def hyprctl_json(*args: str):
    out = hyprctl("-j", *args)
    try:
        return json.loads(out)
    except ValueError:
        return None


def descriptions() -> list[dict]:
    """Every config option: name ("general:gaps_in"), description, default,
    current, and for numbers min/max, for enums a `map` of {label: value}.
    `current` is fixed up from getoption: descriptions reports 0/false for
    most floats and bools (verified on 0.56.2), getoption is right."""
    entries = hyprctl_json("descriptions") or []
    live = current_values([e["name"] for e in entries])
    for e in entries:
        if e["name"] in live:
            e["vtype"], e["current"] = live[e["name"]]
    return entries


def current_values(names: list[str]) -> dict[str, tuple[str, object]]:
    """One batched `getoption` for many options -> {name: (type, value)}. The
    type is getoption's own word (int, float, bool, str, css, gradient, vec2)
    and is the reliable way to tell a float option with an integral default
    from an int one. Options getoption does not answer for are absent."""
    if not names:
        return {}
    out = hyprctl("-j", "--batch", "; ".join(f"getoption {n}" for n in names))
    values: dict[str, object] = {}
    for blob in re.findall(r"\{[^{}]*\}", out):
        try:
            d = json.loads(blob)
        except ValueError:
            continue
        name = d.pop("option", None)
        d.pop("set", None)
        if name and d:
            values[name] = next(iter(d.items()))
    return values


def binds() -> list[dict]:
    return hyprctl_json("binds") or []


def monitors() -> list[dict]:
    return hyprctl_json("monitors") or []


def lua_literal(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(value, dict):
        return "{" + ", ".join(f"[{lua_literal(k)}] = {lua_literal(v)}" for k, v in value.items()) + "}"
    if isinstance(value, (list, tuple)):
        return "{" + ", ".join(lua_literal(v) for v in value) + "}"
    raise TypeError(f"cannot express {value!r} in Lua")


def nested(name: str, value) -> dict:
    """'general:col.active_border' -> {'general': {'col.active_border': value}}"""
    parts = name.split(":")
    out: dict = {parts[-1]: value}
    for part in reversed(parts[:-1]):
        out = {part: out}
    return out


def apply_live(name: str, value) -> str | None:
    """hl.config the one option now. Returns the error text, or None."""
    code = "hl.config(" + lua_literal(nested(name, value)) + ")"
    out = hyprctl("eval", code).strip()
    return None if out == "ok" else out


def dispatch(code: str) -> None:
    hyprctl("dispatch", code)


def reload() -> None:
    hyprctl("reload")


# ── state files ──────────────────────────────────────────────────────────────

def read_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def write_json(path: Path, data) -> None:
    path = path.resolve() if path.is_symlink() else path   # write through a dotfiles symlink, do not replace it
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    os.replace(tmp, path)


def settings() -> dict:
    data = read_json(SETTINGS, {})
    data.setdefault("options", {})
    return data


def set_option(name: str, value) -> str | None:
    """Apply live and persist. Returns an error string if Hyprland refused."""
    err = apply_live(name, value)
    if err:
        return err
    data = settings()
    data["options"][name] = value
    write_json(SETTINGS, data)
    return None


def reset_option(name: str) -> None:
    """Drop the override; a reload puts the conf/*.lua value back."""
    data = settings()
    if name in data["options"]:
        del data["options"][name]
        write_json(SETTINGS, data)
    reload()


def keybinds() -> dict:
    data = read_json(KEYBINDS, {})
    data.setdefault("binds", {})
    data.setdefault("custom", [])
    return data


def export() -> dict:
    return read_json(EXPORT, {"categories": [], "actions": []})


def save_keybinds(data: dict) -> dict:
    """Write, reload, and return the fresh export once the config wrote it."""
    write_json(KEYBINDS, data)
    try:
        before = EXPORT.stat().st_mtime_ns
    except OSError:
        before = 0
    reload()
    for _ in range(40):  # up to ~2 s
        try:
            if EXPORT.stat().st_mtime_ns != before:
                break
        except OSError:
            pass
        time.sleep(0.05)
    return export()
