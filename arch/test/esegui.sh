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
if [ "$#" -eq 0 ] && ls "$QUI"/python/test_*.py >/dev/null 2>&1; then
    if ! python3 -I -m unittest discover -s "$QUI/python" -t "$QUI/python" 2>&1 | tail -n 4; then :; fi
    python3 -I -m unittest discover -s "$QUI/python" -t "$QUI/python" >/dev/null 2>&1 || falliti=$((falliti + 1))
fi
if [ "$falliti" -eq 0 ]; then echo "=== TUTTO OK"; else echo "=== FALLITI: $falliti file di prova"; fi
[ "$falliti" -eq 0 ]
