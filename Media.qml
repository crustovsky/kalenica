import QtQuick
import Quickshell.Services.Mpris

BarItem {
    id: root

    readonly property var player: Mpris.players.values.find(
        p => !(p.identity ?? "").toLowerCase().includes("vivaldi")) ?? null
    readonly property string line: player !== null
        ? [player.trackArtist, player.trackTitle].filter(s => s !== "").join(" - ") : ""

    visible: player !== null && player.playbackState !== MprisPlaybackState.Stopped
    tooltip: line
    onClicked: { if (player !== null && player.canTogglePlaying) player.togglePlaying(); }
    onMiddleClicked: { if (player !== null && player.canGoPrevious) player.previous(); }
    onRightClicked: { if (player !== null && player.canGoNext) player.next(); }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        // capped like ActiveWindow so long tracks elide instead of overlapping
        width: Math.min(implicitWidth, 270)
        elide: Text.ElideRight
        color: root.fg
        font.italic: root.player !== null && !root.player.isPlaying
        text: (root.player !== null && root.player.isPlaying ? "▶ " : "⏸ ")
            + root.line
    }
}
