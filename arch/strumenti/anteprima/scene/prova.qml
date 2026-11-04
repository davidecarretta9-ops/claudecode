// Scena di prova delle anteprime (creato da lfs.sh): solo QtQuick, per provare lo strumento
import QtQuick
Rectangle {
    width: 320
    height: 120
    color: "#1f201c"
    Row {
        anchors.centerIn: parent
        spacing: 12
        Rectangle { width: 40; height: 40; radius: 20; color: "#d9704a" }
        Text { text: "oversicaOS"; font.pixelSize: 28; color: "#eeece4" }
    }
}
