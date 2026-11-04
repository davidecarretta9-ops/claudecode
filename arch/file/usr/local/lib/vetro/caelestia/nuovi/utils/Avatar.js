.pragma library
// oversicaOS: l'avatar a pixel in stile Oversica Lodge. Stesso disegno di
// /usr/local/bin/oversica-avatar (che scrive il PNG): dati in /usr/share/oversica/avatar/pixel.json.

const STILI = ["corti", "folti", "lunghi", "raccolti", "ricci", "rasati"];
const QUANTI = { coloreCapelli: 8, pelle: 6, maglia: 8 };
const PREDEFINITE = { capelli: "corti", coloreCapelli: 2, pelle: 1, maglia: 2 };

// le scelte valide, con le predefinite al posto di quelle che mancano o non valgono
function normalizza(scelte) {
    const s = Object.assign({}, PREDEFINITE);
    if (!scelte || typeof scelte !== "object")
        return s;
    if (STILI.indexOf(scelte.capelli) >= 0)
        s.capelli = scelte.capelli;
    for (const campo in QUANTI) {
        const v = scelte[campo];
        if (Number.isInteger(v) && v >= 0 && v < QUANTI[campo])
            s[campo] = v;
    }
    return s;
}

// la griglia dei colori ("#rrggbb", null = sfondo): il corpo, poi i capelli sopra
function griglia(dati, scelte) {
    const s = normalizza(scelte);
    const t = dati.tavolozze;
    const capelli = t.capelli[s.coloreCapelli];
    const pelle = t.pelle[s.pelle];
    const maglia = t.maglia[s.maglia];
    const colori = Object.assign({}, dati.fissi, { s: pelle.colore, S: pelle.ombra, m: maglia.colore, M: maglia.ombra });
    const g = dati.corpo.map(riga => riga.split("").map(c => colori.hasOwnProperty(c) ? colori[c] : null));
    dati.capelli[s.capelli].forEach((riga, y) => {
        riga.split("").forEach((c, x) => {
            if (c === "h")
                g[y][x] = capelli.colore;
            else if (c === "H")
                g[y][x] = capelli.ombra;
        });
    });
    return g;
}
