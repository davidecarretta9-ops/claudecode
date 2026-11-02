.pragma library
// Le regole di Hyprland per piu' schermi (creato da vetro-arch.sh). Le usa Opzioni.qml
// per scrivere ~/.config/hypr/vetro-impostazioni.conf.
//   schermi: da "hyprctl monitors -j" (name, width, height)
//   scelte:  per nome { risoluzione: "1920x1080", posizione: "destra" | "sinistra" |
//            "sopra" | "duplica", principale: true/false, scala: 1 }
// Una riga per ogni schermo che c'e' adesso; senza scelte salvate niente righe (restano
// la risoluzione migliore e la posizione automatica).

function misura(testo) {
    const m = /^(\d+)x(\d+)$/.exec(testo || "");
    return m ? { l: Number(m[1]), a: Number(m[2]) } : null;
}

function regole(schermi, scelte) {
    scelte = scelte || {};
    const presenti = schermi.filter(s => s && s.name);
    if (!presenti.some(s => scelte[s.name]))
        return "";
    const principale = presenti.find(s => scelte[s.name] && scelte[s.name].principale) || presenti[0];
    const sp = scelte[principale.name] || {};
    const resP = sp.risoluzione || (principale.width + "x" + principale.height);
    const scalaP = Number(sp.scala) || 1;
    const mP = misura(resP) || { l: principale.width, a: principale.height };
    let righe = ["monitor = " + principale.name + ", " + resP + ", 0x0, " + scalaP];
    for (const s of presenti) {
        if (s.name === principale.name)
            continue;
        const c = scelte[s.name];
        if (!c) {
            righe.push("monitor = " + s.name + ", preferred, auto, 1");
            continue;
        }
        if (c.posizione === "duplica") {
            righe.push("monitor = " + s.name + ", preferred, auto, 1, mirror, " + principale.name);
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
        righe.push("monitor = " + s.name + ", " + res + ", " + pos + ", " + scala);
    }
    return righe.join("\n") + "\n";
}
