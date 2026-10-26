import QtQuick
import Quickshell.Services.Mpris

// Mpris line for one player: the one playing wins; with none playing it
// stays on the last one shown, so two paused players don't flip-flop.
// modules.media.exclude hides players by identity substring (browsers).
BarItem {
    id: root

    readonly property var players: Mpris.players.values.filter(p =>
        !Config.modules.media.exclude.some(x =>
            (p.identity ?? "").toLowerCase().includes(x.toLowerCase())))
    // reading isPlaying inside the binding re-runs it on any state change
    readonly property var playing: players.find(p => p.isPlaying) ?? null
    property var player: null
    readonly property string line: player !== null
        ? [player.trackArtist, player.trackTitle].filter(s => s !== "").join(" - ") : ""

    function pick() {
        if (playing !== null)
            player = playing;
        else if (!players.includes(player))
            player = players[0] ?? null;
    }
    // initial bindings don't signal: pick once players exist at startup
    Component.onCompleted: pick()
    onPlayingChanged: pick()
    onPlayersChanged: pick()

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
