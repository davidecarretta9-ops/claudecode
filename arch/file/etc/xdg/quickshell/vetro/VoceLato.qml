// Una voce del lato nelle finestre chiare (creato da vetro-arch.sh), come nelle app del
// video: icona a contorno e nome; la voce scelta e' una pillola blu con testo bianco.
import QtQuick

Item {
    id: voce
    property string icona: ""
    property string testo: ""
    property bool scelta: false
    signal cliccata()

    implicitWidth: 220
    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: voce.scelta ? Tema.accento : (area.containsMouse ? Tema.appSopra : "transparent")
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
    }
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        Icona {
            anchors.verticalCenter: parent.verticalCenter
            nome: voce.icona
            dimensione: 20
            piena: voce.scelta
            color: voce.scelta ? "#ffffff" : Tema.appTesto
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34
            elide: Text.ElideRight
            text: voce.testo
            font.family: Tema.carattere
            font.pixelSize: 14
            font.weight: voce.scelta ? Font.DemiBold : Font.Normal
            color: voce.scelta ? "#ffffff" : Tema.appTesto
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: voce.cliccata()
    }
}
