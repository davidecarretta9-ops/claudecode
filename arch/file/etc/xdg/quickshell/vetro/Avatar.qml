// La tua immagine (~/.face) o l'iniziale del tuo nome in un cerchio (creato da lfs.sh)
import QtQuick
import Quickshell
import Quickshell.Widgets

ClippingRectangle {
    id: avatar
    implicitWidth: 46
    implicitHeight: 46
    radius: width / 2
    color: Tema.accento

    Text {
        anchors.centerIn: parent
        visible: foto.status !== Image.Ready
        text: (Opzioni.nomeUtente() || "?").charAt(0).toUpperCase()
        font.family: Tema.carattere
        font.pixelSize: avatar.height * 0.45
        font.weight: Font.Bold
        color: Tema.suAccento
    }
    Image {
        id: foto
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        source: "file://" + (Quickshell.env("HOME") || "") + "/.face"
        sourceSize.width: avatar.width * 2
        sourceSize.height: avatar.height * 2
    }
}
