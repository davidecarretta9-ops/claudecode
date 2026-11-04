.pragma library
// oversicaOS, schermata di accesso: chi puo' entrare.
// Il tuo utente (scritto in /etc/vetro/utente) per primo, poi gli altri utenti veri:
// UID da 1000 a 59999 e una shell vera (per esempio "fantasma"). Si cambia col tasto Tab.

function utenti(passwd, tuo) {
    const veri = [];
    for (const riga of String(passwd || "").split("\n")) {
        const c = riga.split(":");
        if (c.length < 7)
            continue;
        const uid = Number(c[2]);
        if (uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(c[6].trim()))
            veri.push(c[0]);
    }
    const t = String(tuo || "").trim();
    if (t && veri.indexOf(t) >= 0)
        return [t].concat(veri.filter(u => u !== t));
    return veri;
}

// il messaggio sotto la password quando entri con un utente che non e' il tuo
function avviso(lista, scelto) {
    if (!scelto || scelto >= lista.length)
        return "";
    return "Accesso come " + lista[scelto] + " (Tab per cambiare)";
}
