// Anteprima: il menu delle app (menu) sopra la barra (creato da vetro-arch.sh)
import QtQuick
Item {
    width: 900
    height: 760
    Image {
        anchors.fill: parent
        source: sfondi + "/vetro-argento.jpg"
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignBottom
        horizontalAlignment: Image.AlignLeft
    }
    MenuVista {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.bottom: barra.top
        anchors.bottomMargin: 6 - 8
        altezzaMassima: 540
        risultati: [
            { nome: "Terminale", icona: "" }, { nome: "Tor Browser", icona: "" },
            { nome: "Thunderbird", icona: "" }, { nome: "Thunar", icona: "" },
            { nome: "LibreOffice Writer", icona: "" }, { nome: "Mousepad", icona: "" },
            { nome: "Impostazioni", icona: "" }, { nome: "Programmi Windows", icona: "" }
        ]

    }
    BarraVista {
        id: barra
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        logo: radice + "/usr/share/icons/hicolor/scalable/apps/vetro.svg"
        menuAperto: true
        app: [{ nome: "File", icona: "", aperta: true, attiva: true }, { nome: "Tor Browser", icona: "", aperta: false, attiva: false }]
        ora: "lun 15  14:23"
    }
}
