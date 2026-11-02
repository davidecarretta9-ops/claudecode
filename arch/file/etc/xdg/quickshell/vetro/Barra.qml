// La barra in alto (creato da lfs.sh, Fase 10): a sinistra le app e le scrivanie,
// al centro data e ora (aprono il cruscotto). Centro di controllo (volume, musica,
// modalita' fantasma...) e notifiche: Windows+A e Windows+N.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: barra
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: 46
    color: "transparent"
    WlrLayershell.namespace: "vetro-barra"
    WlrLayershell.layer: WlrLayer.Top

    SystemClock {
        id: orologio
        precision: Opzioni.secondi ? SystemClock.Seconds : SystemClock.Minutes
    }

    // "Resta sveglio" (centro di controllo): lo schermo non si spegne
    IdleInhibitor {
        window: barra
        enabled: Stato.restaSveglio
    }

    // con un pannello aperto Hyprland manda i clic solo alle finestre della sua lista:
    // la barra ci entra, cosi' i suoi tasti rispondono al primo clic
    Component.onCompleted: Stato.barre = Stato.barre.concat([barra])
    Component.onDestruction: Stato.barre = Stato.barre.filter(b => b !== barra)

    // ---------------------------------------------------------------- a sinistra
    Rectangle {
        id: sinistra
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 6
        height: 36
        width: filaSinistra.width + 12
        radius: height / 2
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        Behavior on width { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        Row {
            id: filaSinistra
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 6
            spacing: 8

            // le app (come lo Start o il Launchpad)
            Rectangle {
                width: 28; height: 28; radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: areaApp.containsMouse || Stato.avvio ? Tema.cartaSopra : "transparent"
                Behavior on color { ColorAnimation { duration: Tema.veloce } }
                Icona { anchors.centerIn: parent; nome: "apps"; dimensione: 19 }
                MouseArea {
                    id: areaApp
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stato.alterna("avvio")
                }
            }

            // le scrivanie: un pallino per ognuna, quella attiva e' piu' lunga
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: ScriptModel {
                        values: {
                            const l = Hyprland.workspaces.values.filter(w => w.id > 0);
                            return l.length > 0 ? l : [];
                        }
                    }
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool attiva: modelData.focused || modelData.active
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8
                        width: attiva ? 26 : 8
                        radius: 4
                        color: attiva ? Tema.accento : (modelData.toplevels.values.length > 0 ? Tema.testo2 : Tema.testo3)
                        Behavior on width { NumberAnimation { duration: Tema.media; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                        Behavior on color { ColorAnimation { duration: Tema.media } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.activate()
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                width: Math.min(implicitWidth, 320)
                elide: Text.ElideRight
                text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
                font.family: Tema.carattere
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Tema.testo2
                rightPadding: 6
            }
        }
    }

    // ---------------------------------------------------------------- al centro
    Rectangle {
        id: centro
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 6
        height: 36
        width: testoOra.implicitWidth + 34
        radius: height / 2
        color: areaOra.containsMouse || Stato.cruscotto ? Tema.fondoPieno : Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        Behavior on color { ColorAnimation { duration: Tema.veloce } }

        Text {
            id: testoOra
            anchors.centerIn: parent
            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "ddd d MMM") + "    "
                  + orologio.date.toLocaleString(Qt.locale("it_IT"), Opzioni.secondi ? "HH:mm:ss" : "HH:mm")
            font.family: Tema.carattere
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Tema.testo
        }
        MouseArea {
            id: areaOra
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Stato.alterna("cruscotto")
        }
    }
}
