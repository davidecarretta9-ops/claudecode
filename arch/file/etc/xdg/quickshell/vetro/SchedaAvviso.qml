// Una notifica: icona, programma, titolo, testo e pulsanti (creato da lfs.sh)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: scheda
    property var avviso: null
    property bool compatta: false
    signal chiudi()

    readonly property bool urgente: avviso !== null && avviso.urgency === NotificationUrgency.Critical
    readonly property string iconaApp: {
        if (!avviso) return "";
        if (avviso.appIcon && avviso.appIcon !== "")
            return avviso.appIcon.startsWith("/") ? "file://" + avviso.appIcon
                 : Quickshell.iconPath(avviso.appIcon, "dialog-information");
        return Quickshell.iconPath("dialog-information");
    }

    implicitHeight: Math.max(colonna.implicitHeight, 38) + 24
    radius: Tema.raggioMedio
    color: compatta ? Tema.carta : Tema.fondoPieno
    border.width: 1
    border.color: urgente ? Tema.rosso : Tema.bordo

    RowLayout {
        id: riga
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 10
            color: Tema.cartaForte
            IconImage {
                anchors.centerIn: parent
                visible: !(scheda.avviso && scheda.avviso.image)
                implicitSize: 26
                asynchronous: true
                source: scheda.iconaApp
            }
            Image {
                anchors.fill: parent
                visible: !!(scheda.avviso && scheda.avviso.image)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: scheda.avviso && scheda.avviso.image ? scheda.avviso.image : ""
            }
        }

        ColumnLayout {
            id: colonna
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: scheda.avviso ? (scheda.avviso.appName || "Avviso") : ""
                    font.family: Tema.carattere
                    font.pixelSize: 11
                    color: Tema.testo3
                }
                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 11
                    color: areaX.containsMouse ? Tema.cartaSopra : "transparent"
                    Icona { anchors.centerIn: parent; nome: "close"; dimensione: 15; color: Tema.testo2 }
                    MouseArea {
                        id: areaX
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (scheda.avviso) scheda.avviso.dismiss(); scheda.chiudi(); }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: scheda.avviso ? scheda.avviso.summary : ""
                font.family: Tema.carattere
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Tema.testo
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                wrapMode: Text.Wrap
                maximumLineCount: scheda.compatta ? 2 : 5
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: scheda.avviso ? scheda.avviso.body : ""
                font.family: Tema.carattere
                font.pixelSize: 12
                color: Tema.testo2
                linkColor: Tema.accento
                onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: scheda.avviso !== null && scheda.avviso.actions.length > 0
                spacing: 6
                Repeater {
                    model: scheda.avviso ? scheda.avviso.actions : []
                    delegate: Rectangle {
                        required property var modelData
                        height: 28
                        width: testoAzione.implicitWidth + 24
                        radius: 14
                        color: areaAzione.containsMouse ? Tema.cartaSopra : Tema.cartaForte
                        Text {
                            id: testoAzione
                            anchors.centerIn: parent
                            text: modelData.text
                            font.family: Tema.carattere
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Tema.testo
                        }
                        MouseArea {
                            id: areaAzione
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
