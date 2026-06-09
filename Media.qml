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
        color: root.fg
        font.italic: root.player !== null && !root.player.isPlaying
        text: (root.player !== null && root.player.isPlaying ? "▶ " : "⏸ ")
            + (root.line.length > 48 ? root.line.slice(0, 47) + "…" : root.line)
    }
}
