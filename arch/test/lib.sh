#!/bin/bash
# Strumenti per le prove di lfs.sh (Vetro su Arch): radice finta, comandi finti, confronti.
# Ogni prova gira in una sottoshell (prova NOME); i risultati vanno in un file.
QUI_TEST=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ARCH_DIR=$(dirname "$QUI_TEST")
ESITI=$(mktemp)
PROVA_ATTUALE=""

# carica i pezzi dello script (senza farlo partire)
carica_src() {
    local f
    for f in "$ARCH_DIR"/src/*.sh; do
        # shellcheck disable=SC1090
        source "$f"
    done
}

# radice finta: tutto quello che lo script scrive finisce qui dentro
radice_finta() {
    RADICE=$(mktemp -d)
    export VETRO_RADICE=$RADICE VETRO_PROVA=1
    export VETRO_FILE=${VETRO_FILE_PROVA:-$ARCH_DIR/file}
    VETRO_STATO="$RADICE/var/lib/vetro-arch"
    mkdir -p "$RADICE/etc" "$RADICE/.finti"
    touch "$RADICE/etc/arch-release" "$RADICE/.chiamate"
}

# finto CMD [ESITO]: il comando scrive "CMD argomenti" in .chiamate ed esce con ESITO
finto() {
    local cmd=$1 esito=${2:-0}
    cat > "$RADICE/.finti/$cmd" <<EOF
#!/bin/bash
echo "$cmd \$*" >> "$RADICE/.chiamate"
exit $esito
EOF
    chmod +x "$RADICE/.finti/$cmd"
}

# finto_con CMD: come finto, ma il resto del comando si legge da stdin
finto_con() {
    local cmd=$1
    { echo '#!/bin/bash'
      echo "echo \"$cmd \$*\" >> \"$RADICE/.chiamate\""
      cat
    } > "$RADICE/.finti/$cmd"
    chmod +x "$RADICE/.finti/$cmd"
}

# git finto: ricorda le chiamate; "rev-parse HEAD" risponde $GIT_COMMIT se c'e',
# se no il commit chiesto con fetch (cioe' il download va bene)
git_finto() {
    finto_con git <<'FINE'
dir=""
[ "$1" = -C ] && { dir=$2; shift 2; }
case "$1" in
    init) mkdir -p "$dir"; touch "$dir/.git-finto" ;;
    fetch) for a in "$@"; do c=$a; done; echo "$c" > "$dir/.commit" ;;
    rev-parse) if [ -n "${GIT_COMMIT:-}" ]; then echo "$GIT_COMMIT"; else cat "$dir/.commit"; fi ;;
esac
exit 0
FINE
}

# compilatori finti (Quickshell e Caelestia si compilano dai sorgenti)
compilazione_finta_base() {
    git_finto; finto cmake; finto ninja
    # Caelestia: la sua compilazione si prova a parte (test-caelestia.sh)
    compila_caelestia() { echo "compila_caelestia" >> "$RADICE/.chiamate"; }
}

ok_prova() { echo "ok      $PROVA_ATTUALE: $*" >> "$ESITI"; }
fallita()  { echo "FALLITO $PROVA_ATTUALE: $*" >> "$ESITI"; }

uguale() {
    if [ "$1" = "$2" ]; then ok_prova "$3"; else fallita "$3 (atteso [$1], ottenuto [$2])"; fi
}
contiene() {
    if [ -f "$1" ] && grep -qF -- "$2" "$1"; then ok_prova "$1 contiene '$2'"
    else fallita "$1 non contiene '$2'"; fi
}
non_contiene() {
    if [ -f "$1" ] && grep -qF -- "$2" "$1"; then fallita "$1 contiene '$2'"
    else ok_prova "$1 non contiene '$2'"; fi
}
esiste()     { if [ -e "$1" ] || [ -L "$1" ]; then ok_prova "esiste $1"; else fallita "manca $1"; fi; }
non_esiste() { if [ -e "$1" ] || [ -L "$1" ]; then fallita "non doveva esistere $1"; else ok_prova "non esiste $1"; fi; }
chiamato()     { contiene "$RADICE/.chiamate" "$1"; }
non_chiamato() { non_contiene "$RADICE/.chiamate" "$1"; }

# prova NOME: esegue la funzione in una sottoshell; se esce per errore la prova fallisce
prova() {
    PROVA_ATTUALE=$1
    local prima; prima=$(wc -l < "$ESITI")
    ( "$1" ) > "$ESITI.uscita" 2>&1
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        fallita "uscita inattesa ($rc): $(tail -n 3 "$ESITI.uscita" | tr '\n' ' ')"
    elif [ "$(wc -l < "$ESITI")" -eq "$prima" ]; then
        fallita "nessun controllo eseguito"
    fi
}

riassunto() {
    cat "$ESITI"
    local f; f=$(grep -c '^FALLITO' "$ESITI" || true)
    local t; t=$(wc -l < "$ESITI")
    echo "--- $(basename "$0"): $((t - f))/$t ok"
    rm -f "$ESITI" "$ESITI.uscita"
    [ "$f" -eq 0 ]
}

# curl finto che scrive "carattere" nel file chiesto con -o
curl_carattere() {
    finto_con curl <<'FINE'
while [ $# -gt 0 ]; do [ "$1" = -o ] && { printf carattere > "$2"; shift; }; shift; done
FINE
}
