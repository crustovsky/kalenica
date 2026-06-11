pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Alt-tab style window switcher (the hyprexpo itch, scoped down): centered
// overlay with a card per window — live preview, title, workspace number.
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
        if (t !== undefined && t.wayland !== null)
            t.wayland.activate();
        shown = false;
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
        readonly property int perRow: Math.max(1, Math.min(root.windows.length,
            Math.floor((screen !== null ? screen.width * 0.85 : 1600) / (cardW + gap))))

        screen: {
            const focused = Hyprland.focusedMonitor;
            for (const s of Quickshell.screens) {
                if (focused !== null && s.name === focused.name)
                    return s;
            }
            return Quickshell.screens[0] ?? null;
        }

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
            implicitWidth: flow.width + 32
            implicitHeight: flow.implicitHeight + 32
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

            Flow {
                id: flow
                anchors.centerIn: parent
                width: panel.perRow * (panel.cardW + panel.gap) - panel.gap
                spacing: panel.gap

                BarText {
                    visible: root.windows.length === 0
                    text: "no windows"
                    color: Theme.fgDim
                }

                Repeater {
                    model: root.windows

                    Rectangle {
                        id: card
                        required property var modelData
                        required property int index

                        width: panel.cardW
                        height: panel.cardH
                        radius: 10
                        color: index === root.selected ? Theme.bgHover : "transparent"

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

                                BarText {
                                    text: card.modelData.workspace !== null
                                        ? card.modelData.workspace.id : ""
                                    color: card.index === root.selected
                                        ? Theme.fgHover : Theme.fgDim
                                }

                                BarText {
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
                            onClicked: root.activateSelected()
                        }
                    }
                }
            }
        }
    }
}
