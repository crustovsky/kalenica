pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Networking

// Anchored wifi network list for the network bar item: known/open networks
// connect on click, the connected one disconnects, secured unknown ones
// (lock marker) deep-link to vicinae for the password. Actively scans while
// open. Closes when the mouse stays away (no HyprlandFocusGrab: it eats
// clicks into popup child surfaces, see CLAUDE.md).
PopupWindow {
    id: root

    required property Item anchorItem

    readonly property var wifiDevice: Networking.devices.values.find(
        d => d.type === DeviceType.Wifi) ?? null
    // connected pinned on top so it can't jump under the cursor, then
    // strongest first
    readonly property var networks: wifiDevice !== null
        ? [...wifiDevice.networks.values].sort((a, b) =>
            (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
        : []

    property var failedNet: null

    function toggle() {
        visible = !visible;
    }

    onVisibleChanged: {
        if (wifiDevice !== null)
            wifiDevice.scannerEnabled = visible;
    }

    Timer {
        id: failedTimer
        interval: 3000
        onTriggered: root.failedNet = null
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
                visible: root.networks.length === 0
                x: 8
                text: "no networks"
            }

            Repeater {
                model: root.networks

                Rectangle {
                    id: row
                    required property var modelData

                    readonly property bool open:
                        modelData.security === WifiSecurityType.Open
                        || modelData.security === WifiSecurityType.Owe
                    readonly property bool needsKey: !modelData.known && !open
                    readonly property string detail: {
                        if (modelData.stateChanging)
                            return modelData.state === ConnectionState.Disconnecting
                                ? "disconnecting…" : "connecting…";
                        if (modelData === root.failedNet)
                            return "failed";
                        const s = modelData.signalStrength;
                        return `${Math.round(s <= 1 ? s * 100 : s)}%`;
                    }

                    Connections {
                        target: row.modelData
                        function onConnectionFailed() {
                            root.failedNet = row.modelData;
                            failedTimer.restart();
                        }
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
                            + (row.needsKey ? " 󰌾" : "")
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
                        color: row.detail === "failed" ? Theme.critical : Theme.fg
                    }

                    HoverHandler { id: rowHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (row.modelData.stateChanging)
                                return;
                            if (row.modelData.connected) {
                                row.modelData.disconnect();
                            } else if (row.needsKey) {
                                Quickshell.execDetached(["vicinae",
                                    "vicinae://launch/@dagimg-dot/store.vicinae.wifi-commander/scan-wifi"]);
                                root.visible = false;
                            } else {
                                root.failedNet = null;
                                row.modelData.connect();
                            }
                        }
                    }
                }
            }
        }
    }
}
