import QtQuick
import Quickshell.Io

// One-shot process with a completion callback: Proc.run(cmd, (code, out, err) => ...).
Process {
    id: proc
    property var callback: null
    property string out: ""
    property string err: ""
    property bool exitedFlag: false
    property bool outDone: false
    property bool errDone: false
    stdout: StdioCollector { onStreamFinished: { proc.out = text; proc.outDone = true; proc.finish() } }
    stderr: StdioCollector { onStreamFinished: { proc.err = text; proc.errDone = true; proc.finish() } }
    property int code: 0
    onExited: (exitCode, exitStatus) => { code = exitCode; exitedFlag = true; finish() }
    function finish() {
        if (!(exitedFlag && outDone && errDone)) return
        if (callback) callback(code, out, err)
        destroy()
    }
}
