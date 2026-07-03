pragma Singleton
import QtQuick
import Quickshell

// Colors and font lifted from waybar's style.css (Catppuccin-ish at 0.7 alpha).
Singleton {
    readonly property color bg: Qt.rgba(21 / 255, 18 / 255, 27 / 255, 0.7)
    readonly property color fg: Qt.alpha("#cdd6f4", 0.75)
    readonly property color fgHover: Qt.alpha("#11111b", 0.7)
    readonly property color bgHover: Qt.alpha("#cdd6f4", 0.7)

    readonly property color urgentBg: Qt.alpha("#a6e3a1", 0.7)

    readonly property color warning: Qt.alpha("#f9e2af", 0.7)
    readonly property color critical: Qt.alpha("#f38ba8", 0.7)

    // Notification popups, from dunstrc: bg #1e1e2e nominal 0.7 alpha (b3),
    // kept at the pre-xray blur-compensated 0.5; frame/fg colors as-is.
    readonly property color notifBg: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.5)
    readonly property color notifFg: "#cdd6f4"
    readonly property color notifBorder: "#a6adc8"
    readonly property color notifBorderCritical: "#fab387"

    // faint fg: separators, OSD track (and fill when muted)
    readonly property color fgFaint: Qt.alpha("#cdd6f4", 0.25)
    // de-emphasized text (calendar week numbers / weekday header)
    readonly property color fgDim: Qt.alpha("#cdd6f4", 0.4)

    readonly property string fontFamily: "Iosevka Nerd Font"
    readonly property int fontSize: 14
}
