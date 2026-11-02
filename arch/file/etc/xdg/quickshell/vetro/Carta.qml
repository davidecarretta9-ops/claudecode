// Una "carta" dentro i pannelli: rettangolo chiaro e arrotondato (creato da lfs.sh)
import QtQuick

Rectangle {
    id: carta
    property bool cliccabile: false
    property bool sopra: area.containsMouse
    signal cliccata()

    radius: Tema.raggioMedio
    color: cliccabile && sopra ? Tema.cartaForte : Tema.carta
    border.width: 1
    border.color: Tema.bordo

    Behavior on color { ColorAnimation { duration: Tema.veloce } }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: carta.cliccabile
        hoverEnabled: carta.cliccabile
        cursorShape: carta.cliccabile ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: carta.cliccata()
    }
}
