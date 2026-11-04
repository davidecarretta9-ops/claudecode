#!/bin/bash
# Prove della rete di oversicaOS: NetworkManager (lo usa Caelestia), attivo dal riavvio
# dopo; systemd-networkd resta solo per il primo avvio di una macchina nuova
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"

test_conf_nm() {
    local c="$F/etc/NetworkManager/conf.d/10-oversica.conf"
    # niente DNS del router: i nomi li chiede systemd-resolved (Quad9 cifrato o Tor)
    contiene "$c" "dns=none"
    contiene "$c" "rc-manager=unmanaged"
    # il nome del computer non va al router
    contiene "$c" "ipv4.dhcp-send-hostname=false"
    contiene "$c" "ipv6.dhcp-send-hostname=false"
    contiene "$c" "ipv6.ip6-privacy=2"
}

test_rete_cambia_al_riavvio() {
    radice_finta; finto pacman; finto systemctl
    ( f4_rete ) >/dev/null 2>&1
    uguale 0 "$?" "f4_rete finisce"
    esiste "$RADICE/etc/NetworkManager/conf.d/10-oversica.conf"
    chiamato "pacman -S --needed --noconfirm networkmanager"
    chiamato "systemctl enable NetworkManager.service NetworkManager-wait-online.service"
    chiamato "systemctl disable systemd-networkd.service systemd-networkd-wait-online.service iwd.service"
    # niente start/stop adesso: la rete di questa installazione non si interrompe
    non_chiamato "systemctl start"
    non_chiamato "systemctl stop"
    non_chiamato "--now"
}

test_f2_nomi() {
    # i nomi dei siti passano da systemd-resolved: si accende subito, se no l'installazione
    # resterebbe senza DNS (serve al DNS cifrato e alla modalita' fantasma)
    radice_finta; finto systemctl
    ( f2_nomi ) >/dev/null 2>&1
    uguale 0 "$?" "f2_nomi finisce"
    chiamato "systemctl enable systemd-resolved.service"
    chiamato "systemctl start systemd-resolved.service"
    uguale "/run/systemd/resolve/stub-resolv.conf" "$(readlink "$RADICE/etc/resolv.conf")" \
           "resolv.conf porta allo stub di systemd-resolved"
    case " ${FASE2[*]} " in *"nomi|f2_nomi|"*) ok_prova "la fase 2 ha il passo nomi" ;; *) fallita "manca il passo nomi" ;; esac
}

test_rete_ultimo_passo() {
    local ultimo=${FASE4[${#FASE4[@]}-1]}
    case "$ultimo" in rete\|f4_rete\|*) ok_prova "la rete e' l'ultimo passo" ;; *) fallita "ultimo passo: $ultimo" ;; esac
    case " ${FASE2[*]} " in *"rete|"*) fallita "la fase 2 ha ancora il passo rete di iwd" ;; *) ok_prova "niente iwd nella fase 2" ;; esac
    case " ${PKG_FASE2[*]} " in *" iwd "*) fallita "iwd ancora tra i pacchetti" ;; *) ok_prova "iwd non serve piu'" ;; esac
}

test_leggero_non_spegne_nm() {
    radice_finta; finto pacman; finto systemctl
    mkdir -p "$RADICE/usr/lib/systemd/system"
    : > "$RADICE/usr/lib/systemd/system/NetworkManager.service"
    : > "$RADICE/usr/lib/systemd/system/cups.service"
    ( f1_leggero ) >/dev/null 2>&1
    non_chiamato "disable --now NetworkManager.service"
    chiamato "disable --now cups.service"
}

test_fantasma_prima_di_nm() {
    contiene "$F/etc/systemd/system/fantasma-avvio.service" "NetworkManager.service"
}

test_servizi_controlla() {
    case " $SERVIZI_VETRO " in *" NetworkManager "*) ok_prova "controlla guarda NetworkManager" ;; *) fallita "SERVIZI_VETRO: $SERVIZI_VETRO" ;; esac
    case " $SERVIZI_VETRO " in *" iwd "*|*" systemd-networkd "*) fallita "SERVIZI_VETRO ha ancora iwd o networkd" ;; *) ok_prova "niente iwd e networkd" ;; esac
}

test_vecchi_file_tolti() {
    non_esiste "$F/etc/systemd/network/10-wifi.network"
    non_esiste "$F/etc/iwd/main.conf"
    non_esiste "$F/usr/local/bin/vetro-wifi"
}

test_ordine_file_rete() {
    # networkd (solo primo avvio) usa il PRIMO file in ordine alfabetico: il nostro deve
    # venire prima di quelli che archinstall copia dalla ISO
    local f n
    for f in "$F"/etc/systemd/network/*.network; do
        n=$(basename "$f")
        if [[ "$n" < "20-ethernet.network" && "$n" < "20-wlan.network" ]]; then
            ok_prova "$n viene prima di quelli di archinstall"
        else fallita "$n viene dopo 20-ethernet/20-wlan.network di archinstall"; fi
    done
}

prova test_conf_nm
prova test_rete_cambia_al_riavvio
prova test_f2_nomi
prova test_rete_ultimo_passo
prova test_leggero_non_spegne_nm
prova test_fantasma_prima_di_nm
prova test_servizi_controlla
prova test_vecchi_file_tolti
prova test_ordine_file_rete
riassunto
