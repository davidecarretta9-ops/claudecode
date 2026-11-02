// La schermata di accesso, solo la grafica (creato da vetro-arch.sh): sfondo, al centro
// la foto (l'iniziale) e il nome, sotto la pillola della password; in basso a destra
// spegni e riavvia. Niente Tema: all'accesso non si leggono le scelte dell'utente.
// I dati (utenti, greetd) li gestisce accesso.qml.
import QtQuick

Item {
    id: vista

    property var utenti: []
    property int scelto: 0
    property string sfondo: ""
    property bool controllo: false
    property string errore: ""

    signal entra(string password)
    signal cambiaUtente()
    signal spegni()
    signal riavvia()

    function sbagliata() { pillola.sbagliata(); }
    function metti_a_fuoco() { pillola.metti_a_fuoco(); }

    readonly property string carattere: "DM Sans"
    readonly property string caratteriIcone: "Material Symbols Rounded"
    readonly property bool iconeOk: Qt.fontFamilies().indexOf(caratteriIcone) >= 0
    readonly property string nome: utenti.length > 0 ? utenti[Math.min(scelto, utenti.length - 1)] : ""

    Rectangle {
        anchors.fill: parent
        color: "#0b1f3a"
    }
    Image {
        anchors.fill: parent
        source: vista.sfondo
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 20
        spacing: 20

        // foto (l'iniziale) e nome; clic o Tab: utente dopo
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: riga.width
            height: riga.height
            Row {
                id: riga
                spacing: 14
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 56
                    height: 56
                    radius: 28
                    color: Qt.hsla(((vista.nome || "?").charCodeAt(0) * 37 % 360) / 360, 0.55, 0.55, 1)
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.7)
                    Text {
                        anchors.centerIn: parent
                        text: (vista.nome || "?").charAt(0).toUpperCase()
                        font.family: vista.carattere
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 420)
                    elide: Text.ElideRight
                    text: vista.nome
                    font.family: vista.carattere
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: vista.utenti.length > 1
                    text: vista.iconeOk ? "unfold_more" : "⇅"
                    font.family: vista.iconeOk ? vista.caratteriIcone : vista.carattere
                    font.pixelSize: 24
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: vista.utenti.length > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: vista.cambiaUtente()
            }
        }

        PasswordPillola {
            id: pillola
            anchors.horizontalCenter: parent.horizontalCenter
            controllo: vista.controllo
            errore: vista.errore
            onInvio: p => vista.entra(p)
            onTabulazione: vista.cambiaUtente()
        }
    }

    // spegni e riavvia
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32
        spacing: 14
        Repeater {
            model: [["power_settings_new", "⏻", 0], ["restart_alt", "↻", 1]]
            delegate: Rectangle {
                id: tasto
                required property var modelData
                width: 44
                height: 44
                radius: 22
                color: areaT.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)
                Text {
                    anchors.centerIn: parent
                    text: vista.iconeOk ? tasto.modelData[0] : tasto.modelData[1]
                    font.family: vista.iconeOk ? vista.caratteriIcone : vista.carattere
                    font.pixelSize: 22
                    color: "#ffffff"
                }
                MouseArea {
                    id: areaT
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tasto.modelData[2] === 0 ? vista.spegni() : vista.riavvia()
                }
            }
        }
    }
}
