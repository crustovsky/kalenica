import QtQuick

// Bordered pill button for dialog/notification cards. Highlight follows
// hover by default; bind `highlighted` to drive it externally
// (ConfirmDialog's keyboard selection).
Rectangle {
    id: root

    property alias text: label.text
    readonly property bool hovered: hover.hovered
    property bool highlighted: hovered
    property int padX: 28
    property int padY: 10
    signal clicked()

    width: label.implicitWidth + padX
    height: label.implicitHeight + padY
    radius: 8
    color: highlighted ? Theme.bgHover : "transparent"
    Behavior on color {
        ColorAnimation { duration: Config.timing.hoverFade }
    }
    border.width: 1
    border.color: Theme.notifBorder

    BarText {
        id: label
        anchors.centerIn: parent
        color: root.highlighted ? Theme.fgHover : Theme.notifFg
        font.bold: false
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
