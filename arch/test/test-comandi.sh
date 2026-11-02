#!/bin/bash
# Prove dei comandi "controlla" e "registri" (Task 11)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src

meminfo() {   # meminfo DISPONIBILE_KB
    mkdir -p "$RADICE/proc"
    printf 'MemTotal:        8000000 kB\nMemFree:          100000 kB\nMemAvailable:    %s kB\n' "$1" \
        > "$RADICE/proc/meminfo"
}

test_ram() {
    radice_finta; finto systemctl; meminfo 7400000
    cmd_controlla > "$RADICE/uscita" 2>&1
    contiene "$RADICE/uscita" "[OK] RAM usata: 585 MB"
    meminfo 7000000
    cmd_controlla > "$RADICE/uscita" 2>&1
    contiene "$RADICE/uscita" "[!!] RAM usata: 976 MB"
}

test_servizi() {
    radice_finta; meminfo 7400000
    finto_con systemctl <<'FINE'
[ "$3" = iwd.service ] && exit 3
exit 0
FINE
    cmd_controlla > "$RADICE/uscita" 2>&1
    contiene "$RADICE/uscita" "[OK] Servizio greetd attivo"
    contiene "$RADICE/uscita" "[!!] Servizio iwd non attivo"
    contiene "$RADICE/uscita" "[!!] zram (memoria compressa) non c'e'"
    contiene "$RADICE/uscita" "Modalita' fantasma spenta"
    contiene "$RADICE/uscita" "Passi non fatti"
    mkdir -p "$RADICE/sys/block/zram0" "$RADICE/etc/fantasma" "$RADICE/usr/local/sbin"
    : > "$RADICE/etc/fantasma/attivo"
    finto_con fantasma-aiuto <<'FINE'
exit 1
FINE
    cmd_controlla > "$RADICE/uscita" 2>&1
    contiene "$RADICE/uscita" "[OK] zram (memoria compressa) acceso"
    contiene "$RADICE/uscita" "[OK] Modalita' fantasma accesa"
    contiene "$RADICE/uscita" "[!!] Tor non ancora collegato"
}

test_registri_condivisa() {
    radice_finta; meminfo 7400000
    mkdir -p "$RADICE/mnt/vetro" "$RADICE/etc/vetro" "$RADICE/home/vetro/.cache" "$VETRO_STATO/registri"
    echo vetro > "$RADICE/etc/vetro/utente"
    echo "errore del passo desktop" > "$VETRO_STATO/registri/desktop.log"
    echo "registro del passo fatto" > "$VETRO_STATO/registri/leggero.log"
    mkdir -p "$VETRO_STATO/fatto"; : > "$VETRO_STATO/fatto/leggero"
    echo "riga di hyprland" > "$RADICE/home/vetro/.cache/hyprland.log"
    echo "riga dei pannelli" > "$RADICE/home/vetro/.cache/quickshell-vetro.log"
    finto_con journalctl <<'FINE'
echo "avviso del sistema"
FINE
    finto pgrep 1
    cmd_registri >/dev/null 2>&1
    local f="$RADICE/mnt/vetro/registri-vetro.txt"
    esiste "$f"
    contiene "$f" "=== Passi falliti"
    contiene "$f" "errore del passo desktop"
    non_contiene "$f" "registro del passo fatto"
    contiene "$f" "=== Registro di sistema (avvisi)"
    contiene "$f" "avviso del sistema"
    contiene "$f" "=== Hyprland"
    contiene "$f" "riga di hyprland"
    contiene "$f" "=== Pannelli (Quickshell)"
    contiene "$f" "riga dei pannelli"
    contiene "$f" "=== Schermi e finestre"
    non_esiste "$RADICE/root/registri-vetro.txt"
}

test_registri_root() {
    radice_finta; meminfo 7400000; finto journalctl; finto pgrep 1
    cmd_registri >/dev/null 2>&1
    esiste "$RADICE/root/registri-vetro.txt"
}

prova test_ram
prova test_servizi
prova test_registri_condivisa
prova test_registri_root
riassunto
