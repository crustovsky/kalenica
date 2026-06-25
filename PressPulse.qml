import QtQuick

// Triggered squish-and-spring press feedback. Set `item` and call restart()
// from a MouseArea; the item needs transformOrigin: Item.Center. Scale is
// render-only, so it never reflows.
SequentialAnimation {
    id: root
    property Item item

    NumberAnimation {
        target: root.item; property: "scale"
        to: 0.88; duration: 70; easing.type: Easing.OutQuad
    }
    NumberAnimation {
        target: root.item; property: "scale"
        to: 1.0; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.6
    }
}
