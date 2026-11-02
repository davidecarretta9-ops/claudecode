// Cursore da trascinare (volume, trasparenza...) (creato da lfs.sh, Fase 10)
import QtQuick

Item {
    id: cursore
    property real valore: 0.5          // 0..1
    property string icona: ""
    signal spostato(real valore)

    implicitHeight: 34
    implicitWidth: 200

    Rectangle {
        id: binario
        anchors.fill: parent
        radius: height / 2
        color: Tema.cartaForte
        clip: true

        Rectangle {
            id: pieno
            height: parent.height
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, cursore.valore)))
            radius: height / 2
            color: Tema.accento
            Behavior on width {
                enabled: !trascina.pressed
                NumberAnimation { duration: Tema.veloce; easing.type: Easing.OutCubic }
            }
        }

        Icona {
            visible: cursore.icona !== ""
            nome: cursore.icona
            dimensione: 18
            color: Tema.suAccento
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: trascina
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function calcola(x) { return Math.max(0, Math.min(1, x / width)); }
        onPressed: e => cursore.spostato(calcola(e.x))
        onPositionChanged: e => { if (pressed) cursore.spostato(calcola(e.x)); }
        onWheel: e => cursore.spostato(Math.max(0, Math.min(1, cursore.valore + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
