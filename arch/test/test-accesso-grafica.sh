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

prova test_accesso_usa_vista
prova test_niente_tema
prova test_occhio
prova test_password_sbagliata
prova test_nome_lungo
prova test_qml_accesso
prova test_anteprime_accesso
riassunto
