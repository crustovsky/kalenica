pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Networking

// Anchored wifi network list for the network bar item: known/open networks
// connect on click, the connected one disconnects, secured unknown ones
// (lock marker) open the password prompt. Actively scans while open.
AnchoredPopup {
    id: root

    required property var passwordPrompt

    readonly property var wifiDevice: Networking.devices.values.find(
        d => d.type === DeviceType.Wifi) ?? null
    // connected pinned on top so it can't jump under the cursor, then
    // strongest first
    readonly property var networks: wifiDevice !== null
        ? [...wifiDevice.networks.values].sort((a, b) =>
            (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
        : []

    property var failedNet: null

    onVisibleChanged: {
        if (wifiDevice !== null)
            wifiDevice.scannerEnabled = visible;
    }

    Timer {
        id: failedTimer
        interval: 3000
        onTriggered: root.failedNet = null
    }

    BarText {
        visible: root.networks.length === 0
        x: 8
        text: "no networks"
    }

    Repeater {
        model: root.networks

        PopupRow {
            id: row
            required property var modelData

            readonly property bool open:
                modelData.security === WifiSecurityType.Open
                || modelData.security === WifiSecurityType.Owe
            readonly property bool needsKey: !modelData.known && !open

            Connections {
                target: row.modelData
                function onConnectionFailed() {
                    root.failedNet = row.modelData;
                    failedTimer.restart();
                }
            }

            text: `${modelData.connected ? "●" : "○"} ${modelData.name}`
                + (needsKey ? " 󰌾" : "")
            bold: modelData.connected
            detail: {
                if (modelData.stateChanging)
                    return modelData.state === ConnectionState.Disconnecting
                        ? "disconnecting…" : "connecting…";
                if (modelData === root.failedNet)
                    return "failed";
                const s = modelData.signalStrength;
                return `${Math.round(s <= 1 ? s * 100 : s)}%`;
            }
            detailColor: detail === "failed" ? Theme.critical : Theme.fg
            onClicked: {
                if (modelData.stateChanging)
                    return;
                if (modelData.connected) {
                    modelData.disconnect();
                } else if (needsKey) {
                    root.passwordPrompt.ask(modelData);
                    root.visible = false;
                } else {
                    root.failedNet = null;
                    modelData.connect();
                }
            }
        }
    }
}
