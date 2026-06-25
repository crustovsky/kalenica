import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// Workspace pills with the workspace number and the icons of its windows.
// Every workspace is shown; ones living on another monitor are dimmed.
// Click a pill to switch workspace, click an icon to focus that window,
// middle-click an icon to close it. Drag an icon onto a pill to silently
// move the window there; right-click a dimmed pill to pull that workspace
// onto this monitor.
Row {
    id: root

    required property var screen
    // toplevel riding the drag ghost
    property var dragWindow: null
    // created lazily on the window's content item: a ghost declared here and
    // reparented out stops the first pill from painting (Qt scene quirk)
    property Item ghost: null

    height: parent ? parent.height : undefined
    spacing: 4

    Component {
        id: ghostComponent

        IconImage {
            implicitSize: 16
            visible: Drag.active
            z: 100
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            layer.enabled: true
            layer.effect: MultiEffect {
                saturation: -1
                colorization: 1
                colorizationColor: Theme.fg
            }
        }
    }

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            id: group
            required property var modelData

            // root.screen null-checked: it dies first when a monitor goes away
            readonly property bool foreign: modelData.monitor === null
                || root.screen === null || modelData.monitor.name !== root.screen.name

            visible: modelData.id > 0
            width: content.implicitWidth + 16
            height: root.height
            radius: 10
            color: drop.containsDrag || hover.hovered ? Theme.bgHover
                 : modelData.urgent ? Theme.urgentBg
                 : modelData.focused ? Theme.bgHover
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            transformOrigin: Item.Center
            PressPulse { id: pillPulse; item: group }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 6
                opacity: group.foreign ? 0.45 : 1

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.modelData.id
                    color: hover.hovered || group.modelData.focused || group.modelData.urgent
                         ? Theme.fgHover : Theme.fg
                }

                Repeater {
                    model: group.modelData.toplevels

                    IconImage {
                        id: icon
                        required property var modelData

                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        source: {
                            void DesktopEntries.applications.values;
                            const appId = icon.modelData.wayland !== null ? icon.modelData.wayland.appId : "";
                            return AppIcon.forAppId(appId);
                        }

                        // monochrome, tinted like the pill's text
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            saturation: -1
                            colorization: 1
                            colorizationColor: hover.hovered || group.modelData.focused
                                || group.modelData.urgent ? Theme.fgHover : Theme.fg
                        }

                        MouseArea {
                            id: iconMouse

                            property bool dragged: false

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            drag.target: root.ghost

                            onPressed: mouse => {
                                dragged = false;
                                if (mouse.button !== Qt.LeftButton)
                                    return;
                                if (root.ghost === null)
                                    root.ghost = ghostComponent.createObject(QsWindow.contentItem);
                                const pos = icon.mapToItem(root.ghost.parent, 0, 0);
                                root.ghost.x = pos.x;
                                root.ghost.y = pos.y;
                                root.ghost.source = icon.source;
                            }
                            onPositionChanged: mouse => {
                                if (drag.active && (mouse.buttons & Qt.LeftButton) && !dragged) {
                                    dragged = true;
                                    root.dragWindow = icon.modelData;
                                    root.ghost.Drag.active = true;
                                }
                            }
                            onReleased: {
                                if (root.ghost !== null && root.ghost.Drag.active) {
                                    root.ghost.Drag.drop();
                                    root.ghost.Drag.active = false;
                                }
                                root.dragWindow = null;
                            }
                            onClicked: mouse => {
                                if (dragged || icon.modelData.wayland === null)
                                    return;
                                pillPulse.restart();
                                if (mouse.button === Qt.LeftButton)
                                    icon.modelData.wayland.activate();
                                else
                                    icon.modelData.wayland.close();
                            }
                        }
                    }
                }
            }

            HoverHandler { id: hover }

            DropArea {
                id: drop
                anchors.fill: parent
                onDropped: {
                    const w = root.dragWindow;
                    if (w !== null)
                        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${group.modelData.id}, follow = false, window = "address:0x${w.address}" })`);
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: pillPulse.restart()
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        if (group.foreign)
                            Hyprland.dispatch(`hl.dsp.workspace.move({ workspace = ${group.modelData.id}, monitor = "${root.screen.name}" })`);
                    } else {
                        group.modelData.activate();
                    }
                }
            }
        }
    }
}
