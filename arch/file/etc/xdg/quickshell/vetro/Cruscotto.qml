// Il cruscotto (creato da lfs.sh, Fase 10): si apre cliccando data e ora o con
// Windows+D. Tre schede: Cruscotto (meteo, saluto, orologio, calendario),
// Sfondi e Prestazioni (processore, memoria, disco, rete).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: cruscotto

    visible: Stato.cruscotto || corpo.opacity > 0.01
    anchors { top: true }
    margins { top: 6 }
    implicitWidth: 900
    implicitHeight: 520
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-cruscotto"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: Stato.cruscotto ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [ cruscotto ].concat(Stato.barre)
        active: Stato.cruscotto
        onCleared: Stato.cruscotto = false
    }

    SystemClock { id: orologio; precision: SystemClock.Minutes }

    Rectangle {
        id: corpo
        anchors.fill: parent
        radius: Tema.raggio + 4
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        opacity: Stato.cruscotto ? 1 : 0
        transform: [
            Scale {
                origin.x: corpo.width / 2
                origin.y: 0
                xScale: Stato.cruscotto ? 1 : 0.96
                yScale: Stato.cruscotto ? 1 : 0.96
                Behavior on xScale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
                Behavior on yScale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
            },
            Translate {
                y: Stato.cruscotto ? 0 : -16
                Behavior on y { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
            }
        ]
        Behavior on opacity { NumberAnimation { duration: Tema.media } }

        focus: Stato.cruscotto
        Keys.onEscapePressed: Stato.cruscotto = false
        Keys.onTabPressed: Stato.schedaCruscotto = (Stato.schedaCruscotto + 1) % 3

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // --- le schede ------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: Tema.carta
                Rectangle {
                    id: evidenza
                    y: 4
                    height: parent.height - 8
                    width: (parent.width - 8) / 3
                    x: 4 + Stato.schedaCruscotto * width
                    radius: height / 2
                    color: Tema.cartaSopra
                    Behavior on x { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    Repeater {
                        model: [
                            { nome: "Cruscotto", icona: "dashboard" },
                            { nome: "Sfondi", icona: "wallpaper" },
                            { nome: "Prestazioni", icona: "monitoring" }
                        ]
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: parent.width / 3
                            height: parent.height
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Icona {
                                    nome: modelData.icona
                                    dimensione: 18
                                    piena: Stato.schedaCruscotto === index
                                    color: Stato.schedaCruscotto === index ? Tema.testo : Tema.testo2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.nome
                                    font.family: Tema.carattere
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Stato.schedaCruscotto === index ? Tema.testo : Tema.testo2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Stato.schedaCruscotto = parent.index
                            }
                        }
                    }
                }
            }

            // --- il contenuto: scorre di lato cambiando scheda --------------------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Row {
                    id: pagine
                    x: -Stato.schedaCruscotto * (parent.width + 20)
                    spacing: 20
                    height: parent.height
                    Behavior on x { NumberAnimation { duration: Tema.lenta; easing.type: Easing.OutCubic } }

                    PaginaCruscotto { width: pagine.parent.width; height: pagine.height }
                    PaginaSfondi { width: pagine.parent.width; height: pagine.height }
                    PaginaPrestazioni { width: pagine.parent.width; height: pagine.height }
                }
            }
        }
    }

    // ============================================================ scheda Cruscotto
    component PaginaCruscotto: GridLayout {
        id: paginaC
        columns: 3
        rowSpacing: 12
        columnSpacing: 12

        // (i componenti qui sotto non vedono l'orologio della finestra: ne hanno uno)
        SystemClock { id: ora; precision: SystemClock.Minutes }

        // meteo
        Carta {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16
                visible: Opzioni.meteo
                Icona { nome: Meteo.icona; dimensione: 52; piena: true }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: Meteo.temperatura + "°C"
                        font.family: Tema.carattere; font.pixelSize: 34; font.weight: Font.Bold
                        color: Tema.testo
                    }
                    Text {
                        text: Meteo.pronto ? Meteo.descrizione : "Cerco il meteo..."
                        font.family: Tema.carattere; font.pixelSize: 12
                        color: Tema.testo2
                    }
                    Text {
                        visible: Meteo.luogo !== ""
                        text: Meteo.luogo + (Meteo.umidita !== "" ? "  ·  umidità " + Meteo.umidita + "%" : "")
                        font.family: Tema.carattere; font.pixelSize: 11
                        color: Tema.testo3
                    }
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: Meteo.giorni
                    delegate: Column {
                        required property var modelData
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.giorno
                            font.family: Tema.carattere; font.pixelSize: 11; font.weight: Font.DemiBold
                            color: Tema.testo2
                        }
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: modelData.icona; dimensione: 24 }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.max + "° " + modelData.min + "°"
                            font.family: Tema.carattere; font.pixelSize: 11
                            color: Tema.testo2
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !Opzioni.meteo
                text: "Il meteo è spento (Impostazioni → Cruscotto)"
                font.family: Tema.carattere; font.pixelSize: 12
                color: Tema.testo3
            }
        }

        // saluto
        // (larghezze fisse a destra: lo spazio che avanza va al calendario. Una carta
        // con fillWidth ma senza larghezza di partenza riceve 0: il calendario spariva)
        Carta {
            Layout.preferredWidth: 260
            Layout.preferredHeight: 120
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                RowLayout {
                    spacing: 10
                    Avatar { Layout.preferredWidth: 42; Layout.preferredHeight: 42 }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        text: Saluto.frase(ora.date) + (Opzioni.nomeUtente() !== "" ? ",\n" + Opzioni.nomeUtente() : "")
                        font.family: Tema.carattere; font.pixelSize: 14; font.weight: Font.DemiBold
                        color: Tema.testo
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Pastiglia { icona: "computer"; testo: Sistema.nomeComputer }
                    Pastiglia { icona: "schedule"; testo: "acceso da " + Sistema.testoAcceso() }
                }
            }
        }

        // orologio grande
        Carta {
            Layout.preferredWidth: 150
            Layout.fillHeight: true
            Column {
                anchors.centerIn: parent
                spacing: -6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ora.date.toLocaleString(Qt.locale("it_IT"), "HH")
                    font.family: Tema.carattere; font.pixelSize: 64; font.weight: Font.Black
                    color: Tema.testo
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ora.date.toLocaleString(Qt.locale("it_IT"), "mm")
                    font.family: Tema.carattere; font.pixelSize: 64; font.weight: Font.Black
                    color: Tema.testo2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 10
                    text: ora.date.toLocaleString(Qt.locale("it_IT"), "dddd").toUpperCase()
                    font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.DemiBold
                    font.letterSpacing: 2
                    color: Tema.testo3
                }
            }
        }

        // calendario
        Carta {
            Layout.fillWidth: true
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            Calendario { anchors.fill: parent; anchors.margins: 12; oggi: ora.date }
        }

        // processore, memoria, disco
        Carta {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                MiniAnello { titolo: "Processore"; valore: Sistema.cpu; icona: "memory" }
                MiniAnello { titolo: "Memoria"; valore: Sistema.memoria; icona: "memory_alt" }
                MiniAnello { titolo: "Disco"; valore: Sistema.disco; icona: "hard_drive" }
            }
        }
    }

    component Pastiglia: Rectangle {
        id: pastiglia
        property string icona: ""
        property string testo: ""
        visible: testo !== ""
        height: 24
        width: rigaP.implicitWidth + 16
        radius: 12
        color: Tema.cartaForte
        Row {
            id: rigaP
            anchors.centerIn: parent
            spacing: 4
            Icona { nome: pastiglia.icona; dimensione: 14; color: Tema.testo2; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: pastiglia.testo
                font.family: Tema.carattere; font.pixelSize: 11
                color: Tema.testo2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component MiniAnello: RowLayout {
        id: mini
        property string titolo: ""
        property real valore: 0
        property string icona: ""
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12
        Item {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            Anello { anchors.fill: parent; valore: mini.valore; spessore: 5 }
            Icona { anchors.centerIn: parent; nome: mini.icona; dimensione: 16; color: Tema.testo2 }
        }
        ColumnLayout {
            spacing: 0
            Text { text: mini.titolo; font.family: Tema.carattere; font.pixelSize: 12; color: Tema.testo2 }
            Text {
                text: Math.round(mini.valore * 100) + "%"
                font.family: Tema.carattere; font.pixelSize: 18; font.weight: Font.Bold
                color: Tema.testo
            }
        }
    }

    // ============================================================ scheda Sfondi
    component PaginaSfondi: ColumnLayout {
        spacing: 12
        GridView {
            id: galleria
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / 4
            cellHeight: cellWidth * 0.62
            model: Sfondi.elenco
            delegate: Item {
                required property var modelData
                width: galleria.cellWidth
                height: galleria.cellHeight
                Rectangle {
                    id: cornice
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Tema.raggioMedio
                    color: Tema.carta
                    border.width: modelData === Sfondi.attuale ? 3 : 1
                    border.color: modelData === Sfondi.attuale ? Tema.accento : Tema.bordo
                    scale: areaSf.containsMouse ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                        sourceSize.height: 200
                        source: "file://" + modelData
                    }
                    MouseArea {
                        id: areaSf
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sfondi.scegli(modelData)
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Clicca un'immagine per metterla come sfondo"
                font.family: Tema.carattere; font.pixelSize: 12
                color: Tema.testo3
            }
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: testoMia.implicitWidth + 48
                radius: 16
                color: areaMia.containsMouse ? Tema.cartaSopra : Tema.cartaForte
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icona { nome: "add_photo_alternate"; dimensione: 17; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        id: testoMia
                        text: "Usa una tua immagine..."
                        font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.Medium
                        color: Tema.testo
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: areaMia
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Stato.cruscotto = false; Quickshell.execDetached(["/usr/local/bin/impostazioni-aspetto"]); }
                }
            }
        }
    }

    // ============================================================ scheda Prestazioni
    component PaginaPrestazioni: GridLayout {
        columns: 3
        rowSpacing: 12
        columnSpacing: 12

        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 2
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Icona { nome: "memory"; dimensione: 20 }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: "Processore" + (Sistema.processore !== "" ? "  ·  " + Sistema.processore : "")
                        font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                        color: Tema.testo
                    }
                    Text {
                        visible: Sistema.temperatura > 0
                        text: Math.round(Sistema.temperatura) + "°C"
                        font.family: Tema.mono; font.pixelSize: 12
                        color: Tema.testo2
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16
                    Item {
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 110
                        Anello { anchors.fill: parent; valore: Sistema.cpu; spessore: 10 }
                        Text {
                            anchors.centerIn: parent
                            text: Math.round(Sistema.cpu * 100) + "%"
                            font.family: Tema.carattere; font.pixelSize: 24; font.weight: Font.Bold
                            color: Tema.testo
                        }
                    }
                    Grafico {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        valori: Sistema.storiaCpu
                        massimo: 1
                    }
                }
            }
        }

        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                RowLayout {
                    Icona { nome: "memory_alt"; dimensione: 20 }
                    Text { text: "Memoria"; font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold; color: Tema.testo }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Anello {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 6
                        height: width
                        valore: Sistema.memoria
                        spessore: 10
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Math.round(Sistema.memoria * 100) + "%"
                        font.family: Tema.carattere; font.pixelSize: 22; font.weight: Font.Bold
                        color: Tema.testo
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Sistema.memoriaUsata.toFixed(1) + " / " + Sistema.memoriaTotale.toFixed(1) + " GB"
                    font.family: Tema.mono; font.pixelSize: 12
                    color: Tema.testo2
                }
            }
        }

        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                RowLayout {
                    Icona { nome: "hard_drive"; dimensione: 20 }
                    Text { text: "Disco"; font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold; color: Tema.testo }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Anello {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 6
                        height: width
                        valore: Sistema.disco
                        spessore: 10
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Math.round(Sistema.disco * 100) + "%"
                        font.family: Tema.carattere; font.pixelSize: 22; font.weight: Font.Bold
                        color: Tema.testo
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Sistema.discoUsato.toFixed(1) + " / " + Sistema.discoTotale.toFixed(1) + " GB"
                    font.family: Tema.mono; font.pixelSize: 12
                    color: Tema.testo2
                }
            }
        }

        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 2
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Icona { nome: "network_check"; dimensione: 20 }
                    Text {
                        Layout.fillWidth: true
                        text: "Rete"
                        font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                        color: Tema.testo
                    }
                    Icona { nome: "south"; dimensione: 15; color: Tema.accento }
                    Text { text: Sistema.velocita(Sistema.scarica); font.family: Tema.mono; font.pixelSize: 12; color: Tema.testo }
                    Item { Layout.preferredWidth: 8 }
                    Icona { nome: "north"; dimensione: 15; color: Tema.testo3 }
                    Text { text: Sistema.velocita(Sistema.carica); font.family: Tema.mono; font.pixelSize: 12; color: Tema.testo2 }
                }
                Grafico {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    valori: Sistema.storiaScarica
                    valori2: Sistema.storiaCarica
                }
                Text {
                    text: "Da quando è acceso: scaricati " + Sistema.grandezza(Sistema.totaleScaricato)
                          + ", inviati " + Sistema.grandezza(Sistema.totaleCaricato)
                    font.family: Tema.carattere; font.pixelSize: 11
                    color: Tema.testo3
                }
            }
        }
    }
}
