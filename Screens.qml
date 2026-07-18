pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Shared ShellScreen lookups — Notifications/Osd/Expo/Screenshot all need
// "the screen of Hyprland's focused monitor" (extracted at the fourth copy).
Singleton {
    function focused(): var {
        const f = Hyprland.focusedMonitor;
        return Quickshell.screens.find(s => f !== null && s.name === f.name)
            ?? Quickshell.screens[0] ?? null;
    }

    function byName(name: string): var {
        return Quickshell.screens.find(s => s.name === name) ?? null;
    }
}
