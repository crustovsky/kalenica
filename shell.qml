//@ pragma UseQApplication
// required for tray menus (QsMenuAnchor); pragma changes need a restart
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

    Notifications {}

    Osd {
        id: osd
    }

    BrightnessControl {
        osd: osd
    }

    // toggle with: qs ipc call bar toggle
    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }
}
