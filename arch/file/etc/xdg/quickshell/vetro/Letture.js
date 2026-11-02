.pragma library
// Letture per la barra (creato da vetro-arch.sh): batteria e rete. Le usa Sistema.qml
// sul testo che il suo comando legge ogni 2 secondi.

// batteria(testo): righe "CAPACITA' STATO" (da /sys/class/power_supply/BAT*)
//   -> { livello: 0..100 (-1 se non c'e' batteria), carica: true se attaccata }
function batteria(testo) {
    for (const riga of (testo || "").split("\n")) {
        const c = riga.trim().split(/\s+/);
        if (c.length < 2 || !/^\d+$/.test(c[0])) continue;
        return { livello: Math.min(100, Number(c[0])), carica: c[1] === "Charging" || c[1] === "Full" };
    }
    return { livello: -1, carica: false };
}

// rete(testo): righe "NOME wireless|cavo STATO" (da /sys/class/net) e le righe di
// /proc/net/wireless ("NOME: 0000 QUALITA. ...", qualita' da 0 a 70)
//   -> { tipo: "wifi" | "cavo" | "nessuna", segnale: 0..4 (solo per il Wi-Fi) }
function rete(testo) {
    let wifi = null, cavo = false;
    const qualita = {};
    for (const riga of (testo || "").split("\n")) {
        const c = riga.trim().split(/\s+/);
        if (c.length >= 3 && c[0].endsWith(":")) {
            qualita[c[0].slice(0, -1)] = parseFloat(c[2]);
        } else if (c.length >= 3 && c[2] === "up") {
            if (c[1] === "wireless" && wifi === null) wifi = c[0];
            if (c[1] === "cavo") cavo = true;
        }
    }
    if (wifi !== null) {
        const q = qualita[wifi];
        const segnale = isNaN(q) || q === undefined ? 3 : Math.max(1, Math.min(4, Math.ceil(q / 70 * 4)));
        return { tipo: "wifi", segnale: segnale };
    }
    return { tipo: cavo ? "cavo" : "nessuna", segnale: 0 };
}
