// Il volume a schermo quando lo cambi (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: osd

    property bool mostra: false
    property bool pronto: false

    visible: mostra || corpo.opacity > 0.01
    anchors { bottom: true }
    margins { bottom: Tema.sopraBarra + 40 }
    implicitWidth: 300
    implicitHeight: 56
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    Timer { interval: 3000; running: true; onTriggered: osd.pronto = true }
    Timer { id: nascondi; interval: 1600; onTriggered: osd.mostra = false }

    Connections {
        target: Audio
        function onCambiato() {
            if (!osd.pronto || Stato.pannello) return;
            osd.mostra = true;
            nascondi.restart();
        }
    }

    Rectangle {
        id: corpo
        anchors.fill: parent
        radius: height / 2
        color: Tema.fondoPieno
        border.width: 1
        border.color: Tema.bordo
        opacity: osd.mostra ? 1 : 0
        scale: osd.mostra ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Tema.media } }
        Behavior on scale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutBack } }

        Row {
            anchors.centerIn: parent
            spacing: 14
            Icona { nome: Audio.icona; dimensione: 24; piena: true; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                width: 180
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Tema.cartaSopra
                Rectangle {
                    height: parent.height
                    radius: 4
                    width: parent.width * (Audio.muto ? 0 : Math.min(1, Audio.volume))
                    color: Tema.accento
                    Behavior on width { NumberAnimation { duration: Tema.veloce } }
                }
            }
            Text {
                width: 34
                text: Math.round((Audio.muto ? 0 : Audio.volume) * 100)
                font.family: Tema.carattere
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Tema.testo
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
