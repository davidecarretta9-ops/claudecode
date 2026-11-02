pragma Singleton
// Le scelte fatte da Impostazioni (creato da lfs.sh, Fase 10). Sono salvate in
// ~/.config/vetro/impostazioni.json; quelle che riguardano le finestre anche in
// ~/.config/hypr/vetro-impostazioni.conf (lo legge Hyprland).
import QtQuick
import Quickshell
import Quickshell.Io

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
            property string tema: "ombra"
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
                "tor-browser", "firefox", "thunar", "thunderbird",
                "libreoffice-writer", "org.xfce.mousepad", "foot"
            ]
        }
    }

    // --- lo schermo: risoluzione e grandezza (le sceglie anche Impostazioni -> Schermo,
    // e il programma "schermo" del desktop classico: stesso file ~/.config/schermo.conf)
    property string risoluzione: ""
    property string scala: "1"
    property bool schermoLetto: false
    function leggiSchermo(t) {
        schermoLetto = true;
        const r = /^RISOLUZIONE=(\d+x\d+)/m.exec(t);
        const s = /^SCALA=([0-9.]+)/m.exec(t);
        risoluzione = r ? r[1] : "";
        scala = s ? s[1] : "1";
        applicaFinestre();
    }
    FileView {
        path: opzioni.casa + "/.config/schermo.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: opzioni.leggiSchermo(text())
        onLoadFailed: opzioni.leggiSchermo("")
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
        if (risoluzione !== "")
            t += "monitor = , " + risoluzione + ", auto, " + scala + "\n";
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
