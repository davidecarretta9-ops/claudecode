# =============================================================================
#  vetro-arch.sh — il desktop "Vetro" su Arch Linux (leggero, aspetto GNOME,
#  sicurezza: modalita' fantasma, firewall, Guardiano della rete, VPN...).
#  Si lancia come root su un Arch appena installato (guida: GUIDA-INSTALLAZIONE.md).
#
#    sudo bash vetro-arch.sh              fa tutto (o riprende da dove era)
#    sudo bash vetro-arch.sh controlla    a che punto e' il sistema
#    sudo bash vetro-arch.sh registri     raccoglie i registri in un file
#    sudo bash vetro-arch.sh rifai PASSO  rifa' un passo
#
#  Ogni passo, se si ferma, si riprende rilanciando lo script; se lo script
#  cambia un passo, quel passo si rifa' da solo.
# =============================================================================

# tutto quello che lo script scrive passa da qui (vuota = il disco vero; le prove
# usano una cartella finta)
VETRO_RADICE=${VETRO_RADICE:-}
VETRO_FILE=${VETRO_FILE:-}
FASE1=() FASE2=() FASE3=() FASE4=()

percorso() { printf '%s%s\n' "$VETRO_RADICE" "$1"; }
VETRO_STATO=$(percorso /var/lib/vetro-arch)

titolo() { printf '\n==> %s\n' "$*"; }
info()   { printf '  %s\n' "$*"; }
ok()     { printf '  [OK] %s\n' "$*"; }
avviso() { printf '  [!!] %s\n' "$*" >&2; }
muori()  { printf '\n  [ERRORE] %s\n\n' "$*" >&2; exit 1; }

serve_root() {
    [ "${VETRO_EUID:-$EUID}" -eq 0 ] || muori "Lancialo come root:  sudo bash lfs.sh ${1:-}"
}

controlla_arch() {
    [ -f "$(percorso /etc/arch-release)" ] \
        || muori "Questo script e' fatto per Arch Linux (non trovo /etc/arch-release)"
}

# i comandi che cambiano il sistema (pacman, systemctl, useradd...) passano da qui:
# nelle prove si usano quelli finti, e un comando senza finto non parte mai
esegui() {
    if [ -n "$VETRO_RADICE" ]; then
        if [ -x "$VETRO_RADICE/.finti/${1##*/}" ]; then
            "$VETRO_RADICE/.finti/${1##*/}" "${@:2}"
            return
        fi
        echo "prova: manca il comando finto per '$1'" >&2
        return 127
    fi
    "$@"
}

# installa_file REL...: copia i file dello script (cartella file/) sul disco, con
# gli stessi permessi
installa_file() {
    local rel src dst
    for rel in "$@"; do
        src="$VETRO_FILE/$rel"
        dst=$(percorso "/$rel")
        [ -f "$src" ] || muori "Nello script manca il file $rel"
        install -D -m "$(stat -c %a "$src")" "$src" "$dst"
    done
}

# installa_cartella REL...: come installa_file, per tutti i file di una cartella
installa_cartella() {
    local rel f
    for rel in "$@"; do
        [ -d "$VETRO_FILE/$rel" ] || muori "Nello script manca la cartella $rel"
        while IFS= read -r f; do
            installa_file "$f"
        done < <(cd "$VETRO_FILE" && find "$rel" -type f | LC_ALL=C sort)
    done
}
