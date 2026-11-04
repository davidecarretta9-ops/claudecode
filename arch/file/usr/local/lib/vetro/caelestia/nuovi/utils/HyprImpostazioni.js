.pragma library
// Quello che i pannelli scrivono per Hyprland 0.57, che parla solo Lua (creato da lfs.sh).
//  - i comandi per Hyprland.dispatch(...): riduci, sposta, fuoco, inCima. Se l'indirizzo
//    della finestra e' strano tornano "" (e non si manda niente)
//  - schermi(...): le regole per piu' schermi
//  - impostazioni(...): tutto ~/.config/hypr/vetro-impostazioni.lua (lo scrive Opzioni.qml)

// un testo tra virgolette, scritto come lo legge Lua
function testo(s) {
    return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")
        .replace(/[\x00-\x1f\x7f]/g, "") + '"';
}

// "0x55aa01" o "55AA01" -> "address:0x55aa01"; qualsiasi altra cosa -> ""
function finestra(indirizzo) {
    const a = String(indirizzo === undefined || indirizzo === null ? "" : indirizzo)
        .replace(/^0x/i, "").toLowerCase();
    return /^[0-9a-f]+$/.test(a) ? "address:0x" + a : "";
}

// la finestra va nella scrivania nascosta delle finestre ridotte (senza seguirla)
function riduci(indirizzo) {
    const f = finestra(indirizzo);
    return f ? 'hl.dsp.window.move({ workspace = "special:ridotte", follow = false, window = '
               + testo(f) + " })" : "";
}

// la finestra torna nella scrivania numero "numero"
function sposta(indirizzo, numero) {
    const f = finestra(indirizzo);
    const n = Math.max(1, Math.round(Number(numero)) || 1);
    return f ? "hl.dsp.window.move({ workspace = " + n + ", window = " + testo(f) + " })" : "";
}

function fuoco(indirizzo) {
    const f = finestra(indirizzo);
    return f ? "hl.dsp.focus({ window = " + testo(f) + " })" : "";
}

function inCima(indirizzo) {
    const f = finestra(indirizzo);
    return f ? 'hl.dsp.window.alter_zorder({ mode = "top", window = ' + testo(f) + " })" : "";
}

// --- piu' schermi ---------------------------------------------------------------------
//   elenco: da "hyprctl monitors all -j" (name, width, height)
//   scelte: per nome { risoluzione: "1920x1080", posizione: "destra" | "sinistra" |
//           "sopra" | "duplica", principale: true/false, scala: 1 }
// Una riga per ogni schermo che c'e' adesso; senza scelte salvate niente righe (restano
// la risoluzione migliore e la posizione automatica).
function misura(t) {
    const m = /^(\d+)x(\d+)$/.exec(t || "");
    return m ? { l: Number(m[1]), a: Number(m[2]) } : null;
}

function regolaSchermo(nome, modo, posizione, scala, copia) {
    return "hl.monitor({ output = " + testo(nome) + ", mode = " + testo(modo)
        + ", position = " + testo(posizione) + ", scale = " + testo(scala)
        + (copia ? ", mirror = " + testo(copia) : "") + " })";
}

function schermi(elenco, scelte) {
    scelte = scelte || {};
    const presenti = (elenco || []).filter(s => s && s.name);
    if (!presenti.some(s => scelte[s.name]))
        return "";
    const principale = presenti.find(s => scelte[s.name] && scelte[s.name].principale) || presenti[0];
    const sp = scelte[principale.name] || {};
    const resP = sp.risoluzione || (principale.width + "x" + principale.height);
    const scalaP = Number(sp.scala) || 1;
    const mP = misura(resP) || { l: principale.width, a: principale.height };
    const righe = [regolaSchermo(principale.name, resP, "0x0", scalaP)];
    for (const s of presenti) {
        if (s.name === principale.name)
            continue;
        const c = scelte[s.name];
        if (!c) {
            righe.push(regolaSchermo(s.name, "preferred", "auto", 1));
            continue;
        }
        if (c.posizione === "duplica") {
            righe.push(regolaSchermo(s.name, "preferred", "auto", 1, principale.name));
            continue;
        }
        const res = c.risoluzione || (s.width + "x" + s.height);
        const scala = Number(c.scala) || 1;
        const m = misura(res) || { l: s.width, a: s.height };
        let pos;
        if (c.posizione === "sinistra")
            pos = (-Math.round(m.l / scala)) + "x0";
        else if (c.posizione === "sopra")
            pos = "0x" + (-Math.round(m.a / scala));
        else
            pos = Math.round(mP.l / scalaP) + "x0";        // destra
        righe.push(regolaSchermo(s.name, res, pos, scala));
    }
    return righe.join("\n") + "\n";
}

// --- il file delle impostazioni -------------------------------------------------------
//   o: { animazioni, angoli, sfocatura, spazi, affianca } (da Opzioni.qml)
function impostazioni(o, elenco, scelte) {
    const si = v => (v ? "true" : "false");
    let t = "-- Creato da Impostazioni (desktop Vetro): non modificarlo a mano,\n";
    t += "-- le tue aggiunte vanno in ~/.config/hypr/personale.lua\n";
    t += schermi(elenco, scelte);
    t += "hl.config({\n";
    t += "    animations = { enabled = " + si(o.animazioni) + " },\n";
    t += "    decoration = { rounding = " + Math.round(Number(o.angoli) || 0)
        + ", blur = { enabled = " + si(o.sfocatura) + " } },\n";
    t += "    general = { gaps_in = " + Math.round((Number(o.spazi) || 0) / 2)
        + ", gaps_out = " + Math.round(Number(o.spazi) || 0) + " },\n";
    t += "})\n";
    if (!o.affianca) {
        t += "-- le finestre si aprono libere (non affiancate), come su macOS e Windows\n";
        t += 'hl.window_rule({ name = "vetro-finestre-libere", match = { class = ".*" }, float = true })\n';
    }
    return t;
}
