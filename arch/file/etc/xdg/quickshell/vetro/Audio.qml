pragma Singleton
// Il volume (PipeWire) (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: audio

    readonly property var uscita: Pipewire.defaultAudioSink
    readonly property bool pronto: !!(uscita && uscita.audio)
    readonly property real volume: pronto ? uscita.audio.volume : 0
    readonly property bool muto: pronto ? uscita.audio.muted : false
    readonly property string icona: muto || volume <= 0.001 ? "volume_off"
                                   : volume < 0.34 ? "volume_mute"
                                   : volume < 0.67 ? "volume_down" : "volume_up"

    signal cambiato()

    function imposta(v) {
        if (!pronto) return;
        uscita.audio.muted = false;
        uscita.audio.volume = Math.max(0, Math.min(1, v));
    }
    function alternaMuto() { if (pronto) uscita.audio.muted = !uscita.audio.muted; }

    onVolumeChanged: cambiato()
    onMutoChanged: cambiato()

    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
}
