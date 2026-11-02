#!/bin/bash
# Prove della barra unica in basso, del riquadro musica e del menu (piano nuova grafica)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
F="$ARCH_DIR/file"
V="$F/etc/xdg/quickshell/vetro"
QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}
PY=python3
[ -x "$HOME/.vetro-qt/bin/python" ] && PY="$HOME/.vetro-qt/bin/python"

# sintassi QML dei file dati
sintassi() {
    local f
    for f in "$@"; do
        if [ -f "$V/$f" ] && [ -x "$QMLLINT" ] && ! "$QMLLINT" "$V/$f" 2>&1 | grep -q '\[syntax\]'; then
            ok_prova "$f senza errori di sintassi"
        else fallita "$f: manca, ha errori di sintassi o manca qmllint"; fi
    done
}

# anteprime: le scene date si disegnano senza errori
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

test_barra_su_ogni_schermo() {
    contiene "$V/shell.qml" "model: Quickshell.screens"
    contiene "$V/shell.qml" "Barra {}"
    contiene "$V/shell.qml" "MusicaRiquadro {}"
    non_contiene "$V/shell.qml" "Dock"
}

test_niente_dock() {
    non_esiste "$V/Dock.qml"
    if grep -l "Opzioni.dock" "$V"/*.qml >/dev/null 2>&1; then fallita "qualche file usa ancora Opzioni.dock"
    else ok_prova "nessun file usa Opzioni.dock"; fi
}

test_barra_in_basso() {
    contiene "$V/Barra.qml" "anchors { bottom: true; left: true; right: true }"
    contiene "$V/Barra.qml" "BarraVista"
    contiene "$V/Barra.qml" "Stato.barre"
    contiene "$V/BarraVista.qml" "Tema.altezzaBarra"
    contiene "$V/BarraVista.qml" "Tema.raggioBarra"
}

test_icona_fantasma() {
    contiene "$V/BarraVista.qml" "visible: vista.fantasma"
}

test_pillole() {
    contiene "$V/BarraVista.qml" "visible: vista.nonDisturbare"
    contiene "$V/BarraVista.qml" "visible: vista.musica"
    contiene "$V/BarraVista.qml" "elide: Text.ElideRight"
    contiene "$V/BarraVista.qml" "visible: vista.batteria >= 0"
}

test_musica() {
    contiene "$V/Stato.qml" "property bool musica: false"
    contiene "$V/Musica.qml" "property real posizione"
    contiene "$V/Musica.qml" "function sposta("
    contiene "$V/MusicaRiquadro.qml" "MusicaVista"
}

test_posizioni() {
    contiene "$V/Pannello.qml" "bottom: Tema.sopraBarra"
    contiene "$V/Notifiche.qml" "bottom: Tema.sopraBarra"
    contiene "$V/Cruscotto.qml" "bottom: Tema.sopraBarra"
    contiene "$V/Osd.qml" "bottom: Tema.sopraBarra"
}

test_qml() {
    sintassi BarraVista.qml Barra.qml MusicaVista.qml MusicaRiquadro.qml shell.qml Stato.qml Musica.qml \
             Pannello.qml Notifiche.qml Cruscotto.qml Osd.qml Opzioni.qml FinestraImpostazioni.qml
}

test_anteprime_barra() {
    anteprime barra barra-vuota barra-lunga musica
}

prova test_barra_su_ogni_schermo
prova test_niente_dock
prova test_barra_in_basso
prova test_icona_fantasma
prova test_pillole
prova test_musica
prova test_posizioni
prova test_qml
prova test_anteprime_barra
riassunto
