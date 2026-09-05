pragma Singleton
import QtQuick
import Quickshell

// Run a command, get its output back once: Proc.run(["cmd", "arg"], (code, out, err) => {}).
// Proc.detach(cmd) launches and forgets (a launcher item, setwall).
Singleton {
    id: root
    Component { id: runner; Runner {} }

    function run(cmd, cb, env) {
        const props = { command: cmd, callback: cb ?? null }
        if (env) props.environment = env
        const p = runner.createObject(root, props)
        p.running = true
        return p
    }
    function sh(script, cb) { return run(["sh", "-c", script], cb) }
    function detach(cmd) {
        Quickshell.execDetached(Array.isArray(cmd) ? cmd : ["sh", "-c", cmd])
    }
}
