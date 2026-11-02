#!/bin/bash
# Prove della grafica di accesso, blocco e impostazioni (piano nuova grafica)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
F="$ARCH_DIR/file"
V="$F/etc/xdg/quickshell/vetro"
QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}
PY=python3
[ -x "$HOME/.vetro-qt/bin/python" ] && PY="$HOME/.vetro-qt/bin/python"

sintassi() {
    local f
    for f in "$@"; do
        if [ -f "$V/$f" ] && [ -x "$QMLLINT" ] && ! "$QMLLINT" "$V/$f" 2>&1 | grep -q '\[syntax\]'; then
            ok_prova "$f senza errori di sintassi"
        else fallita "$f: manca, ha errori di sintassi o manca qmllint"; fi
    done
}

anteprime() {
    local out s; out=$(mktemp -d)
    for s in "$@"; do
        if "$PY" "$ARCH_DIR/strumenti/anteprima.py" "$out" --solo "$s" > "$out/uscita" 2>&1 && [ -s "$out/$s.png" ]; then
            ok_prova "anteprima $s"
        else
            fallita "anteprima $s: $(tail -n 4 "$out/uscita" | tr '\n' ' ')"
        fi
    done
    rm -rf "$out"
}

test_accesso_usa_vista() {
    contiene "$V/accesso.qml" "AccessoVista"
    contiene "$V/accesso.qml" "vetro-nuvole.jpg"
    contiene "$V/accesso.qml" "Greetd.createSession"
    contiene "$V/accesso.qml" "Greetd.launch"
}

test_niente_tema() {
    # la schermata di accesso non legge le scelte dell'utente (Tema/Opzioni)
    non_contiene "$V/PasswordPillola.qml" "Tema."
    non_contiene "$V/AccessoVista.qml" "Tema."
    non_contiene "$V/AccessoVista.qml" "Icona {"
}

test_occhio() {
    contiene "$V/PasswordPillola.qml" "TextInput.Normal"
    contiene "$V/PasswordPillola.qml" "TextInput.Password"
    contiene "$V/PasswordPillola.qml" '"Scrivi la password"'
}

test_password_sbagliata() {
    contiene "$V/PasswordPillola.qml" "function sbagliata()"
    contiene "$V/AccessoVista.qml" "function sbagliata()"
    contiene "$V/accesso.qml" "Password sbagliata"
    contiene "$V/accesso.qml" "vista.sbagliata()"
}

test_nome_lungo() {
    contiene "$V/AccessoVista.qml" "elide: Text.ElideRight"
}

test_qml_accesso() {
    sintassi PasswordPillola.qml AccessoVista.qml accesso.qml
}

test_anteprime_accesso() {
    anteprime accesso accesso-errore
}

test_blocco() {
    contiene "$V/Blocco.qml" "BloccoVista"
    contiene "$V/Blocco.qml" "PamContext"
    contiene "$V/Blocco.qml" "vetro-cielo.jpg"
    contiene "$V/BloccoVista.qml" "font.pixelSize: 160"
    contiene "$V/BloccoVista.qml" "PasswordPillola"
    contiene "$V/BloccoVista.qml" '"dddd d MMMM"'
    sintassi BloccoVista.qml Blocco.qml Opzioni.qml FinestraImpostazioni.qml
}

test_password_sbagliata_blocco() {
    contiene "$V/Blocco.qml" "vista.sbagliata()"
    contiene "$V/BloccoVista.qml" "function sbagliata()"
}

test_niente_statistiche() {
    if grep -l "statisticheBlocco" "$V"/*.qml >/dev/null 2>&1; then fallita "statisticheBlocco c'e' ancora"
    else ok_prova "niente statisticheBlocco"; fi
}

test_anteprime_blocco() {
    anteprime blocco
}

test_impostazioni_chiare() {
    contiene "$V/FinestraImpostazioni.qml" "VoceLato"
    contiene "$V/FinestraImpostazioni.qml" "Tema.appFondo"
    non_contiene "$V/FinestraImpostazioni.qml" "Tema.fondoPieno"
    # niente colori dei pannelli scuri (testo bianco) sulla finestra chiara
    if grep -nE 'Tema\.(testo|testo2|testo3|carta|cartaForte|cartaSopra|bordo|bordoForte)([^A-Za-z0-9]|$)' "$V/FinestraImpostazioni.qml" >/dev/null; then
        fallita "FinestraImpostazioni usa ancora colori dei pannelli scuri"
    else ok_prova "FinestraImpostazioni usa solo i colori chiari"; fi
    contiene "$V/VoceLato.qml" "Tema.accento"
    sintassi VoceLato.qml FinestraImpostazioni.qml Interruttore.qml Cursore.qml
}

test_su_chiaro() {
    contiene "$V/Interruttore.qml" "property bool suChiaro: false"
    contiene "$V/Cursore.qml" "property bool suChiaro: false"
    contiene "$V/FinestraImpostazioni.qml" "suChiaro: true"
}

test_anteprime_impostazioni() {
    anteprime impostazioni-lato
}

prova test_impostazioni_chiare
prova test_su_chiaro
prova test_anteprime_impostazioni
prova test_blocco
prova test_password_sbagliata_blocco
prova test_niente_statistiche
prova test_anteprime_blocco
prova test_accesso_usa_vista
prova test_niente_tema
prova test_occhio
prova test_password_sbagliata
prova test_nome_lungo
prova test_qml_accesso
prova test_anteprime_accesso
riassunto
