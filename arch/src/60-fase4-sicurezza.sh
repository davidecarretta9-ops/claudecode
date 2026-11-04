# --- Fase 4: sicurezza ----------------------------------------------------------------------
# Firewall (nessuno entra da fuori), Guardiano della rete (chiede prima che un programma
# esca), modalita' fantasma (tutto da Tor, accesa di serie) e l'utente fantasma.
PKG_FASE4=(iptables tor wireguard-tools)
FILE_SICUREZZA="etc/modules-load.d/vetro.conf usr/local/sbin/firewall-avvia
                usr/local/sbin/guardiano-rete usr/local/sbin/fantasma-aiuto
                usr/local/bin/guardiano-avvisi usr/local/bin/guardiano-regole usr/local/bin/fantasma
                usr/local/lib/fantasma etc/systemd/system/firewall.service
                etc/systemd/system/guardiano-rete.service etc/systemd/system/tor-fantasma.service
                etc/systemd/system/fantasma-avvio.service etc/sudoers.d/30-fantasma
                usr/share/applications/fantasma.desktop usr/share/applications/guardiano-regole.desktop"
FILE_UTENTE_FANTASMA="etc/systemd/system/home-fantasma.mount etc/systemd/system/fantasma-casa.service
                      etc/sudoers.d/31-utente-fantasma usr/local/share/fantasma/casa"
FILE_VPN="usr/local/sbin/vpn-aiuto usr/local/bin/vpn etc/systemd/system/vpn.service
          etc/sudoers.d/20-vpn usr/share/applications/vpn.desktop"
FILE_CASSAFORTE="usr/local/bin/cassaforte usr/share/applications/cassaforte.desktop
                 usr/share/applications/cassaforte-chiudi.desktop"
# DNS, VPN e cassaforte PRIMA della modalita' fantasma: accesa di serie, scrive il DNS
# verso Tor, e dopo non si deve piu' toccare systemd-resolved (installazione senza DNS)
FASE4=("dns|f4_dns|etc/systemd/resolved.conf.d/10-vetro-dns.conf"
       "vpn|f4_vpn|$(echo $FILE_VPN)"
       "cassaforte|f4_cassaforte|$(echo $FILE_CASSAFORTE)"
       "fantasma|f4_fantasma|$(echo $FILE_SICUREZZA)"
       "utente-fantasma|f4_utente_fantasma|$(echo $FILE_UTENTE_FANTASMA)")

# installa solo i pacchetti che mancano: "pacman -T" guarda anche chi li fornisce (es.
# iptables-nft al posto di iptables, che pacman --noconfirm non sostituirebbe)
installa_se_mancano() {
    local mancano
    mancano=$(esegui pacman -T "$@") || true
    # shellcheck disable=SC2086
    if [ -n "$mancano" ]; then installa_pacchetti $mancano; fi
}

# il DNS cifrato (Quad9, DNS-over-TLS): vale dal prossimo avvio (systemd-resolved non
# si riavvia adesso, cosi' l'installazione non resta senza nomi se la rete blocca il TLS)
f4_dns() {
    installa_file etc/systemd/resolved.conf.d/10-vetro-dns.conf
    ok "DNS cifrato (Quad9), dal prossimo avvio"
}

# la VPN WireGuard: si sceglie il file e si accende dal menu (VPN)
f4_vpn() {
    installa_se_mancano wireguard-tools
    # wg-quick passa i DNS della VPN a "resolvconf": con systemd-resolved e' systemd-resolvconf
    if [ -n "$(esegui pacman -T resolvconf || true)" ]; then
        installa_pacchetti systemd-resolvconf
    fi
    # shellcheck disable=SC2086
    installa_file $FILE_VPN
    esegui visudo -cf "$(percorso /etc/sudoers.d/20-vpn)"
    ok "VPN WireGuard (si accende dal menu: VPN)"
}

# la cassaforte usa la cifratura di ext4 (fscrypt): serve la funzione "encrypt" del disco
f4_cassaforte() {
    local tipo disco caratteristiche
    tipo=$(esegui findmnt -no FSTYPE -T /home 2>/dev/null || true)
    if [ "$tipo" != ext4 ]; then
        avviso "La cassaforte ha bisogno di ext4: la salto"
        return 0
    fi
    disco=$(esegui findmnt -no SOURCE -T /home)
    caratteristiche=$(esegui dumpe2fs -h "$disco" 2>/dev/null || true)
    if ! grep -qw encrypt <<<"$caratteristiche"; then
        esegui tune2fs -O encrypt "$disco"
    fi
    # shellcheck disable=SC2086
    installa_file $FILE_CASSAFORTE
    ok "Cassaforte (cartella cifrata)"
}

f4_fantasma() {
    local p u
    installa_se_mancano "${PKG_FASE4[@]}"
    for p in $FILE_SICUREZZA; do
        if [ -d "$VETRO_FILE/$p" ]; then installa_cartella "$p"; else installa_file "$p"; fi
    done
    esegui visudo -cf "$(percorso /etc/sudoers.d/30-fantasma)"
    # le regole del Guardiano: il servizio puo' scrivere solo li' (ReadWritePaths), e
    # senza la cartella non parte (e i tuoi programmi resterebbero senza internet)
    mkdir -p "$(percorso /etc/guardiano-rete)"
    chmod 755 "$(percorso /etc/guardiano-rete)"
    p=$(percorso /etc/guardiano-rete/regole)
    [ -f "$p" ] || printf '# Regole del Guardiano della rete: permetti/blocca <TAB> programma\n' > "$p"
    chmod 644 "$p"
    # il gruppo che risponde alle domande del Guardiano
    u=$(utente_vetro) || exit 1
    esegui groupadd -f guardiano
    esegui usermod -aG guardiano "$u"
    # icona del fantasma (lo sfondo non cambia piu': in oversicaOS c'e' l'icona nella barra)
    rm -f "$(percorso /usr/share/backgrounds/sfondo-fantasma.png)"
    for p in 32 48 64 128 256; do
        mkdir -p "$(percorso "/usr/share/icons/hicolor/${p}x${p}/apps")"
        esegui python3 -I "$(percorso /usr/local/lib/fantasma/disegna-fantasma)" icona \
               "$(percorso "/usr/share/icons/hicolor/${p}x${p}/apps/fantasma.png")" "$p"
    done
    esegui gtk-update-icon-cache -qtf "$(percorso /usr/share/icons/hicolor)" || true
    # Thunderbird in modalita' fantasma avvisa prima di aprirsi
    if [ -e "$(percorso /usr/bin/thunderbird)" ]; then
        ln -sfn ../lib/fantasma/avviso-fantasma "$(percorso /usr/local/bin/thunderbird)"
    fi
    # accesa di serie, una volta sola: se poi la spegni, rifacendo il passo resta spenta
    if [ ! -e "$(percorso /etc/fantasma/predefinita)" ]; then
        esegui python3 -I "$(percorso /usr/local/sbin/fantasma-aiuto)" prepara
        mkdir -p "$(percorso /etc/fantasma)"
        touch "$(percorso /etc/fantasma/predefinita)"
    fi
    esegui systemctl enable fantasma-avvio.service firewall.service guardiano-rete.service
    ok "Firewall, Guardiano della rete e modalita' fantasma (accesa)"
}

f4_utente_fantasma() {
    local uid gid
    if ! esegui id fantasma >/dev/null 2>&1; then
        esegui useradd -m -G video,input,audio,guardiano -s /bin/bash \
               -c "Utente fantasma (tutto in memoria)" fantasma
    fi
    esegui usermod -aG video,input,audio,guardiano fantasma
    uid=$(esegui id -u fantasma)
    gid=$(esegui id -g fantasma)
    installa_file etc/systemd/system/fantasma-casa.service etc/sudoers.d/31-utente-fantasma
    installa_cartella usr/local/share/fantasma/casa
    esegui visudo -cf "$(percorso /etc/sudoers.d/31-utente-fantasma)"
    mkdir -p "$(percorso /etc/systemd/system)"
    sed -e "s/@UID@/$uid/" -e "s/@GID@/$gid/" "$VETRO_FILE/etc/systemd/system/home-fantasma.mount" \
        > "$(percorso /etc/systemd/system/home-fantasma.mount)"
    esegui systemctl enable home-fantasma.mount fantasma-casa.service
    ok "Utente fantasma (casa in memoria)"
}

# la password dell'utente fantasma: dall'impronta lasciata da "fase10", se c'e'; se no
# si chiede alla fine (i passi non possono chiedere niente), solo se non ce l'ha ancora
password_fantasma() {
    # installata da "fase10": l'impronta della password l'ha data il PC
    local impronta
    impronta=$(percorso /etc/vetro/fantasma.hash)
    if [ -s "$impronta" ]; then
        esegui usermod -p "$(cat "$impronta")" fantasma
        rm -f "$impronta"
        return 0
    fi
    [ -n "${VETRO_PROVA:-}" ] && return 0
    case "$(esegui passwd -S fantasma 2>/dev/null | cut -d' ' -f2 || true)" in
        L|NP) ;;
        *) return 0 ;;
    esac
    titolo "Password dell'utente fantasma (per entrare dalla schermata di accesso)"
    local volta
    for volta in 1 2 3; do
        if esegui passwd fantasma; then return 0; fi
        avviso "Password non cambiata, riprova ($volta di 3)"
    done
    avviso "Password del fantasma non impostata: la metti dopo con  sudo passwd fantasma"
}
