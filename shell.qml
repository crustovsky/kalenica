import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool barVisible: true

    Variants {
        model: Quickshell.screens
        Bar {
            visible: root.barVisible
        }
    }

    // toggle with: qs ipc call bar toggle
    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }
}
