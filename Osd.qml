import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Volume OSD replacing swayosd: a centered card near the bottom of the
// focused monitor, shown on any default-sink volume/mute change (keybinds,
// bar scroll, apps) and hidden 1.5s after the last one. show() is generic
// (icon + 0..1 value); showText() swaps the bar for a short line, for
// toasts that used to be 1s notifications (`qs ipc call osd text <icon>
// <text>` from the Hyprland scale/layout cyclers).
Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null

    readonly property var source: Pipewire.defaultAudioSource
    readonly property var micAudio: source?.audio ?? null

    property string icon
    property real value
    property bool dimmed: false
    // non-empty: text mode (no bar)
    property string text: ""
    // when set, the OSD shows on this monitor instead of the focused one
    // (brightness targets the monitor under the cursor)
    property string screenOverride: ""

    PwObjectTracker { objects: [root.sink, root.source] }

    // A node's volume lands before its `ready` sync completes, so the guard
    // swallows the population burst (login, a new default device); and a
    // retargeted Connections doesn't emit, so switching sinks stays quiet.
    Connections {
        target: root.audio
        function onVolumesChanged() { if (root.sink.ready) root.showVolume(); }
        function onMutedChanged() { if (root.sink.ready) root.showVolume(); }
    }

    Connections {
        target: root.micAudio
        function onVolumesChanged() { if (root.source.ready) root.showMic(); }
        function onMutedChanged() { if (root.source.ready) root.showMic(); }
    }

    function show(icon: string, value: real, dimmed: bool) {
        showOn("", icon, value, dimmed);
    }

    function showOn(screenName: string, icon: string, value: real, dimmed: bool) {
        root.screenOverride = screenName;
        root.icon = icon;
        root.value = Math.max(0, Math.min(1, value));
        root.dimmed = dimmed;
        root.text = "";
        panel.visible = true;
        hideTimer.restart();
    }

    function showText(icon: string, text: string) {
        root.screenOverride = "";
        root.icon = icon;
        root.text = text;
        panel.visible = true;
        hideTimer.restart();
    }

    // Read the node directly: the Connections handlers above run before
    // this object's vol/muted bindings re-evaluate, so those still hold the
    // previous value (the OSD showed the old mute state).
    function showVolume() {
        const v = audio.volume, m = audio.muted;
        const icon = m ? "󰝟"
            : v < 0.33 ? "󰕿" : v < 0.66 ? "󰖀" : "󰕾";
        show(icon, v, m);
    }

    function showMic() {
        show(micAudio.muted ? "󰍭" : "󰍬", micAudio.volume, micAudio.muted);
    }

    // Kbd backlight: the non-consuming keybind calls `qs ipc call osd kbdlight`.
    IpcHandler {
        target: "osd"

        function kbdlight(): void {
            kbdTimer.restart();
        }

        function text(icon: string, text: string): void {
            root.showText(icon, text);
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

        screen: Screens.byName(root.screenOverride) ?? Screens.focused()

        visible: false
        anchors.bottom: true
        margins.bottom: 120
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kalenica-osd"
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

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.text !== ""
                    text: root.text
                    color: Theme.notifFg
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.text === ""
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
                    visible: root.text === ""
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
