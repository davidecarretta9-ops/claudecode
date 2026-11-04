pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../utils/HyprImpostazioni.js" as HyprImpostazioni

// oversicaOS: le scelte delle pagine Schermo, Tastiera e Accessibilita' (creato da lfs.sh).
// Sono salvate in ~/.config/oversica/impostazioni.json (e schermi.json per gli schermi);
// quelle per Hyprland finiscono anche in ~/.config/hypr/vetro-impostazioni.lua, scritto da
// HyprImpostazioni.js: se il testo cambia, si riscrive il file e Hyprland lo rilegge.
Singleton {
    id: root

    readonly property string casa: Quickshell.env("HOME") || "/tmp"
    readonly property string cartella: `${Quickshell.env("XDG_CONFIG_HOME") || `${casa}/.config`}`
    readonly property string fileHyprland: `${cartella}/hypr/vetro-impostazioni.lua`

    property alias animazioni: dati.animazioni
    property alias tastiera: dati.tastiera
    property alias velocita: dati.velocita
    property alias naturale: dati.naturale
    property alias tocco: dati.tocco
    property alias luceNotturna: dati.luceNotturna
    property alias affianca: dati.affianca
    property bool caricato

    // gli schermi: le scelte per ogni schermo e quelli che ci sono adesso
    property var scelteSchermi: ({})
    property var schermi: []
    property bool schermiLetti

    // lo chiama il demone di oversicaOS all'avvio, cosi' il file e' sempre giusto
    function avvia(): void {
        elencoSchermi.running = true;
    }

    // sceltaSchermo("HDMI-A-1", "risoluzione" | "posizione" | "principale" | "scala", valore)
    function sceltaSchermo(nome: string, campo: string, valore: var): void {
        const s = JSON.parse(JSON.stringify(scelteSchermi));
        if (campo === "principale" && valore)
            for (const n in s)
                s[n].principale = false;
        if (!s[nome])
            s[nome] = {};
        s[nome][campo] = valore;
        scelteSchermi = s;
        fileSchermi.setText(JSON.stringify(s, null, 2));
        applica();
    }

    function testoHyprland(): string {
        return HyprImpostazioni.impostazioni({
            animazioni: dati.animazioni,
            angoli: dati.angoli,
            sfocatura: dati.sfocatura,
            spazi: dati.spazi,
            affianca: dati.affianca,
            tastiera: dati.tastiera,
            velocita: dati.velocita,
            naturale: dati.naturale,
            tocco: dati.tocco
        }, schermi, scelteSchermi);
    }

    property string ultimo
    function applica(): void {
        if (!caricato || !schermiLetti)
            return;
        const t = testoHyprland();
        if (t === ultimo)
            return;
        ultimo = t;
        if (t === attuale.text())
            return;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && hyprctl reload >/dev/null", "oversica", fileHyprland, t]);
    }

    // la luce notturna (hyprsunset: colori piu' caldi la sera)
    function luce(): void {
        Quickshell.execDetached(["sh", "-c", dati.luceNotturna ? "pgrep -x hyprsunset >/dev/null || exec hyprsunset -t 4000" : "pkill -x hyprsunset; true"]);
    }

    FileView {
        id: file

        path: `${root.cartella}/oversica/impostazioni.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.caricato = true;
            root.applica();
            root.luce();
        }
        onLoadFailed: {
            // la prima volta il file non c'e': si crea con i valori di partenza
            root.caricato = true;
            writeAdapter();
            root.applica();
        }
        onAdapterUpdated: {
            writeAdapter();
            root.applica();
            root.luce();
        }

        JsonAdapter {
            id: dati

            property bool animazioni: true
            property int angoli: 18
            property bool sfocatura: true
            property int spazi: 12
            property bool affianca: false
            property string tastiera: "it"
            property real velocita: 0
            property bool naturale: true
            property bool tocco: true
            property bool luceNotturna: false
        }
    }

    FileView {
        id: fileSchermi

        path: `${root.cartella}/oversica/schermi.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.scelteSchermi = JSON.parse(text()) || {};
            } catch (e) {
                root.scelteSchermi = {};
            }
            root.applica();
        }
    }

    // il file di adesso, per non far rileggere Hyprland se non cambia niente
    FileView {
        id: attuale

        path: root.fileHyprland
        blockLoading: true
        printErrors: false
    }

    Process {
        id: elencoSchermi

        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.schermi = JSON.parse(text);
                } catch (e) {
                    root.schermi = [];
                }
                root.schermiLetti = true;
                root.applica();
            }
        }
    }

    // uno schermo attaccato o staccato: si rileggono gli schermi e si rifanno le regole
    Connections {
        function onValuesChanged(): void {
            elencoSchermi.running = true;
        }

        target: Hyprland.monitors
    }
}
