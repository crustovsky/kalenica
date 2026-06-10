pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Anchored device list for the volume/mic bar items (replaces the vicinae
// pulseaudio extension): outputs (sinks: true) or inputs. Click makes a
// device the default; closes when the mouse stays away (no HyprlandFocusGrab:
// it eats clicks into popup child surfaces, see CLAUDE.md).
PopupWindow {
    id: root

    property bool sinks: true
    required property Item anchorItem

    // nodes expose details (ready/audio/description) only while tracked
    readonly property var candidates: Pipewire.nodes.values.filter(n =>
        n.isSink === root.sinks && !n.isStream)
    readonly property var devices: candidates.filter(n => n.ready && n.audio !== null)
    readonly property var current: root.sinks
        ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource

    PwObjectTracker { objects: root.candidates }

    function toggle() {
        visible = !visible;
    }

    anchor.item: anchorItem
    anchor.rect.w: anchorItem.width
    anchor.rect.h: anchorItem.height + 6
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    color: "transparent"
    implicitWidth: 320
    implicitHeight: column.implicitHeight + 16

    Timer {
        interval: 1500
        running: root.visible && !popHover.hovered
        onTriggered: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.bg

        HoverHandler { id: popHover }

        Column {
            id: column
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 2

            Repeater {
                model: root.devices

                Rectangle {
                    id: row
                    required property var modelData

                    readonly property bool isCurrent:
                        root.current !== null && root.current.id === modelData.id

                    width: column.width
                    height: label.implicitHeight + 10
                    radius: 6
                    color: rowHover.hovered ? Theme.bgHover : "transparent"

                    BarText {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        elide: Text.ElideRight
                        text: `${row.isCurrent ? "●" : "○"} ${row.modelData.description || row.modelData.name}`
                        color: rowHover.hovered ? Theme.fgHover : Theme.fg
                        font.bold: row.isCurrent
                    }

                    HoverHandler { id: rowHover }

                    MouseArea {
                        anchors.fill: parent
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
        }
    }
}
