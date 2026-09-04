"""Audio: the bar's audio panel (outputs, inputs, per-app streams), embedded.
It is the same widget as `barpop audio`, only with the app rows open."""
from __future__ import annotations

from .... import widgets as w
from ... import audio as audio_panel
from . import Page


class AudioPage(Page):
    def __init__(self):
        super().__init__("Audio", "󰕾", 71, "Hardware")

    def build(self, panel):
        body = w.vbox(6)
        body.pack_start(w.label(self.title, "settings-title"), False, False, 0)
        content = w.vbox(6, "settings-page", "audio-page")
        inner = audio_panel.Audio(panel.shell)
        inner.get_style_context().remove_class("panel")   # not a card of its own here
        content.pack_start(inner, False, False, 0)
        body.pack_start(w.scrolled(content, 580), True, True, 0)
        if not inner.apps_revealer.get_reveal_child():
            inner._toggle_apps()
        body.close = inner.close
        return body


PAGE = AudioPage()
