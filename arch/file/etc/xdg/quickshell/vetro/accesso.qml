//@ pragma AppId org.quickshell.vetro.accesso
// La schermata di accesso (creato da vetro-arch.sh). La apre greetd all'accensione,
// dentro un Hyprland tutto suo (/etc/vetro/accesso-hyprland.lua), come utente
// "greeter". Scegli l'utente, scrivi la password e premi Invio: greetd la controlla
// (PAM) e solo allora parte il desktop (/usr/local/bin/avvia-desktop).
// La grafica e' in AccessoVista.qml (con colori scritti dentro: niente Tema/Opzioni,
// che leggono le scelte dell'utente e cambierebbero l'Hyprland di questa schermata).
import QtQuick
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

    readonly property string sfondo: "file:///usr/share/backgrounds/vetro-nuvole.jpg"

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

    // uno sfondo per ogni schermo; nome e password solo sul primo
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
                color: "#0b1f3a"
                WlrLayershell.namespace: "vetro-accesso"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: primo ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                Image {
                    visible: !finestra.primo
                    anchors.fill: parent
                    source: accesso.sfondo
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                AccessoVista {
                    id: vista
                    visible: finestra.primo
                    anchors.fill: parent
                    sfondo: accesso.sfondo
                    utenti: accesso.utenti
                    scelto: accesso.scelto
                    controllo: accesso.controllo
                    errore: accesso.errore
                    Component.onCompleted: if (finestra.primo) vista.metti_a_fuoco()
                    onEntra: p => accesso.entra(p)
                    onCambiaUtente: {
                        accesso.scelto = (accesso.scelto + 1) % Math.max(1, accesso.utenti.length);
                        accesso.errore = "";
                    }
                    onSpegni: Quickshell.execDetached(["systemctl", "poweroff"])
                    onRiavvia: Quickshell.execDetached(["systemctl", "reboot"])
                }
                Connections {
                    target: accesso
                    function onSbagliata() { if (finestra.primo) vista.sbagliata(); }
                }
            }
        }
    }
}
