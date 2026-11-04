// oversicaOS (creato da lfs.sh): l'icona del fantasma nella barra quando la modalita'
// fantasma e' accesa (esiste /etc/fantasma/attivo). Si controlla ogni 3 secondi.
import QtQuick
import Quickshell.Io
import qs.components

MaterialIcon {
    id: root

    required property color colour
    property bool attiva: false

    visible: attiva
    animate: true
    text: "visibility_off"
    color: colour
    fill: 1

    FileView {
        id: segno

        path: "/etc/fantasma/attivo"
        printErrors: false
        onLoaded: root.attiva = true
        onLoadFailed: root.attiva = false
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: segno.reload()
    }
}
