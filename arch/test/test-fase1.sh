#!/bin/bash
# Prove della fase 1, sistema leggero (Task 3)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src

test_file_leggero() {
    radice_finta; finto systemctl; finto pacman
    f1_leggero >/dev/null
    contiene "$RADICE/etc/systemd/zram-generator.conf" "[zram0]"
    contiene "$RADICE/etc/systemd/zram-generator.conf" "zram-size = ram / 2"
    contiene "$RADICE/etc/systemd/zram-generator.conf" "compression-algorithm = zstd"
    contiene "$RADICE/etc/systemd/oomd.conf.d/vetro.conf" "DefaultMemoryPressureDurationSec=20s"
    contiene "$RADICE/etc/systemd/journald.conf.d/vetro.conf" "SystemMaxUse=100M"
}

test_servizi() {
    radice_finta; finto systemctl; finto pacman
    mkdir -p "$RADICE/usr/lib/systemd/system"
    touch "$RADICE/usr/lib/systemd/system/NetworkManager.service"
    f1_leggero >/dev/null
    chiamato "systemctl enable systemd-oomd.service"
    chiamato "systemctl disable --now NetworkManager.service"
    non_chiamato "systemctl disable --now cups.service"
}

test_utente() {
    radice_finta; finto usermod; finto visudo
    finto_con getent <<'FINE'
[ "$1 $2" = "passwd 1000" ] && echo "mario:x:1000:1000::/home/mario:/bin/bash"
FINE
    f1_utente >/dev/null
    uguale "mario" "$(cat "$RADICE/etc/vetro/utente")" "l'utente e' scritto in /etc/vetro/utente"
    chiamato "usermod -aG wheel,video,input,audio mario"
    contiene "$RADICE/etc/sudoers.d/00-vetro" "%wheel ALL=(ALL) ALL"
    uguale "440" "$(stat -c %a "$RADICE/etc/sudoers.d/00-vetro")" "sudoers con permessi 440"
}

test_senza_utente() {
    radice_finta; finto usermod; finto visudo; finto getent 2
    ( f1_utente ) >/dev/null 2>&1
    uguale "1" "$?" "senza utente con UID 1000 si ferma"
}

prova test_file_leggero
prova test_servizi
prova test_utente
prova test_senza_utente
riassunto
