// Anteprima: la barra piena (titolo lunghissimo, fantasma, batteria scarica, tante app)
// (creato da vetro-arch.sh)
import QtQuick
Item {
    width: 1920
    height: 120
    Image {
        anchors.fill: parent
        source: sfondi + "/vetro-magenta.jpg"
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignBottom
    }
    BarraVista {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        logo: radice + "/usr/share/icons/hicolor/scalable/apps/vetro.svg"
        app: [
            { nome: "File", icona: "", aperta: true, attiva: false },
            { nome: "Tor Browser", icona: "", aperta: true, attiva: true },
            { nome: "Thunderbird", icona: "", aperta: true, attiva: false },
            { nome: "LibreOffice Writer", icona: "", aperta: false, attiva: false },
            { nome: "Mousepad", icona: "", aperta: false, attiva: false },
            { nome: "Terminale", icona: "", aperta: false, attiva: false },
            { nome: "Impostazioni", icona: "", aperta: false, attiva: false }
        ]
        nonDisturbare: true
        musica: true
        musicaTitolo: "Un titolo di canzone lunghissimo che non entra nella pillola della barra"
        musicaCopertina: sfondi + "/vetro-magenta.jpg"
        fantasma: true
        iconaRete: "network_wifi_2_bar"
        batteria: 15
        ora: "ven 31 23:59"
    }
}
