pragma Singleton
// Processore, memoria, disco, rete, da quanto e' acceso (creato da lfs.sh, Fase 10).
// Legge /proc ogni 2 secondi con un solo comando.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sis

    property real cpu: 0                 // 0..1
    property real memoria: 0             // 0..1
    property real memoriaUsata: 0        // GB
    property real memoriaTotale: 0       // GB
    property real disco: 0               // 0..1
    property real discoUsato: 0          // GB
    property real discoTotale: 0         // GB
    property real scarica: 0             // byte al secondo
    property real carica: 0
    property real totaleScaricato: 0     // byte da quando e' acceso
    property real totaleCaricato: 0
    property real temperatura: -1        // gradi, -1 = non si sa
    property real gpu: -1                // 0..1, -1 = non si sa
    property real acceso: 0              // secondi
    property var storiaCpu: []
    property var storiaScarica: []
    property var storiaCarica: []
    property bool fantasma: false
    property string nomeComputer: ""
    property string kernel: ""
    property string processore: ""
    readonly property string utente: Quickshell.env("USER") || "utente"

    property var _cpuPrima: null
    property var _retePrima: null
    property real _tempoPrima: 0
    readonly property int punti: 40

    function aggiungi(lista, v) {
        const l = lista.slice();
        l.push(v);
        while (l.length < punti) l.unshift(0);
        while (l.length > punti) l.shift();
        return l;
    }

    function testoAcceso() {
        const s = Math.floor(acceso);
        const g = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
        if (g > 0) return g + "g " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + " min";
    }

    function velocita(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
        if (b >= 1024) return Math.round(b / 1024) + " KB/s";
        return Math.round(b) + " B/s";
    }

    function grandezza(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576) return Math.round(b / 1048576) + " MB";
        return Math.round(b / 1024) + " KB";
    }

    function analizza(testo) {
        let parte = "";
        let rxTot = 0, txTot = 0;
        const righe = testo.split("\n");
        for (let i = 0; i < righe.length; i++) {
            const r = righe[i].trim();
            if (r.startsWith("#")) { parte = r; continue; }
            if (r === "") continue;
            const c = r.split(/\s+/);
            if (parte === "#STAT" && c[0] === "cpu") {
                const n = c.slice(1).map(Number);
                const inattivo = n[3] + (n[4] || 0);
                const totale = n.reduce((a, b) => a + b, 0);
                if (_cpuPrima !== null) {
                    const dt = totale - _cpuPrima.totale;
                    const di = inattivo - _cpuPrima.inattivo;
                    if (dt > 0) cpu = Math.max(0, Math.min(1, 1 - di / dt));
                }
                _cpuPrima = { totale: totale, inattivo: inattivo };
            } else if (parte === "#MEM") {
                if (c[0] === "MemTotal:") memoriaTotale = Number(c[1]) / 1048576;
                if (c[0] === "MemAvailable:" && memoriaTotale > 0) {
                    memoriaUsata = memoriaTotale - Number(c[1]) / 1048576;
                    memoria = memoriaUsata / memoriaTotale;
                }
            } else if (parte === "#NET") {
                const nome = c[0].replace(":", "");
                if (nome === "lo" || c.length < 10) continue;
                rxTot += Number(c[1]);
                txTot += Number(c[9]);
            } else if (parte === "#UP") {
                acceso = Number(c[0]);
            } else if (parte === "#DISK" && c.length >= 4) {
                discoTotale = Number(c[1]) / 1048576;
                discoUsato = Number(c[2]) / 1048576;
                disco = discoTotale > 0 ? discoUsato / discoTotale : 0;
            } else if (parte === "#TEMP") {
                temperatura = Number(c[0]) / 1000;
            } else if (parte === "#GPU") {
                gpu = Number(c[0]) / 100;
            } else if (parte === "#FANTASMA") {
                fantasma = c[0] === "si";
            }
        }
        const ora = Date.now() / 1000;
        if (_retePrima !== null && ora > _tempoPrima) {
            const dt = ora - _tempoPrima;
            scarica = Math.max(0, (rxTot - _retePrima.rx) / dt);
            carica = Math.max(0, (txTot - _retePrima.tx) / dt);
        }
        _retePrima = { rx: rxTot, tx: txTot };
        _tempoPrima = ora;
        totaleScaricato = rxTot;
        totaleCaricato = txTot;
        storiaCpu = aggiungi(storiaCpu, cpu);
        storiaScarica = aggiungi(storiaScarica, scarica);
        storiaCarica = aggiungi(storiaCarica, carica);
    }

    Process {
        id: lettore
        command: ["sh", "-c",
            "echo '#STAT'; head -n1 /proc/stat; " +
            "echo '#MEM'; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; " +
            "echo '#NET'; tail -n +3 /proc/net/dev; " +
            "echo '#UP'; cat /proc/uptime; " +
            "echo '#DISK'; df -Pk / | tail -n 1; " +
            "echo '#TEMP'; cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null; " +
            "echo '#GPU'; cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n 1; " +
            "echo '#FANTASMA'; [ -e /etc/fantasma/attivo ] && echo si || echo no"]
        stdout: StdioCollector {
            onStreamFinished: sis.analizza(this.text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!lettore.running) lettore.running = true
    }

    Process {
        id: info
        running: true
        command: ["sh", "-c",
            "cat /etc/hostname 2>/dev/null || uname -n; uname -r; " +
            "sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = this.text.split("\n");
                sis.nomeComputer = (r[0] || "").trim();
                sis.kernel = (r[1] || "").trim();
                sis.processore = (r[2] || "").trim();
            }
        }
    }
}
