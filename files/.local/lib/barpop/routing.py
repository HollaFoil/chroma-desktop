"""Per-app audio output routing.

Every playing stream (a PipeWire sink-input: one per Spotify, per Firefox tab,
per game) can be sent to a device other than the default sink, at one of
three lifetimes:

  stream    `pactl move-sink-input` on that one stream. Nothing is remembered:
            the next stream from the same app goes to the default sink again.
            (A single Firefox tab, one Discord call.)
  session   A rule for the app, kept in $XDG_RUNTIME_DIR (tmpfs), so it lasts
            until logout/reboot and then evaporates.
  always    A rule for the app in ~/.config/barpop/audio.json (in the dotfiles).

Rules are applied by the `barpop watch` daemon: it moves matching streams as
they appear, re-applies when a device shows up (the headset turns on), and
watches both rule files so a change made in the panel takes effect at once.
The panel also moves the live streams itself so there is no visible lag.

Apps are keyed the way WirePlumber keys its own stream memory: application.name,
falling back to the process binary, then node.name. WirePlumber's own target
memory (node.stream.restore-target) is switched off by bootstrap so that a
"stream" move does not silently become an "always" rule.
"""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
SESSION_RULES = RUNTIME / "barpop-audio.json"
PERSISTENT_RULES = Path.home() / ".config/barpop/audio.json"
SCOPES = ("stream", "session", "always")


# ── pactl / pw ───────────────────────────────────────────────────────────────

def pactl(*args: str) -> str:
    try:
        return subprocess.run(["pactl", *args], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def pactl_json(kind: str) -> list[dict]:
    try:
        return json.loads(pactl("-f", "json", "list", kind) or "[]")
    except json.JSONDecodeError:
        return []


def sinks() -> list[dict]:
    return pactl_json("sinks")


def inputs() -> list[dict]:
    return pactl_json("sink-inputs")


def default_sink() -> str:
    return pactl("get-default-sink").strip()


def app_key(props: dict) -> str:
    return (props.get("application.name") or props.get("application.process.binary")
            or props.get("node.name") or "")


def move(idx: int, sink: str) -> None:
    pactl("move-sink-input", str(idx), sink)


def pinned_ids() -> set[int]:
    """Streams that carry an explicit target (were moved), from PipeWire's
    "default" metadata: those do not follow the default sink."""
    out = set()
    try:
        text = subprocess.run(["pw-metadata", "-n", "default"], capture_output=True, text=True,
                              timeout=3).stdout
    except (OSError, subprocess.TimeoutExpired):
        return out
    for line in text.splitlines():
        if "key:'target." in line and line.startswith("update: id:"):
            try:
                out.add(int(line.split()[1].split(":")[1]))
            except (IndexError, ValueError):
                pass
    return out


def unpin(idx: int) -> None:
    """Back to following the default sink: move there, then drop the target
    the move itself recorded so later default changes carry it along."""
    move(idx, "@DEFAULT_SINK@")
    for key in ("target.object", "target.node"):
        subprocess.run(["pw-metadata", "-d", str(idx), key], capture_output=True, timeout=3)


# ── rules ────────────────────────────────────────────────────────────────────

def _read(path: Path) -> dict[str, str]:
    try:
        data = json.loads(path.read_text())
        rules = data.get("rules", {})
        return {k: v["sink"] if isinstance(v, dict) else str(v) for k, v in rules.items()}
    except (OSError, ValueError, KeyError, TypeError):
        return {}


def _write(path: Path, rules: dict[str, str]) -> None:
    path = path.resolve() if path.is_symlink() else path   # write through the dotfiles symlink, do not replace it
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps({"rules": {k: {"sink": v} for k, v in sorted(rules.items())}}, indent=2) + "\n")
    os.replace(tmp, path)


def rules() -> dict[str, tuple[str, str]]:
    """app key -> (sink name, scope). A session rule shadows an always rule."""
    out = {k: (v, "always") for k, v in _read(PERSISTENT_RULES).items()}
    out.update({k: (v, "session") for k, v in _read(SESSION_RULES).items()})
    return out


def set_rule(key: str, sink: str, scope: str) -> None:
    """scope 'session' or 'always'; the other file's rule for the app is
    dropped so there is exactly one."""
    for path, mine in ((SESSION_RULES, scope == "session"), (PERSISTENT_RULES, scope == "always")):
        r = _read(path)
        if mine:
            r[key] = sink
        else:
            r.pop(key, None)
        if r or path.exists():
            _write(path, r)


def clear_rule(key: str) -> None:
    for path in (SESSION_RULES, PERSISTENT_RULES):
        r = _read(path)
        if key in r:
            del r[key]
            _write(path, r)


def apply(only: int | None = None) -> int:
    """Move every stream that has a rule and is not on its sink (or just the
    one stream `only`). Returns how many moved. A rule whose sink is absent
    right now is left alone; the watcher retries when a sink appears."""
    rs = rules()
    if not rs:
        return 0
    present = {s["name"]: s["index"] for s in sinks()}
    moved = 0
    for si in inputs():
        if only is not None and si["index"] != only:
            continue
        rule = rs.get(app_key(si.get("properties", {})))
        if not rule or rule[0] not in present:
            continue
        if si.get("sink") != present[rule[0]]:
            move(si["index"], rule[0])
            moved += 1
    return moved
