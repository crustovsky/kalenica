import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell's Networking/Bluetooth backends bind NetworkManager/BlueZ D-Bus
// objects once at startup and never re-register when the daemon restarts (no
// service watcher upstream, checked v0.3.0 through master) — after e.g. a
// `systemctl restart NetworkManager` the bar shows "no wifi" forever. Poll the
// bus name owners; when one changes, restart the shell unit to rebind.
Scope {
    id: root

    readonly property var watchedNames: ["org.freedesktop.NetworkManager", "org.bluez"]
    property var owners: ({})
    property bool healing: false

    Timer {
        interval: 15000
        running: !root.healing
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const q = root.watchedNames.map(n =>
                `printf '%s %s\\n' ${n} "$(busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s ${n} 2>/dev/null | cut -d'"' -f2)"`
            ).join(";");
            ownerProc.exec(["sh", "-c", q]);
        }
    }

    Process {
        id: ownerProc
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const [name, owner] = line.split(" ");
                    const prev = root.owners[name];
                    // a change to a new live owner means the daemon restarted;
                    // owner -> "" is just the daemon stopping, keep waiting
                    if (prev !== undefined && owner !== undefined && owner !== "" && owner !== prev && !root.healing) {
                        console.warn(`${name} owner changed (${prev || "none"} -> ${owner}), restarting shell to rebind`);
                        root.healing = true;
                        healProc.exec(["systemctl", "--user", "try-restart", "quickshell.service"]);
                    }
                    root.owners[name] = owner ?? "";
                }
            }
        }
    }

    Process { id: healProc }
}
