#!/bin/bash
# Prova di tutto il giro (sudo bash lfs.sh installa) in una cartella finta: tutte le fasi,
# con i comandi finti. Serve a vedere che i pezzi si incastrano (Task 13).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src

prepara_arch() {
    radice_finta
    export VETRO_EUID=0
    mkdir -p "$RADICE/etc/vetro" "$RADICE/usr/bin"
    : > "$RADICE/etc/arch-release"
    printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n\n#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' \
        > "$RADICE/etc/pacman.conf"
    echo vetro > "$RADICE/etc/vetro/utente"
    : > "$RADICE/usr/bin/thunderbird"; : > "$RADICE/usr/bin/winecfg"
    local c
    for c in systemctl python3 usermod useradd groupadd visudo fc-cache gtk-update-icon-cache \
             vetro-barre-aggiorna tune2fs getent chown; do
        finto "$c"
    done
    finto_con pacman <<'FINE'
case "$1" in
    -Si) [ "$2" = quickshell ] || exit 0 ;;   # quickshell c'e' nei depositi
    -T)  exit 0 ;;                             # tutto gia' soddisfatto
esac
exit 0
FINE
    finto_con curl <<'FINE'
while [ $# -gt 0 ]; do [ "$1" = -o ] && { printf carattere > "$2"; shift; }; shift; done
FINE
    finto_con id <<'FINE'
case "$1" in -u|-g) echo 1001 ;; fantasma) exit 1 ;; *) exit 0 ;; esac
FINE
    finto_con findmnt <<'FINE'
case "$*" in *FSTYPE*) echo ext4 ;; *SOURCE*) echo /dev/vda2 ;; esac
FINE
    finto_con dumpe2fs <<'FINE'
echo "Filesystem features: has_journal extent"
FINE
    FONT_ICONE_SHA256=$(printf carattere | sha256sum | cut -d' ' -f1)
    compilazione_finta_base
}

test_tutto() {
    prepara_arch
    ( set -Eeuo pipefail; cmd_tutto ) > "$RADICE/uscita" 2>&1
    local rc=$?
    uguale 0 "$rc" "il giro completo finisce bene"
    [ "$rc" -eq 0 ] || tail -n 25 "$RADICE/uscita" >&2
    local riga nome
    for riga in "${FASE1[@]}" "${FASE2[@]}" "${FASE3[@]}" "${FASE4[@]}"; do
        nome=${riga%%|*}
        esiste "$VETRO_STATO/fatto/$nome"
    done
    contiene "$RADICE/uscita" "Riavvia il computer"
    # rilanciato: tutto gia' fatto, nessun passo si rifa'
    : > "$RADICE/.chiamate"
    ( set -Eeuo pipefail; cmd_tutto ) > "$RADICE/uscita2" 2>&1
    uguale 0 "$?" "la seconda volta finisce bene"
    non_contiene "$RADICE/uscita2" "[OK] Desktop Vetro"
    contiene "$RADICE/uscita2" "desktop (gia' fatto)"
}

test_controlla_dopo() {
    prepara_arch
    ( set -Eeuo pipefail; cmd_tutto ) > /dev/null 2>&1
    cmd_controlla > "$RADICE/uscita" 2>&1
    contiene "$RADICE/uscita" "Tutti i passi sono fatti"
}

prova test_tutto
prova test_controlla_dopo
riassunto
