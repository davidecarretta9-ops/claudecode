pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Wayland
import "../../utils/Accesso.js" as Accesso

// oversicaOS: il "motore" della schermata di accesso. Ha la stessa forma di Pam.qml
// (quello che usano il campo della password e i messaggi del blocco di Caelestia), ma la
// password la controlla greetd. Se e' giusta: animazione di sblocco, poi parte il desktop.
// Entra il tuo utente (/etc/vetro/utente); col tasto Tab si passa agli altri (fantasma).
Scope {
    id: root

    required property WlSessionLock lock
    readonly property string comando: "/usr/local/bin/avvia-desktop"

    property var utenti: []
    property int scelto: 0
    readonly property string utente: utenti[scelto] ?? ""
    property string tuo
    property string bloccato    // PAM: "The account is locked..." (troppi tentativi)
    property string daDire
    property bool pronto        // password giusta: si parte appena il blocco e' aperto

    readonly property string lockMessage: bloccato || Accesso.avviso(utenti, scelto)
    property int state
    property string buffer

    readonly property QtObject passwd: QtObject {
        property bool active
        property string message

        function start(): void {
            root.entra();
        }

        function abort(): void {
            if (active)
                Greetd.cancelSession();
            active = false;
        }
    }
    // niente impronta digitale e niente volto nella schermata di accesso
    readonly property QtObject fprint: Spento {}
    readonly property QtObject howdy: Spento {}

    signal flashMsg

    function handleKey(event: KeyEvent): void {
        if (passwd.active || pronto)
            return;

        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (utenti.length > 1) {
                scelto = (scelto + (event.key === Qt.Key_Tab ? 1 : utenti.length - 1)) % utenti.length;
                bloccato = "";
                state = Pam.None;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            passwd.start();
        } else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_U) && (event.modifiers & Qt.ControlModifier)) {
            buffer = "";
        } else if (event.key === Qt.Key_Backspace) {
            buffer = buffer.slice(0, -1);
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            // tutto tranne i caratteri di controllo
            buffer += event.text;
        }
    }

    function entra(): void {
        if (passwd.active || pronto || !utente)
            return;
        passwd.active = true;
        passwd.message = "";
        daDire = buffer;
        Greetd.createSession(utente);
    }

    function fallito(stato: int, messaggio: string): void {
        passwd.active = false;
        passwd.message = messaggio;
        daDire = "";
        buffer = "";
        state = stato;
        flashMsg();
        statoReset.restart();
    }

    function leggiUtenti(): void {
        utenti = Accesso.utenti(passwdFile.text(), tuo);
        scelto = 0;
    }

    FileView {
        path: "/etc/vetro/utente"
        onLoaded: {
            root.tuo = text();
            root.leggiUtenti();
        }
        onLoadFailed: root.leggiUtenti()
    }

    FileView {
        id: passwdFile

        path: "/etc/passwd"
        onLoaded: root.leggiUtenti()
    }

    Connections {
        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired) {
                Greetd.respond(root.daDire);
                root.daDire = "";
                root.buffer = "";
            } else if (message.startsWith("The account is locked")) {
                root.bloccato = message;
            } else if (error) {
                root.passwd.message = message;
            }
        }

        function onAuthFailure(message: string): void {
            root.fallito(Pam.Failed, message);
        }

        function onReadyToLaunch(): void {
            root.passwd.active = false;
            root.pronto = true;
            root.lock.unlock();
        }

        function onError(error: string): void {
            Greetd.cancelSession();
            root.fallito(Pam.Error, error);
        }

        target: Greetd
    }

    // l'animazione di sblocco di Caelestia finisce aprendo il blocco: solo allora si parte
    // (greetd vuole che la schermata si chiuda subito dopo launch)
    Connections {
        function onLockedChanged(): void {
            if (!root.lock.locked && root.pronto)
                Greetd.launch([root.comando]);
        }

        target: root.lock
    }

    Timer {
        id: statoReset

        interval: 4000
        onTriggered: root.state = Pam.None
    }

    component Spento: QtObject {
        readonly property bool available: false
        readonly property bool active: false
        readonly property bool canAttempt: false
        readonly property int state: Pam.None
        readonly property int tries: 0
        readonly property string message: ""

        function start(): void {
        }

        function abort(): void {
        }
    }
}
