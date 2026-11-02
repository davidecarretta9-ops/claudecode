// La pillola della password (creato da vetro-arch.sh): blu scuro, pallini bianchi
// grandi e l'occhio per vedere quello che scrivi. La usano la schermata di accesso e il
// blocco. Niente Tema: all'accesso non si leggono le scelte dell'utente.
import QtQuick

Item {
    id: pillola

    property alias testo: campo.text
    property bool controllo: false        // la password si sta controllando
    property string errore: ""
    property string suggerimento: "Scrivi la password"
    property bool vedi: false             // l'occhio: password in chiaro

    signal invio(string password)
    signal tabulazione()

    // password sbagliata: trema, si svuota e resta pronta
    function sbagliata() {
        campo.text = "";
        scuoti.restart();
        campo.forceActiveFocus();
    }
    function metti_a_fuoco() { campo.forceActiveFocus(); }

    readonly property string carattere: "DM Sans"
    readonly property string caratteriIcone: "Material Symbols Rounded"
    readonly property bool iconeOk: Qt.fontFamilies().indexOf(caratteriIcone) >= 0

    implicitWidth: 440
    implicitHeight: 64

    property real scossa: 0
    transform: Translate { x: pillola.scossa }
    SequentialAnimation {
        id: scuoti
        NumberAnimation { target: pillola; property: "scossa"; to: -16; duration: 50 }
        NumberAnimation { target: pillola; property: "scossa"; to: 13; duration: 70 }
        NumberAnimation { target: pillola; property: "scossa"; to: -8; duration: 70 }
        NumberAnimation { target: pillola; property: "scossa"; to: 0; duration: 60 }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(0.059, 0.137, 0.251, 0.85)          // #0f2340
        border.width: 1
        border.color: pillola.errore !== "" ? Qt.rgba(1, 0.42, 0.42, 0.8)
                      : Qt.rgba(1, 1, 1, campo.activeFocus ? 0.24 : 0.12)

        TextInput {
            id: campo
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.right: occhio.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            echoMode: pillola.vedi ? TextInput.Normal : TextInput.Password
            passwordCharacter: "●"
            font.family: pillola.carattere
            font.pixelSize: pillola.vedi ? 20 : 26
            font.letterSpacing: pillola.vedi ? 1 : 6
            color: "#ffffff"
            selectionColor: "#1a8cff"
            selectedTextColor: "#ffffff"
            enabled: !pillola.controllo
            clip: true
            onAccepted: if (text !== "") pillola.invio(text)
            Keys.onTabPressed: pillola.tabulazione()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: campo.text === ""
                text: pillola.controllo ? "Controllo..." : (pillola.errore !== "" ? pillola.errore : pillola.suggerimento)
                font.family: pillola.carattere
                font.pixelSize: 17
                font.letterSpacing: 0
                color: pillola.errore !== "" ? "#ff8a84" : Qt.rgba(1, 1, 1, 0.55)
            }
        }

        // l'occhio
        Item {
            id: occhio
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: areaOcchio.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            }
            Text {
                anchors.centerIn: parent
                text: pillola.iconeOk ? (pillola.vedi ? "visibility_off" : "visibility") : (pillola.vedi ? "◎" : "◉")
                font.family: pillola.iconeOk ? pillola.caratteriIcone : pillola.carattere
                font.pixelSize: 26
                font.variableAxes: pillola.iconeOk ? { "FILL": 1, "wght": 500, "opsz": 24 } : {}
                color: "#ffffff"
            }
            MouseArea {
                id: areaOcchio
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { pillola.vedi = !pillola.vedi; campo.forceActiveFocus(); }
            }
        }
    }
}
