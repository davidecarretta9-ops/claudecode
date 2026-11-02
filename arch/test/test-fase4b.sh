#!/bin/bash
# Prove della fase 4, seconda parte: DNS cifrato, VPN e cassaforte (Task 10)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
DNS="$F/etc/systemd/resolved.conf.d/10-vetro-dns.conf"

test_dns() {
    contiene "$DNS" "[Resolve]"
    contiene "$DNS" "DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net"
    contiene "$DNS" "FallbackDNS="
    contiene "$DNS" "DNSOverTLS=yes"
    contiene "$DNS" "Domains=~."
    contiene "$DNS" "LLMNR=no"
    contiene "$DNS" "MulticastDNS=no"
    # la modalita' fantasma (99-fantasma.conf) deve venire DOPO e vincere
    if [[ "10-vetro-dns.conf" < "99-fantasma.conf" ]]; then ok_prova "il DNS di Vetro viene prima di quello fantasma"
    else fallita "ordine dei file DNS sbagliato"; fi
    # niente DNS del router: si usa solo quello cifrato
    local n
    for n in 10-cavo 10-wifi; do
        contiene "$F/etc/systemd/network/$n.network" "UseDNS=no"
        contiene "$F/etc/systemd/network/$n.network" "SendHostname=no"
    done
}

test_f4_dns() {
    radice_finta
    ( set -Eeuo pipefail; f4_dns ) >/dev/null || fallita "f4_dns si ferma"
    esiste "$RADICE/etc/systemd/resolved.conf.d/10-vetro-dns.conf"
    non_chiamato "systemctl restart systemd-resolved"
}

test_ordine_fase4() {
    local nomi="" riga
    for riga in "${FASE4[@]}"; do nomi+="${riga%%|*} "; done
    uguale "dns vpn cassaforte fantasma utente-fantasma " "$nomi" "ordine dei passi della fase 4"
}

test_vpn() {
    if bash -n "$F/usr/local/bin/vpn"; then ok_prova "vpn: sintassi"; else fallita "vpn: sintassi"; fi
    if python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$F/usr/local/sbin/vpn-aiuto"; then
        ok_prova "vpn-aiuto: sintassi"; else fallita "vpn-aiuto: sintassi"; fi
    radice_finta; finto visudo
    finto_con pacman <<'FINE'
[ "$1" = -T ] && { shift; printf '%s\n' "$@"; exit 127; }
exit 0
FINE
    ( set -Eeuo pipefail; f4_vpn ) >/dev/null || fallita "f4_vpn si ferma"
    esiste "$RADICE/usr/local/sbin/vpn-aiuto"
    esiste "$RADICE/etc/systemd/system/vpn.service"
    chiamato "pacman -S --needed --noconfirm systemd-resolvconf"
    chiamato "visudo -cf $RADICE/etc/sudoers.d/20-vpn"
    non_chiamato "systemctl enable vpn.service"
}

test_cassaforte_senza_ext4() {
    radice_finta; finto tune2fs
    finto_con findmnt <<'FINE'
case "$*" in *FSTYPE*) echo btrfs ;; *SOURCE*) echo /dev/vda2 ;; esac
FINE
    passo cassaforte f4_cassaforte "usr/local/bin/cassaforte" >/dev/null 2>&1
    uguale 0 "$?" "il passo finisce bene anche senza ext4"
    non_chiamato "tune2fs"
    contiene "$VETRO_STATO/registri/cassaforte.log" "La cassaforte ha bisogno di ext4: la salto"
    non_esiste "$RADICE/usr/local/bin/cassaforte"
}

test_cassaforte_ext4() {
    radice_finta; finto tune2fs
    finto_con findmnt <<'FINE'
case "$*" in *FSTYPE*) echo ext4 ;; *SOURCE*) echo /dev/vda2 ;; esac
FINE
    finto_con dumpe2fs <<'FINE'
echo "Filesystem features:      has_journal ext_attr resize_inode dir_index filetype extent"
FINE
    ( set -Eeuo pipefail; f4_cassaforte ) >/dev/null || fallita "f4_cassaforte si ferma"
    chiamato "tune2fs -O encrypt /dev/vda2"
    esiste "$RADICE/usr/local/bin/cassaforte"
    esiste "$RADICE/usr/share/applications/cassaforte.desktop"
    # gia' pronto: non lo rifa'
    finto_con dumpe2fs <<'FINE'
echo "Filesystem features:      has_journal ext_attr dir_index filetype extent encrypt"
FINE
    : > "$RADICE/.chiamate"
    ( set -Eeuo pipefail; f4_cassaforte ) >/dev/null || fallita "f4_cassaforte si ferma (seconda volta)"
    non_chiamato "tune2fs"
}

test_niente_lfs() {
    local f
    for f in usr/local/sbin/vpn-aiuto usr/local/bin/vpn usr/local/bin/cassaforte \
             etc/systemd/system/vpn.service etc/sudoers.d/20-vpn; do
        non_contiene "$F/$f" "lfs.sh"
    done
}

prova test_dns
prova test_f4_dns
prova test_ordine_fase4
prova test_vpn
prova test_cassaforte_senza_ext4
prova test_cassaforte_ext4
prova test_niente_lfs
riassunto
