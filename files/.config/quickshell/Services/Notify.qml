pragma Singleton
import QtQuick
import Quickshell

// Post one of the shell's own notifications (a network change and the like).
Singleton {
    function send(summary, body, icon) { Notifs.post(summary, body, icon) }
}
