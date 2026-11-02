// Il centro di controllo, a destra sopra la barra (creato da vetro-arch.sh): saluto e ora,
// "resta sveglio", ricerca delle app, musica, schermate, comandi rapidi, volume,
// notifiche e spegnimento. Si apre dalla pillola di sistema nella barra o Windows+A.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: pannello

    visible: Stato.pannello || sfondo.opacity > 0.01
    anchors { top: true; bottom: true; right: true }
    margins { top: 10; bottom: Tema.sopraBarra; right: Tema.staccoBarra }
    implicitWidth: 412
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-pannello"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: Stato.pannello ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [ pannello ].concat(Stato.barre)
        active: Stato.pannello
        onCleared: Stato.pannello = false
    }

    SystemClock { id: orologio; precision: SystemClock.Minutes }

    // dopo la chiusura del pannello: la schermata (cosi' il pannello non c'e' nella foto)
    property var schermataDopo: []
    Timer {
        id: attesaSchermata
        interval: 450
        onTriggered: Quickshell.execDetached(pannello.schermataDopo)
    }
    function schermata(area) {
        schermataDopo = area ? ["/usr/local/bin/schermata", "area"] : ["/usr/local/bin/schermata"];
        Stato.pannello = false;
        attesaSchermata.restart();
    }

    Rectangle {
        id: sfondo
        anchors.fill: parent
        radius: Tema.raggio
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        opacity: Stato.pannello ? 1 : 0
        transform: Translate {
            x: Stato.pannello ? 0 : 48
            Behavior on x { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        focus: Stato.pannello
        Keys.onEscapePressed: Stato.pannello = false
        onVisibleChanged: if (visible) cerca.text = ""

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // --- saluto e ora -------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 78
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 16
                    spacing: 12
                    Avatar { Layout.preferredWidth: 46; Layout.preferredHeight: 46 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Saluto.frase(orologio.date) + (Opzioni.nomeUtente() !== "" ? ", " + Opzioni.nomeUtente() : "")
                            font.family: Tema.carattere
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: Tema.testo
                        }
                        Text {
                            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "dddd d MMMM")
                            font.family: Tema.carattere
                            font.pixelSize: 12
                            color: Tema.testo2
                        }
                    }
                    Text {
                        text: orologio.date.toLocaleString(Qt.locale("it_IT"), "HH:mm")
                        font.family: Tema.carattere
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        color: Tema.testo
                    }
                }
            }

            // --- resta sveglio -------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    Icona { nome: "coffee"; dimensione: 22; piena: Stato.restaSveglio }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Resta sveglio"
                            font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                            color: Tema.testo
                        }
                        Text {
                            text: Stato.restaSveglio ? "Lo schermo non si spegne e non si blocca" : "Risparmio energetico normale"
                            font.family: Tema.carattere; font.pixelSize: 11
                            color: Tema.testo2
                        }
                    }
                    Interruttore {
                        acceso: Stato.restaSveglio
                        onCambiato: v => Stato.restaSveglio = v
                    }
                }
            }

            // --- Wi-Fi (solo se c'e' una scheda Wi-Fi) ------------------------------------
            Wifi { Layout.fillWidth: true }

            // --- cerca le app ---------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 44 + griglia.height + 22
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 18
                        color: Tema.cartaForte
                        border.width: cerca.activeFocus ? 1 : 0
                        border.color: Tema.accento
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8
                            Icona { nome: "search"; dimensione: 18; color: Tema.testo2 }
                            TextInput {
                                id: cerca
                                Layout.fillWidth: true
                                font.family: Tema.carattere
                                font.pixelSize: 13
                                color: Tema.testo
                                selectionColor: Tema.accento
                                selectedTextColor: Tema.suAccento
                                clip: true
                                Text {
                                    anchors.fill: parent
                                    visible: cerca.text === ""
                                    text: "Cerca un'app"
                                    font: cerca.font
                                    color: Tema.testo3
                                }
                                Keys.onReturnPressed: {
                                    if (griglia.app.length > 0) {
                                        griglia.app[0].execute();
                                        Stato.pannello = false;
                                    }
                                }
                                Keys.onEscapePressed: Stato.pannello = false
                            }
                        }
                    }
                    Grid {
                        id: griglia
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6
                        readonly property var app: Applicazioni.cerca(cerca.text, 8)
                        Repeater {
                            model: griglia.app
                            delegate: Rectangle {
                                required property var modelData
                                width: (griglia.width - 18) / 4
                                height: 70
                                radius: Tema.raggioPiccolo
                                color: areaApp.containsMouse ? Tema.cartaForte : "transparent"
                                Behavior on color { ColorAnimation { duration: Tema.veloce } }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    IconImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        implicitSize: 34
                                        asynchronous: true
                                        source: Applicazioni.icona(modelData.icon)
                                    }
                                    Text {
                                        width: 82
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: modelData.name
                                        font.family: Tema.carattere
                                        font.pixelSize: 11
                                        color: Tema.testo
                                    }
                                }
                                MouseArea {
                                    id: areaApp
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { parent.modelData.execute(); Stato.pannello = false; }
                                }
                            }
                        }
                    }
                }
            }

            // --- musica ---------------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 12
                    ClippingRectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: 12
                        color: Tema.cartaForte
                        Icona {
                            anchors.centerIn: parent
                            visible: copertina.status !== Image.Ready
                            nome: "music_note"
                            dimensione: 22
                            color: Tema.testo2
                        }
                        Image {
                            id: copertina
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: Musica.copertina
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Musica.attivo ? (Musica.titolo || "Senza titolo") : "Niente in riproduzione"
                            font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                            color: Tema.testo
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Musica.attivo ? (Musica.artista || Musica.attivo.identity || "") : "Fai partire un brano o un video"
                            font.family: Tema.carattere; font.pixelSize: 11
                            color: Tema.testo2
                        }
                    }
                    Row {
                        spacing: 2
                        PulsanteIcona { implicitWidth: 32; implicitHeight: 32; icona: "skip_previous"; color: "transparent"; onCliccato: Musica.indietro() }
                        PulsanteIcona { implicitWidth: 36; implicitHeight: 36; icona: Musica.suona ? "pause" : "play_arrow"; attivo: true; onCliccato: Musica.alterna() }
                        PulsanteIcona { implicitWidth: 32; implicitHeight: 32; icona: "skip_next"; color: "transparent"; onCliccato: Musica.avanti() }
                    }
                }
            }

            // --- schermata -------------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10
                    Icona { nome: "screenshot_monitor"; dimensione: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: "Schermata"; font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold; color: Tema.testo }
                        Text { text: "Salvata in Immagini"; font.family: Tema.carattere; font.pixelSize: 11; color: Tema.testo2 }
                    }
                    Bottoncino { testo: "Schermo"; icona: "fullscreen"; onCliccato: pannello.schermata(false) }
                    Bottoncino { testo: "Area"; icona: "crop"; onCliccato: pannello.schermata(true) }
                }
            }

            // --- comandi rapidi -------------------------------------------------------
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Tessera {
                    Layout.fillWidth: true
                    icona: Opzioni.nonDisturbare ? "do_not_disturb_on" : "do_not_disturb_off"
                    titolo: "Non disturbare"
                    sottotitolo: Opzioni.nonDisturbare ? "Acceso" : "Spento"
                    attiva: Opzioni.nonDisturbare
                    onCliccata: Opzioni.nonDisturbare = !Opzioni.nonDisturbare
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: "visibility_off"
                    titolo: "Modalità fantasma"
                    sottotitolo: Sistema.fantasma ? "Tutto passa da Tor" : "Spenta"
                    attiva: Sistema.fantasma
                    onCliccata: { Stato.pannello = false; Quickshell.execDetached(["/usr/local/bin/fantasma"]); }
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: Tema.chiaro ? "light_mode" : "dark_mode"
                    titolo: Tema.chiaro ? "Tema chiaro" : "Tema scuro"
                    sottotitolo: Tema.attuale.nome
                    attiva: Tema.chiaro
                    onCliccata: Opzioni.tema = Tema.chiaro ? "ombra" : "carta"
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: "animation"
                    titolo: "Animazioni"
                    sottotitolo: Opzioni.animazioni ? "Fluide" : "Spente"
                    attiva: Opzioni.animazioni
                    onCliccata: Opzioni.animazioni = !Opzioni.animazioni
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: "blur_on"
                    titolo: "Sfocatura"
                    sottotitolo: Opzioni.sfocatura ? "Effetto vetro" : "Spenta"
                    attiva: Opzioni.sfocatura
                    onCliccata: Opzioni.sfocatura = !Opzioni.sfocatura
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: "settings"
                    titolo: "Impostazioni"
                    sottotitolo: "Tutte le scelte"
                    onCliccata: Stato.apriImpostazioni("generale")
                }
            }

            // --- volume ---------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Cursore {
                    Layout.fillWidth: true
                    valore: Audio.muto ? 0 : Audio.volume
                    icona: Audio.icona
                    onSpostato: v => Audio.imposta(v)
                }
                Text {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((Audio.muto ? 0 : Audio.volume) * 100) + "%"
                    font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.DemiBold
                    color: Tema.testo2
                }
            }

            // --- notifiche --------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Avvisi.quante > 0 ? "Notifiche (" + Avvisi.quante + ")" : "Nessuna notifica"
                    font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                    color: Tema.testo2
                }
                Bottoncino {
                    visible: Avvisi.quante > 0
                    testo: "Cancella"
                    icona: "clear_all"
                    onCliccato: Avvisi.cancellaTutte()
                }
            }
            ListView {
                id: listaAvvisi
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: ScriptModel { values: Avvisi.tutte.slice().reverse() }
                delegate: SchedaAvviso {
                    required property var modelData
                    width: listaAvvisi.width
                    avviso: modelData
                    compatta: true
                }
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tema.media } }
                displaced: Transition { NumberAnimation { property: "y"; duration: Tema.media; easing.type: Easing.OutCubic } }
            }

            // --- spegnimento -----------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Spegnimento { icona: "lock"; testo: "Blocca"; conferma: false; onFatto: Stato.blocca() }
                Spegnimento { icona: "logout"; testo: "Esci"; onFatto: Quickshell.execDetached(["hyprctl", "dispatch", "exit"]) }
                Spegnimento { icona: "restart_alt"; testo: "Riavvia"; onFatto: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "reboot"]) }
                Spegnimento { icona: "power_settings_new"; testo: "Spegni"; onFatto: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "poweroff"]) }
            }
        }
    }

    // pulsante piccolo con testo
    component Bottoncino: Rectangle {
        id: b
        property string testo: ""
        property string icona: ""
        signal cliccato()
        implicitHeight: 30
        implicitWidth: rigaB.implicitWidth + 20
        radius: 15
        color: areaBot.containsMouse ? Tema.cartaSopra : Tema.cartaForte
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
        Row {
            id: rigaB
            anchors.centerIn: parent
            spacing: 5
            Icona { visible: b.icona !== ""; nome: b.icona; dimensione: 15; anchors.verticalCenter: parent.verticalCenter }
            Text { text: b.testo; font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.Medium; color: Tema.testo; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: areaBot; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.cliccato() }
    }

    // pulsante di spegnimento: il primo clic chiede conferma, il secondo esegue
    component Spegnimento: Rectangle {
        id: s
        property string icona: ""
        property string testo: ""
        property bool conferma: true
        property bool chiede: false
        signal fatto()
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Tema.raggioMedio
        color: chiede ? Tema.rosso : (areaS.containsMouse ? Tema.cartaForte : Tema.carta)
        border.width: 1
        border.color: Tema.bordo
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: s.icona; dimensione: 20; color: s.chiede ? "#ffffff" : Tema.testo }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: s.chiede ? "Sicuro?" : s.testo
                font.family: Tema.carattere; font.pixelSize: 11; font.weight: Font.Medium
                color: s.chiede ? "#ffffff" : Tema.testo2
            }
        }
        Timer { id: annulla; interval: 3000; onTriggered: s.chiede = false }
        MouseArea {
            id: areaS
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!s.conferma || s.chiede) { s.chiede = false; s.fatto(); }
                else { s.chiede = true; annulla.restart(); }
            }
        }
    }
}
