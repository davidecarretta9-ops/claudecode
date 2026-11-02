// L'icona di un'app (creato da vetro-arch.sh): l'immagine, oppure, se non c'e', un
// quadratino colorato con l'iniziale del nome. La usano la barra e il menu.
import QtQuick

Item {
    id: ic
    property string sorgente: ""
    property string nome: ""
    property int lato: 30

    width: lato
    height: lato

    Image {
        id: immagine
        anchors.fill: parent
        source: ic.sorgente
        sourceSize.width: ic.lato * 2
        sourceSize.height: ic.lato * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }
    Rectangle {
        visible: immagine.status !== Image.Ready
        anchors.fill: parent
        anchors.margins: 1
        radius: ic.lato * 0.28
        color: Qt.hsla(((ic.nome || "?").charCodeAt(0) * 37 % 360) / 360, 0.65, 0.55, 1)
        Text {
            anchors.centerIn: parent
            text: (ic.nome || "?").charAt(0).toUpperCase()
            font.family: Tema.carattere
            font.pixelSize: ic.lato * 0.52
            font.weight: Font.Bold
            color: "#ffffff"
        }
    }
}
