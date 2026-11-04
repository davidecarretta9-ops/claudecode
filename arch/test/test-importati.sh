#!/bin/bash
# Prove dei file di Vetro importati da lfs.sh (Task 4) e di tutti i file di arch/file.
# I file QML si controllano con pyside6-qmllint (PySide6):
#   python3 -m venv ~/.vetro-qt && ~/.vetro-qt/bin/pip install PySide6-Essentials
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
F="$ARCH_DIR/file"
QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}

tipo_di() {   # bash | python | altro (dalla prima riga)
    case "$(head -n1 "$1")" in
        '#!'*python*) echo python ;;
        '#!'*bash*|'#!'*/sh*) echo bash ;;
        *) echo altro ;;
    esac
}

test_quanti_qml() {
    local n; n=$(find "$F/etc/xdg/quickshell/vetro" -name '*.qml' | wc -l)
    # i pannelli sono di Caelestia: di Vetro resta la schermata di accesso (3 file)
    if [ "$n" -ge 3 ]; then ok_prova "$n file QML"; else fallita "solo $n file QML (almeno 3)"; fi
}

test_sintassi_script() {
    local f n=0
    while IFS= read -r f; do
        case "$(tipo_di "$f")" in
            bash)   if bash -n "$f" 2>/dev/null; then n=$((n + 1)); else fallita "errore di sintassi bash in ${f#"$F"}"; fi ;;
            python) if python3 -I -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$f" 2>/dev/null; then n=$((n + 1))
                    else fallita "errore di sintassi Python in ${f#"$F"}"; fi ;;
        esac
    done < <(find "$F" -type f)
    ok_prova "$n script senza errori di sintassi"
}

test_qml_lint() {
    if [ ! -x "$QMLLINT" ]; then fallita "manca pyside6-qmllint (vedi in cima a questo file)"; return; fi
    local f errori=0
    for f in "$F"/etc/xdg/quickshell/vetro/*.qml; do
        if "$QMLLINT" "$f" 2>&1 | grep -q '\[syntax\]'; then
            fallita "errore di sintassi QML in $(basename "$f")"; errori=1
        fi
    done
    [ "$errori" -eq 1 ] || ok_prova "nessun errore di sintassi QML"
}

prova test_quanti_qml
prova test_sintassi_script
prova test_qml_lint
riassunto
