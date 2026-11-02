pragma Singleton
// Le scelte fatte da Impostazioni (creato da vetro-arch.sh). Sono salvate in
// ~/.config/vetro/impostazioni.json; quelle che riguardano le finestre anche in
// ~/.config/hypr/vetro-impostazioni.conf (lo legge Hyprland).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Schermi.js" as Schermi

Singleton {
    id: opzioni

    readonly property string casa: Quickshell.env("HOME") || "/tmp"
    readonly property string cartella: casa + "/.config/vetro"
    readonly property string fileHyprland: casa + "/.config/hypr/vetro-impostazioni.conf"

    property alias tema: dati.tema
    property alias opacita: dati.opacita
    property alias animazioni: dati.animazioni
    property alias sfocatura: dati.sfocatura
    property alias affianca: dati.affianca
    property alias spazi: dati.spazi
    property alias angoli: dati.angoli
    property alias dock: dati.dock
    property alias secondi: dati.secondi
    property alias meteo: dati.meteo
    property alias citta: dati.citta
    property alias nonDisturbare: dati.nonDisturbare
    property alias bloccoMinuti: dati.bloccoMinuti
    property alias statisticheBlocco: dati.statisticheBlocco
    property alias preferite: dati.preferite
    property alias nomeMostrato: dati.nomeMostrato
    property bool caricato: false

    FileView {
        id: file
        path: opzioni.cartella + "/impostazioni.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { opzioni.caricato = true; opzioni.applicaFinestre(); }
        onLoadFailed: {
            // prima volta: il file non c'e' ancora, lo crea con i valori normali
            opzioni.caricato = true;
            writeAdapter();
            opzioni.applicaFinestre();
        }
        onAdapterUpdated: {
            writeAdapter();
            opzioni.applicaFinestre();
        }

        JsonAdapter {
            id: dati
            property string tema: "adwaita"
            property real opacita: 0.58
            property bool animazioni: true
            property bool sfocatura: true
            property bool affianca: false
            property int spazi: 12
            property int angoli: 14
            property bool dock: true
            property bool secondi: false
            property bool meteo: true
            property string citta: ""
            property bool nonDisturbare: false
            property int bloccoMinuti: 10
            property bool statisticheBlocco: true
            property string nomeMostrato: ""
            property list<string> preferite: [
                "tor-browser", "thunar", "thunderbird", "org.mozilla.Thunderbird",
                "libreoffice-writer", "org.xfce.mousepad", "foot"
            ]
        }
    }

    // --- gli schermi: le scelte di Impostazioni -> Schermo, per ogni schermo
    // (~/.config/vetro/schermi.json); le regole di Hyprland le fa Schermi.js
    property var scelteSchermi: ({})
    property var schermi: []              // da "hyprctl monitors all -j"
    property bool schermoLetto: false
    function leggiSchermi(t) {
        try { scelteSchermi = JSON.parse(t) || {}; } catch (e) { scelteSchermi = {}; }
        schermoLetto = true;
        applicaFinestre();
    }
    FileView {
        id: fileSchermi
        path: opzioni.casa + "/.config/vetro/schermi.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: opzioni.leggiSchermi(text())
        onLoadFailed: opzioni.leggiSchermi("{}")
    }
    Process {
        id: elencoSchermi
        running: true
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { opzioni.schermi = JSON.parse(this.text); } catch (e) {}
                opzioni.applicaFinestre();
            }
        }
    }
    // uno schermo attaccato o staccato: si rileggono gli schermi e si rifanno le regole
    Connections {
        target: Hyprland.monitors
        function onValuesChanged() { elencoSchermi.running = true; }
    }
    // sceltaSchermo("HDMI-A-1", "risoluzione" | "posizione" | "principale" | "scala", valore)
    function sceltaSchermo(nome, campo, valore) {
        const s = JSON.parse(JSON.stringify(scelteSchermi));
        if (campo === "principale" && valore)
            for (const n in s) s[n].principale = false;
        if (!s[nome]) s[nome] = {};
        s[nome][campo] = valore;
        scelteSchermi = s;
        fileSchermi.setText(JSON.stringify(s, null, 2));
        applicaFinestre();
    }

    // il file di adesso, per non far ricaricare Hyprland se non cambia niente
    FileView {
        id: confAttuale
        path: opzioni.fileHyprland
        blockLoading: true
        printErrors: false
    }

    // --- finestre: la parte che legge Hyprland -----------------------------------
    function testoHyprland() {
        let t = "# Creato da Impostazioni (desktop Vetro): non modificarlo a mano,\n";
        t += "# le tue aggiunte vanno in ~/.config/hypr/personale.conf\n";
        t += Schermi.regole(schermi, scelteSchermi);
        t += "animations {\n    enabled = " + (animazioni ? "true" : "false") + "\n}\n";
        t += "decoration {\n    rounding = " + angoli + "\n";
        t += "    blur {\n        enabled = " + (sfocatura ? "true" : "false") + "\n    }\n}\n";
        t += "general {\n    gaps_in = " + Math.round(spazi / 2) + "\n    gaps_out = " + spazi + "\n}\n";
        if (!affianca)
            t += "windowrule {\n    name = vetro-finestre-libere\n    match:class = .*\n    float = yes\n}\n";
        return t;
    }

    property string ultimoHyprland: ""
    function applicaFinestre() {
        if (!caricato || !schermoLetto)
            return;
        const t = testoHyprland();
        if (t === ultimoHyprland)
            return;
        ultimoHyprland = t;
        if (t === confAttuale.text())
            return;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && hyprctl reload >/dev/null",
            "vetro", fileHyprland, t]);
    }

    function nomeUtente() {
        if (nomeMostrato !== "")
            return nomeMostrato;
        const u = Quickshell.env("USER") || "";
        return u.length > 0 ? u.charAt(0).toUpperCase() + u.slice(1) : "";
    }
}
