// Il blocco schermo (creato da vetro-arch.sh): orologio grande, saluto e la
// password. Si blocca con Windows+L, dal centro di controllo o da solo dopo i minuti
// scelti in Impostazioni (0 = mai). La password la controlla il sistema (PAM, file
// /etc/pam.d/vetro-blocco), come all'accesso.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

Scope {
    id: blocco

    property bool controllo: false        // sta controllando la password
    property string errore: ""
    property int tentativi: 0
    signal sbagliata()

    property string daDire: ""

    function verifica(password) {
        if (controllo || password === "") return;
        controllo = true;
        errore = "";
        daDire = password;
        if (!pam.start()) {
            controllo = false;
            daDire = "";
            errore = "Non riesco a controllare la password";
            sbagliata();
        }
    }

    PamContext {
        id: pam
        config: "vetro-blocco"
        onPamMessage: {
            if (this.responseRequired) {
                this.respond(blocco.daDire);
                blocco.daDire = "";
            }
        }
        onCompleted: risultato => {
            blocco.controllo = false;
            blocco.daDire = "";
            if (risultato === PamResult.Success) {
                blocco.tentativi = 0;
                Stato.bloccato = false;
            } else {
                blocco.tentativi++;
                blocco.errore = risultato === PamResult.Failed ? "Password sbagliata" : "Non riesco a controllare la password";
                blocco.sbagliata();
            }
        }
    }

    // dopo i minuti scelti senza toccare niente: blocca (e poi spegne lo schermo)
    Process {
        id: inattivita
        property int secondi: Math.max(0, Opzioni.bloccoMinuti) * 60
        running: secondi > 0
        command: ["swayidle", "-w",
                  "timeout", String(secondi), "qs -p /etc/xdg/quickshell/vetro ipc call blocco blocca",
                  "timeout", String(secondi + 60), "hyprctl dispatch dpms off",
                  "resume", "hyprctl dispatch dpms on"]
        onSecondiChanged: { running = false; riavviaInattivita.restart(); }
    }
    Timer {
        id: riavviaInattivita
        interval: 500
        onTriggered: inattivita.running = inattivita.secondi > 0
    }

    WlSessionLock {
        id: serratura
        locked: Stato.bloccato

        WlSessionLockSurface {
            id: superficie
            color: "#0c0c0e"

            SystemClock { id: orologio; precision: SystemClock.Seconds }

            // sfondo sfocato e scurito
            Image {
                id: immagine
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: "file://" + Sfondi.attuale
                sourceSize.width: 1280
                sourceSize.height: 720
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: immagine
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                brightness: -0.12
                saturation: -0.25
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.12) }
                }
            }

            // entrata morbida
            Item {
                id: contenuto
                anchors.fill: parent
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: Tema.lenta * 2; easing.type: Easing.OutCubic } }

                Column {
                    id: colonna
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -30
                    x: Math.max(60, parent.width * 0.14)
                    spacing: 14

                    Avatar {
                        width: 64
                        height: 64
                    }

                    Column {
                        spacing: -34
                        Text {
                            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "HH")
                            font.family: Tema.carattere
                            font.pixelSize: 168
                            font.weight: Font.Black
                            font.letterSpacing: -6
                            color: "#f4f4f6"
                        }
                        Text {
                            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "mm")
                            font.family: Tema.carattere
                            font.pixelSize: 168
                            font.weight: Font.Black
                            font.letterSpacing: -6
                            color: Qt.rgba(1, 1, 1, 0.72)
                        }
                    }

                    Column {
                        spacing: 4
                        Text {
                            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "dddd d MMMM")
                            font.family: Tema.mono
                            font.pixelSize: 15
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }
                        Text {
                            text: Saluto.frase(orologio.date) + (Opzioni.nomeUtente() !== "" ? ", " + Opzioni.nomeUtente() : "")
                            font.family: Tema.mono
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }

                    // la password
                    Item {
                        id: zonaPassword
                        width: 300
                        height: 54
                        property real scossa: 0
                        transform: Translate { x: zonaPassword.scossa }

                        SequentialAnimation {
                            id: scuoti
                            NumberAnimation { target: zonaPassword; property: "scossa"; to: -14; duration: 50 }
                            NumberAnimation { target: zonaPassword; property: "scossa"; to: 12; duration: 70 }
                            NumberAnimation { target: zonaPassword; property: "scossa"; to: -8; duration: 70 }
                            NumberAnimation { target: zonaPassword; property: "scossa"; to: 0; duration: 60 }
                        }
                        Connections {
                            target: blocco
                            function onSbagliata() { scuoti.restart(); password.text = ""; }
                        }

                        TextInput {
                            id: password
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            font.family: Tema.mono
                            font.pixelSize: 18
                            font.letterSpacing: 4
                            color: "#ffffff"
                            focus: true
                            enabled: !blocco.controllo
                            Component.onCompleted: forceActiveFocus()
                            onAccepted: blocco.verifica(text)
                            onTextChanged: if (text !== "") blocco.errore = ""
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: password.text === ""
                                text: blocco.controllo ? "Controllo..." : (blocco.errore !== "" ? blocco.errore : "Scrivi la password")
                                font.family: Tema.mono
                                font.pixelSize: 14
                                font.letterSpacing: 0
                                color: blocco.errore !== "" ? "#ff8a84" : Qt.rgba(1, 1, 1, 0.55)
                            }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            radius: 1
                            color: blocco.errore !== "" ? "#ff5f57" : Qt.rgba(1, 1, 1, password.activeFocus ? 0.85 : 0.4)
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    Row {
                        spacing: 14
                        topPadding: 6
                        TastoBlocco { icona: "power_settings_new"; onCliccato: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "poweroff"]) }
                        TastoBlocco { icona: "restart_alt"; onCliccato: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "reboot"]) }
                        TastoBlocco { icona: "arrow_forward"; onCliccato: blocco.verifica(password.text) }
                    }
                }

                // in basso: notifiche e un po' di numeri
                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: colonna.x
                    anchors.bottomMargin: 48
                    spacing: 4
                    visible: Opzioni.statisticheBlocco
                    Text {
                        text: (Avvisi.quante === 1 ? "1 notifica" : Avvisi.quante + " notifiche")
                        font.family: Tema.mono
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.8)
                    }
                    Text {
                        text: "CPU " + Math.round(Sistema.cpu * 100) + "%  ·  RAM " + Math.round(Sistema.memoria * 100)
                              + "%" + (Sistema.gpu >= 0 ? "  ·  GPU " + Math.round(Sistema.gpu * 100) + "%" : "")
                        font.family: Tema.mono
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.6)
                    }
                }

                // in basso a destra: la musica, se suona
                Rectangle {
                    visible: Musica.attivo !== null && Musica.titolo !== ""
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 40
                    width: 320
                    height: 64
                    radius: 20
                    color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    Row {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        Column {
                            width: parent.width - 90
                            anchors.verticalCenter: parent.verticalCenter
                            Text { width: parent.width; elide: Text.ElideRight; text: Musica.titolo; font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#ffffff" }
                            Text { width: parent.width; elide: Text.ElideRight; text: Musica.artista; font.family: Tema.carattere; font.pixelSize: 11; color: Qt.rgba(1, 1, 1, 0.6) }
                        }
                        TastoBlocco { width: 36; height: 36; icona: Musica.suona ? "pause" : "play_arrow"; anchors.verticalCenter: parent.verticalCenter; onCliccato: Musica.alterna() }
                        TastoBlocco { width: 36; height: 36; icona: "skip_next"; anchors.verticalCenter: parent.verticalCenter; onCliccato: Musica.avanti() }
                    }
                }
            }
        }
    }

    component TastoBlocco: Rectangle {
        id: tasto
        property string icona: ""
        signal cliccato()
        width: 42
        height: 42
        radius: width / 2
        color: areaT.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1)
        Behavior on color { ColorAnimation { duration: 150 } }
        Icona { anchors.centerIn: parent; nome: tasto.icona; dimensione: 20; color: "#ffffff" }
        MouseArea {
            id: areaT
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tasto.cliccato()
        }
    }
}
