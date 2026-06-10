import QtQuick
import Quickshell

// One bar module: hover highlight (like waybar's :hover css), optional
// tooltip popup, and click/scroll signals. Content goes in the inner Row.
Rectangle {
    id: root

    default property alias content: inner.data
    property alias spacing: inner.spacing
    property string tooltip: ""
    // display-only modules opt out of the hand cursor
    property bool clickable: true
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(real delta)

    readonly property bool hovered: mouse.containsMouse
    readonly property color fg: hovered ? Theme.fgHover : Theme.fg

    implicitWidth: inner.implicitWidth + 16
    height: parent ? parent.height : inner.implicitHeight
    radius: 10
    color: hovered ? Theme.bgHover : "transparent"

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.clicked();
            else if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.middleClicked();
        }
        onWheel: wheel => root.scrolled(wheel.angleDelta.y / 120)
    }

    property bool showTip: false
    Timer {
        id: tipDelay
        interval: 350
        onTriggered: root.showTip = true
    }
    onHoveredChanged: {
        if (hovered && tooltip !== "")
            tipDelay.start();
        else {
            tipDelay.stop();
            showTip = false;
        }
    }

    PopupWindow {
        visible: root.showTip && root.tooltip !== ""
        anchor.item: root
        anchor.rect.w: root.width
        anchor.rect.h: root.height + 6
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        color: "transparent"
        implicitWidth: tipText.implicitWidth + 20
        implicitHeight: tipText.implicitHeight + 12

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.bg

            BarText {
                id: tipText
                anchors.centerIn: parent
                text: root.tooltip
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
}
