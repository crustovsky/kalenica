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
// selection that holds for adjustment (edge/corner resize, interior move,
// arrow nudge, Shift+arrow resize) with an x/y/w/h readout pill; Enter or
// the pill's check button captures, Esc/right-click cancels (so does an
// outside click released within 4px). Captures come from ScreencopyView +
// grabToImage at source resolution; paintCursor stays off, so grimblast's
// cursor-hiding virtual monitor (which blinked the bar via the
// screensChanged auto-heal) has no equivalent here. The selection overlay
// gets its own layer namespace — the ^quickshell$ xray blur rule would hide
// the very windows being selected. Area crops grab a frozen full-screen
// view inside a clip wrapper, captured ~60ms after the dim chrome hides so
// the compositor has a clean frame up.
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
            // idle -> drag -> adjust -> capture
            property string mode: "idle"
            property real anchorX
            property real anchorY
            property real curX
            property real curY
            readonly property real selX: Math.min(anchorX, curX)
            readonly property real selY: Math.min(anchorY, curY)
            readonly property real selW: Math.abs(curX - anchorX)
            readonly property real selH: Math.abs(curY - anchorY)

            // anchor = top-left, cur = bottom-right; makes nudge/resize
            // keys and edge-grab math simple
            function normalize(): void {
                const x = selX, y = selY, w = selW, h = selH;
                anchorX = x;
                anchorY = y;
                curX = x + w;
                curY = y + h;
            }

            function confirm(): void {
                if (mode !== "adjust")
                    return;
                mode = "capture";
                settle.start();
            }

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
                    if (sel.mode === "capture")
                        return;
                    if (event.key === Qt.Key_Escape) {
                        root.selecting = false;
                        return;
                    }
                    if (sel.mode !== "adjust")
                        return;
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sel.confirm();
                        return;
                    }
                    const d = { [Qt.Key_Left]: [-1, 0], [Qt.Key_Right]: [1, 0],
                                [Qt.Key_Up]: [0, -1], [Qt.Key_Down]: [0, 1] }[event.key];
                    if (d === undefined)
                        return;
                    if (event.modifiers & Qt.ShiftModifier) {
                        // grow/shrink from the bottom-right corner
                        sel.curX = Math.max(sel.anchorX + 4, Math.min(sel.width, sel.curX + d[0]));
                        sel.curY = Math.max(sel.anchorY + 4, Math.min(sel.height, sel.curY + d[1]));
                    } else {
                        const w = sel.selW, h = sel.selH;
                        sel.anchorX = Math.max(0, Math.min(sel.width - w, sel.anchorX + d[0]));
                        sel.anchorY = Math.max(0, Math.min(sel.height - h, sel.anchorY + d[1]));
                        sel.curX = sel.anchorX + w;
                        sel.curY = sel.anchorY + h;
                    }
                }

                MouseArea {
                    id: marea

                    // during a press: the zone being dragged; hovering: none
                    property string activeZone
                    property real pressX
                    property real pressY
                    property real origX
                    property real origY

                    function zoneAt(mx: real, my: real): string {
                        const m = 8;
                        if (mx < sel.selX - m || mx > sel.selX + sel.selW + m
                                || my < sel.selY - m || my > sel.selY + sel.selH + m)
                            return "out";
                        const l = Math.abs(mx - sel.selX) <= m;
                        const r = Math.abs(mx - (sel.selX + sel.selW)) <= m;
                        const t = Math.abs(my - sel.selY) <= m;
                        const b = Math.abs(my - (sel.selY + sel.selH)) <= m;
                        if (t && l) return "tl";
                        if (t && r) return "tr";
                        if (b && l) return "bl";
                        if (b && r) return "br";
                        if (l) return "l";
                        if (r) return "r";
                        if (t) return "t";
                        if (b) return "b";
                        return "in";
                    }

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: {
                        if (sel.mode !== "adjust")
                            return Qt.CrossCursor;
                        const z = marea.pressed ? marea.activeZone
                                                : zoneAt(marea.mouseX, marea.mouseY);
                        switch (z) {
                        case "tl": case "br": return Qt.SizeFDiagCursor;
                        case "tr": case "bl": return Qt.SizeBDiagCursor;
                        case "l": case "r": return Qt.SizeHorCursor;
                        case "t": case "b": return Qt.SizeVerCursor;
                        case "in": return Qt.SizeAllCursor;
                        default: return Qt.CrossCursor;
                        }
                    }

                    onPressed: e => {
                        if (sel.mode === "capture")
                            return;
                        if (e.button === Qt.RightButton) {
                            root.selecting = false;
                            return;
                        }
                        const z = sel.mode === "adjust" ? zoneAt(e.x, e.y) : "out";
                        activeZone = z;
                        pressX = e.x;
                        pressY = e.y;
                        origX = sel.selX;
                        origY = sel.selY;
                        if (z === "out") {
                            sel.anchorX = sel.curX = e.x;
                            sel.anchorY = sel.curY = e.y;
                            sel.mode = "drag";
                        } else if (z !== "in") {
                            // pin the anchor to the opposite corner so the
                            // normalized rect follows the grabbed side
                            // (normalize() guarantees anchor = top-left here)
                            const right = sel.selX + sel.selW, bottom = sel.selY + sel.selH;
                            if (z.includes("l"))
                                sel.anchorX = right;
                            if (z.includes("t"))
                                sel.anchorY = bottom;
                            sel.curX = z === "t" || z === "b" ? right : e.x;
                            sel.curY = z === "l" || z === "r" ? bottom : e.y;
                        }
                    }

                    onPositionChanged: e => {
                        if (!pressed || sel.mode === "capture")
                            return;
                        const z = activeZone;
                        if (sel.mode === "drag") {
                            sel.curX = e.x;
                            sel.curY = e.y;
                        } else if (z === "in") {
                            const w = sel.selW, h = sel.selH;
                            sel.anchorX = Math.max(0, Math.min(sel.width - w, marea.origX + e.x - marea.pressX));
                            sel.anchorY = Math.max(0, Math.min(sel.height - h, marea.origY + e.y - marea.pressY));
                            sel.curX = sel.anchorX + w;
                            sel.curY = sel.anchorY + h;
                        } else if (z !== "out") {
                            if (z !== "t" && z !== "b")
                                sel.curX = e.x;
                            if (z !== "l" && z !== "r")
                                sel.curY = e.y;
                        }
                    }

                    onReleased: {
                        if (sel.mode === "drag") {
                            if (sel.selW < 4 || sel.selH < 4) {
                                root.selecting = false;
                                return;
                            }
                            sel.mode = "adjust";
                        }
                        if (sel.mode === "adjust")
                            sel.normalize();
                    }
                }

                // dim everything but the selection (4 strips around the
                // hole; QML can't punch one in a single rectangle)
                Rectangle {
                    visible: sel.mode !== "capture"
                    width: sel.width
                    height: sel.mode === "idle" ? sel.height : sel.selY
                    color: Theme.screenshotDim
                }
                Rectangle {
                    visible: sel.mode === "drag" || sel.mode === "adjust"
                    y: sel.selY + sel.selH
                    width: sel.width
                    height: Math.max(0, sel.height - sel.selY - sel.selH)
                    color: Theme.screenshotDim
                }
                Rectangle {
                    visible: sel.mode === "drag" || sel.mode === "adjust"
                    y: sel.selY
                    width: sel.selX
                    height: sel.selH
                    color: Theme.screenshotDim
                }
                Rectangle {
                    visible: sel.mode === "drag" || sel.mode === "adjust"
                    x: sel.selX + sel.selW
                    y: sel.selY
                    width: Math.max(0, sel.width - sel.selX - sel.selW)
                    height: sel.selH
                    color: Theme.screenshotDim
                }

                Rectangle {
                    visible: sel.mode === "drag" || sel.mode === "adjust"
                    x: sel.selX
                    y: sel.selY
                    width: sel.selW
                    height: sel.selH
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.notifBorder
                }

                // x/y/w/h readout; below the selection, flipping above (or
                // tucking inside) when there's no room
                Rectangle {
                    id: pill

                    visible: sel.mode === "drag" || sel.mode === "adjust"
                    x: Math.max(0, Math.min(sel.selX, sel.width - width))
                    y: {
                        const below = sel.selY + sel.selH + 6;
                        if (below + height <= sel.height)
                            return below;
                        const above = sel.selY - 6 - height;
                        return above >= 0 ? above : sel.selY + sel.selH - height - 6;
                    }
                    width: row.width + 16
                    height: 26
                    radius: 8
                    color: Theme.bg

                    // eat presses and hover so the readout never triggers
                    // the resize zones or an outside-drag beneath it
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                    }

                    Row {
                        id: row
                        anchors.centerIn: parent
                        spacing: 7

                        Repeater {
                            // static model: the values bind per-delegate, so
                            // dragging never rebuilds the row
                            model: ["x", "y", "w", "h"]

                            Row {
                                id: field
                                required property string modelData
                                spacing: 4

                                BarText {
                                    text: field.modelData
                                    color: Theme.fgDim
                                }
                                BarText {
                                    text: Math.round({ x: sel.selX, y: sel.selY,
                                                       w: sel.selW, h: sel.selH }[field.modelData])
                                }
                            }
                        }

                        Rectangle {
                            visible: sel.mode === "adjust"
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: 14
                            color: Theme.fgFaint
                        }

                        Rectangle {
                            id: saveBtn
                            visible: sel.mode === "adjust"
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 4
                            color: btnArea.containsMouse ? Theme.bgHover : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            BarText {
                                anchors.centerIn: parent
                                text: "✓"
                                color: btnArea.containsMouse ? Theme.fgHover : Theme.fg
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: btnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sel.confirm()
                            }
                        }
                    }
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
                visible: sel.mode === "capture"
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
