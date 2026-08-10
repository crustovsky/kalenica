import QtQuick
import Quickshell

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 30
    color: Theme.bg

    Row {
        id: leftRow
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 4
        }

        BarItem {
            id: launcher
            onClicked: Quickshell.execDetached(Config.modules.launcher.command)
            BarText { color: launcher.fg; text: " " }
        }
        GroupedWorkspaces { screen: bar.screen }
    }

    ActiveWindow {
        anchors.centerIn: parent
        // never overlap the side sections, like waybar's box layout
        maxWidth: Math.max(0, 2 * Math.min(
            bar.width / 2 - (leftRow.x + leftRow.width) - 16,
            rightRow.x - bar.width / 2 - 16))
    }

    Row {
        id: rightRow
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            rightMargin: 4
        }

        Memory {}
        Cpu {}
        NetworkStatus {}
        BluetoothStatus {}
        Drawer {
            Battery {}
            PowerMode {}
            Backlight {}
        }
        Drawer {
            AudioControl {}
            AudioControl { sinks: false }
        }
        Media {}
        Tray {}
        ClockItem {}
        PowerMenu {}
    }
}
