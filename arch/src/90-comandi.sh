# --- i comandi --------------------------------------------------------------------

aiuto() {
    cat <<'EOF'
vetro-arch.sh — il desktop Vetro su Arch Linux

  sudo bash vetro-arch.sh              fa tutto (o riprende da dove era)
  sudo bash vetro-arch.sh controlla    a che punto e' il sistema
  sudo bash vetro-arch.sh registri     raccoglie i registri in un file
  sudo bash vetro-arch.sh rifai PASSO  rifa' un passo
EOF
}

cmd_tutto() {
    serve_root tutto
    controlla_arch
    # (pacchetti: li aggiunge il pezzo dei pacchetti, se c'e')
    if declare -F abilita_multilib >/dev/null; then abilita_multilib; fi
    if declare -F controlla_tutti_i_pacchetti >/dev/null; then controlla_tutti_i_pacchetti; fi
    titolo "Fase 1 - sistema leggero";      esegui_fase "${FASE1[@]}"
    titolo "Fase 2 - desktop";               esegui_fase "${FASE2[@]}"
    titolo "Fase 3 - programmi";             esegui_fase "${FASE3[@]}"
    titolo "Fase 4 - sicurezza";             esegui_fase "${FASE4[@]}"
    if declare -F password_fantasma >/dev/null; then password_fantasma; fi
    titolo "Fatto. Riavvia il computer:  reboot"
}

# passi non ancora fatti (per "controlla")
passi_mancanti() {
    local riga nome fn file
    for riga in "${FASE1[@]}" "${FASE2[@]}" "${FASE3[@]}" "${FASE4[@]}"; do
        IFS='|' read -r nome fn file <<<"$riga"
        [ -f "$VETRO_STATO/fatto/$nome" ] || echo "$nome"
    done
}

# controllo ESITO TESTO: [OK] se ESITO e' 0, [!!] se no
controllo() {
    if [ "$1" -eq 0 ]; then ok "$2"; else avviso "$2"; fi
}

# la RAM usata in MB (totale meno disponibile)
ram_usata_mb() {
    awk '/^MemTotal:/ {t = $2} /^MemAvailable:/ {a = $2} END { if (t) print int((t - a) / 1024) }' \
        "$(percorso /proc/meminfo)" 2>/dev/null
}

SERVIZI_VETRO="greetd systemd-networkd iwd firewall guardiano-rete systemd-oomd"

cmd_controlla() {
    local ram s m
    titolo "Come sta Vetro"
    ram=$(ram_usata_mb)
    if [ -n "$ram" ]; then
        controllo "$([ "$ram" -lt 700 ] && echo 0 || echo 1)" "RAM usata: $ram MB"
    fi
    for s in $SERVIZI_VETRO; do
        if esegui systemctl is-active --quiet "$s.service" 2>/dev/null; then
            ok "Servizio $s attivo"
        else
            avviso "Servizio $s non attivo"
        fi
    done
    if [ -e "$(percorso /sys/block/zram0)" ]; then ok "zram (memoria compressa) acceso"
    else avviso "zram (memoria compressa) non c'e'"; fi
    if [ -e "$(percorso /etc/fantasma/attivo)" ]; then
        ok "Modalita' fantasma accesa"
        if esegui "$(percorso /usr/local/sbin/fantasma-aiuto)" pronto 2>/dev/null; then
            ok "Tor collegato"
        else
            avviso "Tor non ancora collegato (internet resta bloccato finche' non si collega)"
        fi
    else
        info "Modalita' fantasma spenta"
    fi
    m=$(passi_mancanti)
    if [ -z "$m" ]; then ok "Tutti i passi sono fatti"
    else avviso "Passi non fatti: $(echo "$m" | tr '\n' ' ')"; fi
}

# sezione TITOLO: l'intestazione di una parte del file dei registri
sezione() { printf '\n=== %s\n' "$1"; }

# il contenuto dei registri (per cmd_registri)
scrivi_registri() {
    local f nome u casa uid
    sezione "Sistema"
    date '+%F %T'
    uname -r 2>/dev/null
    echo "RAM usata: $(ram_usata_mb) MB"
    sezione "Passi falliti"
    for f in "$VETRO_STATO"/registri/*.log; do
        [ -f "$f" ] || continue
        nome=$(basename "$f" .log)
        [ -f "$VETRO_STATO/fatto/$nome" ] && continue
        echo "--- $nome"
        tail -n 100 "$f"
    done
    sezione "Registro di sistema (avvisi)"
    esegui journalctl -b -p warning --no-pager 2>/dev/null | tail -n 300
    u=$(utente_vetro 2>/dev/null) || u=""
    [ -n "$u" ] || return 0
    casa=$(esegui getent passwd "$u" 2>/dev/null | cut -d: -f6)
    [ -n "$casa" ] || casa="/home/$u"
    sezione "Hyprland"
    tail -n 300 "$(percorso "$casa/.cache/hyprland.log")" 2>/dev/null
    sezione "Pannelli (Quickshell)"
    tail -n 300 "$(percorso "$casa/.cache/quickshell-vetro.log")" 2>/dev/null
    sezione "Schermi e finestre"
    if esegui pgrep -u "$u" -x Hyprland >/dev/null 2>&1; then
        uid=$(esegui id -u "$u" 2>/dev/null)
        for f in monitors devices layers; do
            echo "--- hyprctl $f"
            esegui runuser -u "$u" -- env XDG_RUNTIME_DIR="/run/user/$uid" hyprctl -i 0 "$f" 2>&1
        done
    else
        echo "(il desktop non e' acceso)"
    fi
}

cmd_registri() {
    local cartella file
    cartella=$(percorso /mnt/vetro)
    # la cartella condivisa con il PC (vetro-vm.sh), se c'e'; se no quella di root
    [ -d "$cartella" ] || cartella=$(percorso /root)
    mkdir -p "$cartella"
    file="$cartella/registri-vetro.txt"
    scrivi_registri > "$file" 2>&1 || true
    ok "Registri raccolti in: ${file#"$VETRO_RADICE"}"
}

cmd_rifai() {
    serve_root rifai
    [ -n "${1:-}" ] || muori "Quale passo? Esempio:  sudo bash $0 rifai desktop"
    rifai_passo "$1"
    ok "Il passo $1 si rifa' al prossimo lancio"
}

# estrae l'archivio dei file messo in fondo al file unico (lo aggiunge costruisci.sh)
estrai_archivio() {
    local dir=$1
    mkdir -p "$dir"
    sed -n '/^__VETRO_ARCHIVIO__$/,$p' "${BASH_SOURCE[0]}" | tail -n +2 | base64 -d | tar -xz -C "$dir"
}

principale() {
    case "${1:-tutto}" in
        tutto)            cmd_tutto ;;
        controlla)        cmd_controlla ;;
        registri)         cmd_registri ;;
        rifai)            cmd_rifai "${2:-}" ;;
        _estrai)          estrai_archivio "${2:?cartella}" ;;
        aiuto|-h|--help)  aiuto ;;
        *)                aiuto; exit 1 ;;
    esac
}
