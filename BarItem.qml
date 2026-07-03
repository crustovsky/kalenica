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
    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    // press feedback fired from the MouseArea (so display-only modules don't
    // pulse, and a fast tap still plays in full)
    transformOrigin: Item.Center
    PressPulse { id: pressPulse; item: root }

    // content with its own MouseArea (tray icons) eats the press before the
    // z: -1 area sees it — call this from there to still pulse the module
    function pulse() {
        pressPulse.restart();
    }

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        // under the content, like the workspace pills: clicks must reach
        // mouse areas inside content (tray icons) first
        z: -1
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: { if (root.clickable) pressPulse.restart(); }
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
        interval: 150
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
        id: tip
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
            // springy scale-in on appear (window unmaps instantly on hide → opening only)
            transformOrigin: Item.Top
            scale: tip.visible ? 1 : 0.85
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }

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
