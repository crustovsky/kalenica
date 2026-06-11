pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Anchored device list for the bluetooth bar item (replaces the vicinae
// bluetooth extension): paired devices, click connects/disconnects. The
// bottom row toggles a scan; discovered devices list below it and click
// pairs + trusts + connects. Closes when the mouse stays away (no
// HyprlandFocusGrab: it eats clicks into popup child surfaces, see CLAUDE.md)
// — except while scanning, so a scan survives fetching the device.
PopupWindow {
    id: root

    required property Item anchorItem

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool scanning: adapter !== null && adapter.discovering

    // name order, not connected-first: rows must not jump under the cursor
    // when a click changes connection state
    readonly property var paired: Bluetooth.devices.values
        .filter(d => d.paired || d.bonded)
        .sort((a, b) => (a.name || "").localeCompare(b.name || ""))
    // discoveries without a device-provided name are address junk; hide them
    readonly property var discovered: scanning ? Bluetooth.devices.values
        .filter(d => !d.paired && !d.bonded && d.deviceName !== "")
        .sort((a, b) => a.deviceName.localeCompare(b.deviceName)) : []

    // device we initiated pairing on: trust + connect once paired lands
    property var pendingDevice: null
    property var failedDevice: null

    function toggle() {
        visible = !visible;
    }

    // never leave the radio scanning in the background
    onVisibleChanged: {
        if (!visible && adapter !== null)
            adapter.discovering = false;
    }

    Connections {
        target: root.pendingDevice

        function onPairedChanged() {
            const dev = root.pendingDevice;
            if (dev.paired) {
                dev.trusted = true;
                dev.connect();
                root.pendingDevice = null;
                if (root.adapter !== null)
                    root.adapter.discovering = false;
            }
        }
        function onPairingChanged() {
            const dev = root.pendingDevice;
            if (!dev.pairing && !dev.paired) {
                root.failedDevice = dev;
                root.pendingDevice = null;
                failedTimer.start();
            }
        }
    }

    Timer {
        id: failedTimer
        interval: 3000
        onTriggered: root.failedDevice = null
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
        running: root.visible && !popHover.hovered && !root.scanning
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
                visible: root.paired.length === 0
                x: 8
                text: "no paired devices"
            }

            Repeater {
                model: root.paired

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

            Rectangle {
                width: column.width - 16
                height: 1
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.fgFaint
            }

            Rectangle {
                id: scanRow

                width: column.width
                height: scanLabel.implicitHeight + 10
                radius: 6
                color: scanHover.hovered ? Theme.bgHover : "transparent"

                BarText {
                    id: scanLabel
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    text: root.scanning ? "scanning… (click to stop)" : "scan for new devices"
                    color: scanHover.hovered ? Theme.fgHover : Theme.fg
                }

                HoverHandler { id: scanHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.adapter !== null)
                            root.adapter.discovering = !root.scanning;
                    }
                }
            }

            Repeater {
                model: root.discovered

                Rectangle {
                    id: foundRow
                    required property var modelData

                    readonly property string detail: {
                        if (modelData === root.pendingDevice || modelData.pairing)
                            return "pairing…";
                        if (modelData === root.failedDevice)
                            return "failed";
                        return "";
                    }

                    width: column.width
                    height: foundLabel.implicitHeight + 10
                    radius: 6
                    color: foundHover.hovered ? Theme.bgHover : "transparent"

                    BarText {
                        id: foundLabel
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16 - (foundDetail.visible ? foundDetail.implicitWidth + 8 : 0)
                        elide: Text.ElideRight
                        text: `+ ${foundRow.modelData.deviceName}`
                        color: foundHover.hovered ? Theme.fgHover : Theme.fg
                    }

                    BarText {
                        id: foundDetail
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        visible: foundRow.detail !== ""
                        text: foundRow.detail
                        color: foundRow.detail === "failed" ? Theme.critical : Theme.fg
                    }

                    HoverHandler { id: foundHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (foundRow.modelData.pairing || root.pendingDevice !== null)
                                return;
                            root.failedDevice = null;
                            root.pendingDevice = foundRow.modelData;
                            foundRow.modelData.pair();
                        }
                    }
                }
            }
        }
    }
}
