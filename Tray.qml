import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

BarItem {
    id: root

    spacing: 10

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property var modelData

            width: 13
            height: 13

            IconImage {
                implicitSize: 13
                anchors.centerIn: parent
                source: trayItem.modelData.icon
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.rect.h: trayItem.height + 12
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton && !trayItem.modelData.onlyMenu)
                        trayItem.modelData.activate();
                    else if (trayItem.modelData.hasMenu)
                        menuAnchor.open();
                }
            }
        }
    }
}
