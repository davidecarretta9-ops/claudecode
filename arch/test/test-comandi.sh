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
[ "$3" = NetworkManager.service ] && exit 3
exit 0
FINE
    cmd_controlla > "$RADICE/uscita" 2>&1
    contiene "$RADICE/uscita" "[OK] Servizio greetd attivo"
    contiene "$RADICE/uscita" "[!!] Servizio NetworkManager non attivo"
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
    mkdir -p "$RADICE/var/log/oversica"
    echo "riga della schermata di accesso" > "$RADICE/var/log/oversica/accesso.log"
    echo "riga di hyprland dell'accesso" > "$RADICE/var/log/oversica/accesso-hyprland.log"
    finto_con journalctl <<'FINE'
case "$*" in *greetd*) echo "riga di greetd" ;; *) echo "avviso del sistema" ;; esac
FINE
    finto pgrep 1
    cmd_registri >/dev/null 2>&1
    local f="$RADICE/mnt/vetro/registri-vetro.txt"
    esiste "$f"
    contiene "$f" "=== Passi falliti"
    contiene "$f" "errore del passo desktop"
    non_contiene "$f" "registro del passo fatto"
    contiene "$f" "=== Registro di sistema (avvisi)"
    contiene "$f" "=== Registro di sistema, accensione precedente (avvisi)"
    contiene "$f" "avviso del sistema"
    contiene "$f" "=== Hyprland"
    contiene "$f" "riga di hyprland"
    contiene "$f" "=== Pannelli (Quickshell)"
    contiene "$f" "riga dei pannelli"
    contiene "$f" "=== Schermi e finestre"
    # la schermata di accesso (greetd): il suo registro e quello di greetd
    contiene "$f" "=== Schermata di accesso"
    contiene "$f" "riga della schermata di accesso"
    contiene "$f" "riga di hyprland dell'accesso"
    contiene "$f" "riga di greetd"
    # la data dei registri del desktop (per capire se sono di oggi o vecchi)
    contiene "$f" "(file del $(date '+%F') "
    non_esiste "$RADICE/root/registri-vetro.txt"
}

test_registri_root() {
    radice_finta; meminfo 7400000; finto journalctl; finto pgrep 1
    cmd_registri >/dev/null 2>&1
    esiste "$RADICE/root/registri-vetro.txt"
}

test_dove_sono() {
    radice_finta
    export VETRO_PC="$RADICE/pc/vetro-arch"
    rm -f "$RADICE/etc/arch-release"
    uguale "pc" "$(dove_sono)" "senza /etc/arch-release: sul PC"
    mkdir -p "$RADICE/etc"; : > "$RADICE/etc/arch-release"
    uguale "arch" "$(dove_sono)" "con /etc/arch-release: dentro Arch"
    mkdir -p "$VETRO_PC"; : > "$VETRO_PC/disco.qcow2"
    uguale "pc" "$(dove_sono)" "un PC con Arch che ha la macchina virtuale: sul PC"
}

test_aiuto_comandi() {
    aiuto > "$ARCH_DIR/.aiuto" 2>&1
    contiene "$ARCH_DIR/.aiuto" "sudo bash lfs.sh fase10"
    contiene "$ARCH_DIR/.aiuto" "sudo bash lfs.sh avvia"
    contiene "$ARCH_DIR/.aiuto" "sudo bash lfs.sh installa"
    contiene "$ARCH_DIR/.aiuto" "sudo bash lfs.sh registri"
    rm -f "$ARCH_DIR/.aiuto"
}

test_comandi_pc_senza_pezzo() {
    # se il pezzo del PC manca, fase10 si ferma con un messaggio chiaro
    ( unset -f pc_fase10 2>/dev/null; principale fase10 ) > "$ARCH_DIR/.uscita" 2>&1
    uguale 1 "$?" "fase10 senza il pezzo del PC si ferma"
    rm -f "$ARCH_DIR/.uscita"
}

prova test_dove_sono
prova test_aiuto_comandi
prova test_comandi_pc_senza_pezzo
prova test_ram
prova test_servizi
prova test_registri_condivisa
prova test_registri_root
riassunto
