#!/bin/bash
# Esegue tutte le prove di vetro-arch.sh: test-*.sh e test/python/test_*.py
# Uso: bash arch/test/esegui.sh [nome-file-di-prova...]
QUI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
falliti=0
if [ "$#" -gt 0 ]; then elenco=("$@"); else elenco=("$QUI"/test-*.sh); fi
for t in "${elenco[@]}"; do
    [ -f "$t" ] || t="$QUI/$t"
    if ! bash "$t"; then falliti=$((falliti + 1)); fi
done
# per le prove Python serve PySide6 (motore JS di Qt): ~/.vetro-qt se c'e'
PY=python3
[ -x "$HOME/.vetro-qt/bin/python" ] && PY="$HOME/.vetro-qt/bin/python"
if [ "$#" -eq 0 ] && ls "$QUI"/python/test_*.py >/dev/null 2>&1; then
    if "$PY" -I -B -m unittest discover -s "$QUI/python" -t "$QUI/python" > "$QUI/.python.log" 2>&1; then
        echo "--- prove Python: $(grep -o 'Ran [0-9]* tests' "$QUI/.python.log"), ok"
    else
        grep -E '^(FAIL|ERROR|AssertionError)' "$QUI/.python.log" | head -n 20
        echo "--- prove Python: FALLITE"; falliti=$((falliti + 1))
    fi
    rm -f "$QUI/.python.log"
fi
if [ "$falliti" -eq 0 ]; then echo "=== TUTTO OK"; else echo "=== FALLITI: $falliti file di prova"; fi
[ "$falliti" -eq 0 ]
