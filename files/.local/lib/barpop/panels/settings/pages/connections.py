"""Wired, Tailscale, and the way to everything else (nm-connection-editor)."""
from __future__ import annotations

from .... import widgets as w
from ... import network as net
from . import Page


class ConnectionsPage(Page):
    def __init__(self):
        super().__init__("Connections", "󰈀", 42, "Network")

    def build(self, panel):
        body = w.vbox(6)
        head = w.hbox(8)
        head.pack_start(w.label(self.title, "settings-title"), True, True, 0)
        head.pack_end(w.pill_button("󰒓  All connections…", lambda: net.advanced_editor(panel.shell), "small"),
                      False, False, 0)
        body.pack_start(head, False, False, 0)
        host = net.NetworkHost()
        content = w.vbox(10, "settings-page", "net-page")
        classes = [net.Wired, net.Tailscale] + [c for c in net.plugin_network_sections()
                                               if c not in (net.Wifi, net.Hotspot, net.Bluetooth)]
        sections = host.build(classes)
        for sec in sections:
            content.pack_start(sec, False, False, 0)
        if not sections:
            content.pack_start(w.label("Nothing here: no wired adapter, no tailscale.", "empty"), False, False, 0)
        body.pack_start(w.scrolled(content, 580), True, True, 0)
        body.close = host.close
        return body


PAGE = ConnectionsPage()
