"""Wi-Fi and the hotspot that shares its radio. The section starts scanning
the moment the page is built and keeps rescanning every 12 s (network.Wifi),
so opening the tab is the scan."""
from __future__ import annotations

from .... import widgets as w
from ... import network as net
from . import Page


class WifiPage(Page):
    def __init__(self):
        super().__init__("Wi-Fi", "󰖩", 40, "Network")

    def build(self, panel):
        body = w.vbox(6)
        body.pack_start(w.label(self.title, "settings-title"), False, False, 0)
        host = net.NetworkHost()
        content = w.vbox(10, "settings-page", "net-page")
        sections = host.build([net.Wifi, net.Hotspot])
        for sec in sections:
            if isinstance(sec, net.Wifi):
                sec.list_scroll.set_max_content_height(420)   # the popup keeps it short; here there is room
            content.pack_start(sec, False, False, 0)
        if not sections:
            content.pack_start(w.label("No Wi-Fi adapter.", "empty"), False, False, 0)
        body.pack_start(w.scrolled(content, 580), True, True, 0)
        body.close = host.close
        return body


PAGE = WifiPage()
