pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Alt-tab style window switcher (the hyprexpo itch, scoped down): centered
// overlay with a card per window — live preview, title, workspace number.
// At most 3x2 cards are visible; beyond that the grid scrolls (keyboard
// selection drags the viewport along, mouse wheel scrolls by row).
// Toggle with `qs ipc call expo toggle` (Meta+A). Tab/arrows cycle, Enter or
// click focuses, Esc closes. Cards are sorted most-recently-used first and
// the previous window starts selected, so open+Enter flips like alt-tab.
// Previews of windows on hidden workspaces are snapshots from when they were
// last visible (the compositor doesn't re-render hidden windows).
Scope {
    id: root

    property bool shown: false
    property var windows: []
    property int selected: 0

    function focusId(t) {
        return t.lastIpcObject !== null && t.lastIpcObject.focusHistoryID !== undefined
            ? t.lastIpcObject.focusHistoryID : 999;
    }

    function toggle() {
        if (shown) {
            shown = false;
            return;
        }
        Hyprland.refreshToplevels();
        windows = Hyprland.toplevels.values
            .filter(t => t.wayland !== null && t.workspace !== null && t.workspace.id > 0)
            .sort((a, b) => focusId(a) - focusId(b));
        selected = windows.length > 1 ? 1 : 0;
        shown = true;
    }

    function activateSelected() {
        const t = windows[selected];
        // close first: activating while the panel still holds exclusive
        // focus gets undone when the unmap hands focus back
        shown = false;
        if (t !== undefined && t.wayland !== null)
            t.wayland.activate();
    }

    IpcHandler {
        target: "expo"

        function toggle(): void {
            root.toggle();
        }
    }

    PanelWindow {
        id: panel

        readonly property int cardW: 300
        readonly property int cardH: 196
        readonly property int gap: 12

        screen: Screens.focused()

        visible: root.shown
        // no anchors: the compositor centers an unanchored layer surface
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive
                                             : WlrKeyboardFocus.None
        color: "transparent"
        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight

        onVisibleChanged: {
            if (visible)
                keyCatcher.forceActiveFocus();
        }

        Rectangle {
            id: frame
            anchors.fill: parent
            implicitWidth: grid.width + 32
            implicitHeight: grid.height + 32
            radius: 12
            color: Theme.notifBg
            border.width: 2
            border.color: Theme.notifBorder

            Item {
                id: keyCatcher
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    const n = root.windows.length;
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape)
                        root.shown = false;
                    else if (n === 0)
                        return;
                    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right
                            || event.key === Qt.Key_Down)
                        root.selected = (root.selected + 1) % n;
                    else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left
                            || event.key === Qt.Key_Up)
                        root.selected = (root.selected + n - 1) % n;
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.activateSelected();
                }
            }

            BarText {
                anchors.centerIn: parent
                visible: root.windows.length === 0
                text: "no windows"
                color: Theme.fgDim
            }

            GridView {
                id: grid

                readonly property int cols: Math.max(1, Math.min(3, root.windows.length))
                readonly property int rows: Math.max(1, Math.min(2, Math.ceil(root.windows.length / 3)))

                anchors.centerIn: parent
                width: cols * cellWidth
                height: rows * cellHeight
                cellWidth: panel.cardW + panel.gap
                cellHeight: panel.cardH + panel.gap
                clip: true
                interactive: root.windows.length > 6
                snapMode: GridView.SnapToRow
                boundsBehavior: Flickable.StopAtBounds
                model: root.windows
                // dragging the selection past an edge scrolls the viewport
                currentIndex: root.selected

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        id: card
                        readonly property var modelData: cell.modelData
                        readonly property int index: cell.index

                        anchors.centerIn: parent
                        width: panel.cardW
                        height: panel.cardH
                        radius: 10
                        color: cell.index === root.selected ? Theme.bgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Config.timing.hoverFade } }

                        transformOrigin: Item.Center
                        PressPulse { id: cardPulse; item: card }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            ScreencopyView {
                                anchors.horizontalCenter: parent.horizontalCenter
                                captureSource: card.modelData.wayland
                                live: panel.visible
                                constraintSize: Qt.size(280, 150)
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 18
                                    visible: card.modelData.wayland !== null
                                    source: {
                                        void DesktopEntries.applications.values;
                                        const appId = card.modelData.wayland !== null
                                            ? card.modelData.wayland.appId : "";
                                        return AppIcon.forAppId(appId);
                                    }
                                }

                                BarText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: card.modelData.workspace !== null
                                        ? card.modelData.workspace.id : ""
                                    color: card.index === root.selected
                                        ? Theme.fgHover : Theme.fgDim
                                }

                                BarText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    property real maxWidth: 220
                                    width: Math.min(implicitWidth, maxWidth)
                                    elide: Text.ElideRight
                                    font.bold: false
                                    text: card.modelData.wayland !== null
                                        ? card.modelData.wayland.title : ""
                                    color: card.index === root.selected
                                        ? Theme.fgHover : Theme.fg
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = card.index
                            onPressed: cardPulse.restart()
                            onClicked: root.activateSelected()
                        }
                    }
                }
            }
        }
    }
}
