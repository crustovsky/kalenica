pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire

// Anchored device list for the volume/mic bar items (replaces the vicinae
// pulseaudio extension): outputs (sinks: true) or inputs. Click makes a
// device the default.
AnchoredPopup {
    id: root

    property bool sinks: true

    // nodes expose details (ready/audio/description) only while tracked
    readonly property var candidates: Pipewire.nodes.values.filter(n =>
        n.isSink === root.sinks && !n.isStream)
    readonly property var devices: candidates.filter(n => n.ready && n.audio !== null)
    readonly property var current: root.sinks
        ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource

    PwObjectTracker { objects: root.candidates }

    Repeater {
        model: root.devices

        PopupRow {
            id: row
            required property var modelData

            readonly property bool isCurrent:
                root.current !== null && root.current.id === modelData.id

            text: `${isCurrent ? "●" : "○"} ${modelData.description || modelData.name}`
            bold: isCurrent
            onClicked: {
                if (root.sinks)
                    Pipewire.preferredDefaultAudioSink = row.modelData;
                else
                    Pipewire.preferredDefaultAudioSource = row.modelData;
                root.visible = false;
            }
        }
    }
}
