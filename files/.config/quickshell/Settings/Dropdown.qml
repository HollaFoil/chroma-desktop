pragma Singleton
import QtQuick
import Quickshell

// State of the one dropdown list the settings window can show at a time
// (DropdownLayer draws it, Picker opens it). Items are { text, value, hint }.
Singleton {
    id: root
    property bool open: false
    property var anchor: null
    property var items: []
    property var current: undefined
    property bool searchable: false
    property var callback: null

    function show(anchorItem, items, current, cb, searchable) {
        root.anchor = anchorItem
        root.items = items
        root.current = current
        root.callback = cb
        root.searchable = searchable === undefined ? items.length > 8 : searchable
        root.open = true
    }
    function pick(value) {
        const cb = callback
        close()
        if (cb) cb(value)
    }
    function close() { open = false; anchor = null; callback = null }
}
