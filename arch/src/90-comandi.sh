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

cmd_controlla() {
    local m; m=$(passi_mancanti)
    if [ -z "$m" ]; then ok "Tutti i passi sono fatti"
    else avviso "Passi non fatti: $(echo "$m" | tr '\n' ' ')"; fi
}

cmd_registri() {
    info "I registri dei passi sono in $VETRO_STATO/registri"
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
