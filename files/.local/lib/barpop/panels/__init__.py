"""Panel registry. Built-ins are imported here; plugins come from
~/.config/barpop/plugins/*.py (each may export PANELS and NETWORK_SECTIONS)."""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402

PLUGIN_DIR = Path.home() / ".config/barpop/plugins"


class Panel(Gtk.Box):
    """Base for everything shown in the overlay. Subclasses set `name`, build
    their widgets in __init__ and release watches/subprocesses in close()."""

    name = ""

    def __init__(self, shell):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.shell = shell
        self.get_style_context().add_class("panel")
        self.get_style_context().add_class(f"panel-{self.name}")

    def close(self) -> None:
        pass


_REGISTRY: dict[str, type[Panel]] = {}
_PLUGINS: list = []
_loaded = False


def register(cls: type[Panel]) -> type[Panel]:
    _REGISTRY[cls.name] = cls
    return cls


def _load_plugins() -> None:
    global _loaded
    if _loaded:
        return
    _loaded = True
    if not PLUGIN_DIR.is_dir():
        return
    for path in sorted(PLUGIN_DIR.glob("*.py")):
        spec = importlib.util.spec_from_file_location(f"barpop_plugin_{path.stem}", path)
        if not spec or not spec.loader:
            continue
        mod = importlib.util.module_from_spec(spec)
        try:
            spec.loader.exec_module(mod)
        except Exception as e:  # a broken plugin must not take the menu down
            print(f"barpop: plugin {path.name} failed: {e}", file=sys.stderr)
            continue
        _PLUGINS.append(mod)
        for cls in getattr(mod, "PANELS", []):
            register(cls)


def plugin_network_sections() -> list:
    _load_plugins()
    out = []
    for mod in _PLUGINS:
        out.extend(getattr(mod, "NETWORK_SECTIONS", []))
    return out


def names() -> list[str]:
    _load_plugins()
    return list(_REGISTRY)


def get(name: str) -> type[Panel]:
    _load_plugins()
    return _REGISTRY[name]


from . import audio, launcher, network  # noqa: E402,F401  (register built-ins)
