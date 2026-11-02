// Cerca e apri le app (creato da lfs.sh, Fase 10): tasto Windows, Windows+Spazio o
// l'icona in alto a sinistra. Scrivi, scegli con le frecce e premi Invio. Senza
// scrivere niente mostra tutte le app (come il Launchpad).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: avvio

    visible: Stato.avvio || sfumatura.opacity > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vetro-avvio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Stato.avvio ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int scelta: 0
    readonly property var risultati: campo.text.trim() === "" ? Applicazioni.ordinate() : Applicazioni.cerca(campo.text, 40)

    function apri(e) {
        if (!e) return;
        e.execute();
        Stato.avvio = false;
    }

    Connections {
        target: Stato
        function onAvvioChanged() {
            if (Stato.avvio) { campo.text = ""; avvio.scelta = 0; campo.forceActiveFocus(); }
        }
    }

    // velo scuro su tutto lo schermo (dietro si sfoca): cliccandolo si chiude
    Rectangle {
        id: sfumatura
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.32)
        opacity: Stato.avvio ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: Stato.avvio = false }
    }

    Rectangle {
        id: riquadro
        width: Math.min(760, avvio.width - 80)
        height: Math.min(620, avvio.height - 160)
        anchors.horizontalCenter: parent.horizontalCenter
        y: (avvio.height - height) / 2 - 30
        radius: Tema.raggio + 4
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordoForte
        opacity: sfumatura.opacity
        scale: Stato.avvio ? 1 : 0.94
        Behavior on scale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        MouseArea { anchors.fill: parent }       // i clic qui dentro non chiudono

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: 27
                color: Tema.cartaForte
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12
                    Icona { nome: "search"; dimensione: 24; color: Tema.testo2 }
                    TextInput {
                        id: campo
                        Layout.fillWidth: true
                        font.family: Tema.carattere
                        font.pixelSize: 20
                        color: Tema.testo
                        selectionColor: Tema.accento
                        selectedTextColor: Tema.suAccento
                        clip: true
                        focus: true
                        onTextChanged: avvio.scelta = 0
                        Text {
                            anchors.fill: parent
                            visible: campo.text === ""
                            text: "Cerca un'app..."
                            font: campo.font
                            color: Tema.testo3
                        }
                        Keys.onEscapePressed: Stato.avvio = false
                        Keys.onReturnPressed: avvio.apri(avvio.risultati[avvio.scelta])
                        Keys.onEnterPressed: avvio.apri(avvio.risultati[avvio.scelta])
                        Keys.onDownPressed: avvio.scelta = Math.min(avvio.risultati.length - 1, avvio.scelta + (vista.colonne > 1 ? vista.colonne : 1))
                        Keys.onUpPressed: avvio.scelta = Math.max(0, avvio.scelta - (vista.colonne > 1 ? vista.colonne : 1))
                        Keys.onTabPressed: avvio.scelta = Math.min(avvio.risultati.length - 1, avvio.scelta + 1)
                        Keys.onRightPressed: e => {
                            if (vista.colonne > 1 && campo.cursorPosition === campo.text.length)
                                avvio.scelta = Math.min(avvio.risultati.length - 1, avvio.scelta + 1);
                            else e.accepted = false;
                        }
                        Keys.onLeftPressed: e => {
                            if (vista.colonne > 1 && campo.cursorPosition === campo.text.length)
                                avvio.scelta = Math.max(0, avvio.scelta - 1);
                            else e.accepted = false;
                        }
                    }
                }
            }

            GridView {
                id: vista
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                readonly property int colonne: 6
                cellWidth: width / colonne
                cellHeight: 118
                currentIndex: avvio.scelta
                model: ScriptModel { values: avvio.risultati }
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Tema.veloce
                highlight: Rectangle {
                    radius: Tema.raggioMedio
                    color: Tema.cartaForte
                    border.width: 1
                    border.color: Tema.bordoForte
                }
                delegate: Item {
                    id: casella
                    required property var modelData
                    required property int index
                    width: vista.cellWidth
                    height: vista.cellHeight
                    scale: areaCasella.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.veloce } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 56
                            asynchronous: true
                            mipmap: true
                            source: Applicazioni.icona(casella.modelData.icon)
                        }
                        Text {
                            width: vista.cellWidth - 16
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            text: casella.modelData.name
                            font.family: Tema.carattere
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Tema.testo
                        }
                    }
                    MouseArea {
                        id: areaCasella
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: avvio.scelta = casella.index
                        onClicked: avvio.apri(casella.modelData)
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: avvio.risultati.length === 0 ? "Nessuna app trovata"
                      : "Invio per aprire  ·  frecce per scegliere  ·  Esc per chiudere"
                font.family: Tema.carattere
                font.pixelSize: 11
                color: Tema.testo3
            }
        }
    }
}
