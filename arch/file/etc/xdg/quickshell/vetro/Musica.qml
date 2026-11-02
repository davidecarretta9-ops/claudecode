pragma Singleton
// I lettori musicali e video (MPRIS) (creato da vetro-arch.sh)
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
    // il punto del brano e la sua durata, in secondi (0 se il lettore non li dice)
    readonly property real posizione: attivo && attivo.positionSupported ? attivo.position : 0
    readonly property real durata: attivo && attivo.lengthSupported ? attivo.length : 0

    // il lettore non avvisa mentre il tempo scorre: si chiede (vedi MusicaRiquadro)
    function aggiornaPosizione() { if (attivo) attivo.positionChanged(); }
    function sposta(secondi) {
        if (attivo && attivo.canSeek && attivo.positionSupported) attivo.position = secondi;
    }

    function alterna() { if (attivo && attivo.canTogglePlaying) attivo.togglePlaying(); }
    function avanti() { if (attivo && attivo.canGoNext) attivo.next(); }
    function indietro() { if (attivo && attivo.canGoPrevious) attivo.previous(); }
}
