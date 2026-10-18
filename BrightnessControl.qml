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
    property string target  // laptop panel name the in-flight adjustment is for
    // DDC/CI state per external monitor, keyed by connector name: the level
    // cache (reads are slow; the old script used /tmp for this) and the
    // pre-dim level while dimmed. An unknown level fetches first, then
    // applies the press/dim that asked for it.
    property var ddcLevel: ({})
    property var ddcSaved: ({})
    // the fetch in flight: which monitor, and "adjust" (a key) or "dim" (idle)
    property string ddcFetchTarget
    property string ddcAfterFetch

    readonly property string icon: "󰃠"

    readonly property bool hasLaptopPanel:
        Hyprland.monitors.values.some(m => root.isLaptop(m))

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
            root.ddcLevel = {};
            root.ddcSaved = {};
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

    function isLaptop(mon: var): bool {
        return mon.name.startsWith("eDP");
    }

    function externals(): var {
        return Hyprland.monitors.values.filter(m => !isLaptop(m));
    }

    // ddcutil display selection by EDID model (Hyprland reports it in the
    // monitor's IPC object); the -d index shifts with what is plugged in
    function ddcSelect(mon: var): var {
        const model = mon.lastIpcObject?.model ?? "";
        return model !== "" ? ["--model", model] : ["-d", "1"];
    }

    function dim() {
        const level = Config.modules.idle.brightnessDimLevel;
        if (hasLaptopPanel)
            Quickshell.execDetached(["brightnessctl", "-s", "set", `${level}%`]);
        Quickshell.execDetached(["brightnessctl", "-s", "-d", "platform::kbd_backlight", "set", "0"]);
        for (const m of externals())
            dimDdc(m);
    }

    function restore() {
        if (hasLaptopPanel)
            Quickshell.execDetached(["brightnessctl", "-r"]);
        Quickshell.execDetached(["brightnessctl", "-r", "-d", "platform::kbd_backlight"]);
        for (const m of externals()) {
            const saved = ddcSaved[m.name];
            if (saved !== undefined) {
                delete ddcSaved[m.name];
                setDdc(m, saved);
            }
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
        return mons.find(m => isLaptop(m)) ?? mons[0] ?? null;
    }

    function dispatch(cx: int, cy: int) {
        const mon = monitorAt(cx, cy);
        if (mon === null)
            return;
        if (isLaptop(mon)) {
            target = mon.name;
            laptopProc.exec(["brightnessctl", "-m", "set",
                             pending === "raise" ? "5%+" : "5%-"]);
        } else
            adjustDdc(mon);
    }

    function fetchDdc(mon: var, then: string) {
        if (ddcGetProc.running) // one read at a time; the next press/idle retries
            return;
        ddcFetchTarget = mon.name;
        ddcAfterFetch = then;
        ddcGetProc.exec(["ddcutil", "getvcp", "10", ...ddcSelect(mon),
                         "--brief", "--sleep-multiplier", "0.1"]);
    }

    function setDdc(mon: var, value: int) {
        ddcLevel[mon.name] = value;
        Quickshell.execDetached(["ddcutil", "setvcp", "10", String(value), ...ddcSelect(mon),
                                 "--noverify", "--sleep-multiplier", "0.1"]);
    }

    function adjustDdc(mon: var) {
        const cur = ddcLevel[mon.name];
        if (cur === undefined) {
            fetchDdc(mon, "adjust");
            return; // resumes from ddcGetProc when the value lands
        }
        const step = pending === "raise" ? 5 : -5;
        const next = Math.max(5, Math.min(100, cur + step));
        setDdc(mon, next);
        osd.showOn(mon.name, icon, next / 100, false);
    }

    function dimDdc(mon: var) {
        const cur = ddcLevel[mon.name];
        if (cur === undefined) {
            fetchDdc(mon, "dim");
            return;
        }
        if (ddcSaved[mon.name] === undefined)
            ddcSaved[mon.name] = cur;
        setDdc(mon, Math.min(cur, Config.modules.idle.brightnessDimLevel));
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
                const mon = Hyprland.monitors.values.find(m => m.name === root.ddcFetchTarget);
                if (mon === undefined) // unplugged while reading
                    return;
                const cur = parseInt(text.trim().split(/\s+/)[3]);
                root.ddcLevel[mon.name] = isNaN(cur) ? 50 : cur;
                // apply what triggered the fetch; a dim only if still idle
                // (the read is slow enough for the user to have come back)
                if (root.ddcAfterFetch === "dim") {
                    if (Idle.brightnessIdle)
                        root.dimDdc(mon);
                } else
                    root.adjustDdc(mon);
            }
        }
    }
}
