//@ pragma AppId org.quickshell.vetro
//@ pragma IconTheme AdwaitaLegacy
// Desktop "Vetro" (creato da vetro-arch.sh): il punto di partenza di Quickshell.
// Ogni pezzo e' in un file a parte, qui accanto. Comandi da terminale:
//   qs -p /etc/xdg/quickshell/vetro ipc call pannelli apri pannello|cruscotto|avvio|impostazioni
//   qs -p /etc/xdg/quickshell/vetro ipc call blocco blocca
//   qs -p /etc/xdg/quickshell/vetro ipc call sfondo aggiorna
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: radice

    // su ogni schermo: sfondo e barra unica in basso
    Variants {
        model: Quickshell.screens
        delegate: Component { Sfondo {} }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component { Barra {} }
    }

    Pannello {}
    MusicaRiquadro {}
    Cruscotto {}
    Avvio {}
    Notifiche {}
    Osd {}
    Blocco {}

    LazyLoader {
        active: Stato.impostazioni
        FinestraImpostazioni {}
    }

    // --- i tasti (li manda Hyprland: vedi "global" in hyprland.conf) -------------------
    GlobalShortcut { name: "avvio"; description: "Cerca le app"; onPressed: Stato.alterna("avvio") }
    GlobalShortcut { name: "pannello"; description: "Centro di controllo"; onPressed: Stato.alterna("pannello") }
    GlobalShortcut { name: "cruscotto"; description: "Cruscotto"; onPressed: Stato.alterna("cruscotto") }
    GlobalShortcut { name: "notifiche"; description: "Notifiche"; onPressed: Stato.alterna("pannello") }
    GlobalShortcut { name: "impostazioni"; description: "Impostazioni"; onPressed: Stato.apriImpostazioni("") }
    GlobalShortcut { name: "blocca"; description: "Blocca lo schermo"; onPressed: Stato.blocca() }
    GlobalShortcut { name: "riduci"; description: "Riduci la finestra"; onPressed: Finestre.riduciAttiva() }
    GlobalShortcut { name: "musica-play"; description: "Play/pausa"; onPressed: Musica.alterna() }
    GlobalShortcut { name: "musica-avanti"; description: "Brano dopo"; onPressed: Musica.avanti() }
    GlobalShortcut { name: "musica-indietro"; description: "Brano prima"; onPressed: Musica.indietro() }

    // --- comandi da fuori (blocca-schermo, sfondo-desktop, il menu delle app) ----------
    // risponde "ok" solo se tutti i pannelli si sono caricati (lo usa avvia-pannelli)
    IpcHandler {
        target: "vetro"
        function ping(): string { return "ok"; }
    }
    IpcHandler {
        target: "blocco"
        function blocca(): void { Stato.blocca(); }
    }
    IpcHandler {
        target: "sfondo"
        function aggiorna(): void { Sfondi.aggiorna(); }
    }
    IpcHandler {
        target: "pannelli"
        function apri(nome: string): void {
            if (nome === "impostazioni") Stato.apriImpostazioni("");
            else if (nome === "cruscotto") Stato.apriCruscotto(0);
            else Stato.alterna(nome);
        }
        function chiudi(): void { Stato.chiudiTutto(); }
    }

    // i servizi partono subito (notifiche, finestre ridotte, meteo)
    Component.onCompleted: {
        Avvisi.quante;
        Finestre.nascoste;
        Meteo.pronto;
    }
}
