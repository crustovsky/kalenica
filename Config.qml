pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User settings from config.json (watched — edits apply live). Property
// initializers are the defaults: a missing file or key falls back, a missing
// file is materialized with the defaults. Placement rule: a value owned by
// exactly one feature goes under modules.<name>, cross-cutting ones under
// theme/timing. Inline components (vs anonymous JsonObjects) so qmllint can
// resolve members.
Singleton {
    id: root

    readonly property ThemeConfig theme: ThemeConfig {}
    readonly property TimingConfig timing: TimingConfig {}
    readonly property ModulesConfig modules: ModulesConfig {}

    component ColorsConfig: JsonObject {
        property string background: "#15121b"
        property string foreground: "#cdd6f4"
        property string hoverForeground: "#11111b"
        property string urgent: "#a6e3a1"
        property string warning: "#f9e2af"
        property string critical: "#f38ba8"
        property string notificationBackground: "#1e1e2e"
        property string notificationForeground: "#cdd6f4"
        property string notificationBorder: "#a6adc8"
        property string notificationBorderCritical: "#fab387"
    }

    component FontConfig: JsonObject {
        property string family: "Iosevka Nerd Font"
        property int size: 14
    }

    component ThemeConfig: JsonObject {
        property ColorsConfig colors: ColorsConfig {}
        // bar/notification translucency, calibrated against the xray blur
        // (see CLAUDE.md) — the fg emphasis alphas stay in Theme
        property real barAlpha: 0.7
        property real notificationAlpha: 0.5
        property FontConfig font: FontConfig {}
    }

    component TimingConfig: JsonObject {
        property int hoverFade: 120
        property int popupGrow: 200
        property int drawerSlide: 300
        property int tooltipDelay: 150
        property int popupHoverClose: 1500
    }

    component ClockConfig: JsonObject {
        property string format: "dd MMM HH:mm:ss"
    }

    component BatteryConfig: JsonObject {
        property int low: 20
        property int critical: 10
    }

    component NotificationsConfig: JsonObject {
        property int timeout: 5000
    }

    component OsdConfig: JsonObject {
        property int hideDelay: 1500
    }

    component ScreenshotConfig: JsonObject {
        property string directory: "~/Pictures"
    }

    component LauncherConfig: JsonObject {
        property list<string> command: ["vicinae", "toggle"]
    }

    component PowerConfig: JsonObject {
        property list<string> lockCommand: ["uwsm", "app", "--", "hyprlock"]
    }

    component ModulesConfig: JsonObject {
        property ClockConfig clock: ClockConfig {}
        property BatteryConfig battery: BatteryConfig {}
        property NotificationsConfig notifications: NotificationsConfig {}
        property OsdConfig osd: OsdConfig {}
        property ScreenshotConfig screenshot: ScreenshotConfig {}
        property LauncherConfig launcher: LauncherConfig {}
        property PowerConfig power: PowerConfig {}
    }

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        adapter: JsonAdapter {
            property ThemeConfig theme: root.theme
            property TimingConfig timing: root.timing
            property ModulesConfig modules: root.modules
        }
    }
}
