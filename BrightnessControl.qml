import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Brightness keys, replacing brightness-osd.sh + swayosd: adjusts the
// monitor under the cursor — laptop panel (eDP*) via brightnessctl, anything
// else via ddcutil DDC/CI — and reports to the OSD. Keybinds call
// `qs ipc call brightness raise|lower`.
//
// Also the idle dim that used to be a hypridle listener (brightnessctl -s/-r
// plus a ddcutil script): after modules.idle.brightnessDim seconds every
// panel drops to brightnessDimLevel and comes back on input. In-process so
// the DDC cache below stays the truth the keys adjust against.
Scope {
    id: root

    required property var osd

    property string pending // raise/lower in flight while cursorpos runs
    property string target  // monitor name the in-flight adjustment is for
    // In-memory DDC cache (reads are slow; the old script used /tmp for
    // this). -1 = unknown: the next press fetches, then applies itself.
    property int ddcBrightness: -1
    // what the fetch in flight is for: "adjust" (a key) or "dim" (idle)
    property string ddcAfterFetch: "adjust"
    // pre-dim DDC level to restore on resume, -1 = not dimmed
    property int ddcSaved: -1

    readonly property string icon: "󰃠"

    readonly property bool hasLaptopPanel:
        Hyprland.monitors.values.some(m => m.name.startsWith("eDP"))
    readonly property bool hasDdcMonitor:
        Hyprland.monitors.values.some(m => !m.name.startsWith("eDP"))

    IpcHandler {
        target: "brightness"

        function raise(): void {
            root.adjust("raise");
        }

        function lower(): void {
            root.adjust("lower");
        }
    }

    // Monitor unplugged/plugged: don't trust brightness of a different panel.
    Connections {
        target: Hyprland.monitors
        function onValuesChanged() {
            root.ddcBrightness = -1;
            root.ddcSaved = -1;
        }
    }

    Connections {
        target: Idle
        function onBrightnessIdleChanged() {
            if (Idle.brightnessIdle)
                root.dim();
            else
                root.restore();
        }
    }

    function dim() {
        const level = Config.modules.idle.brightnessDimLevel;
        if (hasLaptopPanel)
            Quickshell.execDetached(["brightnessctl", "-s", "set", `${level}%`]);
        Quickshell.execDetached(["brightnessctl", "-s", "-d", "platform::kbd_backlight", "set", "0"]);
        if (hasDdcMonitor)
            dimDdc();
    }

    function restore() {
        if (hasLaptopPanel)
            Quickshell.execDetached(["brightnessctl", "-r"]);
        Quickshell.execDetached(["brightnessctl", "-r", "-d", "platform::kbd_backlight"]);
        if (ddcSaved >= 0) {
            setDdc(ddcSaved);
            ddcSaved = -1;
        }
    }

    function adjust(dir: string) {
        if (cursorProc.running) // drop piled-up key repeats
            return;
        pending = dir;
        cursorProc.exec(["hyprctl", "cursorpos", "-j"]);
    }

    function monitorAt(cx: int, cy: int): var {
        const mons = Hyprland.monitors.values;
        for (const m of mons) {
            if (m.x <= cx && cx < m.x + m.width / m.scale
                && m.y <= cy && cy < m.y + m.height / m.scale)
                return m;
        }
        return mons.find(m => m.name.startsWith("eDP")) ?? mons[0] ?? null;
    }

    function dispatch(cx: int, cy: int) {
        const mon = monitorAt(cx, cy);
        if (mon === null)
            return;
        target = mon.name;
        if (mon.name.startsWith("eDP"))
            laptopProc.exec(["brightnessctl", "-m", "set",
                             pending === "raise" ? "5%+" : "5%-"]);
        else
            adjustDdc();
    }

    function fetchDdc(then: string) {
        ddcAfterFetch = then;
        if (!ddcGetProc.running)
            ddcGetProc.exec(["ddcutil", "getvcp", "10", "-d", "1",
                             "--brief", "--sleep-multiplier", "0.1"]);
    }

    function setDdc(value: int) {
        ddcBrightness = value;
        Quickshell.execDetached(["ddcutil", "setvcp", "10", String(value),
                                 "-d", "1", "--noverify", "--sleep-multiplier", "0.1"]);
    }

    function adjustDdc() {
        if (ddcBrightness < 0) {
            fetchDdc("adjust");
            return; // resumes from ddcGetProc when the value lands
        }
        const step = pending === "raise" ? 5 : -5;
        setDdc(Math.max(5, Math.min(100, ddcBrightness + step)));
        osd.showOn(target, icon, ddcBrightness / 100, false);
    }

    function dimDdc() {
        if (ddcBrightness < 0) {
            fetchDdc("dim");
            return;
        }
        if (ddcSaved < 0)
            ddcSaved = ddcBrightness;
        setDdc(Math.min(ddcBrightness, Config.modules.idle.brightnessDimLevel));
    }

    Process {
        id: cursorProc
        stdout: StdioCollector {
            onStreamFinished: {
                const pos = JSON.parse(text);
                root.dispatch(pos.x, pos.y);
            }
        }
    }

    Process {
        id: laptopProc
        stdout: StdioCollector {
            // machine-readable: device,class,current,percent%,max
            onStreamFinished: {
                const pct = parseInt(text.split(",")[3]);
                if (!isNaN(pct))
                    root.osd.showOn(root.target, root.icon, pct / 100, false);
            }
        }
    }

    Process {
        id: ddcGetProc
        stdout: StdioCollector {
            // --brief: "VCP 10 C <current> <max>"
            onStreamFinished: {
                const cur = parseInt(text.trim().split(/\s+/)[3]);
                root.ddcBrightness = isNaN(cur) ? 50 : cur;
                // apply what triggered the fetch; a dim only if still idle
                // (the read is slow enough for the user to have come back)
                if (root.ddcAfterFetch === "dim") {
                    if (Idle.brightnessIdle)
                        root.dimDdc();
                } else
                    root.adjustDdc();
            }
        }
    }
}
