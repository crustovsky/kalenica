import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Volume OSD replacing swayosd: a centered card near the bottom of the
// focused monitor, shown on any default-sink volume/mute change (keybinds,
// bar scroll, apps) and hidden 1.5s after the last one. show() is generic
// (icon + 0..1 value), the scaffold for the brightness OSD later.
Scope {
    id: root

    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property real vol: audio !== null ? audio.volume : -1
    readonly property bool muted: audio !== null && audio.muted

    readonly property var micAudio: Pipewire.defaultAudioSource?.audio ?? null
    readonly property real micVol: micAudio !== null ? micAudio.volume : -1
    readonly property bool micMuted: micAudio !== null && micAudio.muted

    // Pipewire populates asynchronously after startup; -1 means "no baseline
    // yet" so the initial snapshot doesn't flash the OSD on login.
    property real lastVol: -1
    property int lastMuted: -1
    property real lastMicVol: -1
    property int lastMicMuted: -1

    property string icon
    property real value
    property bool dimmed: false
    // when set, the OSD shows on this monitor instead of the focused one
    // (brightness targets the monitor under the cursor)
    property string screenOverride: ""

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    function show(icon: string, value: real, dimmed: bool) {
        showOn("", icon, value, dimmed);
    }

    function showOn(screenName: string, icon: string, value: real, dimmed: bool) {
        root.screenOverride = screenName;
        root.icon = icon;
        root.value = Math.max(0, Math.min(1, value));
        root.dimmed = dimmed;
        panel.visible = true;
        hideTimer.restart();
    }

    function showVolume() {
        const icon = muted ? "󰝟"
            : vol < 0.33 ? "󰕿" : vol < 0.66 ? "󰖀" : "󰕾";
        show(icon, vol, muted);
    }

    function showMic() {
        show(micMuted ? "󰍭" : "󰍬", micVol, micMuted);
    }

    // muted is false both before and usually after the async Pipewire
    // population, so onMutedChanged never fires to set the baseline —
    // without this, the first mute toggle after startup shows no OSD.
    onAudioChanged: {
        if (audio !== null && lastMuted < 0)
            lastMuted = muted ? 1 : 0;
    }

    onMicAudioChanged: {
        if (micAudio !== null && lastMicMuted < 0)
            lastMicMuted = micMuted ? 1 : 0;
    }

    onVolChanged: {
        if (vol < 0)
            return;
        const last = lastVol;
        lastVol = vol;
        if (last >= 0 && Math.abs(vol - last) > 0.0001)
            showVolume();
    }

    onMutedChanged: {
        if (audio === null)
            return;
        const m = muted ? 1 : 0;
        const last = lastMuted;
        lastMuted = m;
        if (last >= 0 && m !== last)
            showVolume();
    }

    onMicVolChanged: {
        if (micVol < 0)
            return;
        const last = lastMicVol;
        lastMicVol = micVol;
        if (last >= 0 && Math.abs(micVol - last) > 0.0001)
            showMic();
    }

    onMicMutedChanged: {
        if (micAudio === null)
            return;
        const m = micMuted ? 1 : 0;
        const last = lastMicMuted;
        lastMicMuted = m;
        if (last >= 0 && m !== last)
            showMic();
    }

    // Kbd backlight: the non-consuming keybind calls `qs ipc call osd kbdlight`.
    IpcHandler {
        target: "osd"

        function kbdlight(): void {
            kbdTimer.restart();
        }
    }

    Timer {
        id: kbdTimer
        // the EC cycles the backlight itself; give it a beat to apply
        interval: 150
        onTriggered: kbdProc.exec(["brightnessctl", "-m", "-d", "platform::kbd_backlight"])
    }

    Process {
        id: kbdProc
        stdout: StdioCollector {
            // machine-readable: device,class,current,percent%,max
            onStreamFinished: {
                const pct = parseInt(text.split(",")[3]);
                if (!isNaN(pct))
                    root.show("󰌌", pct / 100, pct === 0);
            }
        }
    }

    Timer {
        id: hideTimer
        interval: Config.modules.osd.hideDelay
        onTriggered: panel.visible = false
    }

    PanelWindow {
        id: panel

        screen: {
            const focused = Hyprland.focusedMonitor;
            for (const s of Quickshell.screens) {
                if (s.name === root.screenOverride)
                    return s;
                if (root.screenOverride === ""
                    && focused !== null && s.name === focused.name)
                    return s;
            }
            return Quickshell.screens[0] ?? null;
        }

        visible: false
        anchors.bottom: true
        margins.bottom: 120
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        Rectangle {
            id: card
            anchors.fill: parent
            implicitWidth: row.implicitWidth + 36
            implicitHeight: row.implicitHeight + 20
            radius: 10
            color: Theme.notifBg
            border.width: 2
            border.color: Theme.notifBorder

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 12

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    // fixed width so the card doesn't resize as glyphs swap
                    width: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: root.icon
                    color: Theme.notifFg
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 160
                    height: 6
                    radius: 3
                    color: Theme.fgFaint

                    Rectangle {
                        width: parent.width * root.value
                        height: parent.height
                        radius: parent.radius
                        color: root.dimmed ? Theme.fgFaint : Theme.notifFg
                    }
                }

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: `${Math.round(root.value * 100)}%`
                    color: Theme.notifFg
                    font.bold: false
                }
            }
        }
    }
}
