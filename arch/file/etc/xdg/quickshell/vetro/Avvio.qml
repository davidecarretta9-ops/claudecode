// Il menu delle app (creato da vetro-arch.sh): tasto Windows, Windows+Spazio o il logo
// nella barra. Si apre in basso a sinistra sopra la barra: scrivi per cercare, frecce
// e Invio per aprire, Esc per chiudere; "Tutte le app" mostra la griglia di tutte.
// La grafica e' in MenuVista.qml.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: avvio

    visible: Stato.avvio || vista.opacity > 0.01
    anchors { bottom: true; left: true }
    margins { bottom: Tema.sopraBarra; left: Tema.staccoBarra }
    implicitWidth: vista.implicitWidth
    implicitHeight: vista.implicitHeight
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-avvio"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: Stato.avvio ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [ avvio ].concat(Stato.barre)
        active: Stato.avvio
        onCleared: Stato.avvio = false
    }

    property bool tutte: false
    property string testo: ""
    readonly property var elenco: testo.trim() !== "" ? Applicazioni.cerca(testo, 8)
                                  : (tutte ? Applicazioni.ordinate() : [])
    // quante caselle si salta con le frecce su e giu'
    readonly property int passo: (tutte && testo.trim() === "") ? vista.colonne : 1

    function apri(i) {
        const e = elenco[i];
        if (!e) return;
        e.execute();
        Stato.avvio = false;
    }

    Connections {
        target: Stato
        function onAvvioChanged() {
            if (Stato.avvio) {
                avvio.tutte = false;
                avvio.testo = "";
                vista.scelta = 0;
                vista.metti_a_fuoco();
            }
        }
    }

    MenuVista {
        id: vista
        anchors.fill: parent
        altezzaMassima: (avvio.screen ? avvio.screen.height : 1080) / 2
        risultati: avvio.elenco.map(e => ({ nome: e.name, icona: Applicazioni.icona(e.icon) }))
        tutte: avvio.tutte

        opacity: Stato.avvio ? 1 : 0
        transform: Translate {
            y: Stato.avvio ? 0 : 24
            Behavior on y { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        onCercato: t => { avvio.testo = t; vista.scelta = 0; }
        onAperta: i => avvio.apri(i)
        onTutteCliccato: { avvio.tutte = true; vista.scelta = 0; }
        onChiudi: Stato.avvio = false
        onSu: vista.scelta = Math.max(0, vista.scelta - avvio.passo)
        onGiu: vista.scelta = Math.min(Math.max(0, avvio.elenco.length - 1), vista.scelta + avvio.passo)
    }
}
