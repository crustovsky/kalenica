import QtQuick
import Quickshell.Hyprland

BarText {
    readonly property string title: Hyprland.activeToplevel !== null ? Hyprland.activeToplevel.title : ""

    text: {
        if (title === "")
            return "";
        const vivaldi = title.match(/^(.*) - Vivaldi$/);
        return vivaldi ? "󰖟 " + vivaldi[1] : " " + title;
    }
    property real maxWidth: 600

    elide: Text.ElideRight
    width: Math.min(implicitWidth, maxWidth)
}
