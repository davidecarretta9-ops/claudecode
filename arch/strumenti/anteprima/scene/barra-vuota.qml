// Anteprima: la barra senza musica, senza batteria e senza rete (creato da vetro-arch.sh)
import QtQuick
Item {
    width: 1280
    height: 120
    Image {
        anchors.fill: parent
        source: sfondi + "/vetro-onde.jpg"
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignBottom
    }
    BarraVista {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        logo: radice + "/usr/share/icons/hicolor/scalable/apps/vetro.svg"
        app: [{ nome: "Terminale", icona: "", aperta: false, attiva: false }]
        iconaRete: "signal_wifi_off"
        iconaVolume: "volume_off"
        batteria: -1
        ora: "dom 26 13:46"
    }
}
