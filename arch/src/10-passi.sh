# --- il motore dei passi ----------------------------------------------------------
# Ogni passo ha un segno in $VETRO_STATO/fatto/NOME con l'impronta del suo testo e
# dei suoi file: se e' uguale il passo e' gia' fatto, se cambia si rifa'.

# impronta FUNZIONE [REL...]: sha256 del testo della funzione e dei file elencati
impronta() {
    local fn=$1 rel
    shift
    {
        declare -f "$fn"
        for rel in "$@"; do
            if [ -d "$VETRO_FILE/$rel" ]; then
                # una cartella: tutti i file dentro, in ordine, con il loro nome
                (cd "$VETRO_FILE" && find "$rel" -type f | LC_ALL=C sort | while IFS= read -r f; do
                    printf '== %s\n' "$f"; cat "$f"; done)
            else
                printf '== %s\n' "$rel"
                cat "$VETRO_FILE/$rel" 2>/dev/null || true
            fi
        done
    } | sha256sum | cut -d' ' -f1
}

# passo NOME FUNZIONE [REL...]: esegue la funzione (se non gia' fatta) con il suo
# registro; se si ferma mostra le ultime righe e lo script esce
passo() {
    local nome=$1 fn=$2
    shift 2
    local segno="$VETRO_STATO/fatto/$nome" registro="$VETRO_STATO/registri/$nome.log" imp esito=0
    imp=$(impronta "$fn" "$@")
    if [ -f "$segno" ] && [ "$(cat "$segno")" = "$imp" ]; then
        info "$nome (gia' fatto)"
        return 0
    fi
    mkdir -p "$VETRO_STATO/fatto" "$VETRO_STATO/registri"
    info "$nome..."
    # in sottofondo e non dentro un "if": cosi' "fermati al primo errore" vale davvero
    ( set -Eeuo pipefail; "$fn" ) > "$registro" 2>&1 < /dev/null &
    wait "$!" || esito=$?
    if [ "$esito" -ne 0 ]; then
        tail -n 15 "$registro" | sed 's/^/      | /' >&2
        muori "Il passo \"$nome\" non e' riuscito (registro: $registro). Rilancia lo script: riparte da qui."
    fi
    printf '%s\n' "$imp" > "$segno"
    grep -F '[OK]' "$registro" | sed 's/^ */    /' || true
    ok "$nome"
}

rifai_passo() { rm -f "$VETRO_STATO/fatto/$1"; }

# esegui_fase RIGA...: ogni riga e' "nome|funzione|file1 file2"
esegui_fase() {
    local riga nome fn file
    for riga in "$@"; do
        IFS='|' read -r nome fn file <<<"$riga"
        # shellcheck disable=SC2086
        passo "$nome" "$fn" $file
    done
}
