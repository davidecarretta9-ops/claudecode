pragma Singleton
// Lo sfondo del desktop (creato da lfs.sh, Fase 10). La scelta resta in
// ~/.config/sfondo.conf, come per il desktop classico: e' sfondo-desktop a dire
// quale immagine usare (in modalita' fantasma quella scura).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sfondi

    property string attuale: "/usr/share/backgrounds/sfondo-desktop.png"
    property var elenco: []
    readonly property string fileScelta: (Quickshell.env("HOME") || "/tmp") + "/.config/sfondo.conf"

    function aggiorna() {
        if (!percorso.running) percorso.running = true;
        if (!lista.running) lista.running = true;
    }

    function scegli(file) {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf 'SFONDO=%s\\n' \"$2\" > \"$1\"",
            "vetro", fileScelta, file]);
        attuale = file;
        ritardo.restart();
    }

    Process {
        id: percorso
        command: ["/usr/local/bin/sfondo-desktop", "--percorso"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p !== "") sfondi.attuale = p;
            }
        }
    }

    Process {
        id: lista
        command: ["sh", "-c",
            "for f in /usr/share/backgrounds/*.png /usr/share/backgrounds/*.jpg " +
            "\"$HOME\"/.local/share/sfondi/*.png \"$HOME\"/.local/share/sfondi/*.jpg; do " +
            "[ -f \"$f\" ] || continue; case \"$f\" in */sfondo-fantasma.png|*/sfondo-desktop.png) continue ;; esac; " +
            "echo \"$f\"; done"]
        stdout: StdioCollector {
            onStreamFinished: sfondi.elenco = this.text.split("\n").filter(r => r.trim() !== "")
        }
    }

    // la scelta puo' cambiare anche da fuori (Impostazioni classiche, modalita' fantasma)
    FileView {
        path: sfondi.fileScelta
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); ritardo.restart(); }
    }

    Timer {
        id: ritardo
        interval: 300
        onTriggered: sfondi.aggiorna()
    }

    Component.onCompleted: aggiorna()
}
