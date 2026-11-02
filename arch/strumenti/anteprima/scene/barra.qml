// Anteprima: la barra in basso sullo sfondo "sfera" (creato da vetro-arch.sh)
import QtQuick
Item {
    width: 1920
    height: 200
    Image {
        anchors.fill: parent
        source: sfondi + "/vetro-sfera.jpg"
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignBottom
    }
    BarraVista {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        logo: radice + "/usr/share/icons/hicolor/scalable/apps/vetro.svg"
        app: [
            { nome: "File", icona: "", aperta: true, attiva: true },
            { nome: "Tor Browser", icona: "", aperta: true, attiva: false },
            { nome: "Musica", icona: "", aperta: false, attiva: false },
            { nome: "Calcolatrice", icona: "", aperta: false, attiva: false },
            { nome: "Immagini", icona: "", aperta: false, attiva: false }
        ]
        nonDisturbare: true
        musica: false
        iconaRete: "signal_wifi_4_bar"
        iconaVolume: "volume_up"
        batteria: 100
        ora: "lun 15 14:23"
    }
}
