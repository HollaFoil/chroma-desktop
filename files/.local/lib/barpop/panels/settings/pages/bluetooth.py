"""Bluetooth on its own page. Discovery runs while the page is on screen:
shown() starts a scan (the section's own 15 s window, then it forgets the
strangers it found), hidden() stops it."""
from __future__ import annotations

from .... import widgets as w
from ... import network as net
from . import Page


class BluetoothPage(Page):
    def __init__(self):
        super().__init__("Bluetooth", "󰂯", 41, "Network")

    def build(self, panel):
        body = w.vbox(6)
        body.pack_start(w.label(self.title, "settings-title"), False, False, 0)
        host = net.NetworkHost()
        content = w.vbox(10, "settings-page", "net-page")
        sections = host.build([net.Bluetooth])
        bt = sections[0] if sections else None
        if bt is not None:
            for child in bt.get_children():
                if hasattr(child, "set_max_content_height"):
                    child.set_max_content_height(440)
            content.pack_start(bt, False, False, 0)
        else:
            content.pack_start(w.label("No Bluetooth adapter.", "empty"), False, False, 0)
        body.pack_start(w.scrolled(content, 580), True, True, 0)

        def shown():
            if bt is not None and bt.switch.get_active():
                bt._scan()

        def hidden():
            if bt is not None:
                bt._stop_scan()

        body.shown, body.hidden, body.close = shown, hidden, host.close
        return body


PAGE = BluetoothPage()
