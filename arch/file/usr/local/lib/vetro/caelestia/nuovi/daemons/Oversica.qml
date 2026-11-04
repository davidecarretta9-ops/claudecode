// oversicaOS dentro Caelestia (creato da lfs.sh): risponde "ok" quando la shell e'
// caricata e viva. Lo usa avvia-pannelli per capire se i pannelli si sono bloccati:
//   qs -c caelestia ipc call oversica ping
// All'avvio carica anche le scelte di Schermo, Tastiera e Accessibilita'
// (ImpostazioniOversica), cosi' il file per Hyprland e' sempre aggiornato.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Scope {
    Component.onCompleted: ImpostazioniOversica.avvia()

    IpcHandler {
        target: "oversica"

        function ping(): string {
            return "ok";
        }
    }
}
