// Il blocco schermo, solo la grafica (creato da vetro-arch.sh): cielo azzurro, in alto
// a sinistra la data e l'orologio enorme; in basso al centro nome e pillola della
// password; in basso a destra spegni e riavvia. Il controllo della password (PAM) e'
// in Blocco.qml.
import QtQuick

Item {
    id: vista

    property date ora: new Date()
    property string nome: ""
    property string sfondo: ""
    property bool controllo: false
    property string errore: ""

    signal invio(string password)
    signal spegni()
    signal riavvia()

    function sbagliata() { pillola.sbagliata(); }
    function metti_a_fuoco() { pillola.metti_a_fuoco(); }

    Rectangle {
        anchors.fill: parent
        color: "#0b3a6e"
    }
    Image {
        anchors.fill: parent
        source: vista.sfondo
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // data e orologio, in alto a sinistra
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 64
        anchors.topMargin: 64
        spacing: -10

        Text {
            leftPadding: 6
            text: vista.ora.toLocaleString(Qt.locale("it_IT"), "dddd d MMMM")
            font.family: Tema.carattere
            font.pixelSize: 20
            font.weight: Font.Medium
            color: Qt.rgba(1, 1, 1, 0.85)
        }
        Item {
            width: ora.implicitWidth
            height: ora.implicitHeight
            // un leggero alone bianco dietro le cifre
            Repeater {
                model: [[-3, 0], [3, 0], [0, -3], [0, 3]]
                delegate: Text {
                    required property var modelData
                    x: modelData[0]
                    y: modelData[1]
                    text: ora.text
                    font: ora.font
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
            }
            Text {
                id: ora
                text: vista.ora.toLocaleString(Qt.locale("it_IT"), "HH:mm")
                font.family: Tema.carattere
                font.pixelSize: 160
                font.weight: Font.Light
                font.letterSpacing: -4
                color: "#ffffff"
            }
        }
    }

    // nome e password, in basso al centro
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        spacing: 16
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                color: Qt.hsla(((vista.nome || "?").charCodeAt(0) * 37 % 360) / 360, 0.55, 0.55, 1)
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.7)
                Text {
                    anchors.centerIn: parent
                    text: (vista.nome || "?").charAt(0).toUpperCase()
                    font.family: Tema.carattere
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 420)
                elide: Text.ElideRight
                text: vista.nome
                font.family: Tema.carattere
                font.pixelSize: 24
                font.weight: Font.Bold
                color: "#ffffff"
            }
        }
        PasswordPillola {
            id: pillola
            anchors.horizontalCenter: parent.horizontalCenter
            controllo: vista.controllo
            errore: vista.errore
            onInvio: p => vista.invio(p)
        }
    }

    // spegni e riavvia
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32
        spacing: 14
        Repeater {
            model: [["power_settings_new", 0], ["restart_alt", 1]]
            delegate: Rectangle {
                id: tasto
                required property var modelData
                width: 44
                height: 44
                radius: 22
                color: areaT.containsMouse ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.2)
                Icona { anchors.centerIn: parent; nome: tasto.modelData[0]; dimensione: 22; color: "#ffffff" }
                MouseArea {
                    id: areaT
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tasto.modelData[1] === 0 ? vista.spegni() : vista.riavvia()
                }
            }
        }
    }
}
