#!/bin/bash
# Prove dei pacchetti (Task 2)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src

conf_pacman() {
    cat > "$RADICE/etc/pacman.conf" <<'FINE'
[options]
HoldPkg     = pacman glibc

[extra]
Include = /etc/pacman.d/mirrorlist

#[multilib-testing]
#Include = /etc/pacman.d/mirrorlist

#[multilib]
#Include = /etc/pacman.d/mirrorlist
FINE
}

test_multilib() {
    radice_finta; conf_pacman; finto pacman
    abilita_multilib >/dev/null
    contiene "$RADICE/etc/pacman.conf" $'\n[multilib]\nInclude = /etc/pacman.d/mirrorlist'
    uguale "1" "$(grep -c '^\[multilib\]$' "$RADICE/etc/pacman.conf")" "multilib acceso una volta"
    uguale "1" "$(grep -c '^#\[multilib-testing\]$' "$RADICE/etc/pacman.conf")" "multilib-testing resta spento"
    cp "$RADICE/etc/pacman.conf" "$RADICE/prima"
    abilita_multilib >/dev/null
    cmp -s "$RADICE/prima" "$RADICE/etc/pacman.conf"
    uguale "0" "$?" "rifarlo non cambia il file"
    chiamato "pacman -Sy"
}

test_mancanti() {
    radice_finta
    finto_con pacman <<'FINE'
[ "$1 $2" = "-Si inesistente" ] && exit 1
exit 0
FINE
    local msg; msg=$( (controlla_pacchetti hyprland inesistente) 2>&1 ); local rc=$?
    uguale "1" "$rc" "con un pacchetto che non c'e' esce con 1"
    case "$msg" in *inesistente*) ok_prova "dice quale manca" ;; *) fallita "dice quale manca: $msg" ;; esac
    case "$msg" in *hyprland*) fallita "non deve citare quelli che ci sono" ;; *) ok_prova "non cita quelli che ci sono" ;; esac
}

test_tentativi() {
    radice_finta
    finto_con pacman <<FINE
n=\$(cat "$RADICE/volte" 2>/dev/null || echo 0); n=\$((n + 1)); echo \$n > "$RADICE/volte"
[ \$n -ge 3 ]
FINE
    installa_pacchetti foot >/dev/null 2>&1
    uguale "0" "$?" "al terzo tentativo riesce"
    uguale "3" "$(grep -c '^pacman -S --needed --noconfirm foot$' "$RADICE/.chiamate")" "tre tentativi"
}

test_controllo_iniziale() {
    radice_finta
    finto_con pacman <<'FINE'
[ "$1 $2" = "-Si b" ] && exit 1
exit 0
FINE
    PKG_FASE1=(a quickshell); PKG_FASE2=(); PKG_FASE3=(b); PKG_FASE4=()
    local msg; msg=$( (controlla_tutti_i_pacchetti) 2>&1 ); local rc=$?
    uguale "1" "$rc" "con un pacchetto mancante esce con 1"
    case "$msg" in *b*) ok_prova "dice quale manca" ;; *) fallita "dice quale manca: $msg" ;; esac
    non_chiamato "pacman -S "
    non_chiamato "pacman -Si quickshell"
}

test_quickshell_ripiego() {
    radice_finta
    finto_con pacman <<'FINE'
[ "$1 $2" = "-Si quickshell" ] && exit 1
exit 0
FINE
    finto_con curl <<'FINE'
while [ $# -gt 0 ]; do [ "$1" = -o ] && { echo "file sbagliato" > "$2"; shift; }; shift; done
FINE
    local msg; msg=$( (installa_quickshell) 2>&1 ); local rc=$?
    uguale "1" "$rc" "con il file sbagliato si ferma"
    case "$msg" in *controllo*) ok_prova "dice che il controllo non passa" ;; *) fallita "dice che il controllo non passa: $msg" ;; esac
    chiamato "curl "
    non_chiamato "cmake -S"
}

prova test_multilib
prova test_mancanti
prova test_tentativi
prova test_controllo_iniziale
prova test_quickshell_ripiego
riassunto
