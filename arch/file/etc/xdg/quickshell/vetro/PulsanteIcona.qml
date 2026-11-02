// Pulsante tondo con un'icona (creato da lfs.sh, Fase 10)
import QtQuick

Rectangle {
    id: pulsante
    property string icona: "circle"
    property real dimensioneIcona: 20
    property bool attivo: false
    property string suggerimento: ""
    property color coloreIcona: attivo ? Tema.suAccento : Tema.testo
    signal cliccato()

    implicitWidth: 40
    implicitHeight: 40
    radius: height / 2
    color: attivo ? Tema.accento : (area.containsMouse ? Tema.cartaSopra : Tema.cartaForte)
    scale: area.pressed ? 0.92 : 1

    Behavior on color { ColorAnimation { duration: Tema.veloce } }
    Behavior on scale { NumberAnimation { duration: Tema.veloce; easing.type: Easing.OutCubic } }

    Icona {
        anchors.centerIn: parent
        nome: pulsante.icona
        dimensione: pulsante.dimensioneIcona
        color: pulsante.coloreIcona
        piena: pulsante.attivo
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pulsante.cliccato()
    }
}
