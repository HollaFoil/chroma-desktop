pragma Singleton
import QtQuick
import Quickshell

// Post a desktop notification. Until the shell is the notification server
// (Phase 2) this goes through notify-send to whatever daemon is running.
Singleton {
    function send(summary, body, icon) {
        const cmd = ["notify-send", "-a", "quickshell", "-t", "4000", "--hint=boolean:transient:true"]
        if (icon) cmd.push("-i", icon)
        cmd.push(summary, body || "")
        Proc.detach(cmd)
    }
}
