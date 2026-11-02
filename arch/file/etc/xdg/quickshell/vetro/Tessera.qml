// "Tessera" dei comandi rapidi: icona, nome e stato, accesa o spenta (creato da lfs.sh)
import QtQuick

Rectangle {
    id: tessera
    property string icona: "circle"
    property string titolo: ""
    property string sottotitolo: ""
    property bool attiva: false
    signal cliccata()

    implicitHeight: 62
    radius: Tema.raggioMedio
    color: attiva ? Tema.accento : (area.containsMouse ? Tema.cartaForte : Tema.carta)
    border.width: 1
    border.color: attiva ? "transparent" : Tema.bordo
    scale: area.pressed ? 0.96 : 1

    Behavior on color { ColorAnimation { duration: Tema.media } }
    Behavior on scale { NumberAnimation { duration: Tema.veloce; easing.type: Easing.OutCubic } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 10

        Rectangle {
            width: 36
            height: 36
            radius: 18
            anchors.verticalCenter: parent.verticalCenter
            color: tessera.attiva ? Qt.rgba(0, 0, 0, 0.12) : Tema.cartaForte
            Icona {
                anchors.centerIn: parent
                nome: tessera.icona
                dimensione: 20
                piena: tessera.attiva
                color: tessera.attiva ? Tema.suAccento : Tema.testo
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 46 - 10
            spacing: 1
            Text {
                width: parent.width
                text: tessera.titolo
                elide: Text.ElideRight
                font.family: Tema.carattere
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: tessera.attiva ? Tema.suAccento : Tema.testo
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: tessera.sottotitolo
                elide: Text.ElideRight
                font.family: Tema.carattere
                font.pixelSize: 11
                color: tessera.attiva ? Qt.rgba(Tema.suAccento.r, Tema.suAccento.g, Tema.suAccento.b, 0.7) : Tema.testo2
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tessera.cliccata()
    }
}
