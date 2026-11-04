#!/bin/bash
# Unisce arch/src/*.sh e la cartella arch/file/ in un solo file: arch/dist/vetro-arch.sh
#   bash arch/costruisci.sh [CARTELLA_FILE] [USCITA]
set -euo pipefail
qui=$(cd "$(dirname "$0")" && pwd)
file=${1:-$qui/file}
uscita=${2:-$qui/dist/vetro-arch.sh}
mkdir -p "$(dirname "$uscita")"

{
    echo '#!/bin/bash'
    echo '# vetro-arch.sh: generato da arch/costruisci.sh (i sorgenti sono in arch/src e arch/file)'
    echo 'set -Eeuo pipefail'
    for f in "$qui"/src/*.sh; do
        echo "# ===== $(basename "$f")"
        cat "$f"
    done
    cat <<'FINE'
# ===== avvio
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    VETRO_LFS=${VETRO_LFS:-$(readlink -f "${BASH_SOURCE[0]}")}
    trap pulisci EXIT
    if [ -z "${VETRO_FILE:-}" ]; then
        VETRO_FILE=$(mktemp -d)
        VETRO_FILE_TEMP=$VETRO_FILE
        estrai_archivio "$VETRO_FILE"
    fi
    principale "$@"
fi
return 0 2>/dev/null || exit 0
FINE
    echo '__VETRO_ARCHIVIO__'
    # archivio sempre uguale a parita' di file (ordine, date e proprietari fissi)
    tar -C "$file" --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -c . \
        | gzip -n -9 | base64 -w 76
} > "$uscita.nuovo"
chmod 755 "$uscita.nuovo"
mv "$uscita.nuovo" "$uscita"
bash -n "$uscita"
echo "Scritto $uscita ($(wc -c < "$uscita") byte)"
