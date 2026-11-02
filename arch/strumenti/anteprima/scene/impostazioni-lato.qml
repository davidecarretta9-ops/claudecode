// Anteprima: il lato delle Impostazioni chiare (creato da vetro-arch.sh)
import QtQuick
Rectangle {
    width: 760
    height: 460
    color: Tema.appFondo
    Rectangle {
        x: 0
        y: 0
        width: 260
        height: parent.height
        color: Tema.appCarta
        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 2
            Text {
                leftPadding: 6
                bottomPadding: 10
                text: "Impostazioni"
                font.family: Tema.carattere
                font.pixelSize: 20
                font.weight: Font.Bold
                color: Tema.appTesto
            }
            VoceLato { width: parent.width; icona: "home"; testo: "Generale" }
            VoceLato { width: parent.width; icona: "palette"; testo: "Aspetto"; scelta: true }
            VoceLato { width: parent.width; icona: "select_window"; testo: "Finestre" }
            VoceLato { width: parent.width; icona: "dock_to_bottom"; testo: "Barra" }
            VoceLato { width: parent.width; icona: "notifications"; testo: "Notifiche" }
            VoceLato { width: parent.width; icona: "lock"; testo: "Blocco schermo" }
            VoceLato { width: parent.width; icona: "desktop_windows"; testo: "Schermo" }
        }
    }
    Text {
        x: 290
        y: 26
        text: "Aspetto"
        font.family: Tema.carattere
        font.pixelSize: 24
        font.weight: Font.Bold
        color: Tema.appTesto
    }
    Rectangle {
        x: 290
        y: 80
        width: 440
        height: 120
        radius: 14
        color: Tema.appCarta
        border.width: 1
        border.color: Tema.appBordo
        Text {
            x: 18
            y: 18
            text: "Tema"
            font.family: Tema.carattere
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Tema.appTesto
        }
        Text {
            x: 18
            y: 42
            text: "Vetro: barra scura, finestre chiare, accento blu"
            font.family: Tema.carattere
            font.pixelSize: 12
            color: Tema.appTesto2
        }
    }
}
