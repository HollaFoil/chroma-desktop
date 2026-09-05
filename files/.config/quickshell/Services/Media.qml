pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The Spotify player (the bar's transport is pinned to it, like waybar's was).
Singleton {
    id: root
    readonly property var player: Mpris.players.values.find(p => /spotify/i.test(p.dbusName) || /spotify/i.test(p.identity)) ?? null
    readonly property bool present: player !== null
    readonly property bool playing: present && player.isPlaying
    readonly property string title: present ? (player.trackTitle || "") : ""
    readonly property string artist: present ? (player.trackArtist || "") : ""
    readonly property string album: present ? (player.trackAlbum || "") : ""
    readonly property string label: (artist && title) ? artist + " — " + title : (title || artist)
    readonly property bool stopped: !present || (!title && !artist)

    function playPause() { if (present && player.canTogglePlaying) player.togglePlaying() }
    function next() { if (present && player.canGoNext) player.next() }
    function previous() { if (present && player.canGoPrevious) player.previous() }
    readonly property bool volumeSupported: present && player.volumeSupported
    readonly property real volume: volumeSupported ? player.volume : 0
    function setVolume(v) { if (volumeSupported) player.volume = Math.max(0, Math.min(1, v)) }
    function volumeStep(d) { setVolume(volume + d) }
}
