import QtQuick

// Waybar-style drawer group: first child is always visible,
// the rest slide out on hover.
Item {
    id: root

    default property alias content: row.data
    readonly property bool expanded: hover.hovered

    height: parent ? parent.height : row.implicitHeight
    implicitWidth: expanded ? row.implicitWidth
                            : (row.visibleChildren.length > 0 ? row.visibleChildren[0].implicitWidth : 0)
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
    }

    Row {
        id: row
        height: parent.height
    }

    HoverHandler { id: hover }
}
