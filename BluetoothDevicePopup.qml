pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Anchored device list for the bluetooth bar item (replaces the vicinae
// bluetooth extension): paired devices, click connects/disconnects. Pairing
// new devices stays in bluetoothctl. Closes when the mouse stays away (no
// HyprlandFocusGrab: it eats clicks into popup child surfaces, see CLAUDE.md).
PopupWindow {
    id: root

    required property Item anchorItem

    // name order, not connected-first: rows must not jump under the cursor
    // when a click changes connection state
    readonly property var devices: Bluetooth.devices.values
        .filter(d => d.paired || d.bonded)
        .sort((a, b) => (a.name || "").localeCompare(b.name || ""))

    function toggle() {
        visible = !visible;
    }

    anchor.item: anchorItem
    anchor.rect.w: anchorItem.width
    anchor.rect.h: anchorItem.height + 6
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    color: "transparent"
    implicitWidth: 320
    implicitHeight: column.implicitHeight + 16

    Timer {
        interval: 1500
        running: root.visible && !popHover.hovered
        onTriggered: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.bg

        HoverHandler { id: popHover }

        Column {
            id: column
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 2

            BarText {
                visible: root.devices.length === 0
                x: 8
                text: "no paired devices"
            }

            Repeater {
                model: root.devices

                Rectangle {
                    id: row
                    required property var modelData

                    readonly property bool busy:
                        modelData.state === BluetoothDeviceState.Connecting
                        || modelData.state === BluetoothDeviceState.Disconnecting
                    readonly property string detail: {
                        if (modelData.state === BluetoothDeviceState.Connecting)
                            return "connecting…";
                        if (modelData.state === BluetoothDeviceState.Disconnecting)
                            return "disconnecting…";
                        if (modelData.connected && modelData.batteryAvailable)
                            return `${Math.round(modelData.battery * 100)}%`;
                        return "";
                    }

                    width: column.width
                    height: label.implicitHeight + 10
                    radius: 6
                    color: rowHover.hovered ? Theme.bgHover : "transparent"

                    BarText {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16 - (detailText.visible ? detailText.implicitWidth + 8 : 0)
                        elide: Text.ElideRight
                        text: `${row.modelData.connected ? "●" : "○"} ${row.modelData.name}`
                        color: rowHover.hovered ? Theme.fgHover : Theme.fg
                        font.bold: row.modelData.connected
                    }

                    BarText {
                        id: detailText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        visible: row.detail !== ""
                        text: row.detail
                        color: Theme.fg
                    }

                    HoverHandler { id: rowHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (row.busy)
                                return;
                            if (row.modelData.connected)
                                row.modelData.disconnect();
                            else
                                row.modelData.connect();
                        }
                    }
                }
            }
        }
    }
}
