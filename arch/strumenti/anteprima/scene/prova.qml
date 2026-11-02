// Scena di prova delle anteprime (creato da vetro-arch.sh): colori e icone del tema
import QtQuick
Rectangle {
    width: 320
    height: 120
    color: Tema.base
    Row {
        anchors.centerIn: parent
        spacing: 12
        Rectangle { width: 40; height: 40; radius: 20; color: Tema.accento }
        Icona { nome: "wifi"; dimensione: 28 }
        Text { text: "Vetro"; font.family: Tema.carattere; font.pixelSize: 28; color: Tema.testo }
    }
}
