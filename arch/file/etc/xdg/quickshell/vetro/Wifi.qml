// Il Wi-Fi nel centro di controllo (creato da vetro-arch.sh). Le reti vicine le da'
// /usr/local/bin/vetro-wifi (iwd). Clic su una rete per collegarti: se e' protetta e
// non e' salvata chiede la password. Si vede solo se c'e' una scheda Wi-Fi.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Carta {
    id: wifi

    property var reti: []
    property bool aperto: false          // elenco delle reti aperto
    property string chiede: ""           // la rete che aspetta la password
    property string messaggio: ""
    readonly property var collegata: reti.find(r => r.collegata) || null

    visible: reti.length > 0
    implicitHeight: colonna.implicitHeight + 24

    // --- leggere le reti: ogni 4 secondi con l'elenco aperto, se no ogni 15 ---------
    Process {
        id: leggi
        command: ["/usr/local/bin/vetro-wifi", "elenco"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { wifi.reti = JSON.parse(this.text) || []; } catch (e) { wifi.reti = []; }
            }
        }
    }
    Timer {
        interval: wifi.aperto ? 4000 : 15000
        running: Stato.pannello
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!leggi.running) leggi.running = true
    }

    // --- collegarsi e scollegarsi -----------------------------------------------
    Process {
        id: comando
        property string rete: ""
        property bool conPassword: false
        property bool protetta: false
        onExited: (codice, stato) => {
            if (codice === 0) {
                wifi.messaggio = rete !== "" ? "Collegato a " + rete : "";
                wifi.chiede = "";
            } else if (rete !== "" && protetta && !conPassword) {
                wifi.chiede = rete;
                wifi.messaggio = "Scrivi la password di " + rete;
            } else if (rete !== "") {
                wifi.messaggio = conPassword ? "Password sbagliata o rete troppo lontana"
                                             : "Non riesco a collegarmi a " + rete;
            } else {
                wifi.messaggio = "";
            }
            leggi.running = true;
        }
    }
    function collega(r, password) {
        if (comando.running) return;
        comando.rete = r.nome;
        comando.protetta = r.protetta;
        comando.conPassword = password !== "";
        messaggio = "Mi collego a " + r.nome + "...";
        comando.command = password !== ""
            ? ["/usr/local/bin/vetro-wifi", "collega", r.nome, password]
            : ["/usr/local/bin/vetro-wifi", "collega", r.nome];
        comando.running = true;
    }
    function scollega() {
        if (comando.running) return;
        comando.rete = "";
        messaggio = "";
        comando.command = ["/usr/local/bin/vetro-wifi", "scollega"];
        comando.running = true;
    }
    function iconaSegnale(s) {
        return s >= 4 ? "signal_wifi_4_bar" : s === 3 ? "network_wifi_3_bar"
             : s === 2 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    ColumnLayout {
        id: colonna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6

        // titolo: la rete di adesso, clic per aprire l'elenco
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 2
                spacing: 12
                Icona {
                    nome: wifi.collegata ? wifi.iconaSegnale(wifi.collegata.segnale) : "wifi_off"
                    dimensione: 22
                    piena: wifi.collegata !== null
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: "Wi-Fi"
                        font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                        color: Tema.testo
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: wifi.messaggio !== "" ? wifi.messaggio
                              : (wifi.collegata ? "Collegato a " + wifi.collegata.nome : "Non collegato")
                        font.family: Tema.carattere; font.pixelSize: 11
                        color: Tema.testo2
                    }
                }
                Icona {
                    nome: wifi.aperto ? "expand_less" : "expand_more"
                    dimensione: 22
                    color: Tema.testo2
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { wifi.aperto = !wifi.aperto; if (wifi.aperto) leggi.running = true; }
            }
        }

        // l'elenco delle reti
        Repeater {
            model: wifi.aperto ? wifi.reti : []
            delegate: ColumnLayout {
                id: voce
                required property var modelData
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Tema.raggioPiccolo
                    color: areaRete.containsMouse ? Tema.cartaForte : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10
                        Icona {
                            nome: wifi.iconaSegnale(voce.modelData.segnale)
                            dimensione: 18
                            color: voce.modelData.collegata ? Tema.accento : Tema.testo
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: voce.modelData.nome
                            font.family: Tema.carattere; font.pixelSize: 13
                            font.weight: voce.modelData.collegata ? Font.DemiBold : Font.Normal
                            color: Tema.testo
                        }
                        Icona {
                            visible: voce.modelData.protetta
                            nome: "lock"
                            dimensione: 14
                            color: Tema.testo3
                        }
                        Text {
                            visible: voce.modelData.collegata
                            text: "Scollega"
                            font.family: Tema.carattere; font.pixelSize: 11; font.weight: Font.DemiBold
                            color: Tema.accento
                        }
                    }
                    MouseArea {
                        id: areaRete
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: voce.modelData.collegata ? wifi.scollega() : wifi.collega(voce.modelData, "")
                    }
                }

                // la password, solo per la rete che la chiede
                Rectangle {
                    visible: wifi.chiede === voce.modelData.nome
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 17
                    color: Tema.cartaForte
                    border.width: password.activeFocus ? 1 : 0
                    border.color: Tema.accento
                    onVisibleChanged: if (visible) password.forceActiveFocus()
                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        font.family: Tema.carattere; font.pixelSize: 13
                        color: Tema.testo
                        clip: true
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text === ""
                            text: "Password e Invio"
                            font: password.font
                            color: Tema.testo3
                        }
                        Keys.onReturnPressed: { wifi.collega(voce.modelData, password.text); password.text = ""; }
                        Keys.onEscapePressed: { wifi.chiede = ""; wifi.messaggio = ""; }
                    }
                }
            }
        }
    }
}
