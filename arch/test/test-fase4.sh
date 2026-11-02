#!/bin/bash
# Prove della fase 4: firewall, Guardiano, modalita' fantasma e utente fantasma (Task 9)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"

# una cartella con i comandi finti per gli script del desktop (non passano da "esegui")
comandi_finti() {
    BIN="$RADICE/bin-finti"; mkdir -p "$BIN"
    local c
    for c in "$@"; do
        { echo '#!/bin/bash'; echo "echo \"$c \$*\" >> \"$RADICE/.chiamate\""; cat; } > "$BIN/$c"
        chmod +x "$BIN/$c"
    done < /dev/null
}
comando_finto() {   # comando_finto NOME  (corpo da stdin)
    { echo '#!/bin/bash'; echo "echo \"$1 \$*\" >> \"$RADICE/.chiamate\""; cat; } > "$BIN/$1"
    chmod +x "$BIN/$1"
}

test_spegni_senza_tor() {
    radice_finta; comandi_finti setsid notify-send
    comando_finto sudo <<'FINE'
case "$3" in stato) echo acceso ;; pronto) exit 1 ;; esac
exit 0
FINE
    comando_finto yad <<'FINE'
exit 2
FINE
    PATH="$BIN:$PATH" bash "$F/usr/local/bin/fantasma" >/dev/null 2>&1
    local prima; prima=$(grep -m1 "^yad " "$RADICE/.chiamate")
    case "$prima" in *"--button Spegni:2"*) ok_prova "la prima finestra ha Spegni" ;;
        *) fallita "la prima finestra non ha Spegni: $prima" ;; esac
    chiamato "fantasma-aiuto spegni"
    non_chiamato "fantasma-aiuto attendi"
}

test_desktop_fantasma() {
    radice_finta; comandi_finti Hyprland systemd-detect-virt
    comando_finto id <<'FINE'
echo fantasma
FINE
    comando_finto sudo <<'FINE'
exit 1
FINE
    HOME="$RADICE/casa" PATH="$BIN:$PATH" bash "$F/usr/local/bin/avvia-desktop" >/dev/null 2>&1
    uguale 1 "$?" "senza modalita' fantasma il desktop non parte"
    non_chiamato "Hyprland"
    comando_finto sudo <<'FINE'
exit 0
FINE
    : > "$RADICE/.chiamate"
    HOME="$RADICE/casa" PATH="$BIN:$PATH" bash "$F/usr/local/bin/avvia-desktop" >/dev/null 2>&1
    chiamato "Hyprland -c /etc/xdg/hypr/vetro.conf"
    local a h
    a=$(grep -n "fantasma-aiuto accendi" "$RADICE/.chiamate" | cut -d: -f1)
    h=$(grep -n "^Hyprland" "$RADICE/.chiamate" | cut -d: -f1)
    if [ -n "$a" ] && [ -n "$h" ] && [ "$a" -lt "$h" ]; then ok_prova "prima la modalita' fantasma, poi il desktop"
    else fallita "ordine sbagliato (accendi '$a', Hyprland '$h')"; fi
}

test_fase4() {
    contiene "$F/etc/modules-load.d/vetro.conf" "nfnetlink_queue"
    contiene "$F/etc/modules-load.d/vetro.conf" "xt_owner"
    contiene "$F/etc/modules-load.d/vetro.conf" "xt_NFQUEUE"
    radice_finta; finto systemctl; finto python3; finto groupadd; finto usermod
    finto visudo; finto gtk-update-icon-cache
    finto_con pacman <<'FINE'
[ "$1" = -T ] && { shift; printf '%s\n' "$@"; exit 127; }
exit 0
FINE
    echo vetro > "$RADICE/etc/vetro/utente" 2>/dev/null || { mkdir -p "$RADICE/etc/vetro"; echo vetro > "$RADICE/etc/vetro/utente"; }
    ( set -Eeuo pipefail; f4_fantasma ) >/dev/null || fallita "f4_fantasma si ferma"
    chiamato "pacman -S --needed --noconfirm iptables tor wireguard-tools"
    chiamato "systemctl enable fantasma-avvio.service firewall.service guardiano-rete.service"
    chiamato "python3 -I $RADICE/usr/local/sbin/fantasma-aiuto prepara"
    chiamato "groupadd -f guardiano"
    chiamato "usermod -aG guardiano vetro"
    esiste "$RADICE/etc/fantasma/predefinita"
    esiste "$RADICE/usr/local/sbin/firewall-avvia"
    esiste "$RADICE/etc/systemd/system/tor-fantasma.service"
    contiene "$RADICE/etc/systemd/system/guardiano-rete.service" "GUARDIANO_GRUPPO=guardiano"
    # il servizio ha ReadWritePaths=/etc/guardiano-rete: senza la cartella non parte
    esiste "$RADICE/etc/guardiano-rete/regole"
    uguale 644 "$(stat -c %a "$RADICE/etc/guardiano-rete/regole" 2>/dev/null)" "regole leggibili (644)"
    # la seconda volta (rifai) non la riaccende se l'avevi spenta
    : > "$RADICE/.chiamate"
    ( set -Eeuo pipefail; f4_fantasma ) >/dev/null || fallita "f4_fantasma si ferma (seconda volta)"
    non_chiamato "fantasma-aiuto prepara"
}

test_pacchetti_gia_presenti() {
    radice_finta; finto systemctl; finto python3; finto groupadd; finto usermod
    finto pacman      # -T esce 0: tutto c'e' gia' (anche iptables-nft al posto di iptables)
    mkdir -p "$RADICE/etc/vetro"; echo vetro > "$RADICE/etc/vetro/utente"
    finto visudo; finto gtk-update-icon-cache
    ( set -Eeuo pipefail; f4_fantasma ) >/dev/null || fallita "f4_fantasma si ferma"
    non_chiamato "pacman -S --needed"
}

test_utente_fantasma() {
    radice_finta; finto systemctl; finto useradd; finto usermod; finto visudo
    finto_con id <<'FINE'
case "$1" in -u|-g) echo 1001 ;; *) exit 1 ;; esac
FINE
    ( set -Eeuo pipefail; f4_utente_fantasma ) >/dev/null || fallita "f4_utente_fantasma si ferma"
    chiamato "visudo -cf $RADICE/etc/sudoers.d/31-utente-fantasma"
    chiamato "useradd -m -G video,input,audio,guardiano"
    chiamato "systemctl enable home-fantasma.mount fantasma-casa.service"
    contiene "$RADICE/etc/systemd/system/home-fantasma.mount" "uid=1001,gid=1001"
    non_contiene "$RADICE/etc/systemd/system/home-fantasma.mount" "@UID@"
    esiste "$RADICE/etc/sudoers.d/31-utente-fantasma"
    esiste "$RADICE/usr/local/share/fantasma/casa/.bash_profile"
    non_contiene "$RADICE/usr/local/share/fantasma/casa/.bash_profile" "labwc"
}

test_password_fantasma() {
    radice_finta
    finto_con passwd <<'FINE'
[ "$1" = -S ] && echo "fantasma L 2026-11-02 0 99999 7 -1"
exit 0
FINE
    password_fantasma >/dev/null 2>&1
    non_chiamato "passwd fantasma"           # nelle prove (VETRO_PROVA=1) non chiede
    VETRO_PROVA= password_fantasma >/dev/null 2>&1 < /dev/null
    chiamato "passwd fantasma"
}

test_script() {
    if bash -n "$F/usr/local/bin/fantasma" && bash -n "$F/usr/local/bin/avvia-desktop" \
            && bash -n "$F/usr/local/sbin/firewall-avvia"; then ok_prova "script bash: sintassi"
    else fallita "script bash: sintassi"; fi
    non_contiene "$F/usr/local/sbin/fantasma-aiuto" "lfs.sh"
    contiene "$F/etc/systemd/system/tor-fantasma.service" "User=tor"
}

prova test_spegni_senza_tor
prova test_desktop_fantasma
prova test_fase4
prova test_pacchetti_gia_presenti
prova test_utente_fantasma
prova test_password_fantasma
prova test_script
riassunto
