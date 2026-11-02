pragma Singleton
// I lettori musicali e video (MPRIS) (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: musica

    readonly property var lettori: Mpris.players.values
    readonly property var attivo: {
        for (let i = 0; i < lettori.length; i++)
            if (lettori[i].isPlaying) return lettori[i];
        return lettori.length > 0 ? lettori[0] : null;
    }
    readonly property bool suona: attivo !== null && attivo.isPlaying
    readonly property string titolo: attivo ? (attivo.trackTitle || attivo.identity || "") : ""
    readonly property string artista: attivo ? (attivo.trackArtist || "") : ""
    readonly property string copertina: attivo ? (attivo.trackArtUrl || "") : ""

    function alterna() { if (attivo && attivo.canTogglePlaying) attivo.togglePlaying(); }
    function avanti() { if (attivo && attivo.canGoNext) attivo.next(); }
    function indietro() { if (attivo && attivo.canGoPrevious) attivo.previous(); }
}
