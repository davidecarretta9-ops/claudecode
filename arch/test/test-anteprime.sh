#!/bin/bash
# Prove dello strumento delle anteprime (arch/strumenti/anteprima.py): disegna le
# Viste della grafica in immagini PNG con PySide6 (piano nuova grafica)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
STRUMENTO="$ARCH_DIR/strumenti/anteprima.py"
PY=python3
[ -x "$HOME/.vetro-qt/bin/python" ] && PY="$HOME/.vetro-qt/bin/python"

# misura_png FILE -> "LARGHEZZAxALTEZZA"
misura_png() {
    python3 -I -c 'import struct,sys; d=open(sys.argv[1],"rb").read(24); print("%dx%d" % struct.unpack(">II", d[16:24]))' "$1" 2>/dev/null
}

test_scena_prova() {
    local out; out=$(mktemp -d)
    "$PY" "$STRUMENTO" "$out" --solo prova > "$out/uscita" 2>&1
    uguale 0 "$?" "anteprima della scena di prova"
    esiste "$out/prova.png"
    uguale "320x120" "$(misura_png "$out/prova.png")" "grande quanto la scena"
    rm -rf "$out"
}

test_errore_qml() {
    local out scene; out=$(mktemp -d); scene=$(mktemp -d)
    printf 'import QtQuick\nItem { width: 10; height: 10; TipoCheNonEsiste {} }\n' > "$scene/rotta.qml"
    "$PY" "$STRUMENTO" "$out" --scene "$scene" > "$out/uscita" 2>&1
    uguale 1 "$?" "una scena sbagliata fa uscire con 1"
    contiene "$out/uscita" "rotta.qml"
    rm -rf "$out" "$scene"
}

test_tutte_le_scene() {
    # ogni scena di arch/strumenti/anteprima/scene si disegna senza errori
    local out; out=$(mktemp -d)
    "$PY" "$STRUMENTO" "$out" > "$out/uscita" 2>&1
    uguale 0 "$?" "tutte le scene senza errori"
    [ -s "$out/uscita" ] && grep -i "errore" "$out/uscita" | head -n 5 >&2
    local s
    for s in "$ARCH_DIR"/strumenti/anteprima/scene/*.qml; do
        esiste "$out/$(basename "$s" .qml).png"
    done
    rm -rf "$out"
}

prova test_scena_prova
prova test_errore_qml
prova test_tutte_le_scene
riassunto
