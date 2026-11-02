pragma Singleton
// Le app installate e la ricerca (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell

Singleton {
    id: applicazioni

    readonly property var tutte: DesktopEntries.applications.values

    // l'immagine dell'icona: un nome del tema, oppure un file (es. Firefox, Tor Browser)
    function icona(nome) {
        if (!nome || nome === "") return Quickshell.iconPath("application-x-executable");
        if (nome.startsWith("/")) return "file://" + nome;
        return Quickshell.iconPath(nome, "application-x-executable");
    }

    function ordinate() {
        return tutte.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    function preferite(quante) {
        const r = [];
        const lista = Opzioni.preferite;
        for (let i = 0; i < lista.length && r.length < quante; i++) {
            const e = DesktopEntries.byId(lista[i]);
            if (e && r.indexOf(e) < 0) r.push(e);
        }
        // tor-browser e firefox: basta il primo che c'e'
        const browser = r.filter(e => e.id === "tor-browser" || e.id === "firefox");
        if (browser.length > 1) r.splice(r.indexOf(browser[1]), 1);
        const altre = ordinate();
        for (let i = 0; i < altre.length && r.length < quante; i++)
            if (r.indexOf(altre[i]) < 0) r.push(altre[i]);
        return r;
    }

    function cerca(testo, quante) {
        const t = (testo || "").trim().toLowerCase();
        if (t === "") return preferite(quante);
        const prima = [], dopo = [];
        for (let i = 0; i < tutte.length; i++) {
            const e = tutte[i];
            const nome = (e.name || "").toLowerCase();
            const altro = ((e.genericName || "") + " " + (e.comment || "") + " "
                           + (e.keywords || []).join(" ") + " " + (e.id || "")).toLowerCase();
            if (nome.startsWith(t) || nome.indexOf(" " + t) >= 0) prima.push(e);
            else if (nome.indexOf(t) >= 0 || altro.indexOf(t) >= 0) dopo.push(e);
        }
        prima.sort((a, b) => a.name.localeCompare(b.name));
        dopo.sort((a, b) => a.name.localeCompare(b.name));
        return prima.concat(dopo).slice(0, quante);
    }
}
