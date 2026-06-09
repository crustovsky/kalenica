import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// Workspace pills with the workspace number and the icons of its windows.
// Click a pill to switch workspace, click an icon to focus that window,
// middle-click an icon to close it.
Row {
    id: root

    required property var screen
    height: parent ? parent.height : undefined
    spacing: 4

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            id: group
            required property var modelData

            visible: modelData.id > 0
                && modelData.monitor !== null
                && modelData.monitor.name === root.screen.name
            width: content.implicitWidth + 16
            height: root.height
            radius: 10
            color: hover.hovered ? Theme.bgHover
                 : modelData.urgent ? Theme.urgentBg
                 : modelData.focused ? Theme.bgHover
                 : "transparent"

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 6

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
                            const entry = DesktopEntries.heuristicLookup(appId);
                            if (entry !== null && entry.icon !== "")
                                return Quickshell.iconPath(entry.icon, "application-x-executable");
                            return Quickshell.iconPath(appId, "application-x-executable");
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (icon.modelData.wayland === null)
                                    return;
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

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: group.modelData.activate()
            }
        }
    }
}
