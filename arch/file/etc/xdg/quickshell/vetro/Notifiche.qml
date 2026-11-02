// Le notifiche nuove, in basso a destra sopra la barra (creato da vetro-arch.sh). Entrano da
// destra e dopo qualche secondo spariscono (restano nel centro di controllo).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: finestra

    visible: Avvisi.visibili.length > 0 && !Stato.pannello && !Stato.bloccato
    anchors { bottom: true; right: true }
    margins { bottom: Tema.sopraBarra; right: Tema.staccoBarra }
    implicitWidth: 380
    implicitHeight: Math.max(1, lista.contentHeight)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-notifiche"
    WlrLayershell.layer: WlrLayer.Overlay

    ListView {
        id: lista
        anchors.fill: parent
        interactive: false
        spacing: 8
        model: ScriptModel { values: Avvisi.visibili }

        delegate: SchedaAvviso {
            id: scheda
            required property var modelData
            width: lista.width
            avviso: modelData
            onChiudi: Avvisi.nascondi(modelData)

            // si nasconde da sola (le urgenti restano finche' non le chiudi)
            Timer {
                running: !scheda.urgente && !areaSopra.containsMouse
                interval: scheda.avviso && scheda.avviso.expireTimeout > 0
                          ? Math.min(15000, scheda.avviso.expireTimeout * 1000) : 6000
                onTriggered: Avvisi.nascondi(scheda.modelData)
            }
            MouseArea {
                id: areaSopra
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: 420; to: 0; duration: Tema.lenta; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tema.media }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; to: 420; duration: Tema.media; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: Tema.media }
            }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Tema.media; easing.type: Easing.OutCubic }
        }
    }
}
