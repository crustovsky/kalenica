pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Native screenshots (replaced grimblast 2026-07-16): dated png to ~/Pictures,
// wl-copy to clipboard, notify on save — `qs ipc call screenshot
// screen|active|area`. screen = focused monitor, active = focused window
// (via ToplevelManager, so no geometry math), area = slurp-style drag
// selection (Esc/right-click cancels, sub-4px drags too). Captures come from
// ScreencopyView + grabToImage at source resolution; paintCursor stays off,
// so grimblast's cursor-hiding virtual monitor (which blinked the bar via
// the screensChanged auto-heal) has no equivalent here. The selection
// overlay gets its own layer namespace — the ^quickshell$ xray blur rule
// would hide the very windows being selected. Area crops grab a frozen
// full-screen view inside a clip wrapper, captured ~60ms after the dim
// chrome hides so the compositor has a clean frame up.
Scope {
    id: root

    property bool selecting: false
    // non-null while a screen/active capture is in flight; doubles as the
    // busy guard for all three modes
    property var fullSource: null
    property string pendingWhat

    function shotPath(): string {
        return Quickshell.env("HOME") + "/Pictures/"
            + Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss") + ".png";
    }

    function finish(file: string, what: string): void {
        // fixed filename format: no quoting hazards
        proc.exec(["sh", "-c",
            `wl-copy --type image/png < ${file} && ` +
            `notify-send -i ${file} Screenshot '${what} copied to buffer and saved to ${file}'`]);
    }

    Process {
        id: proc
    }

    IpcHandler {
        target: "screenshot"

        function screen(): void {
            if (root.fullSource !== null || root.selecting)
                return;
            const focused = Hyprland.focusedMonitor;
            for (const s of Quickshell.screens) {
                if (focused !== null && s.name === focused.name) {
                    root.pendingWhat = s.name;
                    root.fullSource = s;
                    return;
                }
            }
        }

        function active(): void {
            if (root.fullSource !== null || root.selecting)
                return;
            const t = ToplevelManager.activeToplevel;
            if (t === null)
                return;
            root.pendingWhat = (t.appId || "Active") + " window";
            root.fullSource = t;
        }

        function area(): void {
            if (root.fullSource === null && !root.selecting)
                root.selecting = true;
        }
    }

    // 1x1 transparent window: ScreencopyView only renders (and can only be
    // grabbed) with a mapped window's render context; the view extends far
    // past the window, which grabToImage doesn't mind
    PanelWindow {
        visible: root.fullSource !== null
        anchors {
            top: true
            left: true
        }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-screenshot"

        Loader {
            active: root.fullSource !== null
            sourceComponent: ScreencopyView {
                captureSource: root.fullSource
                live: false
                paintCursor: false
                width: sourceSize.width
                height: sourceSize.height

                onHasContentChanged: {
                    if (!hasContent)
                        return;
                    const file = root.shotPath();
                    const size = Qt.size(sourceSize.width, sourceSize.height);
                    Qt.callLater(() => grabToImage(res => {
                        const ok = res.saveToFile(file);
                        root.fullSource = null;
                        if (ok)
                            root.finish(file, root.pendingWhat);
                    }, size));
                }
            }
        }
    }

    Variants {
        model: root.selecting ? Quickshell.screens : []

        PanelWindow {
            id: sel

            required property ShellScreen modelData
            property bool dragging: false
            property bool capturing: false
            property real anchorX
            property real anchorY
            property real curX
            property real curY
            readonly property real selX: Math.min(anchorX, curX)
            readonly property real selY: Math.min(anchorY, curY)
            readonly property real selW: Math.abs(curX - anchorX)
            readonly property real selH: Math.abs(curY - anchorY)

            screen: modelData
            visible: true
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-screenshot"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape && !sel.capturing)
                        root.selecting = false;
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPressed: mouse => {
                        if (sel.capturing)
                            return;
                        if (mouse.button === Qt.RightButton) {
                            root.selecting = false;
                            return;
                        }
                        sel.anchorX = sel.curX = mouse.x;
                        sel.anchorY = sel.curY = mouse.y;
                        sel.dragging = true;
                    }

                    onPositionChanged: mouse => {
                        if (sel.dragging) {
                            sel.curX = mouse.x;
                            sel.curY = mouse.y;
                        }
                    }

                    onReleased: {
                        if (!sel.dragging || sel.capturing)
                            return;
                        sel.dragging = false;
                        if (sel.selW < 4 || sel.selH < 4) {
                            root.selecting = false;
                            return;
                        }
                        sel.capturing = true;
                        settle.start();
                    }
                }

                // dim everything but the selection (4 strips around the
                // hole; QML can't punch one in a single rectangle)
                Rectangle {
                    visible: !sel.capturing
                    width: sel.width
                    height: sel.dragging ? sel.selY : sel.height
                    color: Theme.screenshotDim
                }
                Rectangle {
                    visible: sel.dragging && !sel.capturing
                    y: sel.selY + sel.selH
                    width: sel.width
                    height: Math.max(0, sel.height - sel.selY - sel.selH)
                    color: Theme.screenshotDim
                }
                Rectangle {
                    visible: sel.dragging && !sel.capturing
                    y: sel.selY
                    width: sel.selX
                    height: sel.selH
                    color: Theme.screenshotDim
                }
                Rectangle {
                    visible: sel.dragging && !sel.capturing
                    x: sel.selX + sel.selW
                    y: sel.selY
                    width: Math.max(0, sel.width - sel.selX - sel.selW)
                    height: sel.selH
                    color: Theme.screenshotDim
                }

                Rectangle {
                    visible: sel.dragging && !sel.capturing
                    x: sel.selX
                    y: sel.selY
                    width: sel.selW
                    height: sel.selH
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.notifBorder
                }
            }

            Timer {
                id: settle
                interval: 60
                onTriggered: capLoader.active = true
            }

            // shows the frozen region exactly in place, so nothing visibly
            // changes between chrome-off and grab
            Item {
                id: clipper
                clip: true
                visible: sel.capturing
                x: sel.selX
                y: sel.selY
                width: sel.selW
                height: sel.selH

                Loader {
                    id: capLoader
                    active: false
                    sourceComponent: ScreencopyView {
                        x: -sel.selX
                        y: -sel.selY
                        width: sel.width
                        height: sel.height
                        captureSource: sel.screen
                        live: false
                        paintCursor: false

                        onHasContentChanged: {
                            if (!hasContent)
                                return;
                            const file = root.shotPath();
                            const size = Qt.size(
                                Math.round(sel.selW * sourceSize.width / sel.width),
                                Math.round(sel.selH * sourceSize.height / sel.height));
                            Qt.callLater(() => clipper.grabToImage(res => {
                                const ok = res.saveToFile(file);
                                root.selecting = false;
                                if (ok)
                                    root.finish(file, "Area");
                            }, size));
                        }
                    }
                }
            }
        }
    }
}
