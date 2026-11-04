// Il blocco schermo (creato da vetro-arch.sh): orologio grande in alto a sinistra e la
// pillola della password (la grafica e' in BloccoVista.qml). Si blocca con Windows+L, dal centro di controllo o da solo dopo i minuti
// scelti in Impostazioni (0 = mai). La password la controlla il sistema (PAM, file
// /etc/pam.d/vetro-blocco), come all'accesso.
import QtQuick
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
                  "timeout", String(secondi + 60), "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'",
                  "resume", "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'"]
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
            color: "#0b3a6e"

            SystemClock { id: orologio; precision: SystemClock.Minutes }

            BloccoVista {
                id: vista
                anchors.fill: parent
                ora: orologio.date
                nome: Opzioni.nomeUtente() !== "" ? Opzioni.nomeUtente() : Sistema.utente
                sfondo: "file:///usr/share/backgrounds/vetro-cielo.jpg"
                controllo: blocco.controllo
                errore: blocco.errore
                Component.onCompleted: vista.metti_a_fuoco()
                onInvio: p => blocco.verifica(p)
                onSpegni: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "poweroff"])
                onRiavvia: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "reboot"])
            }
            Connections {
                target: blocco
                function onSbagliata() { vista.sbagliata(); }
            }
        }
    }
}
