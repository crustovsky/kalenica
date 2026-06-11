import QtQuick
import Quickshell.Io
import Quickshell.Networking

BarItem {
    id: root

    readonly property var device: Networking.devices.values.find(d => d.connected) ?? null
    readonly property var net: device !== null
        ? (device.networks.values.find(n => n.connected) ?? null) : null
    readonly property string ifname: device !== null ? device.name : ""

    property real rxRate: 0
    property real txRate: 0
    property var lastBytes: null
    property string ipInfo: ""

    function fmtRate(bytes) {
        if (bytes >= 1048576)
            return `${(bytes / 1048576).toFixed(1)}MB/s`;
        if (bytes >= 1024)
            return `${(bytes / 1024).toFixed(1)}KB/s`;
        return `${Math.round(bytes)}B/s`;
    }

    function netmask(prefix) {
        const m = [];
        for (let i = 0; i < 4; i++) {
            const bits = Math.min(8, Math.max(0, prefix - i * 8));
            m.push(256 - (1 << 8 - bits));
        }
        return m.join(".");
    }

    tooltip: {
        if (device === null)
            return Networking.wifiEnabled ? "Disconnected" : "Wifi off";
        let lines = [` ${fmtRate(rxRate)}   ${fmtRate(txRate)}`];
        lines.push(`Network: ${net !== null ? net.name : device.name}`);
        if (net !== null && device.type === DeviceType.Wifi) {
            const s = net.signalStrength;
            lines.push(`Signal strength: ${Math.round(s <= 1 ? s * 100 : s)}%`);
        }
        lines.push(`Interface: ${ifname}`);
        if (ipInfo !== "")
            lines.push(ipInfo);
        return lines.join("\n");
    }
    // left click on a disabled radio re-enables it; right click switches off
    onClicked: {
        if (!Networking.wifiEnabled)
            Networking.wifiEnabled = true;
        else
            wifiPopup.toggle();
    }
    onRightClicked: {
        wifiPopup.visible = false;
        Networking.wifiEnabled = false;
    }

    WifiNetworkPopup {
        id: wifiPopup
        anchorItem: root
        passwordPrompt: pskPrompt
    }

    WifiPasswordPrompt { id: pskPrompt }

    FileView {
        id: rxBytes
        path: root.ifname !== "" ? `/sys/class/net/${root.ifname}/statistics/rx_bytes` : ""
        blockLoading: true
    }

    FileView {
        id: txBytes
        path: root.ifname !== "" ? `/sys/class/net/${root.ifname}/statistics/tx_bytes` : ""
        blockLoading: true
    }

    Timer {
        interval: 1000
        running: root.ifname !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            rxBytes.reload();
            txBytes.reload();
            const rx = parseInt(rxBytes.text()) || 0;
            const tx = parseInt(txBytes.text()) || 0;
            if (root.lastBytes !== null) {
                root.rxRate = Math.max(0, rx - root.lastBytes.rx);
                root.txRate = Math.max(0, tx - root.lastBytes.tx);
            }
            root.lastBytes = { rx: rx, tx: tx };
        }
    }

    Process {
        id: ipProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [addrJson, routeJson] = text.split("---");
                    const addr = JSON.parse(addrJson)[0].addr_info.find(a => a.family === "inet");
                    const gw = JSON.parse(routeJson).find(r => r.dev === root.ifname);
                    let lines = [];
                    if (addr !== undefined) {
                        lines.push(`IP: ${addr.local}/${addr.prefixlen}`);
                        if (gw !== undefined)
                            lines.push(`Gateway: ${gw.gateway}`);
                        lines.push(`Netmask: ${root.netmask(addr.prefixlen)}`);
                    }
                    root.ipInfo = lines.join("\n");
                } catch (e) {
                    root.ipInfo = "";
                }
            }
        }
    }

    function fetchIpInfo() {
        if (ifname === "")
            return;
        ipProc.exec(["sh", "-c",
            `ip -j addr show dev ${ifname} 2>/dev/null; echo ---; ip -j route show default 2>/dev/null`]);
    }

    onIfnameChanged: fetchIpInfo()
    onHoveredChanged: { if (hovered) fetchIpInfo(); }

    BarText {
        color: root.fg
        text: root.device === null ? "󰖪 "
            : root.device.type === DeviceType.Wifi ? " " : "󰈀 "
    }
}
