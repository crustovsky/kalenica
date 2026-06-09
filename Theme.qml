pragma Singleton
import QtQuick
import Quickshell

// Colors and font lifted from waybar's style.css (Catppuccin-ish at 0.75 alpha).
Singleton {
    readonly property color bg: Qt.rgba(21 / 255, 18 / 255, 27 / 255, 0.25)
    readonly property color fg: Qt.alpha("#cdd6f4", 0.75)
    readonly property color fgHover: Qt.alpha("#11111b", 0.75)
    readonly property color bgHover: Qt.alpha("#cdd6f4", 0.75)

    readonly property color urgentBg: Qt.alpha("#a6e3a1", 0.75)

    readonly property color warning: Qt.alpha("#f9e2af", 0.75)
    readonly property color critical: Qt.alpha("#f38ba8", 0.75)

    readonly property string fontFamily: "Iosevka Nerd Font"
    readonly property int fontSize: 14
}
