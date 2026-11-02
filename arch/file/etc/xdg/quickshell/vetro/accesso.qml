//@ pragma AppId org.quickshell.vetro.accesso
// La schermata di accesso (creato da vetro-arch.sh). La apre greetd all'accensione,
// dentro un Hyprland tutto suo (/etc/vetro/accesso-hyprland.conf), come utente
// "greeter". Scegli l'utente, scrivi la password e premi Invio: greetd la controlla
// (PAM) e solo allora parte il desktop (/usr/local/bin/avvia-desktop).
// Colori e caratteri sono scritti qui: niente Tema/Opzioni, che leggono le scelte
// dell'utente e cambierebbero l'Hyprland di questa schermata.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Wayland

ShellRoot {
    id: accesso

    property var utenti: []
    property int scelto: 0
    property bool controllo: false
    property string errore: ""
    property string daDire: ""
    signal sbagliata()

    readonly property string carattere: "Adwaita Sans"
    readonly property color accento: "#3584e4"

    // gli utenti veri: UID da 1000 a 59999 e una shell vera (il tuo e "fantasma")
    function leggiUtenti(testo) {
        const l = [];
        for (const riga of testo.split("\n")) {
            const c = riga.split(":");
            if (c.length < 7) continue;
            const uid = Number(c[2]);
            if (uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(c[6]))
                l.push(c[0]);
        }
        utenti = l;
    }
    FileView {
        path: "/etc/passwd"
        onLoaded: accesso.leggiUtenti(text())
    }

    function entra(password) {
        if (controllo || password === "" || utenti.length === 0) return;
        controllo = true;
        errore = "";
        daDire = password;
        Greetd.createSession(utenti[scelto]);
    }

    Connections {
        target: Greetd
        function onAuthMessage(messaggio, eErrore, rispostaServe, mostra) {
            if (rispostaServe) {
                Greetd.respond(accesso.daDire);
                accesso.daDire = "";
            } else if (eErrore) {
                accesso.errore = messaggio;
            }
        }
        function onAuthFailure(messaggio) {
            accesso.controllo = false;
            accesso.daDire = "";
            accesso.errore = "Password sbagliata";
            accesso.sbagliata();
        }
        function onReadyToLaunch() {
            Greetd.launch(["/usr/local/bin/avvia-desktop"]);
        }
        function onError(e) {
            accesso.controllo = false;
            accesso.daDire = "";
            accesso.errore = "Errore: " + e;
            Greetd.cancelSession();
        }
    }

    // uno sfondo per ogni schermo; il riquadro della password solo sul primo
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: finestra
                required property var modelData
                readonly property bool primo: modelData === Quickshell.screens[0]
                screen: modelData
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "#0c0c0e"
                WlrLayershell.namespace: "vetro-accesso"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: primo ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                SystemClock { id: orologio; precision: SystemClock.Seconds }

                Image {
                    id: immagine
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: "file:///usr/share/backgrounds/vetro-nuvole.jpg"
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
                    brightness: -0.15
                }

                Column {
                    visible: finestra.primo
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(60, parent.width * 0.14)
                    spacing: 14

                    Text {
                        text: orologio.date.toLocaleString(Qt.locale("it_IT"), "HH:mm")
                        font.family: accesso.carattere; font.pixelSize: 140; font.weight: Font.Black
                        color: "#f4f4f6"
                    }
                    Text {
                        text: orologio.date.toLocaleString(Qt.locale("it_IT"), "dddd d MMMM")
                        font.family: accesso.carattere; font.pixelSize: 18
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }

                    // gli utenti: clic o Tab per cambiare
                    Row {
                        spacing: 8
                        topPadding: 12
                        Repeater {
                            model: accesso.utenti
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: nomeUtente.implicitWidth + 32
                                height: 38
                                radius: 19
                                color: index === accesso.scelto ? accesso.accento : Qt.rgba(1, 1, 1, 0.12)
                                Text {
                                    id: nomeUtente
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: accesso.carattere; font.pixelSize: 15; font.weight: Font.DemiBold
                                    color: "#ffffff"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { accesso.scelto = index; password.forceActiveFocus(); }
                                }
                            }
                        }
                    }

                    // la password
                    Item {
                        id: zona
                        width: 320
                        height: 54
                        property real scossa: 0
                        transform: Translate { x: zona.scossa }
                        SequentialAnimation {
                            id: scuoti
                            NumberAnimation { target: zona; property: "scossa"; to: -14; duration: 50 }
                            NumberAnimation { target: zona; property: "scossa"; to: 12; duration: 70 }
                            NumberAnimation { target: zona; property: "scossa"; to: -8; duration: 70 }
                            NumberAnimation { target: zona; property: "scossa"; to: 0; duration: 60 }
                        }
                        Connections {
                            target: accesso
                            function onSbagliata() { scuoti.restart(); password.text = ""; }
                        }
                        TextInput {
                            id: password
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            font.family: accesso.carattere; font.pixelSize: 18; font.letterSpacing: 4
                            color: "#ffffff"
                            focus: finestra.primo
                            enabled: !accesso.controllo
                            Component.onCompleted: if (finestra.primo) forceActiveFocus()
                            onAccepted: accesso.entra(text)
                            onTextChanged: if (text !== "") accesso.errore = ""
                            Keys.onTabPressed: accesso.scelto = (accesso.scelto + 1) % Math.max(1, accesso.utenti.length)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: password.text === ""
                                text: accesso.controllo ? "Controllo..."
                                      : (accesso.errore !== "" ? accesso.errore : "Scrivi la password e premi Invio")
                                font.family: accesso.carattere; font.pixelSize: 14; font.letterSpacing: 0
                                color: accesso.errore !== "" ? "#ff8a84" : Qt.rgba(1, 1, 1, 0.55)
                            }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            radius: 1
                            color: accesso.errore !== "" ? "#ff5f57" : Qt.rgba(1, 1, 1, password.activeFocus ? 0.85 : 0.4)
                        }
                    }

                    // spegni e riavvia
                    Row {
                        spacing: 14
                        topPadding: 6
                        Repeater {
                            model: [["⏻", "poweroff"], ["↻", "reboot"]]
                            delegate: Rectangle {
                                required property var modelData
                                width: 42
                                height: 42
                                radius: 21
                                color: areaT.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData[0]
                                    font.pixelSize: 20
                                    color: "#ffffff"
                                }
                                MouseArea {
                                    id: areaT
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["systemctl", modelData[1]])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
