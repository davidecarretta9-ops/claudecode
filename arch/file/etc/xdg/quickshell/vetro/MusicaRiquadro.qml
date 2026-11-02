// Il riquadro della musica (creato da vetro-arch.sh): si apre dalla pillola della musica
// nella barra, in basso a destra sopra la barra. La grafica e' in MusicaVista.qml.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: riquadro

    visible: Stato.musica || vista.opacity > 0.01
    anchors { bottom: true; right: true }
    margins { bottom: Tema.sopraBarra; right: Tema.staccoBarra }
    implicitWidth: vista.implicitWidth
    implicitHeight: vista.implicitHeight
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-musica"
    WlrLayershell.layer: WlrLayer.Top

    HyprlandFocusGrab {
        windows: [ riquadro ].concat(Stato.barre)
        active: Stato.musica
        onCleared: Stato.musica = false
    }

    // il tempo che scorre: si chiede al lettore ogni secondo, solo a riquadro aperto
    Timer {
        interval: 1000
        running: Stato.musica && Musica.suona
        repeat: true
        triggeredOnStart: true
        onTriggered: Musica.aggiornaPosizione()
    }

    MusicaVista {
        id: vista
        anchors.fill: parent
        opacity: Stato.musica ? 1 : 0
        transform: Translate {
            y: Stato.musica ? 0 : 24
            Behavior on y { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        titolo: Musica.titolo
        artista: Musica.artista
        copertina: Musica.copertina
        posizione: Musica.posizione
        durata: Musica.durata
        suona: Musica.suona

        onIndietro: Musica.indietro()
        onAlterna: Musica.alterna()
        onAvanti: Musica.avanti()
        onSposta: s => Musica.sposta(s)
    }
}
