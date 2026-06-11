import QtQuick
import Quickshell.Bluetooth

BarItem {
    id: root

    readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)

    visible: Bluetooth.defaultAdapter !== null
    tooltip: {
        const adapter = Bluetooth.defaultAdapter;
        if (adapter === null)
            return "";
        let lines = [`${adapter.name}\n${connectedDevices.length} connected`];
        for (const dev of connectedDevices)
            lines.push(dev.batteryAvailable
                ? `${dev.name}\t${Math.round(dev.battery * 100)}%` : dev.name);
        return lines.join("\n");
    }
    onClicked: devicesPopup.toggle()

    BluetoothDevicePopup {
        id: devicesPopup
        anchorItem: root
    }

    BarText {
        color: root.fg
        text: root.connectedDevices.length > 0 ? "" : ""
    }
}
