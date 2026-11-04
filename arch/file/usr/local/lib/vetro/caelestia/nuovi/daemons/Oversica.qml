// oversicaOS dentro Caelestia (creato da lfs.sh): risponde "ok" quando la shell e'
// caricata e viva. Lo usa avvia-pannelli per capire se i pannelli si sono bloccati:
//   qs -c caelestia ipc call oversica ping
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    IpcHandler {
        target: "oversica"

        function ping(): string {
            return "ok";
        }
    }
}
