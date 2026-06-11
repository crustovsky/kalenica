import QtQuick
import Quickshell.Bluetooth

BarItem {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOff: adapter !== null && !adapter.enabled
    readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)

    visible: adapter !== null
    tooltip: {
        const adapter = root.adapter;
        if (adapter === null)
            return "";
        if (!adapter.enabled)
            return `${adapter.name}\noff`;
        let lines = [`${adapter.name}\n${connectedDevices.length} connected`];
        for (const dev of connectedDevices)
            lines.push(dev.batteryAvailable
                ? `${dev.name}\t${Math.round(dev.battery * 100)}%` : dev.name);
        return lines.join("\n");
    }
    // left click on a disabled adapter re-enables it; right click switches off
    onClicked: {
        if (btOff)
            adapter.enabled = true;
        else
            devicesPopup.toggle();
    }
    onRightClicked: {
        devicesPopup.visible = false;
        if (adapter !== null)
            adapter.enabled = false;
    }

    BluetoothDevicePopup {
        id: devicesPopup
        anchorItem: root
    }

    BarText {
        color: root.fg
        text: root.btOff ? "󰂲" : (root.connectedDevices.length > 0 ? "" : "")
    }
}
