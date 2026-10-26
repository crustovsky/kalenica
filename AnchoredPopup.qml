import QtQuick
import Quickshell
import Quickshell.Hyprland

// Chrome shared by the anchored list popups (audio/wifi/bluetooth): window
// anchored under its bar item, springy scale-in card, closes when the mouse
// stays away (no HyprlandFocusGrab: it eats clicks into popup child
// surfaces, see CLAUDE.md). `shown` is the request; the window stays mapped
// until the close animation ends, faded compositor-side by
// HyprlandWindow.opacity (which takes the blur along, unlike item opacity).
// Rows go in the inner Column; non-visual helpers (timers, trackers) can
// live there too.
PopupWindow {
    id: root

    required property Item anchorItem
    default property alias content: column.data
    // holds the popup open while the mouse is away (bluetooth scan)
    property bool holdOpen: false
    property bool shown: false
    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: Config.timing.popupGrow }
    }

    function toggle() {
        shown = !shown;
    }

    anchor.item: anchorItem
    anchor.rect.w: anchorItem.width
    anchor.rect.h: anchorItem.height + 6
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    color: "transparent"
    implicitWidth: 320
    implicitHeight: column.implicitHeight + 16
    visible: shown || reveal > 0
    HyprlandWindow.opacity: reveal

    Timer {
        interval: Config.timing.popupHoverClose
        running: root.shown && !popHover.hovered && !root.holdOpen
        onTriggered: root.shown = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.bg
        // springy scale on open, shrink back while the window fades out
        transformOrigin: Item.Top
        scale: root.shown ? 1 : 0.85
        Behavior on scale {
            NumberAnimation { duration: Config.timing.popupGrow; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        HoverHandler { id: popHover }

        Column {
            id: column
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 2
        }
    }
}
