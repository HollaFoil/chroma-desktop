"""Every option Hyprland reports in `hyprctl descriptions`, one section per
config group, with a filter box. Rows are built lazily per section so opening
the page is quick; the filter matches option names and descriptions."""
from __future__ import annotations

from .... import widgets as w
from .. import options
from . import Page, schema_of
from gi.repository import Gtk  # noqa: E402

# debug/opengl are footguns rather than settings
HIDDEN_GROUPS = {"debug", "opengl", "quirks", "experimental"}


class AllPage(Page):
    def __init__(self):
        super().__init__("All options", "󰒓", 90, "Advanced")

    def build(self, panel):
        schema = schema_of(panel)
        body = w.vbox(6)
        body.pack_start(w.label(self.title, "settings-title"), False, False, 0)

        search = Gtk.SearchEntry()
        search.set_placeholder_text("filter options…")
        w.klass(search, "settings-search")
        body.pack_start(search, False, False, 0)

        groups: dict[str, list[str]] = {}
        for name in schema.names():
            g = name.split(":")[0]
            if g in HIDDEN_GROUPS:
                continue
            groups.setdefault(g, []).append(name)

        sections = []  # (title label, revealer, [option names], rows box)
        content = w.vbox(4, "settings-page")
        for g in sorted(groups):
            head = Gtk.Button()
            w.klass(head, "item", "group-head")
            row = w.hbox(8)
            chevron = w.label("󰅂", "item-chevron")
            row.pack_start(chevron, False, False, 0)
            row.pack_start(w.label(g, "settings-section"), True, True, 0)
            row.pack_end(w.label(str(len(groups[g])), "detail"), False, False, 0)
            head.add(row)
            rows = w.vbox(6)
            rev = w.revealer(rows)
            rev.set_reveal_child(False)
            content.pack_start(head, False, False, 0)
            content.pack_start(rev, False, False, 0)
            sec = {"head": head, "rev": rev, "rows": rows, "names": groups[g], "built": False, "chevron": chevron}
            sections.append(sec)

            def toggle(_b, s=sec):
                if not s["built"]:
                    for n in s["names"]:
                        s["rows"].pack_start(options.OptionRow(schema, n), False, False, 0)
                    s["rows"].show_all()
                    s["built"] = True
                open_ = not s["rev"].get_reveal_child()
                s["rev"].set_reveal_child(open_)
                s["chevron"].set_text("󰅀" if open_ else "󰅂")

            head.connect("clicked", toggle)

        def filter_changed(entry):
            q = entry.get_text().strip().lower()
            for s in sections:
                if not q:
                    s["head"].set_visible(True)
                    for child in s["rows"].get_children():
                        child.set_visible(True)
                    continue
                hits = [n for n in s["names"]
                        if q in n.lower() or q in (schema.get(n) or {}).get("description", "").lower()]
                s["head"].set_visible(bool(hits))
                if hits and not s["built"]:
                    s["head"].clicked()  # builds and opens
                elif hits and not s["rev"].get_reveal_child():
                    s["rev"].set_reveal_child(True)
                    s["chevron"].set_text("󰅀")
                for child in s["rows"].get_children():
                    child.set_visible(child.name in hits)
                if not hits:
                    s["rev"].set_reveal_child(False)

        search.connect("search-changed", filter_changed)
        body.pack_start(w.scrolled(content, 580), True, True, 0)
        return body


PAGE = AllPage()
