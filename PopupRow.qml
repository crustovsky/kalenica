import QtQuick

// One hover/click row in an AnchoredPopup: elided label, optional
// right-aligned detail.
Rectangle {
    id: root

    property alias text: label.text
    property string detail: ""
    property color detailColor: Theme.fg
    property bool bold: false
    signal clicked()

    width: parent.width
    height: label.implicitHeight + 10
    radius: 6
    color: hover.hovered ? Theme.bgHover : "transparent"
    Behavior on color {
        ColorAnimation { duration: Config.timing.hoverFade }
    }

    BarText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        width: parent.width - 16 - (detailText.visible ? detailText.implicitWidth + 8 : 0)
        elide: Text.ElideRight
        color: hover.hovered ? Theme.fgHover : Theme.fg
        font.bold: root.bold
    }

    BarText {
        id: detailText
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 8
        visible: root.detail !== ""
        text: root.detail
        color: root.detailColor
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
