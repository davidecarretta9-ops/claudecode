#!/bin/bash
# Prove della rete: systemd-networkd, iwd e il Wi-Fi nel centro di controllo (Task 7)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
V="$F/etc/xdg/quickshell/vetro"
QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}

test_file_rete() {
    contiene "$F/etc/systemd/network/10-cavo.network" "Name=en* eth*"
    contiene "$F/etc/systemd/network/10-cavo.network" "DHCP=yes"
    contiene "$F/etc/systemd/network/10-wifi.network" "Name=wl*"
    contiene "$F/etc/systemd/network/10-wifi.network" "DHCP=yes"
    contiene "$F/etc/systemd/network/10-wifi.network" "IgnoreCarrierLoss=3s"
    contiene "$F/etc/iwd/main.conf" "EnableNetworkConfiguration=false"
    contiene "$F/etc/iwd/main.conf" "AddressRandomization=network"
    if [ -x "$F/usr/local/bin/vetro-wifi" ]; then ok_prova "vetro-wifi si puo' eseguire"
    else fallita "vetro-wifi manca o non si puo' eseguire"; fi
}

test_f2_rete() {
    radice_finta; finto pacman; finto systemctl
    f2_rete >/dev/null
    esiste "$RADICE/etc/systemd/network/10-cavo.network"
    esiste "$RADICE/etc/iwd/main.conf"
    esiste "$RADICE/usr/local/bin/vetro-wifi"
    chiamato "pacman -S --needed --noconfirm iwd"
    chiamato "systemctl enable systemd-networkd.service systemd-resolved.service iwd.service"
    chiamato "systemctl start systemd-resolved.service"
    uguale "/run/systemd/resolve/stub-resolv.conf" "$(readlink "$RADICE/etc/resolv.conf")" \
           "resolv.conf porta allo stub di systemd-resolved"
}

test_fase2_ha_rete() {
    case " ${FASE2[*]} " in
        *"rete|f2_rete|"*) ok_prova "la fase 2 ha il passo rete" ;;
        *) fallita "la fase 2 non ha il passo rete" ;;
    esac
    case " ${PKG_FASE2[*]} " in *" iwd "*) ok_prova "iwd e' tra i pacchetti" ;; *) fallita "manca iwd tra i pacchetti" ;; esac
}

test_pannello_wifi() {
    contiene "$V/Pannello.qml" "Wifi {"
    contiene "$V/Wifi.qml" '"/usr/local/bin/vetro-wifi", "elenco"'
    contiene "$V/Wifi.qml" '"/usr/local/bin/vetro-wifi", "collega"'
    local f
    for f in Wifi.qml Pannello.qml; do
        if [ -f "$V/$f" ] && [ -x "$QMLLINT" ] && ! "$QMLLINT" "$V/$f" 2>&1 | grep -q '\[syntax\]'; then
            ok_prova "$f senza errori di sintassi"
        else fallita "$f: errori di sintassi o manca qmllint"; fi
    done
}

test_ordine_file_rete() {
    # networkd usa il PRIMO file (in ordine alfabetico) che va bene per la scheda:
    # i nostri devono venire prima di quelli che archinstall copia dalla ISO
    local f n
    for f in "$F"/etc/systemd/network/*.network; do
        n=$(basename "$f")
        if [[ "$n" < "20-ethernet.network" && "$n" < "20-wlan.network" ]]; then
            ok_prova "$n viene prima di quelli di archinstall"
        else fallita "$n viene dopo 20-ethernet/20-wlan.network di archinstall"; fi
    done
}

prova test_ordine_file_rete
prova test_file_rete
prova test_f2_rete
prova test_fase2_ha_rete
prova test_pannello_wifi
riassunto
