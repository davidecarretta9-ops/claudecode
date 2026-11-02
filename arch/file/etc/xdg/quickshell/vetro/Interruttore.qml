// Interruttore acceso/spento, con l'animazione (creato da lfs.sh, Fase 10)
import QtQuick

Item {
    id: interruttore
    property bool acceso: false
    signal cambiato(bool valore)

    implicitWidth: 46
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: interruttore.acceso ? Tema.accento : Tema.cartaSopra
        Behavior on color { ColorAnimation { duration: Tema.media } }

        Rectangle {
            id: pallino
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: interruttore.acceso ? parent.width - width - 3 : 3
            color: interruttore.acceso ? Tema.suAccento : "#ffffff"
            Behavior on x { NumberAnimation { duration: Tema.media; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on color { ColorAnimation { duration: Tema.media } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: interruttore.cambiato(!interruttore.acceso)
    }
}
