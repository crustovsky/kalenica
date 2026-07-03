pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Bluetooth

// Anchored device list for the bluetooth bar item (replaces the vicinae
// bluetooth extension): paired devices, click connects/disconnects. The
// bottom row toggles a scan; discovered devices list below it and click
// pairs + trusts + connects. holdOpen while scanning, so a scan survives
// the mouse leaving to fetch the device.
AnchoredPopup {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool scanning: adapter !== null && adapter.discovering

    holdOpen: scanning

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

    BarText {
        visible: root.paired.length === 0
        x: 8
        text: "no paired devices"
    }

    Repeater {
        model: root.paired

        PopupRow {
            id: row
            required property var modelData

            readonly property bool busy:
                modelData.state === BluetoothDeviceState.Connecting
                || modelData.state === BluetoothDeviceState.Disconnecting

            text: `${modelData.connected ? "●" : "○"} ${modelData.name}`
            bold: modelData.connected
            detail: {
                if (modelData.state === BluetoothDeviceState.Connecting)
                    return "connecting…";
                if (modelData.state === BluetoothDeviceState.Disconnecting)
                    return "disconnecting…";
                if (modelData.connected && modelData.batteryAvailable)
                    return `${Math.round(modelData.battery * 100)}%`;
                return "";
            }
            onClicked: {
                if (busy)
                    return;
                if (modelData.connected)
                    modelData.disconnect();
                else
                    modelData.connect();
            }
        }
    }

    Rectangle {
        width: parent.width - 16
        height: 1
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.fgFaint
    }

    PopupRow {
        bold: true
        text: root.scanning ? "scanning… (click to stop)" : "scan for new devices"
        onClicked: {
            if (root.adapter !== null)
                root.adapter.discovering = !root.scanning;
        }
    }

    Repeater {
        model: root.discovered

        PopupRow {
            required property var modelData

            bold: true
            text: `+ ${modelData.deviceName}`
            detail: {
                if (modelData === root.pendingDevice || modelData.pairing)
                    return "pairing…";
                if (modelData === root.failedDevice)
                    return "failed";
                return "";
            }
            detailColor: detail === "failed" ? Theme.critical : Theme.fg
            onClicked: {
                if (modelData.pairing || root.pendingDevice !== null)
                    return;
                root.failedDevice = null;
                root.pendingDevice = modelData;
                modelData.pair();
            }
        }
    }
}
