pragma Singleton
import QtQuick
import Quickshell

// Palette bases and font come from config.json (Config.theme); the alphas
// composed here are relationships, not preferences — the fg emphasis ladder
// (0.75/0.4/0.25) and the blur-calibrated bar/notification translucency
// (Config.theme.barAlpha/notificationAlpha). Colors originally lifted from
// waybar's style.css (Catppuccin-ish).
Singleton {
    readonly property var palette: Config.theme.colors
    readonly property real barAlpha: Config.theme.barAlpha

    readonly property color bg: Qt.alpha(palette.background, barAlpha)
    readonly property color fg: Qt.alpha(palette.foreground, 0.75)
    readonly property color fgHover: Qt.alpha(palette.hoverForeground, barAlpha)
    readonly property color bgHover: Qt.alpha(palette.foreground, barAlpha)

    readonly property color urgentBg: Qt.alpha(palette.urgent, barAlpha)

    readonly property color warning: Qt.alpha(palette.warning, barAlpha)
    readonly property color critical: Qt.alpha(palette.critical, barAlpha)

    // Notification popups, from dunstrc; bg kept at the pre-xray
    // blur-compensated alpha, frame/fg colors opaque.
    readonly property color notifBg: Qt.alpha(palette.notificationBackground, Config.theme.notificationAlpha)
    readonly property color notifFg: palette.notificationForeground
    readonly property color notifBorder: palette.notificationBorder
    readonly property color notifBorderCritical: palette.notificationBorderCritical

    // screenshot area-selection dim (outside the rubber band); the readout
    // pill just reuses the bar chrome (bg/fg)
    readonly property color screenshotDim: Qt.alpha(palette.hoverForeground, 0.6)

    // faint fg: separators, OSD track (and fill when muted)
    readonly property color fgFaint: Qt.alpha(palette.foreground, 0.25)
    // de-emphasized text (calendar week numbers / weekday header)
    readonly property color fgDim: Qt.alpha(palette.foreground, 0.4)

    readonly property string fontFamily: Config.theme.font.family
    readonly property int fontSize: Config.theme.font.size
}
