"""Settings pages. Each module exports PAGE; the panel sorts them by `order`.

Pages that are just Hyprland options use OptionsPage with a spec list (see
options.option_list); anything else subclasses Page and builds its own widget.
"""
from __future__ import annotations

from collections.abc import Callable

from .. import options


# Nav groups, in order. A page names one; unknown groups go last.
GROUPS = ["System", "Desktop", "Hardware", "Network", "Advanced"]


class Page:
    """A settings page. build(panel) returns the widget; the panel calls
    widget.shown() / widget.hidden() on nav changes and widget.close() on
    teardown when the widget has them (e.g. to scan only while visible)."""

    title = ""
    glyph = ""
    order = 50
    group = "Desktop"

    def __init__(self, title: str, glyph: str, order: int, group: str = "Desktop",
                 build: Callable | None = None):
        self.title, self.glyph, self.order, self.group = title, glyph, order, group
        if build:
            self.build = build  # type: ignore[method-assign]

    def build(self, panel):
        raise NotImplementedError


def schema_of(panel) -> options.Schema:
    """One `hyprctl descriptions` per panel, shared by the option pages."""
    if not hasattr(panel, "schema"):
        panel.schema = options.Schema()
    return panel.schema


class OptionsPage(Page):
    def __init__(self, title: str, glyph: str, order: int, spec: list, group: str = "Desktop"):
        super().__init__(title, glyph, order, group)
        self.spec = spec

    def build(self, panel):
        return options.page_body(self.title, options.option_list(schema_of(panel), self.spec))
