#!/bin/bash
# vetro-arch.sh: generato da arch/costruisci.sh (i sorgenti sono in arch/src e arch/file)
set -Eeuo pipefail
# ===== 00-testa.sh
# =============================================================================
#  vetro-arch.sh — il desktop "Vetro" su Arch Linux (leggero, aspetto GNOME,
#  sicurezza: modalita' fantasma, firewall, Guardiano della rete, VPN...).
#  Si lancia come root su un Arch appena installato (guida: GUIDA-INSTALLAZIONE.md).
#
#    sudo bash vetro-arch.sh              fa tutto (o riprende da dove era)
#    sudo bash vetro-arch.sh controlla    a che punto e' il sistema
#    sudo bash vetro-arch.sh registri     raccoglie i registri in un file
#    sudo bash vetro-arch.sh rifai PASSO  rifa' un passo
#
#  Ogni passo, se si ferma, si riprende rilanciando lo script; se lo script
#  cambia un passo, quel passo si rifa' da solo.
# =============================================================================

# tutto quello che lo script scrive passa da qui (vuota = il disco vero; le prove
# usano una cartella finta)
VETRO_RADICE=${VETRO_RADICE:-}
VETRO_FILE=${VETRO_FILE:-}
FASE1=() FASE2=() FASE3=() FASE4=()

percorso() { printf '%s%s\n' "$VETRO_RADICE" "$1"; }
VETRO_STATO=$(percorso /var/lib/vetro-arch)

titolo() { printf '\n==> %s\n' "$*"; }
info()   { printf '  %s\n' "$*"; }
ok()     { printf '  [OK] %s\n' "$*"; }
avviso() { printf '  [!!] %s\n' "$*" >&2; }
muori()  { printf '\n  [ERRORE] %s\n\n' "$*" >&2; exit 1; }

serve_root() {
    [ "${VETRO_EUID:-$EUID}" -eq 0 ] || muori "Lancialo come root:  sudo bash $0 ${1:-}"
}

controlla_arch() {
    [ -f "$(percorso /etc/arch-release)" ] \
        || muori "Questo script e' fatto per Arch Linux (non trovo /etc/arch-release)"
}

# i comandi che cambiano il sistema (pacman, systemctl, useradd...) passano da qui:
# nelle prove si usano quelli finti, e un comando senza finto non parte mai
esegui() {
    if [ -n "$VETRO_RADICE" ]; then
        if [ -x "$VETRO_RADICE/.finti/${1##*/}" ]; then
            "$VETRO_RADICE/.finti/${1##*/}" "${@:2}"
            return
        fi
        echo "prova: manca il comando finto per '$1'" >&2
        return 127
    fi
    "$@"
}

# installa_file REL...: copia i file dello script (cartella file/) sul disco, con
# gli stessi permessi
installa_file() {
    local rel src dst
    for rel in "$@"; do
        src="$VETRO_FILE/$rel"
        dst=$(percorso "/$rel")
        [ -f "$src" ] || muori "Nello script manca il file $rel"
        install -D -m "$(stat -c %a "$src")" "$src" "$dst"
    done
}

# installa_cartella REL...: come installa_file, per tutti i file di una cartella
installa_cartella() {
    local rel f
    for rel in "$@"; do
        [ -d "$VETRO_FILE/$rel" ] || muori "Nello script manca la cartella $rel"
        while IFS= read -r f; do
            installa_file "$f"
        done < <(cd "$VETRO_FILE" && find "$rel" -type f | LC_ALL=C sort)
    done
}
# ===== 10-passi.sh
# --- il motore dei passi ----------------------------------------------------------
# Ogni passo ha un segno in $VETRO_STATO/fatto/NOME con l'impronta del suo testo e
# dei suoi file: se e' uguale il passo e' gia' fatto, se cambia si rifa'.

# impronta FUNZIONE [REL...]: sha256 del testo della funzione e dei file elencati
impronta() {
    local fn=$1 rel
    shift
    {
        declare -f "$fn"
        for rel in "$@"; do
            if [ -d "$VETRO_FILE/$rel" ]; then
                # una cartella: tutti i file dentro, in ordine, con il loro nome
                (cd "$VETRO_FILE" && find "$rel" -type f | LC_ALL=C sort | while IFS= read -r f; do
                    printf '== %s\n' "$f"; cat "$f"; done)
            else
                printf '== %s\n' "$rel"
                cat "$VETRO_FILE/$rel" 2>/dev/null || true
            fi
        done
    } | sha256sum | cut -d' ' -f1
}

# passo NOME FUNZIONE [REL...]: esegue la funzione (se non gia' fatta) con il suo
# registro; se si ferma mostra le ultime righe e lo script esce
passo() {
    local nome=$1 fn=$2
    shift 2
    local segno="$VETRO_STATO/fatto/$nome" registro="$VETRO_STATO/registri/$nome.log" imp esito=0
    imp=$(impronta "$fn" "$@")
    if [ -f "$segno" ] && [ "$(cat "$segno")" = "$imp" ]; then
        info "$nome (gia' fatto)"
        return 0
    fi
    mkdir -p "$VETRO_STATO/fatto" "$VETRO_STATO/registri"
    info "$nome..."
    # in sottofondo e non dentro un "if": cosi' "fermati al primo errore" vale davvero
    ( set -Eeuo pipefail; "$fn" ) > "$registro" 2>&1 < /dev/null &
    wait "$!" || esito=$?
    if [ "$esito" -ne 0 ]; then
        tail -n 15 "$registro" | sed 's/^/      | /' >&2
        muori "Il passo \"$nome\" non e' riuscito (registro: $registro). Rilancia lo script: riparte da qui."
    fi
    printf '%s\n' "$imp" > "$segno"
    grep -F '[OK]' "$registro" | sed 's/^ */    /' || true
    ok "$nome"
}

rifai_passo() { rm -f "$VETRO_STATO/fatto/$1"; }

# esegui_fase RIGA...: ogni riga e' "nome|funzione|file1 file2"
esegui_fase() {
    local riga nome fn file
    for riga in "$@"; do
        IFS='|' read -r nome fn file <<<"$riga"
        # shellcheck disable=SC2086
        passo "$nome" "$fn" $file
    done
}
# ===== 20-pacchetti.sh
# --- pacchetti: solo i repository ufficiali di Arch (core, extra, multilib) --------
# Le liste le riempiono le fasi (PKG_FASE1..PKG_FASE4). Unico ripiego: Quickshell
# compilato dai sorgenti ufficiali se un giorno non fosse nei repository.
PKG_FASE1=() PKG_FASE2=() PKG_FASE3=() PKG_FASE4=()

QUICKSHELL_URL="https://git.outfoxxed.me/quickshell/quickshell/archive/v0.3.2.tar.gz"
QUICKSHELL_SHA256="f14115a73c9fff6aa6399f924b632e88c3ce2cead2657f814a7825341f35baad"
QUICKSHELL_DIPENDENZE=(cmake ninja pkgconf qt6-base qt6-declarative qt6-wayland qt6-svg
                       qt6-shadertools wayland-protocols cli11 libdrm mesa pipewire
                       jemalloc pam polkit)

# multilib serve per Wine (i programmi Windows a 32 bit)
abilita_multilib() {
    local conf; conf=$(percorso /etc/pacman.conf)
    [ -f "$conf" ] || muori "Non trovo $conf"
    sed -i '/^#\[multilib\]$/{s/^#//;n;s/^#Include/Include/}' "$conf"
    esegui pacman -Sy --noconfirm >/dev/null
    ok "Repository multilib acceso"
}

# controlla_pacchetti PKG...: esce con 1 (e dice quali) se qualcuno non c'e'
controlla_pacchetti() {
    local p mancanti=()
    for p in "$@"; do
        esegui pacman -Si "$p" >/dev/null 2>&1 || mancanti+=("$p")
    done
    if [ "${#mancanti[@]}" -gt 0 ]; then
        avviso "Nei repository di Arch non trovo: ${mancanti[*]}"
        return 1
    fi
}

controlla_tutti_i_pacchetti() {
    local tutti=() p
    for p in "${PKG_FASE1[@]}" "${PKG_FASE2[@]}" "${PKG_FASE3[@]}" "${PKG_FASE4[@]}"; do
        [ "$p" = quickshell ] || tutti+=("$p")     # Quickshell: vedi installa_quickshell
    done
    [ "${#tutti[@]}" -gt 0 ] || return 0
    info "Controllo che i ${#tutti[@]} pacchetti ci siano tutti..."
    controlla_pacchetti "${tutti[@]}" \
        || muori "Mancano dei pacchetti: lo script va aggiornato (mandami questo messaggio)"
    ok "Ci sono tutti i pacchetti"
}

# installa_pacchetti PKG...: fino a 3 tentativi (la rete a volte si interrompe)
installa_pacchetti() {
    local volta
    for volta in 1 2 3; do
        if esegui pacman -S --needed --noconfirm "$@"; then return 0; fi
        avviso "pacman non e' riuscito (tentativo $volta di 3)"
        [ -n "$VETRO_RADICE" ] || sleep $((volta * 5))
    done
    muori "Non riesco a installare: $*"
}

installa_quickshell() {
    if esegui pacman -Si quickshell >/dev/null 2>&1; then
        installa_pacchetti quickshell
    else
        compila_quickshell
    fi
}

compila_quickshell() {
    info "Quickshell non e' nei repository: lo compilo dai sorgenti ufficiali (v0.3.2)"
    installa_pacchetti "${QUICKSHELL_DIPENDENZE[@]}"
    local t; t=$(mktemp -d)
    esegui curl -fL --retry 3 -o "$t/quickshell.tar.gz" "$QUICKSHELL_URL" \
        || { rm -rf "$t"; muori "Non riesco a scaricare Quickshell"; }
    if [ "$(sha256sum "$t/quickshell.tar.gz" | cut -d' ' -f1)" != "$QUICKSHELL_SHA256" ]; then
        rm -rf "$t"
        muori "Il file di Quickshell non passa il controllo (sha256): non lo uso"
    fi
    tar -xzf "$t/quickshell.tar.gz" -C "$t"
    esegui cmake -S "$t/quickshell" -B "$t/build" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX=/usr -DDISTRIBUTOR="vetro-arch.sh" -DCRASH_HANDLER=OFF
    esegui ninja -C "$t/build"
    esegui ninja -C "$t/build" install
    rm -rf "$t"
    ok "Quickshell compilato e installato"
}
# ===== 30-fase1-sistema.sh
# --- Fase 1: sistema leggero ---------------------------------------------------------
PKG_FASE1=(zram-generator python sudo)
FASE1=(
    "leggero|f1_leggero|etc/systemd/zram-generator.conf etc/systemd/oomd.conf.d/vetro.conf etc/systemd/journald.conf.d/vetro.conf"
    "utente|f1_utente|"
)

# il tuo utente: quello scritto in /etc/vetro/utente, altrimenti quello con UID 1000
# (lo crea archinstall), che poi si scrive li'
utente_vetro() {
    local f u; f=$(percorso /etc/vetro/utente)
    if [ -s "$f" ]; then cat "$f"; return 0; fi
    u=$(esegui getent passwd 1000 | cut -d: -f1)
    [ -n "$u" ] || muori "Non trovo il tuo utente (UID 1000): crealo con archinstall, poi rilancia"
    mkdir -p "$(dirname "$f")"
    printf '%s\n' "$u" > "$f"
    printf '%s\n' "$u"
}

f1_leggero() {
    installa_pacchetti "${PKG_FASE1[@]}"
    installa_file etc/systemd/zram-generator.conf etc/systemd/oomd.conf.d/vetro.conf \
                  etc/systemd/journald.conf.d/vetro.conf
    esegui systemctl enable systemd-oomd.service
    # servizi che qui non servono (la rete la fa systemd-networkd, vedi Fase 2)
    local s
    for s in NetworkManager.service cups.service; do
        if [ -e "$(percorso "/usr/lib/systemd/system/$s")" ]; then esegui systemctl disable --now "$s"; fi
    done
    if [ -e "$(percorso /usr/lib/systemd/system/bluetooth.service)" ] \
       && [ -z "$(ls -A "$(percorso /sys/class/bluetooth)" 2>/dev/null)" ]; then
        esegui systemctl disable --now bluetooth.service
    fi
    ok "Memoria compressa (zram), guardiano della memoria e registro leggero"
}

f1_utente() {
    local u; u=$(utente_vetro) || exit 1
    esegui usermod -aG wheel,video,input,audio "$u"
    local f; f=$(percorso /etc/sudoers.d/00-vetro)
    mkdir -p "$(dirname "$f")"
    printf '# vetro-arch.sh: chi e'"'"' nel gruppo wheel puo'"'"' usare sudo (con la password)\n%%wheel ALL=(ALL) ALL\n' > "$f"
    chmod 440 "$f"
    esegui visudo -cf "$f" >/dev/null
    ok "Utente $u: gruppi e sudo"
}
# ===== 40-fase2-desktop.sh
# --- Fase 2: desktop Vetro con l'aspetto di GNOME ---------------------------------------
PKG_FASE2=(hyprland quickshell greetd xdg-desktop-portal-hyprland pipewire wireplumber
           pipewire-pulse adwaita-fonts adwaita-icon-theme gnome-themes-extra grim slurp
           swayidle swaylock libnotify jq git cmake ninja meson cpio base-devel)
FILE_DESKTOP="etc/xdg/quickshell/vetro etc/xdg/hypr usr/local/lib/vetro etc/gtk-3.0 etc/gtk-4.0
              usr/local/bin/avvia-desktop usr/local/bin/avvio-vetro usr/local/bin/avvia-pannelli
              usr/local/bin/blocca-schermo usr/local/bin/sfondo-desktop
              usr/local/bin/vetro-barre-aggiorna etc/pam.d/vetro-blocco
              etc/pacman.d/hooks/vetro-barre.hook usr/share/icons/default/index.theme"
FASE2=("desktop|f2_desktop|$(echo $FILE_DESKTOP)")

# il carattere delle icone dei pannelli (Material Symbols): non c'e' nei pacchetti
# ufficiali di Arch, si scarica da Google a una versione fissa e si controlla
FONT_ICONE_URL="https://github.com/google/material-design-icons/raw/10ecc14790612ca8fd164e3f4ffe9c16fc50d5b7/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
FONT_ICONE_SHA256=7e74e36533ccee12c2b81e75bfcf3ccf123d3bb7e7e46d65d94445f23db0c97c

installa_font_icone() {
    local dst tmp
    dst=$(percorso /usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf)
    if [ -f "$dst" ] && echo "$FONT_ICONE_SHA256  $dst" | sha256sum -c --status; then
        return 0
    fi
    tmp=$(mktemp)
    if ! esegui curl -fsSL --retry 3 -o "$tmp" "$FONT_ICONE_URL"; then
        rm -f "$tmp"
        muori "Non riesco a scaricare il carattere delle icone: controlla la rete e rilancia"
    fi
    if ! echo "$FONT_ICONE_SHA256  $tmp" | sha256sum -c --status; then
        rm -f "$tmp"
        muori "Il carattere delle icone scaricato non passa il controllo (sha256): rilancia piu' tardi"
    fi
    install -D -m 644 "$tmp" "$dst"
    rm -f "$tmp"
    esegui fc-cache -f
}

f2_desktop() {
    local senza=() p s
    for p in "${PKG_FASE2[@]}"; do [ "$p" = quickshell ] || senza+=("$p"); done
    installa_pacchetti "${senza[@]}"
    installa_quickshell
    installa_font_icone
    for p in $FILE_DESKTOP; do
        if [ -d "$VETRO_FILE/$p" ]; then installa_cartella "$p"; else installa_file "$p"; fi
    done
    # puntatori (freccia bianca stile Windows) e sfondi, disegnati con Python
    esegui python3 -I "$(percorso /usr/local/lib/vetro/disegna-cursori)" "$(percorso /usr/share/icons/Vetro)"
    mkdir -p "$(percorso /usr/share/backgrounds)"
    for s in notte alba nebbia; do
        [ -f "$(percorso "/usr/share/backgrounds/vetro-$s.png")" ] \
            || esegui python3 -I "$(percorso /usr/local/lib/vetro/disegna-vetro)" \
                      "$(percorso "/usr/share/backgrounds/vetro-$s.png")" "$s"
    done
    # barre del titolo: file vuoto finche' il plugin non c'e', poi il plugin
    p=$(percorso /etc/xdg/hypr/vetro-barre.conf)
    [ -f "$p" ] || echo "# Barre del titolo: vuoto finche' il plugin hyprbars non c'e'" > "$p"
    esegui "$(percorso /usr/local/bin/vetro-barre-aggiorna)"
    esegui systemctl --global enable pipewire.socket wireplumber.service pipewire-pulse.socket
    ok "Desktop Vetro con l'aspetto di GNOME"
}

# --- la schermata di accesso: greetd apre accesso.qml in un Hyprland tutto suo ----------
FASE2+=("accesso|f2_accesso|etc/greetd/config.toml etc/vetro/accesso-hyprland.conf")

f2_accesso() {
    installa_pacchetti greetd
    installa_file etc/greetd/config.toml etc/vetro/accesso-hyprland.conf
    # l'utente "greeter" (lo crea il pacchetto greetd) deve poter usare la scheda video
    esegui usermod -aG video greeter
    esegui systemctl enable greetd.service
    # greetd usa la prima console: il login di testo li' non serve piu'
    esegui systemctl disable getty@tty1.service
    ok "Schermata di accesso (greetd)"
}

# --- la rete: systemd-networkd (indirizzi), systemd-resolved (nomi), iwd (Wi-Fi) --------
PKG_FASE2+=(iwd)
FASE2+=("rete|f2_rete|etc/systemd/network/10-cavo.network etc/systemd/network/10-wifi.network etc/iwd/main.conf usr/local/bin/vetro-wifi")

f2_rete() {
    installa_pacchetti iwd
    installa_file etc/systemd/network/10-cavo.network etc/systemd/network/10-wifi.network \
                  etc/iwd/main.conf usr/local/bin/vetro-wifi
    esegui systemctl enable systemd-networkd.service systemd-resolved.service iwd.service
    # i nomi (DNS) passano da systemd-resolved: lo si accende subito, se no lo script
    # resterebbe senza DNS per il resto dell'installazione
    if esegui systemctl start systemd-resolved.service; then
        mkdir -p "$(percorso /etc)"
        ln -sfn /run/systemd/resolve/stub-resolv.conf "$(percorso /etc/resolv.conf)"
    else
        avviso "systemd-resolved non parte: lascio /etc/resolv.conf com'e'"
    fi
    ok "Rete via cavo e Wi-Fi (iwd)"
}
# ===== 50-fase3-programmi.sh
# --- Fase 3: i programmi ------------------------------------------------------------------
# Tor Browser (l'unico browser), posta, ufficio, file, testi, terminale e i programmi
# Windows (Wine, sempre nel recinto). Wine sta nel deposito "multilib".
PKG_FASE3=(torbrowser-launcher thunderbird thunderbird-i18n-it libreoffice-fresh
           libreoffice-fresh-it thunar mousepad foot yad wine wine-mono wine-gecko
           bubblewrap xdg-utils)
FILE_PROGRAMMI="usr/local/bin/tor-browser usr/local/bin/browser-predefinito usr/local/bin/wine
                usr/local/lib/wine-recinto/xdg-open etc/xdg/mimeapps.list
                usr/share/applications/tor-browser.desktop
                usr/local/share/applications/torbrowser.desktop
                usr/local/share/applications/wine.desktop"
FASE3=("programmi|f3_programmi|$(echo $FILE_PROGRAMMI)")

# i comandi di Wine che passano anche loro dal recinto (se Wine li ha)
STRUMENTI_WINE="msidb msiexec notepad regedit regsvr32 wineboot winecfg wineconsole winedbg
                winefile winemine winepath wineserver"

f3_programmi() {
    local t
    abilita_multilib
    installa_pacchetti "${PKG_FASE3[@]}"
    # shellcheck disable=SC2086
    installa_file $FILE_PROGRAMMI
    for t in $STRUMENTI_WINE; do
        if [ -e "$(percorso "/usr/bin/$t")" ]; then
            ln -sfn wine "$(percorso "/usr/local/bin/$t")"
        fi
    done
    ok "Programmi: Tor Browser, Thunderbird, LibreOffice, Thunar, Mousepad, foot, Wine nel recinto"
}
# ===== 60-fase4-sicurezza.sh
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
    # sfondo scuro e icona del fantasma
    mkdir -p "$(percorso /usr/share/backgrounds)"
    esegui python3 -I "$(percorso /usr/local/lib/fantasma/disegna-fantasma)" sfondo \
           "$(percorso /usr/share/backgrounds/sfondo-fantasma.png)"
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

# la password dell'utente fantasma: si chiede alla fine (i passi non possono chiedere
# niente), solo se non ce l'ha ancora
password_fantasma() {
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
# ===== 90-comandi.sh
# --- i comandi --------------------------------------------------------------------

aiuto() {
    cat <<'EOF'
vetro-arch.sh — il desktop Vetro su Arch Linux

  sudo bash vetro-arch.sh              fa tutto (o riprende da dove era)
  sudo bash vetro-arch.sh controlla    a che punto e' il sistema
  sudo bash vetro-arch.sh registri     raccoglie i registri in un file
  sudo bash vetro-arch.sh rifai PASSO  rifa' un passo
EOF
}

cmd_tutto() {
    serve_root tutto
    controlla_arch
    # (pacchetti: li aggiunge il pezzo dei pacchetti, se c'e')
    if declare -F abilita_multilib >/dev/null; then abilita_multilib; fi
    if declare -F controlla_tutti_i_pacchetti >/dev/null; then controlla_tutti_i_pacchetti; fi
    titolo "Fase 1 - sistema leggero";      esegui_fase "${FASE1[@]}"
    titolo "Fase 2 - desktop";               esegui_fase "${FASE2[@]}"
    titolo "Fase 3 - programmi";             esegui_fase "${FASE3[@]}"
    titolo "Fase 4 - sicurezza";             esegui_fase "${FASE4[@]}"
    if declare -F password_fantasma >/dev/null; then password_fantasma; fi
    titolo "Fatto. Riavvia il computer:  reboot"
}

# passi non ancora fatti (per "controlla")
passi_mancanti() {
    local riga nome fn file
    for riga in "${FASE1[@]}" "${FASE2[@]}" "${FASE3[@]}" "${FASE4[@]}"; do
        IFS='|' read -r nome fn file <<<"$riga"
        [ -f "$VETRO_STATO/fatto/$nome" ] || echo "$nome"
    done
}

# controllo ESITO TESTO: [OK] se ESITO e' 0, [!!] se no
controllo() {
    if [ "$1" -eq 0 ]; then ok "$2"; else avviso "$2"; fi
}

# la RAM usata in MB (totale meno disponibile)
ram_usata_mb() {
    awk '/^MemTotal:/ {t = $2} /^MemAvailable:/ {a = $2} END { if (t) print int((t - a) / 1024) }' \
        "$(percorso /proc/meminfo)" 2>/dev/null
}

SERVIZI_VETRO="greetd systemd-networkd iwd firewall guardiano-rete systemd-oomd"

cmd_controlla() {
    local ram s m
    titolo "Come sta Vetro"
    ram=$(ram_usata_mb)
    if [ -n "$ram" ]; then
        controllo "$([ "$ram" -lt 700 ] && echo 0 || echo 1)" "RAM usata: $ram MB"
    fi
    for s in $SERVIZI_VETRO; do
        if esegui systemctl is-active --quiet "$s.service" 2>/dev/null; then
            ok "Servizio $s attivo"
        else
            avviso "Servizio $s non attivo"
        fi
    done
    if [ -e "$(percorso /sys/block/zram0)" ]; then ok "zram (memoria compressa) acceso"
    else avviso "zram (memoria compressa) non c'e'"; fi
    if [ -e "$(percorso /etc/fantasma/attivo)" ]; then
        ok "Modalita' fantasma accesa"
        if esegui "$(percorso /usr/local/sbin/fantasma-aiuto)" pronto 2>/dev/null; then
            ok "Tor collegato"
        else
            avviso "Tor non ancora collegato (internet resta bloccato finche' non si collega)"
        fi
    else
        info "Modalita' fantasma spenta"
    fi
    m=$(passi_mancanti)
    if [ -z "$m" ]; then ok "Tutti i passi sono fatti"
    else avviso "Passi non fatti: $(echo "$m" | tr '\n' ' ')"; fi
}

# sezione TITOLO: l'intestazione di una parte del file dei registri
sezione() { printf '\n=== %s\n' "$1"; }

# il contenuto dei registri (per cmd_registri)
scrivi_registri() {
    local f nome u casa uid
    sezione "Sistema"
    date '+%F %T'
    uname -r 2>/dev/null
    echo "RAM usata: $(ram_usata_mb) MB"
    sezione "Passi falliti"
    for f in "$VETRO_STATO"/registri/*.log; do
        [ -f "$f" ] || continue
        nome=$(basename "$f" .log)
        [ -f "$VETRO_STATO/fatto/$nome" ] && continue
        echo "--- $nome"
        tail -n 100 "$f"
    done
    sezione "Registro di sistema (avvisi)"
    esegui journalctl -b -p warning --no-pager 2>/dev/null | tail -n 300
    u=$(utente_vetro 2>/dev/null) || u=""
    [ -n "$u" ] || return 0
    casa=$(esegui getent passwd "$u" 2>/dev/null | cut -d: -f6)
    [ -n "$casa" ] || casa="/home/$u"
    sezione "Hyprland"
    tail -n 300 "$(percorso "$casa/.cache/hyprland.log")" 2>/dev/null
    sezione "Pannelli (Quickshell)"
    tail -n 300 "$(percorso "$casa/.cache/quickshell-vetro.log")" 2>/dev/null
    sezione "Schermi e finestre"
    if esegui pgrep -u "$u" -x Hyprland >/dev/null 2>&1; then
        uid=$(esegui id -u "$u" 2>/dev/null)
        for f in monitors devices layers; do
            echo "--- hyprctl $f"
            esegui runuser -u "$u" -- env XDG_RUNTIME_DIR="/run/user/$uid" hyprctl -i 0 "$f" 2>&1
        done
    else
        echo "(il desktop non e' acceso)"
    fi
}

cmd_registri() {
    local cartella file
    cartella=$(percorso /mnt/vetro)
    # la cartella condivisa con il PC (vetro-vm.sh), se c'e'; se no quella di root
    [ -d "$cartella" ] || cartella=$(percorso /root)
    mkdir -p "$cartella"
    file="$cartella/registri-vetro.txt"
    scrivi_registri > "$file" 2>&1 || true
    ok "Registri raccolti in: ${file#"$VETRO_RADICE"}"
}

cmd_rifai() {
    serve_root rifai
    [ -n "${1:-}" ] || muori "Quale passo? Esempio:  sudo bash $0 rifai desktop"
    rifai_passo "$1"
    ok "Il passo $1 si rifa' al prossimo lancio"
}

# estrae l'archivio dei file messo in fondo al file unico (lo aggiunge costruisci.sh)
estrai_archivio() {
    local dir=$1
    mkdir -p "$dir"
    sed -n '/^__VETRO_ARCHIVIO__$/,$p' "${BASH_SOURCE[0]}" | tail -n +2 | base64 -d | tar -xz -C "$dir"
}

principale() {
    case "${1:-tutto}" in
        tutto)            cmd_tutto ;;
        controlla)        cmd_controlla ;;
        registri)         cmd_registri ;;
        rifai)            cmd_rifai "${2:-}" ;;
        _estrai)          estrai_archivio "${2:?cartella}" ;;
        aiuto|-h|--help)  aiuto ;;
        *)                aiuto; exit 1 ;;
    esac
}
# ===== avvio
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    if [ -z "${VETRO_FILE:-}" ]; then
        VETRO_FILE=$(mktemp -d)
        trap 'rm -rf "$VETRO_FILE"' EXIT
        estrai_archivio "$VETRO_FILE"
    fi
    principale "$@"
fi
return 0 2>/dev/null || exit 0
__VETRO_ARCHIVIO__
H4sIAAAAAAACA+xde3PbtrLv3/wUGGd6LHUkWdQzcUd36sRuklu/4kdzezweDUxCFK5JggFAOfad
ns9+dwGKejpOXFt2G6qTWiJAACSwu79d7C5qGz88+qcOn267bf7CZ/7vku+deqvxA2n/sIJPqjSV
hPzwnX5qG7WA60vGksed/06r9Q3z32113B9IvZj/Fcw/097Gs6P/jtsu6H918x9IxrS/8Vzm34UV
0C3mf+Xz74l4wIOaFlG4Sv7farpz899oNLoF/1/F5wUZMS1FlUpvWFPDTRJSorwhkxHVlPicUM9j
SokasWuE0EQyksbk3XUiQxr7RKdaC6JSQUqpZrFmzguyZiozuVYmsKbm2mScJDSOWRjyn4kvEoHl
CVXqSkifBBxnBH5LzQgPobq61CKpOWfQXsRjGp47I016xHWcM58NaBrqvoIhchGfO56IIhxUj6zl
A6x6xCxy86Ab2fNUh1lxDRf9mpMqJvGu8cCd74v+9WW1Was/kgD4dvnf7cKfgv+vfP4V05rHgarx
mK+Q/7uL/L/ZLvj/k/D/RIpA0iji5O3Jb8C9I+DCMXm7f7C3Q0pb/hXlGrl5KkW5Ypg7cPM01lQL
ycnv2JZzdpwto3MHF5YesohVYxqxXna/uUyTJOQe1cC3qyBTBkxWfSqz6j3X1OHQwW33wxCUkNOl
tveFMsVvWK/RMgUDEeuZpsgxjRVxXee7p//W8+L/bsH/Vz//z4j/dwr+X/D/gv+vhv75lf+INsB7
8P9Wgf9XPf8R5bFRhh9l/r/E/5vt5hz/d91uq+D/q+H/MPcVNLR85NVfOSl5kgEvJz6dFQxl5+wt
i5lE88sLEoQcpILPJb+54QR++HSdqGulWeRXY6avhLz0nZ2YXoRs3/58Y2yLqTQMvzegoUJDURrn
7UCfLMwsRdB7aW/rTZn4fMSAlZOESSKCmBPJNAMhxdN1KBsMuMdDRhQLUi41d7Z8XzKljmjsi4jf
2L6y8XyvHP5r6D8SfhoyVQ0F9WsPLgq+3f7vthqtgv8/2fwbyn84WXAX/3c78/i/2WrWC/6/Gv5/
K8cnZlVww3tBPgy4ZFc0DIkxy79NqfQ5jcdcG/myEw+A14Y8vux/SlnKnM+6L65AaOCX/V8/nO6c
7hRc+DnSf0K9iMa1R1IC7rH/2+h2Cv7/BPM/FOJSPQv5X9j/nm7+rRy4oFKyGl55bPsfEPvs/Lfa
6P9XyP8nsP+ZDXmjatEg4EKisSxGeMAnW/6SeyJKOIh9UL7MMkEUQDTXIhTO2YnkQcDkuXMA0MHo
YKRH3sfwosNw5tppEkjqM+fkOmHw85B6lzSAn1QGDLf4x3v0jnO25Wmzwb/NlCd5kjXweq5vUsJb
YESqbGALjDBOxQiRjUQHATb9GM7HIcNGDoXSJ5LGipo+nJ3PzIPLG6mSG6HwaLhxweNpmqiO34zz
z6H/qPZ4FsB72P86bqH/rXz+syUOa94Tq7T/Ndz2/P6P22wW/H8l/P/Hw629qlurO8s8wXKvLGSx
dmFknlzCbP5AfVD+NLX7RMDe1zP3Koemekh47IWpzzLLYBWvOVBBpLFeWlaoY09E/yr1BUjIR5IB
99D/2o1mwf+fYv4b9eooiR9+/lut+u37P432gv7XKfD/ivD/m+Xmv03iDTlh6yQG1h/INAG14GrI
4Aey+Bg4N/DuhAWAqUFQ/H64TxSLbyYiA+RJSSEk/5QyBe2DhMBdGRAbQ2aa0OhHgBUGuIXzkUtm
bIpTYoWXnR9tl1u7u72SFEKXyf7B4dbx8cftzWmArgxCT+Iq5akWhRy5P/0369UBjTVVEV0Z/Te6
rXn812oX/p9/J/qPhE9Druk6Ga8eoP9ZhrCUHXwbhY/bLsj88ejfrdoojgdkA3fRf2tB/je77cL/
76npP1y3KyEn6ZzylxI8KcVZqI/hCmUnL7gHbWdd8cpd9RR6Ht5ZK5EAKu6uRrXGTp3vj/6t685z
8f926816Ef/7BPP/vyKVMQ1tUNyDWQO+ff6bjW6x//cM5v9hHIHu9P9pz89/u9Et7L8rkv9zUp+H
RLKAK7iIm2WK48qgBGW78Lw0oWPnS+LW62TvNVFpCL+UJ5yz/7bL59w5Nutpj34+VawH9fYKrP63
oP/MVfaBccA9/D+6hf/PU86/W696dCRq2e8HmP8v8X809s/7f7SL/A8r4v9HDFS8EacEZ/x2b9DN
KUd9CspSRDX3oP72uzeH5RrZ50ZV3N4/xr1C5wWRArRHSUqKk1RRNPuEoSAeH0hovmwiDmLcNMSd
RfQmMbVRyoxAzwyz2yvk/eGogyZhaHEScABrNRGSxozXnLM9qr3hubOPQV0s/okwPfzJcc6ysINz
BwfYu2bKwaYOJR9R73rnMyh66BCiTIlzhpVGrXPnCLvdgwfnHsotB+QXPFIvFs4xaIbvhNImeAx+
O2fY3haoqYk+2jqfqvnPoP8rPuAro//WAv13CvvPKun/juCfTYwSAiwIlBiGLKCVhWAfEwEUruc8
ogYEO8sTHoYjzBH8VXgLrQexkOwNlZIzuSuU6jW/nQF0vgMGMEv/QkQPrPvfD/81MCS8wH9POv8P
FwR0p/9Xc97+32q5Bf57Gv1fWfM+i4QETDjgMaj2DHftOXprAY8eJwjIDAGBBO4qAJyNmIfutcD3
Q6o8TiWzHmMoUPiEoztnBwd76MdrMnftYT/Xhxi0mUq2nYWHHjOv16irwmiwavqHeRDhiD0H+2+h
/z+D+Qc9wLIHP1b3FwV38f9uZ37+O816wf9XxP9v3f8FMM5NtkbFNUcBwBT8peRDSv1XpHQ8ApzP
JOgCiNEzmzHFeiACsLbPypg6JhJ+jvJr5Nikk/mU0hD9wDBqlJSGQrOwQlITzi/gJtsjNgu6AsXN
W1FBfxJMNSPWiUejCyNfAG8fjJg82T1GFI8NT10RSSKkTkF+ae6hOrK7fNf61avc1cEs8QoJGWa0
xECYMkEvFTqWbty+E0pOBCoiR5ZaQJgB7n9VM/+9QEr5hG8IlWfitl7VXLcx/jdX2ug06psDtgn/
biuZa9D5lYbhBfUusUtn9vmdbYE5PFTvPzVnd3dv/wh1kT0QstyjSt+im8zSv/37DOL/Os0C/z8B
/8/mf+IWMRpxUVNMjrjHHs/+05mP/+u4Rf6v1XzOTmOuZ8LqensLTHJziWEGuKHPYs0HJofXSJAY
UL9ACVGaSxyTQf1tlqDzUOyBHEFOtDWAZnrGGac6UDVtgv6c12wgJBvnbMHEYFnJgsVpvCyJf5Gq
/AfUApVFj5v7CE+glrTmYJIyc8e5iT7siZgpkEPOEUMeasa285lrw1cxIPAY7tO9u/yHkFzQMGRj
Hc9N98x/fd2bG9bfhf5BcNC/TP53039rnv7b3UL/fzL6B208oYDkQtwSUoCQEMRZe0DZZPuY9wsE
ovmUctAdekNgExM0FWGgV0bny0oyWh8TNqbgrmaZvHOCvi+hInWqIeb+XvcSUqUzrn9DAI/5It/A
h9yokQ0c4uQq+de/AMWKq5hUj6YY4Wyt9aXEHiHmMo/z/Oj96+g/S/Xy10n/q+i/4y74/9Tdwv//
qej/13Gin9L8JlBsN3SyTSDMC4CZ38ggBd4A+pvyuCkdx++AaKZTmYK+CQjk4h7+ejpfiV/CB8NU
+0Cvd4p+zEQXcg8K5295IFCQvT+Dnukz5xBL6T8YT1kVFfRHx//dhfjvjtso8j8+Ff0vS+1FStai
QxLJI3MuSGbkN1RvTwTJNwbKGUnPi5GMJBcuT5HdCyK5SkTsC+ge6gALMYFCaHsBDHIhudFCsnik
tXyhrpGSTkEnWcAmZWcnHnEpYuRWvbenW0fb77f2D/pvj04PDw96eQNfoOdZagBmoEw1Gl7RazX+
iVsWrrMv9tkVbjFzYJDM7i0fSqGZp61LZG+QhiHcQ/2PEpjlIdVD1bMpuGd7MfvUmp1ESbZB/UhM
ZCn9LwFrjyn/W915+m+3WoX/74rsv7c5fWySX07fb/8CRPXLW/yLqVhhRcTCem7wpapA2VnCUN6g
FrGs9rRqsWncS2jsGZ5D0TXEBBJxk36oDBSwh+sQ1v+Q6p6OkoHCBD6ABWYhuZXctvzA9K96kfBZ
r96t1ysp93vmsSoBfsMHq5j84K36j5VYKCiHPz4bLaW4eWPFP9X+p4WckP9f1wHuoH+3vnD+V7tT
L+L/n0r+nwg5Tp61bL9kzrpnRf0YZos45HEOyW8BAEsrT6OAU6jfg0XovJUiTcy3I6B9YAXb0KIH
v69702t0oXTPEny7PhHrh8gpULKjSIc6pDqwx4LB95x51OCH9Ei1OmKSD66r9kA8+P0p5TDEOYzw
VS3B0LbUNgUmF5N6Dh5EDIPnYSrZNIBofwWAUOiaphcgxIgCZuEXOIbxDe+ALWYNrAZLFJ9/CP8f
JfEDmX6+Dv81G/P+X4X95+n4P+ZymaRjWQW//wvGljzpC1FpVk0kX6gV8LRggLfS/w3o79XAnPMA
guShMsDfef5HoztP/65b6H8r0v/mlL6x5ydu9KJbJiA+XBVlEkhjhzGZ/iKGmNCah4629mrkDaCb
l+Tta8LW0fvHZAMEDBVDfS49StxGdmiHSugNt+d5cISXRpPcep/likkVuvXwLKC05pxh1/Vzx6xL
1NNIj8BXskEazniAeH4UDQMYtB5GUH6jtF+gl2+jf3s07mP1cZ/z/9pF/teVz//So5Efn/+77cX8
3/Ui/v+J+H+e5Ntk68rsAMtOBCclKDengWcngxuuv+QI8Dw4FBRjzY2dD8HmiNkuptLM1tC3NPbF
bJdDG4agBaYUnDsnvGyshjY2gcboUprlF8sfgy05Shx0cY6Ke49UiD16UDK/YsJaK8SFbvBwcpBy
8KRDQKxkxKVOKQiq0oedvdNynug2tjnFwzwprukLQPDFBXTLPQ/ToU86+902U3Whk1eN+me3/rI+
3Ss8tXlFgL4IB3zKaUwr9rViErZs+KSk4PfsoemZq2z2WtMAemFlh8dJqsn/OQQ+lxf9kF6LFNOq
c+386TgsHsH3/3lzenR8cNQ/fv/vnQpptOYun7zb2YPr9mRFW/ThpP/hcKt/uLt18uvB0V6FXNFr
k049Apmd9QbiG4/+6o85ST8UgYB7tUzZTAWVhFQN+xI3hCWPg+k6AyE91h8f8Y56RUITc0p7fXkn
QQoQn4eqD5PhXS7r7gpDB30RwBcZT3X3p2NPjMyGH4v+EHQfqMT6tkCZA+f/dBhoGKDHeAhEPilS
Tazl57MfbHxKuXephrByZtlp7VMU/mxS2XvaAJsEB0EY6DbOc+H/OP7H6+Me8r/Z7Rbyf7Xzjyv0
2Zz/0+wU/t9PMf8WDPAoEfBaQFGL+QOAwDv9P9sL+z+F/r8y/DeJ/3k/Ne2kNIYbRvaj85cwsTzG
4Vsi9MPYGBOXA1BJp8ycF5MizhvROMaIUPKfjZrdQbGLK8GjPGOAJuaqQ2MemXBPlYldZs4L9SdC
2WeeyA6LsTWkSGPfym23Za5chOlYai9pAi/9CQ1Zk1aYVQxoovocj37pTH5baOQ2oPYVBwx6JVN4
rgwP0AgFviUOwKKAMCWrhvyCSdtHhCJ90wMsg0Ch9pPFL6Gg2CYaMP90/kb0/9CnAH+Z/t1Ot9tY
iP+vF/5fK6L/saZUyRWMNUPya7enA8Foug9WzzLJ29m6URR1qlG/gwsnpztjXjE01kKN1e7kCKDf
jUBVZFkEHraJZnnQq1AHA9QNuuQuqI0eC40XiTYuprN8y0asC8OAoMG5Dm+RbzVygmOHbnxgZKDo
4ZOTUSow4BG9OKu57ni38li6TXvMlb5NqzIaZW2meXxFdoiZQmkjEg2PNW/EmFCFxkjKXYq+ciJM
b4wSal4KRirOvo7qf5HjTDcdUTwqOTXTBNohNFqtVgnGUhrtvPoAn9uUyhckAcmAewrWfy8SKSix
+TobSOZ5nJIL0Hi97DAZGOhHw4cVyB70NuKKBTE1GQgonjDzgqwtaXStRrZAcQP1eZcF1LtG64Ex
M3B4k2xzbGeOiclq6PPJwJwJKUBTGMs6Mr2p1CRChHfNJFwppTCIQJjx0pubVIKyrniE6xvbhUnB
aNaQx7R8ty797o/Do8V3Vcr8rN+e/NZ/c7zdczfN27BqNl5t4vrhmOKGVpBKYILXJ4PPPDXzo9nW
QmpsJzh+JtcMCc0f2oa1p99wmAawksaHqW3CooRXMH0sIK7L8l0WAVu8d/Dv/s7+1uvdnf7HrT92
t/a3kU6yd7P9tg8v4Ghn/6S/vXP828nBYWVyQNukzvHO8fH7g/3+yR+HO5P2x0tYJYY6qg/z+Sa0
YDCIkD6T/Wx/wjXXPBHW8Dy5EevbYty5CC5oaWA+rXo5rwZL5faKbstWlAyb74t4UitHOAyTGflZ
QT+Q9KJPkX/lA8wtPz5CmxCh1ddgq/GVfiKuTI+Nmi3IxisS6nF9jTfUrEkmf5TFIp9H/XExXLYH
wJsSNaRA5l8GcWY4NA7w1sbLySVjN8rH18wL0PKWv8ksyqRTni2eHs5UvWaznOHGrwSY5hns3L/K
LyCPYmpmTLEAAkPrVa3emBpJDJxG6ak3ZXqVPBhqAJrK3DBpd8Qv4D141+ay2530J5I0UfO4906M
bfpiN9y8vkjIC+4DS6nXGg2gUfzS7FSyFZ1XkzTJarlt+L/5slCJhWjJ9Ey1ZguKTUv1Wqe1UBWd
AmC92qZMt7ZCPnaoE4Tigoam8CUCFWMTXKhlgbt6H5uKrRoMbzIOeENAxS9f/njbbQepNvc1K/kj
2nte1W+9Z0+M2KSz/AWqkPts4R5LoKZ6J6+8UGtAfdtkE5u0I1moBBQN0Gn8oHf2bKuPH7Axabhi
uls6ht3pLpq3jmRSdUnzi69NyEsFvIEpU3XhnWFrxF0yR8DiQeKGH8f3L39wkG/Gtp3xuWzNJ4ql
vjAQdGrZ4+YxSkS0QXM9UTqn7djfbIK+n53bSxVydsONMGxqqtCAmn4Ey6xvSVf1/SSaIfRLdt03
O+G31kDZTwDqgF5u9tslx30KxMjoXC1ndjAASYzTNuH6B6QF1eAGO/RQ2JkJQ3HVz2I14aG9S3g0
UAckm+02AzKIcZUga5GBd+OXVR3b69c2DTbJ9k3yfScaeikA27G+jbmlbKs2JITOHElbgjsiHE+F
rM0kqTLJSWxMCVsrV8in1GYWSRW86W/dR1h4IoPe0fnIwErjyJlvn65NbaaFNjiczsJ9cxjWZIZw
WHazCqWHSXo41guMacHkW53tAwafvTWG3hBkDcG9IOJyrfyVGx/O5wxNzSz5GyZFX3mgtczUfTGT
G3z8dJsmUTisa/sIRhlB3QbdQhRfHycRG+t/FB56I99jBopByJtlg7QuJSOBqowNNVp2U9UU4a3l
n1E3kHioZBBys++IZ9mQ2kY4UKCqjsfL10wsogYsf/gGlDV8MfgUwFYA/gMYukiDub0raF3lQGUi
Ov+fvX9rjhzJ1kSx8xy/whNV3RlRGQQjgpdkBYtZw2IyqzidF3aSWbV7s7hpYARIojMCiAYQTLKy
cttIdmwkk8lsTDPnIsmOTHP0IDsyk2TnSdLoyPQw+5/sX6CfoLWWX+AOOBCI4CWrd5O9dyUJOPzu
y9f1WydJOgRmSr6WM2PYj8oNiLg1hcABiyWNTA7jY/alIQ/YbX+GJUrwvspg6Auh6oa8b4XNkO8O
Ovm8KcnrJmgIBdLFGT5OGdNoOriYeEONdQq9dApsNWwrDA/Nc1CpN1lKo6XBKDCPHLEx50ABpkRc
4CK6AGHtF2CbkB9Q94mcD0UtbkkW+EJJo7CYbw6YL6VSlJhUYwqmCIQt0go6PBuOd3ZGIi3I25RP
FXZjNMLUWEBli9qQEuVEJuLldR0g3L/IukBSdvQYNQF4Fohiqh7EXP+SITe7jRl6Tr0fmpIT5EW6
R/+haXQlSxXQ+rKg/SRGF+lmrNShKI/CxUdbAj7GFvUbCqr7o7KnisxhQ7gE+QHBiUauGYglxiC3
GsTf0EC2OMMeAdtCArJ/4o0mFx6ytG0xAhwl7RkYAx+q+xV0Wq8Djh0yH1RN2UfQfUxg9qVxEm9L
Bl1qfIn1IS9x8G5/9y02wh/I7Tfkeo0+TCw62KH6YTJhTdqtMFnkLcvg30mUjlCWaDVO4UtcAF5z
m1d88rKtmOvMgt3nSCb4hf7B/vbObv3i29aiYokLpZ9bSw/iaTJAfVe++J61uLFnc1/YB8p5nXzZ
19ayYZRyjWYjX/7t7uG7t/ARugcASx1FqSyxc/j2Jdt+edhmh7bXsoJd+TK9mIZenH/9nXydS0p/
GsNW8GOMbgcmlTvJ6A0f/LD3AtrdPdjZ3ldNXJ0N/NUlqPk9sFHeua9aa7P9t3uvD0vaUg45srio
vNY3DBUSuIklyZSV0NS8AEb+fQA3P4nj7fzo/1j59t0+TOl0NIJrxfdRWskXeGG+7+Tf/wizHp2f
j3wiWcDwFJp4/uYn+46Ig+F0EBhjOdyGxRpcD0Z+6F+l7eI7D+75+BchCgJvp5WQU5qrA0WVy7Ji
1urGWufpru73niL9AwrKiX5pKRT0SNUkyiGdRmYOyKHPmuq6beWnqKvdxZY16Bmve/nXK8brlfzr
VeP1av71mvF6zXwtJ6vLh59G5d2URXuWoj170RVL0RV70VVL0VV70TVL0fyw8HwD4dn7/odDY/j+
k6615MvdF7mCS4VV4sImImJUVylLTieFGjGNfDSajjE9KPwThCABpN5j+t4fEZH5uxcb69vTYRC9
9YLE/5FKS/rxYYJOUomfLolalkasy/7V890X2+9eHp5sv3u+9+bkYO/1H/4VW/vdE2utL1EZOKPW
kgqXqMJcfa+mqaWiMTy1V8Npia2mfWAxrGRkPAXZzluawHvbd6+JCJR/58HpTANri0A4qr5EuH4y
R0hNOt7jt8fD6N5yuZuBWuLgsg3uQlAwSQxJhlI8djNnlGijyJxQiloMBQjQytFqJNE05u1Z/Foy
00WDu1vqBjS0BaHwjYJ8kxxQLfY5j0XnoXKB1ZqzsvK6EU+Mssp2ifqWQHpTKPPpjDYK4kJp+Zyx
NW//HwdjH1jIxB0BH3/r/l+V8d/r+fif3oP/z73Z//eUsizgudm5IBtw0365DwB7cx5OoaAOyYsa
DtPqbuyqxpGAgGLbk8mIgCOjMDlupEDgli/S8YiiugVT64oz1/CysstXWOrJVUnJKzpxY3/pwkP1
bwx1ppP6JZOZzU+GZ9YyAWJGLA+z4HTi4tVrGh9Q9yDciuJzFxlwl27QiTe0D3NpnCwNo2QJKeg0
Rb3T1geMnSwrHFS/xisdmNtheanLcOiOg0EcJdFZ6iJyMjZa2v5D4NS/OP9PzX/9s/v/dtcQ/+fB
//czrf8thwMukP/nKeK/PKz/Z13/bdLTYfjK3fJ/K921Av7D+krngf+7j5/lZcbXmYwFIEj+Qrie
EYhbcURCDnpmiKDwtojLdt2WzhhyU1ubvfBAIut2Wg2USeKU/TElHX7uT/fgwpsgDM1e6o+F4SEY
9pnH1cLcNB+BsJJeM2hihH6L0Ik+6zDtB/rdcd2upXgy4b3usw3zLfcJov/Cy0N/7LkUxJdGtnKk
3RfFBiAXei9gDL6lPe4rmELZV1564Y69q2anLX4Pwma3LQbQanGHIpgN4LqC9KdgmF702dfrxtMf
fFTW02N6/p1/4YGkjBYN1RL7yF5Px6d+vK0cJD6yocidJLo8QrvmJvO9JAjP3fR6AkPe5X+8maY7
09NgwD5JHydaEc1Sh5GUUZy4IAGM+oxbWTJPI+nz+pY8Avz4kCqnOtydaXzpyxcN9Q29RKQirRGy
HAKdee/v4ITLDeDSxFtKifkSpeQqGwWxv6IyB2YqFAYixyg08CYH6fVIdhl75b5FT7cdb2IUxDfb
4fnI344HuX5nBq2/Uz36gP0jZAJ7yT+pkhe0xtaisTcMpglU2lQbSK++bVbRYkv5+WhVVAs9EPUX
CpBXAQ22z7ora8X3H3x/It7D5Wy8/9Qo/jbPgvMT+bDiv90VzwgbunbB+rOvZC8kTWpVbolPv90A
mAf5r5T/4+oBrlm8CRc4g/9b7XUK+V86q90H/u8+fiaxdz722EGAJz2NwgYwVi+5L0HAQbLQIdHn
ynLuarAA56e2VqOhWtJZP22nNYS7uzeMwtF1xmtdejzACMjRc66E2g3TOPATV1NjJS7wWlNkLgWP
OHocjMfeOfpgEQAtRoF4fYz/UBlt0GelzaLJZMphrLnaE+plCIR/Fl21Md0X+46r/DidO5uGA+K7
qL4m1tXSLozgjDUfUQO//sob2traYo7TQiztaRxqE+JiDXjvNB1tHEtXmubNaW0aNWOFLpHv5KcA
P1x2WqpmB7vfX1522BNqeVPzlS9tGgu22cwOCG5RDT6Kh0EI26Opj100Q0vlJlAfvHbhnkqbTZjm
0xbbesY8F91pXLIGATMwxku7eUoPWyVtca4zgMb+MkXMNr1JGEaSMnRtOTrezD1FtTNGQryZcDqm
6skKnsHqNmFLsgC91zbhn2/4Z8hEn8MN//vfs1j+/g3j7UOxJ09aOSaBN4mml9wWPb3eGzapzqPg
WFtOuaQ+bwOtmVdvzpowum9YB9bUnUyTC/hz08Jiwe7WVNHMJ/Q92K59durhmMkLFmPnUKk/eOw/
zs2M/HALmoFNA/wKdAMWx3eDId+vWvUO7uTsjWgqvzOlWlzM1TPWxTGgfzXsgmx4othR97jVhiL5
JfNGKbn6Zdureq2o/Oy1Kkx61iGqAVfGmHb1tHCGYvseJfLYTH2ykJdtU/SJ42VwSoEmuLBFxnBG
Um653gFS2szNa5qnH4XTkJ9D7juLB6JNiQxzZ8M2jfzE8qmbsbupKMzMpuU9J3ewpek4qzHaB2cu
OvayCR9S/FUweJ19D8TMYUjSmmi8HKOGwnhT4F61H/rovX+NQDkJfnV03HL/HAGfDR8aNcPu5pVW
9tdGgoEvF5Re7SleK7x4toV7inssF44z+RWP0Dtf1iq/F19ivTQ3+RctWtcqAsGbnJ/0khM01r3Y
p2qLBjyhJlwoTcqlKW6Djjobmw+ywW+a/0cPkltQ/87i/3udXkH/u7r2gP/+2fj/vZH04WruBxMf
sYBbN+P6C09cgf2buNjCB2ihRDLAPVglElDSKeDoZTWuCNaizQs1vi/59jSKKEooRMXto0dNXg+y
D/w3l1pulXzN9dI0R31RC/vW+NIVM9gX8RAlPRhPsX17DehiNoQKsgiUYiUY2hKeMyHWYG14YYi2
v6FY004XKnb4o5Po7KzyspQ/fVUHxW9qNWCv5q9i/alWBXojOPBe/j2dOCISODgPYWK5M0kaNVs5
Bkv4OjUvC8IWn0HJH2WXkWVCRUhPSRnR561yZX4moRh9Iz/c0Hs1xX6zj9Qt2StrLx4Vn25KljIK
uQPjzgXGPMM50KaEv8d2bG/p9f6HN6d/9gfpYewN3gOL/5FF9HfSZ0flJ4UdP9zFD/e/dv9fenA1
3r39t7v2tID/vb76gP9/X/bflx4IdB5TirLmPy67Z+jjzyLUn4XBLwEix5CubBpxAS8IUVWGAu9F
EBV5g4VYgp+C4bmfJo3GziiYTOBaewsky0OeQGcIaFPaDKmrdkOqeMzNIH1m2mwG3HRk2ILpxaF/
lVoMotyusxcWjKKXQRKcoqnkLEojlAzTacIegdC+B5Pqu5it5ToLdYTK+6wpVVI4oe8INrdJYqTz
LQjMgwsv3k6bHRRF300mUhTVJPgwhVUaB6PrzEiNTsWagYzKTIIrf3QQ/OLLuZPGqK/gWl5dMwt/
EJP2Av/4LhoNTcQM0VIy3dbs5vwepHHqt/KQz0U9mzI+xJw9fTFf+yI2fxvD/tMd4HayepJrqAld
VHE5jRBSChLW+SXiKcgbum8oRpvarvPDy6bzw5tXu05LUynwE+DkasFp5GY5NZl8P32lWeC0ohdi
OvMT3/vtCL6V9P/yPuS/7tPeWgH/e637gP92X/R/h6w65PgdZHGkpdJe3wxEbctfnhzw1A5Rg9td
UCShkONRimCRCYIApLHnsgMMrAjaIk4Z9X8US40YYGhpmsT+OGB7IW4+doDhGFghj8aIfQnAwO3O
XBNpBr8GI7jRgCvH6POWO8MX6SXFtyf17ieBOlVxc+2jVZzPh3FnXUohVt0TB4gB4PJ4GyA7ydl0
TLHQrkROeoaymwTCIdIJbHwaTTjN2wTxMU2jsfxr5J+l8veYEx38QxBn/2owmiJUB6exu/qf7h6F
SevXYdGT4qdRzDFeaLgqFhpFOB4UgOOwFaWg6r566L6BNcQop2LJ9/71aeTFwxeIhmLOz7dY9A/6
e1cM4RIF7MLL11EooKWUnByEqUDIKxfIUZ0QBwmIRB7CGIJQNYlcvKuFhl4o4aE7hmVcs4L1zTfc
HpDV02YI+5UTG+HQNYvGQ78oyvout8gZCml9mgzBVgiSO1EY+gMdAIpjLWCGIzHJ2SWs7HohkX4h
XjbzdgDsoNYuCrvZGBlO0Sbf8q7AJCQTAy9C6CLbFMhLawVjsTiLSOvtpU/ANFME6uC4hZEOVdMU
uAGIfI9YAkCaED5igCkERlGWGYCqyzOT8nCqk1ePUxFH5I+pyyHDJGpVx13pZdyZOMT5bdxV6qC8
a5889TU8+8b+MKjj2SebeYWBJtuIB/fROrRNaH8HUTdQk2DZT+aqlE1jHPxl6g3jbDcJNkmpTp6u
Y64D2hacZ1piG51sxiSrpMqv91R5wTctse669oUcSwYHskPcuRxX4YX6EtalmatZeleBYAB/rXQa
ph+VmPoYIY4j4A9XrXyx6bnI0b4ku9jNP9c/xEdR5l9q7KDCzZAxmmiHsW4x9+tV6y6jL26+x77z
Bu/Vy+gSKXgUwdp13e5cOw8KK1N2QEeX0JmGiEkVEdIHnV9g9TNP0h3Ui4X82s7RpcpzqxcYA/kL
QljU7obpdYgTHJ73Ef/QeGHb9PKHd4UaFYKoIZPkiinnWSmerq2WuO6hn2XRr1DbNDmnZKO/0Qfr
DNWeqXxBZC9e0axBtzqVRYn7mFE2m+ie9f0e8Y4fSdUAPEbiY9Ah3CpDTAZNOVeg6tVNYzrIpN7T
dp/+g+L8noZsZPsJhuLOLy1Rc6nnEdGt32gie8kE5vcCDb60ZOKPOA+wY1F3VH/kD3HqdkqFf2vH
RsFk5tQMCtJ7/icKqWmp485zFKXf5VQ3N9r/BfWOzugQN1j5GVf0OFzAmoaPQUhxXbf6G9wBfcUt
zehXYQ+slBb/VPoGmOfEjcJduB0mPmpekhJOYFYNb4ljVTXwFSMGl/+qmOsjfTGPWzN7hrf37Vf7
PPqQ76zaXpkvttmEdC1aQjwR45sniF2OTmO4JsB0o/cT3MfmM6B4rZn9ejep7hW3SRmvlm6t8UPv
9DbnpDuzwbd4X6gmyQOt+vCi+FEc7O9/L84MR8nbR9gRQg6FU6pJcryrrZn2y1sZ+mZlM+T24xMd
nljtknOf4JdwS/91zKR1C9/ThBWffsrFLhh/fh8Hwx8D/4NlLpFjoPm7IVOIxSQ/aC1XcaMW1Rio
6hDr2ReQ5WZoiuqTtIWI0taisl/dHK9M76cx3px76JhmUotCUcr02ifV3yRFtdMI2Dvuqy2/VIfK
skIX0AlCsXtB+JPJjmg59ccl86K+QITm56Z0g2qFQcUn/UqGv0QqfOWjp8qsS7qCaa+SGS1lZsiP
5bsd5t4/99CPXgvAtDPDCaKx2ifAB0kNxBhTe0ar/NxL636DW5XcGq3lxSwICiW3rbWo1B5kZfm+
tUsfXG5GRLodPkR3wqkmXJkoO7OyqV9Ilua7zRCM9R8u0FZQ6pm2x1LpaqO0CApYeYtdVdvz61is
m0qYZrlos7Ze3XS5nc/2Mw4mY29So6C0BxqaWh7GITa8q7YxPW8tcCHXkEHsu5uUXJXfZTO+DcQq
RFfoPrXn0t8/1FgHH6HSxUe7+Pvb0rOipte7CsbT8csg9HeiKTbZqx5d7E24sYFa+SnORVraJaXi
AqCpYaa4NK+QbRO0u73ZxQ3rONL76Xg+6ezGnEpOq1apy9Do20zaUksQvkBV3y7PHzHjoHHWkaJt
SVe+HwGpB5r0gxcOd+hdhdhP4p5F/pC7o/zG4N8rZbYmKRZ2Vus2eMOSYy7YOi87n3+ccTr59i8R
LpDx7qD75Gu4pDDDENo60zhCp4IyXUKfOWRB5UD6MAOxz9h//n8yaWbFxxlONL0B+Z8ec5tJbHHy
nOesFc5XtzGn8uIhhvg34P+RBHfv/9db7Rb8P9bXH+J/P2f8r4K6rvYE4VlBKNQwQp+QYQCcwvsI
87gTeGc4hTsDq0SETi/gWfmkR8jQJxcOpDl/mXojbCzxB2hD40CYmFHEgy8w9/mA24SGAU+YhFKg
e6Owg9d8gDxquCT2gPZ/jXhknljNTcnbemjULOORy0V1HgvVN8LvTN8FbIkU0MEo6LOj45wHAfeE
aYbFUEMEg5UfyhDPK1QLXZFrYqjpW0buNEwugrO0qT+VH2MGoSx6a9XuAB96mHZxGJg90aqo0ZVc
lQPgT/DaxuSMZpRxNkAj0Nja9VmBjyMz6HF0FBy7wyAZB0nSNKOR9aU9oEXPOxPQQ/Xove9P3oRv
fYRezPslnkbD64PpBDdogZ3Cd6+8+P10UlbC4z4dZa8DlO3KXiIOLKZqgLnNF8nMz6E+1j4Li9rE
UG54ka1jM/d2MIpApMYIQPRAaTZ5DCG/U7S9YomufJR5xobPA8z8cQqcKUVYutP43Kf0Z7Br9C6+
48/dnTjAdF+jIn8nmlbHZfOBv6i+/7/z4ti7B//PlZXVtYf4v8/q/4/A2JmzZuWVn3lySrdLn+Na
iyQBbbzuvezGxuQPPougeFMiC8NLmdaj5bKd4tXOmpcCv53jlFOdILqBRJV6j4GQhqmXgNSAOHQa
r9JXrqjbWZ6eJ68XYhTKnT1VdtISb0+ay0ZdJSnPStHXnpa7fFY7eZYEPizs00njqOPTeRhNBIzc
NSYA2sF0cLl7MYJljc41/TgwjoMgoatFEnvO+wUg6Gr1AMOGTxMQaPWnr4Jwmgq2KnMXdN4ix8iS
S5RrKX91cWu1+roHoUi3lUz8c2H/2BuO/L3wAniHNNJvd54OQ19dLZumtJYTx3rAm8/1Db2cp6FM
cATsL26ISMs4TBnthBcUpTvyDPR7nhgtmXocmqSvAG7k4R0EDEfrtaEpTLoWYOLiQGQlEgnw8PR5
ChYEWhI+orDHQ9TmoocI7CI/zYbEUfm39L9kUP8RNSzs7Holz7HL0wHnHMqrEWzgKfIFp8QGUoUt
NWc3zT+g0apqF1C9UN7tSam68Y9GlWNUt1N4TYdXfJ/qQSzZe/n1esEVcmU970wJM+YdSD96br17
omsupVnKAjd3e36KVs9C3plb9F5taL5sef/joTkTVh8/zASKfGDOXmE+bpT5utkXvWzh1xsl5pdG
DrG0LEmXEbJQ2/NQrFhvY1NtGfxdboJu0bNw8cnRthDqlbcnE6QCqReECemjkTk3HVEzc+dBNAH6
VAXQmN9NHIH1IyO/s8VMa9KFsMx6timdCzE5Qc61sPu1pcJZanepcoepuZnPZU01+4Iq9qKvN49b
bzo8hqM1nwacb2rF/PX5HTcaBSFXPUeYI8JDxBe6v7wUM9xiypZJMH3MRtPw3Dy+xdN+832rDmQR
5PKtPwFO1xDjZ3ktlBoepDfDxxk2Iam4kFe/m+VEFtoieTN+wJvxA8ISPWOdGc4xAnVnlGFvoclg
xPqG+uMmdqfMb2CWd8SiDgIVOBl842hssksupD4hNmUPeYq4meauxfZR/n4uN6/LEFG+279lvXVW
VVxS7NVZvr6qQt2DF6puZjMAHMXIB7qo9pKxH3RPacPyUm7kvoNbvjx+YLXUTWLRK4J6UllrHXvq
Qk7DhXCDpbVq0rC40TRH2cV+zp0LilG7W2e5EoPozc6dcr4mt+tHdrfrfLiRAQ7QZiu9TnHoNf0g
uHFWkWtOYw7FOYNDVfLG5Zly+7be3siSutJY2DuhGDBRdCgkf1xvOKQrc32GSfb2RDWpMaqU1LQi
N3NPuiMBjeb0DQhnxvYDIW1ldQ4hDdlIrKSEw1bKM0nQSZ7bD/wwYncn4S3AkzcqyAKuppytxtzu
bvxISq2SOwTSRpCN6JN3QJBYTSCgHKmw6QTpyd6h02ozZzgcsiF79eqVAH6EH5sHxZP5qy5qsZwf
fuiPx/0kIagr+iPHXdelAgUKsNqoPv3P/XFgoHdUeyNZI/YaNuGmbLFK78QZwsycV1658KLOhDbF
D24jN7T/YGrsu8//s9JdLeR/Wl1/wP+4N/vP3ohRFnQtsL4s6WNGc9l5DGfUb7MExAwoigjxaKWZ
eEmCSLsuOwh4tR7pvqU15mUbarX6c7BI5rTniMUBG6OWP+DoH/4oxdySRr5U1uyAHD32gpaLRizZ
NOrEZa0Eg03W7rHHmvvbr9qE74510safeGN3KLPD0iS0UIE+9lH9/likeZ0FIrJ7dobgerXsSntR
JRimN66wRTUOBtFEB8PiPc5BXZC8rGZVuB1o+ho0kajpgUXB6ZJTZ9YkwCX9OKaMSYKPNbxXELYK
bv/LQAIbCAjH5NQ7HwUgekhIwnylQ+95ICo1fT7gviCjflP2KY+NkW0Y4IjUmpsA2QYctiid91Lg
w+J4FRnuMXULHsqKN3M4k7BfCPe52bLAY6uWLIFJqma9ObMfr2H4CBc/QO8otUSxr69Q7mNtnjft
zDlsqR2oyuTAAhISx/osnQXnmemP9pWjeYNALa/gKHjnft+CBpJeBAkavyZRmPhvheanZREEtYLD
Jm/F5RNjUW8Z7y0TZ8s7ZFiwpCdtVHReEXXPWLNZPSAU+awR2IIwT299fOAeTIl42GZBVKvODrki
FUoJUxmR0LSkg594UNzsJp48KZ1ftf/KRvLCA4qJsTHOvjxtatsRb7vAvtXat27hamnTuB/k5ZBQ
5u4Up0vBRPXlFdT0yaWQG3o1CzDnFvd5qrvcAUFUH5w7TVtp4glxVt/M+yblAD44slMHLfYVW9cg
RaZhSMK1lBWeadHsiG4PVLnPjpzkg3cdDEe+A4LL0genbRFUnDQY+9E0hSJCNhF1orDzl4QtTVgp
f8eCyYCBFKNufz5V87UDotJ6BxvDDOODdIQJAideOrhgw8k4YQg3bK0PaMB0TCMr+TB0jrVDzb0A
AgUG8FFOojoWsAEpU/ueWjRujUdKvak2EAmjMJS4gF6T+zh7i1LopQfSzVqno/XoMA7Oz3mYQqA1
qXqlPcwvs9jHP40OYM/BZnlZ9JdI4FCaoETo9qBZ5QVVyERso7aDaYzwhRYhLpnC/oXrNfBtsqHz
RWcA//MdU6tn+HUY/hybuiOHzW2jaC5KSDfBAZuIb0R8pyAXG1MWm0bHUuCUNhZS0M6BNDlHJJoN
ZPIABxq4sA2m3qjsEx1Rstvb6FQVk2qnpxZQkAx/tADUYCpsXwFFDzjDWqGorZxCOdjShTgdTWcY
MLEE6vs71jevvKs+Wy9aQ05JNxnCPu+zpY5rCdlK6NBwbRSU6K1VzESVFavWPJyjJo/Ce74Xv5VY
EKI44PcwdkuWdX9QuknrR7LcQRpN4NRNRBg+ojt1NitgyNbWWiW6/Ioan1bV2O215rUDwDknZyQQ
NcZRfBoMTbVRSeAxaXiRV4VLM1psTRRsVnFnlbg5SeS1LUvM74IIbZR7FWFe5/FzqRUPzGcIo/W9
xt0YOO01vDk7SxAwcGnFjrtzpTFBiPMm2pPguLCHVlszkKBWG9YCHIS8wjQniOf66kx7bUmRT43F
4rJV15dWVm8SCLyoLvuHH5zW/YTGrm/MGRv73cgbvJ/9DZxA6MyBmsf1OtG0zhdnq/C/deduwrIX
XY2Ccv9vYzXkddFtM/5/cJf05jcy3/AEfpbzN1TGpFdzL/0YMQ3nWvW1BVdjY611lwflgLS/7lmM
6PTGHKKBzQ5x/0jC6KL4B6WshVAz+LlndQYkfjWRoh/ndk4C9/M2lLQFf8dyLBfJOACz6e1X1aFd
pyudzsz7dK382JmJkpJBlCRevwKzjzxDz6J4DCuJv1LS2Y/IVuiddnlFZbNEoqr/lynsoMAbafxZ
NSgJSsWDaZQGlcWKTJ8EUdZ7uKlGjrCV1Ftnk2GKp6Xu6qbGJ651Kk7fbbTX7enNPb3r5pY27rW5
jt7aelVr5W/s0NjW3Sn6JswtlSQjw9A+yPSaMD6+xXSdlLKUabDZVeOoJNazwE0zpf+M81/fE77s
KxGZJD6LZ0LL3I5TJllSoKIMdIamxN2vM2A5KzsXwJINqHXnn//bf+fc+f2zMTdbtno71w+vflAL
WkkFOT3KW00qPyuRt4sI8DO8GrcF3p88f66yEOLBmfW1gSFLtqrMibBVMIHMwHOtwRbd7o42VHs5
gjEbfjZj0wrmLmC+dhSQguuiGadpTobi0szHsLl4/g7DuDMbBnKB01LD9anuqenM/EqcnJI5wAO1
4W2s4jxZmOy1teoJWOR6quNk//mItcw+Ij7kf1bjlskQpeowBhm81LjZYq2drT21LpY6RF5Gggj2
b2ONkPNXq1dyTo/IXqdT6Xs+lxRgj42xadJKiUE0KfHsNagcpvfhzl9o7uGpRZ0J5sM+SeBcwefJ
Seh/cGTmCDTk9HWHFUxU8txPMR3XsHnkJNNhREbMEP+7PE3i5dMgXE7IXjRIR/iUqkdz4XGrSi61
dk0wVSfeKL3VPsX+aRSli/TIgy354QSuug8emr6NPuVvMYOst+bww29YxMQgZKdQHzSTIfj4FJQV
PUZvq3A6hnbnUzrPR2HmpxC2kEqh5HavarQhv1ndaCygJVLXq/LgRUtNkuLUfVfO8M9gBUSKPwmh
RRg/dGVTMt6uXB3ynzALoVuyWruKi3XOC7VGFEENZVJrjnixWjPk7Oy/IyUQmQ/iaBoOmwfcXc8d
TKbsK9btdMhX+3ccpe7t9quy8mN/HMWBJ76ZceNjjZQKUH59Dq09E0B7vKnvy7t2bnbNmaGu+hxr
td66FUKicLr6yPAJOA6W+IguYDFCzeJa1Gl7RTW55CQRcQyo6WiE4OPiTRqk6Ar6qJzNnZeHWZwy
qQiu1U4VUvFKSbaOGQYole+l05hviUvA9ecHkbbVXaLFr2ZC5oqRK6bjWa3B3XQqFDoz7AXaUhkG
yiX2deeeVBScKNp6sVkSjrYpKKVxLDarzEmbFgKyWRElsllQG8zQ3t14EMCsIYjJvKPoblbSu4XE
LJN/kwd5fVML8tqUbJ3oPVE+vCYm3jTxifZPRt71CTF9mPtunt1i8oZyfkRYS+uWOu4k74MJsOxX
6e107xI4laDZWjhm1PxNXEADqS/Sh9YvDQWkJKRFx0zhXi4HrmXw5Y7pAzEYTe0k5m61VwjwWy1C
q5j5ozX6jOFRh7mQvW9tG7XXa7FZ5HxOMbO7ZoqZdcEvaA45+HkuuVankijMChM7/I0EifHxWZb8
ITSsRvzXjjfyw6EX3zgJ9Az836erT1dz8V9rq08f8P/uLf+zWmfE+GBjP/HbuazMCOWCuZrhYooD
LBFUgQTWzLncsORy5HlHZH/MyCH0KmDR+XnQZ6H/gT3P8AxMt3wKEEPcdTQUZhIN9ZpfXctBKFLH
IjCanxIcMdZcgtNLLeO8aC1jcffcT1+A2PIn34ubrTaTz17BLXDRRNlQ60wbk2FVgAmfA70Pg34B
5NYLQ4z+wObz7Y2156LNzdzXHOttizVVx7E++BS7g989966pp8A//Y493cwcDqahPwweG6n2eJWk
qMCglXyVCEYGF5mo1kxUnPXGs3xZ/dWoBojvak/A9xaCsqCCEB3ygc3nkwG9LIbxhFBHt8VG7mSa
XDQ/MrwrqbNPWNhmZ9MoDvjV1BZbUOTGzcWsUDgOr++ZmCiz0hC6wZ/PW6uspcBdYa2qMqqgGHIh
jg2poOQu5ZONIvfYeC53L7zge097l+0+k6UrRJ/xfc4xiQwMZSXJrYuEwpZcpTPSZ+1PRwnqygSb
Y66lDrzAAdHywJg9U08oWcXBhX8ZR+EJqiENQLA9XiBnrC3F1TT5EM44ZyTN1SjC0pJl0ixqsxrZ
xBbICsMlso8WjBA8Mikl3FC9JipTxysO3eHYNfw4log+sSFSd3DhxdtpEw59Gr2bAA3ERCVEhlIB
5d0tDQabx5nyrpETcszw7Pza9o2AZMwazni3O51UZfez1Z88sQt9mF1v3uM/K2vegNgKkNWy/Mkg
mCtbcC9XUHuRgU7aceEEHtyRM5qifWjs0X8pjO08wP9e0u8JPR9GWggb/mQAaiWq8Xkx0xZMPS3K
dg19r8wASXD6bOTF5xc+m55PvVHRWrRgCipOcMqHc8vpZWoebusBX5kZaFy9Q7RDwNm6ko1Q4rV5
txthZrrJsg0zt7Z/rtR1eQQvXa+oIkq4ZqbNVkoMPFJz86E0VWC5IseyIzIENWSAisB71ZCmRUVY
hU1srrnKHSU3bNxGyEHNnGjGwSrMkPKTZuLUvY7icUmMW+Usq0TjJsAh8bkGlOGKAWVo3xcqLqxY
UcddtyZ8/PQ3kY2qUv8Tp/eQ/6HT7T3tFvM/dB70P/ek/3kHrKVDSM0OXE2EyxNIoHoQGoFpRyKP
xtjBReDFGLONpo40ghvOli2ioP9p5O8JruWJxU2WQ64hTvI0MIOZzTIJIkpzVbOpcW8UNf0KgaYy
Z6+gRFnjKP1SMwaUNeXYZXou30aZxbUUXK+xgILfiqxn08JLDXyjlvJdefbSUNxs9A27ar60mKGi
z5fiZpCi1p5bQbbRapZT4xsCU1YZreWD4v7e6L/E1LvpHVBN/9eerq6vFPT/vYf8f/eI/5ZBilbm
/kEFOkgFgkwijIeW3idCzRECq0mot+cuO4x9QtpBl4CdrI2xn/qRhI5rq9jLtiY3tSjnD8fQgAb2
ycdToL5NOFxPFGOCIO701Ub8mAHUALeV33JrWiDuNhGQmlROrpXrUx7F9ddfYebiSeRKiIFniPHQ
LcsDJBhQ4TUj36znsgAJme1rEceX1wytCWcj/2owmibBpf/3ZPft3CxlUIbCWTNtULHUe//6NPLi
4QsenFJEvIXif9DLuG9CkOsxhU6/+O41jIrPvlwsev597J0WcvtAa0faQTiWaW60lDUtI//eZXEt
jRvM9+IMsSereEtjaz5ZEifVA9gRGZBkDaWAybix6jEDFv6IPdGcZu8gg4ySyorL3GV61IYWH3pk
QhMhxbBI1EAT4HS4V2IG3HJpX5S0QoZcUfWl3XO/LjrRX8//ic4LXokB3V4inarWru+0tU+mGUoL
7C3Omm3COgzDZqvn6/rOOq/+OrZ65cwBB5OlIGjkQu/KqAcQscSNwt1kAAw1Xn3JLEKifXXoneY+
oRvY29E+bNpfPEET6O/YStZRi4m+tltP0b+zJFFSHvuF48nzxDLIO9wIXb425tOC2nSVbq/ovKoc
e3uVGudMjpxHt4rU3b8Mhoh6aC1wXRbxIHWkhkqVLZUkKBFUvZnzmN1oATVdKQMDWkX8M+sW+6qG
ataCjF85d5RgqjErXOvqLqlq8Um5o3RtJ+mi+7ndJbs6iZFuuKp06/0oU2Kp1XLaymY49JILYqyc
PF0vrYYz71odH7zRaIKJD+vXofH9WkVj+DON0Ahd5ap8XPpmpgHmJsaY6m/RQwnYTf9qbi/1suNW
eawrv6j25V/IMGGl7xszi9rs22U/fGdkenzaFLW+NHK8bdT6ZBL4uONK7tGtrRprmSNbM6oyLBus
OlXL3ceef5pZomZIvNVoBQtZ68NFobMWiKda0ID8t7He1W/r5tGaO05oQT9wqxkwn0CkyBqLiZt9
rj/dbSotwQQHowwSE4GKIsyjO0T0BejtwBufBqSH4+NgNdngklvvlt0IBqNAqKwac3BHHKXGiisr
mMulMs7S5FGfsF5nBujkjHi92Tfp3PwlQYMuAgtK3mA4LdqItRAsnC/XjMTKRkEvBVP9qaJmoW29
7Wp13e3t1P2pJk781g1+5JHaMaTzLEgptxh9uyub2s3eTtE/bcXqn9YtdVDrah5qMLpmkHUnYMBo
soS2RUhZNCjZ9+ixytfCE4iLfOIeOrKzC3LvnYaaz4RNE+nVVUIqR/vUz3QZ5EVgd2hVwwvzsCA1
KFGZHN7NHWqbf/Fc19AsNYapylhvzAQYMOcnH7PF2dtXWMYWmbXW25RMqWYMKIbBlo7Z6G5n8ch9
3kPYCiDXEOo2RsL/5/9xx2kswMYVgz1XVjfnxV+sdtO9BbACPmQQ5ULST/I/hz5mP8aVJXCkHT8e
UEJvWmWEVrqd+ej26o+7d3sDz+L1aTijaXReGZOfnyz+wRPW5H9Ox8EwAHKQYfVwqAX+/J/+I8db
MIouhq9QGUZcfyZXFuLkMharhJDZ1EW1MlHzqbG4lBY1GzOj4RfVa9wO6u7iqTvriJY0Q9GieMz2
0PMFxcGap7NaosgH9NaetU27uiQX7bt6Myjgu13LsXfFrxYiDtrzIOTPndtc57tdy/qsbMXU11bI
KeL9qJr1EFA8e+LSYv/0P2CiJLzkmka6vX/+t/8+Y4dbc2U1rnWhzeGGr/Ob3I3E4Ix5/MIvv/jA
8CaJr4PYREjAYDwMobEwHPQXDwgf5R/OnPbJJ9K0y1CMRMgUJWdjT6Scko15KJfDUqT0NA4G/qXP
On0S4bMQW3SoCC69Vh0GOe+B31vvLMQDz2AJF2SDVxtzaHyr2HCTg+5U5oEomxqM/yw1zfUWY35q
6kOU0j72Jhn8rPsT/FlukPGugvF0/BLEsZ1oGlbiIlqR1r36IOs/hwuirM93nlcXuiIXZdqLT16M
SnVKcyykFp5q12gkaYCwzhrYHwrhIAbHiE2NI4C1EjBhONc74m2piqRYIWkepiM/q9ChTKTklUep
pUT99HabXjVbc+lJdLKWS+m6CGHqrnUa86oISxnU2vdbUpGrokakzc3YFZk2wruFjC1zHbR1u2Rc
muRj9gn79Fcxe6UZVu539nq/ienTgFxLLswFZhgzmji5kOybzzhmIpjzYrBBOPfqLc/KgkQwBzoy
g/7No5j8yZ5RoxaJzNjGstjyIlsG083RHuTal4653I/6FpnTGnfAPTKmlsPyKgiDbYx1wknm8Hrk
eCLnBm7hS29EGbA1ZNIMW41m7trmiGKv+RWfaUu1Yg3yVROuce3qn+P6WSqndc2qvvDi4ckQJBHf
mReeTbEs5eBsE1lkDoC2fAnJ+mQllDzLjeU5NaQCGF/NI7vFwbm37xqe8ejquF5wfe72GqVOZhT6
1Si3X/I0stBQY25epkSjZloE1JTaNDjIfBdvqjmx/uppH/i9kvXGzlLcVOtS49pd3PNh5g7PTlbf
KrjiWo8DTQVb2LvyNFq2N6VEkqezM8cBuSEsRmIxMFocAcrk6/VamodcMUWe7JeXnAWcS5f/sYmq
J6K7fbaW25F1YQ2pOtspWbedEiu8Q8XFVGI8E6CoQnuJPVgMqrU3o48zj6YGV63NqwFXfcPjulHb
NFcte9yt4Z57M1it9vxVv2yVbScFrfs/Br6N6p97o5EfB96CjGIlg6T50BiPfVWtdA5dLRSQlarC
lIl1vWcDLBHJqn3gN3OA97cOViIuZTlrrupeo8wPxyj6g90bp467/ADNZgP/lp2y1yt92a3R5lXH
xB4NgD9mmJWaYPIlNJONs2/ZCqsH/T2jmhzeiSWGyyCNPPYJA9APzgpYuF23U94r3ZMquesYKLpM
SlLML+SiWNgU5R6mCySgV63MTkSvVqKQXb4MnD5XWnHRnVnFzWz31XZj+xLU8RiVgAYHZ7ezUjOw
hm/J31T3M+VHKhn4wC5nODatW4HOrrKs1LiBSviImupymcGDgsHZNHwcjMfkuEdwsWNS34w8vHx9
llDE6Gc0Gc66I8oY2pVeXXgsav4Vymc5QdOSl0YJnOtlI8I9j5XliWgu6omVi6izXW3niuyYYRgx
hVXHGw5PJhdRGp0ILPvUd3LM+NObiac1bXgEFS9WZlYumncJbmOPweXH5F6+TQ8uG9uMTMF0fEPz
2O0EAtQxss0i2ZJcl812bVpdk04vSKM1+vyxLK52syJ7GOULIwU6ZQ0LNC+JJY8jSjvHrc3P7Lqs
OV5bxSDtfYn78q24Kt9Mj14pHs10JL4bBXOFA/D63J4Pcxinc0RWaJ7zqRvuxdnBnudlFoXVtOp6
7q3MEFHwDNXN3Vqx23RcWLlXx4V5nG4zO3/mZf2sKo16XgFkqaC1gJ82Ziu7H5fkT3d5fOoGLpk6
oBJ+pzpwuMxPoiJ9VakzV8U3NfWrht0q0692O7fj9zlXZHDpHs2l+7tFr87e/LEE8/Fen+Y4+9/H
3lmAOZtuixLPs6uJuuCmCLJNkWAkvbczmVY4qyVJMI7KVDcL+R3dIVPwV3DnWy9ykb92jstcXquZ
Sfku0sJp8cn1Ix/uk1ZLKti4NUI1BxZ1iy1V5FKejUetjmTREaAiBCMj4bfHdsw9S6Wk3MzEOoOc
z0fKe/cWFjaXW5fYrl6Gh//HGWj4mmevOWvvEoxuSKMXMOphs0vTx5YNRliUPIxSb+Tni37/nVPT
aWsutm5uR7gHsj+L7Gs+OAuRfenq80D0/yUQfdPx7q+N5FPvHwj+XASf5gzJfVRN7qncA7F/UPzJ
iyP00w9R/P5kcOEP3n8e/Z+4gt76qe/81erhctOawARc5M1Ua+aVKH0hatzP8vgSbn+QeopWJjAL
wcBrbc5xTOtdzNlVXKaB2qg3FWEUz5wKkXzlJjNxOxPRq0XMqxUvd8Sl2JUtB3zcFV/0CvoZ+xdz
3VmSbfQoA+WQAn15YBkiS1EDaWDcPDwi7JdfshVL6RoSAyjLtsN/4H5qsyC8DOrWulNZ6W0Ect8o
XIT/919Y5omq/A9kP/VvngFoRv6flc56J5//obOy/pD/4b7yP/N1xuDSNPYSYGeAHWLNS+Sg/DY9
IwbpF8913dY8iZ8bmlhIDpi8pUaFP7y7lh0+6FvHdbuN2e7xIuUPTziZRk2tTpH9J58AYWXVli4B
vd4q8fRPcXKCORH1LXjGM8JLbNB5Zd5LFG8T+Dm4k9kYdoa46101ZWo9A0Tvq+x9p52Jxt22XEvh
Xt5qmUR7BpSzhaNqlHmD8o4UbzSVvOiR3LXI7CDueaHoTEdSnlpplifpbInHhmOrrLlyxmjr2kCU
OO9lFDNdscvxa/UJVYnzrJFImN5YbQv8o7TUKxJ7+uzrxs39jAz3lrLEVXId652uOVx/zqbhgBYe
OgYz5TWvWrAHRDbisg1+BbuW9l7LcOSJQoWu77OtZ2q5FO2RbfjulXYo4LMoCbATOxdwitXnHylb
uNi4rRm1mf346cJH1317L+odW3TC8F2iKs/9Ueq5lHyGkiJ21jD9Av7bkof7Ie3W31T+r+cI8XgL
6R9n8H/d9d7Tp/n8jyvd3gP/d3/5v4aI9xmE7NRLkhk5wID/8CYTxvUKQQoM4l+msGfwqY/JEX3M
2zXyJdKoz+JgGIGU5mLccIJi5yAQmRWhFF5yPuYVA8KNUiFqOsNI+IxP2dgbvDlwsUb01+zz7GOj
x9CBNosY8poe9PLSQwDUkQdfZAinLoibqDU/D4mz1YGsStODLZYHDHjHcz9NytKA4dw26gZKJTD1
fqhnyc6lATtFF9WxASOY42EncFnCjaFQkFftGcC6wrM9lwFs44YpwHC082T/GnvJe4wjP+d8GWyo
sRqC5BfU9Y1gXh4BF+kuqmGSsphtsaPjzdzTUZBgYJPCPlKbNis48lN2GkcfEj9Wjr9amp6YNbFE
AO86m/DPN7xOxHE+R8Ti4MmTVo7f403Drcye+8n7NJrshiCy+Il7er03bNLnR8Fxa9Nk4oEJeORj
KriYQ4+/OWv6LfYMmm0RAHgQTv3iJ8AlDilwy0mjeEmMw8FqsjdnsOfOoiunZeGhsQ7xVVkzFDKm
Jgi33WZFiEXsTqbJBXR90xKpIhiueFNnBtXiXgIH/jzAUX+sXAAoF5jzj6PApzCtLuavvaaBQ0Wi
QfFuM9+RcDoabeb8rkePeQwkbMIYxAWkURqpm0QBEcAREjYkg5zoiePtDaNwdG0eb2y7r40ImshI
B9R1fu5Lkgr0lwCcKVSmj4RscOE/JjjnC6JrASZLpF3Uoqdw3i4NgLowQK7bZS+xWughYkLLAcHe
Rkw6zk7Cu0BQfaEK9GJEpXNzB4iwbnErb0+QegjymU5T/QiJs2Y9gRx+bys7udWHi4obi2vsrhHf
XR8pETGm36PyuOzBsM1o6bNnKl1MVgj+bgspSz1EEtZWt1UfxsA+tYrDEJfZFnshfs3Pgn04ouxM
cpHSHPHSxlbNiuAW0ZqHP+G0pBY6QgW5GzUQAvjLRRYnTX4K0oumE8XnbsbqOa2yc19Kxi78aQxE
LBi8jKL30wk2l+sEzsIlfJidr8Ik/ZlP0p+RoKrZ+XN+veWImpSOeXT059z5huHRQ74d6Cn2Bu4R
bB5fbQLt8r33+UgMohhUHvtoo4xYQbbPMPKKKCqyIBO11Xy1x0QBRIgURfg2489xj8nn5k4r0lqx
xy9bVWT20lVbi0qnVfR2ZKe3mMQVmtFlcJwVN7dpaZY6+SniRWkaWkz8QkEyU/OQZ92wdRBIFsZb
cQ4REc2jGDEbkLyiqoMzdUCD0P004+wQZpN4TuQDq68K13oCCyNRh0r0RJsFvKpxQ2lFiO3MFdmU
o9RGh53x0hTIKvRoqbt5K101mnUpDSnQ1WEraynYNBZUPEdOAg+RfX27+fXVZ2Q6CJpO5wotOFrr
HWh9OES9hRv7kxHwgM3lf+hcLbcxMqP2DqiaVtl1kZWw0HPJQ4mNbSqUx6hj+jtMINmZpdMV3GZB
6zQ/RJv8UjLpojz/s6SU1LJtFICM1tfzQEZngcbXa/HclkSDd5Ct1aKUvb0Q/casCENcqaSQ6G+m
H8eMOEJUPk/g/HwHl3mELh5/TN3XEf+rYUYM2vV3yEO5fLPB2fPdq9xXu1fAOAopMCvHd6VFgWzH
lcJ1vwGs1HojFwZdCjUv0UAGcBxTRCkY4V3qjaZ+IoaA/KzF6lwrox6ZgLwEE5HYMTMWQKQX23it
V5nJZ63XKGkxz7MT8cBpjYEFR+BxlTkY6VBnnlouA1Rmh794fUPH3GVL/G/vNGnyluCJtj8ws2Z3
pSR3UbGt0ygacTnE02HT82Qe48YWiWTCRatOsTcX/oLK5PyG8i7z/eJ+Z1LIgpMVxxWRYryH5IZD
kmNa5Ses46722Fdyb7lq4kvRRvLkrA7iSLfXWTRxkzQNzcIcWTioSip3uPPD6np1C/VhRIgmBJOx
N6lRUMKCGLIibZ2mXJlcGoJWdX0ZmsyONO2RaWJjo3JhF1lczQpYihhTFellfYwQm95oFIRASohZ
ZSDO85Naksi1GsPoZsxJWU0g2pVxKhWfSLalO8udWi49Hzes3xrrV4SwKopdnrdEMjvu2k3jT2/G
1ZRulPLtEIxILpT678flhPV+9wLIsktr67OWErsOh7sAcNKbvZy99ZnrWZGVs8DM7hf8HQx1ZQmH
W1KunOPN/4ik733LTQPXq/s1XUdVu1v5Asj08VXR3Aumm69BxWrE9uK1L9b7rmKAi5fCzIywi2aC
nSN0XRWfB6alviPy3JfIPCBZO7fDo90O8BVxtKRkKiz07YBfPbgj3K39X+hmPMN0uog/QKX9H9jq
Tnc9Z/9/uvb0wf/z3uz/eo4nFPmHXOHPfsRtUO0N4DEQgQLSygKrgsqBNlrrZb4lfJgM/BEapQ5R
qYLKBLTsnwbwu88IgAgTOF1iEBRa7MnCj2p0bkdPnuxRhUMllaP2Fy0WcYThf9itkeCjKMWpX8/S
z/90uSt/UssBYC+yPPzhehLPcgt4MYo8JJ8FzwCp0KYHaZAiY+CYqxHA/JKLvGMz9Xc7Jcb9p0K7
hADA4+mYX3pAyRP4pbmx0WmztQ2hYLBa+huSlkdJlitbR7mStvLGTNPnkaLaPJ+sc+6Hfgy7wGkr
l0fne/2ZuNMkUD2UcNindr4aCbPVzjwnnW39mVkNCGIISGirSWpK9A690J+ZNcFdBrz5yQdaTVt9
p14ce/JDUd93+Aw2PLlHtI368NFJGp1w2ctWoYImwy9FhVkWaJ9nbXPa2ljjdHR9MhhF0+H1ydC7
tlUaRmlwFgwufK3S1/ozc9SiODGaiXXUwHUO5NTLUdMzgiOLx/ydrA/zB9uq0cvKag70Z2a3BKkS
q2HtmDxARo36M7PGIDyLZEqEY9Nihh8/D5rB8GYuCsIxA6sxHRSI/y14KTiOYeYos2IMongyp1+6
hk3cqClqzWs8qOHWXhIlOZNj1XDYGzkxe2nhHzhL4VS71RbGDy1JijJP/FgRFXqRXM+LA1t3V6uR
sTZK1RzNgKGzxGQ6Ssg1L6W88j5Pvoh3CBp3USkWoGfLyGNEMon34KD5ZRXzG14SbOF6yD+cjKbQ
bXYBFzLUlrRKOze4gEvVt6fPnRWyu0CgrCiuqcw2ZpUtMwyWrkQVQtisvImrFXkTq/LC1th6lpNa
VayGViJTHljTGf76q4oxnNKzmZXNF1S4tnAW4PkUBOVKgoXmypaO8JZnpjv/6HsLDn8u7clLGLol
bUNeeYJU/3PhsZWkeLAeoPI5E5Zb5f2MLEWVggevgT10NO3P2EYVfm28lXJ/FetsAyNkfK5xRFzM
mBA2reKNgs3KOkWpzuYCWbUvYHVGuEKvokv/uUXDP/tLIwWWjbHaDwYDygJTH0Sgtj39Jnbz8m+D
ENYad0bldzILBRwctxrnRjcDrHZmdMZq3CYNgtc39gdtGM2cWE1+61hTFlKVVrDUYuXrEkbU3/4Y
Dfwc4vvvf88eCWsOnwYDA57Ya2bz01/sWinHip8/lHDWl8qC2Kv92eLY5na2aXbLtoDOsh+RfMo0
cdf60gjs/LrWJxjx66kZMHZIre/FrrN9L3eYiiNl9a/tu1mxTzNL1OSHMp5oDqPTYhzRSv06P5ix
2vnFMLhMJrjO11E89kZ3u9S/uZWuflvHUpa3mCHFvZsbYY5EM7dgd7PY38zbsv5d+enGMMd5s90t
qmfEcKR9YR7Ir5psfF32vUz9NMOlbn6coYJYvr46y1BcAgeuha4rFpxCQw6uUUBELtiaRr4GgZ2f
JbCxAr2Nxt2SGU771eCFQteQO/4KYQsLj14gDUDKU+GImwyiOA7uEwtrhqCLfC+snp7WsKrcD+rS
xGUTACdZuGvR12caDhPpUtPPpsg9SKPJdvodvS9RIkTe0Oourc8n70dpkavK3S2kKb4mwsN/iVV4
ZClPpFlZ2nZkzpdZcn7yIUgHF8w8DDO+QceOzBLXl8L4RNjhNmt8rIxv2dfS9lbnc25ry74lO1ud
DzObWvaxsqnVqSCzn2UVKPtZra5zg5nWd3pQ51NpJMu+FSayWh8L25f2MX9S/fHQP/OmozT7Stps
N2+Vm+BMDJ04Ss4kjoQ49H/iOih0BAAx26fLq2nNsyR/9oFGj0b+SHOYm+n3RtVXlio64UFPzn1F
jjaVBgNkc3FWEag5xqggGAAaP7qbJV6lt9fylWpzrccb7W1sLhShc+s8Yd6V6zbyXsn0VxizTcnb
GpwtlFmvcmFfcgPPlfQ5BwFrg7idn9ks5nxZK9J1zqTtoOFcmLaj2Pse19sfBAmtp1bEfRWEU2Aj
Fsios7jFsDfDYljiKDzLRrVRYaPaKLNR1bRPzancV0NZvYlzrTDLeKMpXLVnMZDlJq6lO/RSH3Gd
m1brVpYaq01wmtZC1Ymx5udjP0/qnLnmUU2dm0YvMSeff0AYgU0QoSlHn990gvRk79BpwcQN4YcN
2Sv44RnGfvihPx7f5pzNUP3MYQi7hclxsB3aLtzywDM7054hAHGaAg4Cix5+OkwrdW6bXjVvc3p6
803Pyp3dPRUTKXPbRonHLqdRALzT+DQAUvjtTXPYrs5lQ56xWcyxWFM4zknoLBkflY1Dz/zYKfmy
qkRF4GmZCdNNQE7zm137/susZGX38E1NZIvZfi23VJX5dzDwTjGTdnXdXLU38IqWsHq6vTq+LQtp
O+vA5Nt5qdVbM9qVebf0KrxberWtejWU+TMAXWfYl0rDaDbtVqUc5H/vRnrzmraTOY/Cjcwtd0lS
F+dVZk9lDkUfhPLLOApPYuxXIU/DHGj6ty5plQpFQnVzE5nokFz4CPw/QZmTWBAnn4vdammuIg31
bg8xl+Ng1oVB47qDG0Nzj7wpYZNetii0X8y+SUr8EDB0LarDcmnYAQZgiF2dqvsBS0kE2caCYwYI
LCsz47VN/+FZ9RlONOXuxtblyYLKD3OuFt+yrttZ/Wyh5fNeeVc8G8Y1J4BiJdZXs63SBQoj98Na
XTKYzbQNl3tOb5KFRrPSU6P5el3b+NlgVucfjARDpKsZZWiQDePzUw8BOcT/ud01FJ/li26b8f+D
Fxute5+F1XU1C0/vdxbKJqHXumfb/OG/UMO8Sd3uzjBfk7e7PRSBhdi929QdGFzgrEtkUbea208L
XamfyDNTu2dnPgVSYnCmU9AATCcTW4qjt8F52dHjERfIpmWJPoBRCmD5Q8yxGNgdCgmqVH27H/zT
f8oyhSCDlQTQxaGPIYwTfImxH8RXtPFfTPNjr1dmI5k7t3qvAoZCphdpdtyv19iS2hvcNOMh4lLH
rbC2hgcCV7+PwJDP8t/DKdZSIspGLtlXWGtLZkVcxn/uYksc0Lw6d6kNWv1c2iAaW+ByDNsZPH2d
m/YzK4JkVpWq3baAL3ExVKwe467Gzf3v+VwLHfFMvt3k2WdUVcqylwNmzQGWtbiuqlqzg/UiDF6f
98ZF/yk/vvRRSh6kO3E0uU2kLe6xgTedXJ+VXqfuFwppp9OphdLlnKHKcXkZNf6zt385h1GXs5t7
qW7IdOmekHwzJgP/fBQ0Z6CQ3NbFvc+DH32rcYHT7XeJR/i3cEZYMB6Tydp13eK9KGOTveHwZHIR
pdGJNwLKGXq25JtKTwxNaHAECM773E+9wYU/bB45y9MkXibr2PJpEC7rsf1L0qHnuHUjVZL047mJ
LulGDM22wgmsw8LI7jJfcT7IxIyn0SWmpAhCPCYROxtNg2EJ77KH7HGMOBfIwKjcikXcQvTF3CGL
UoGl0MANt+BNncyWdebigHiuaezVmYqXklcD7o0wQAJjSoivE0wca/o6Q9paaGIS2bmKeVFlbnVa
ts/OAqBMnp6xpNYMaQlOQtghlMNkGFzC1oC9MlKYB2hTTSKovAnMhpEW5Tz4p/8o0gf0FdjJj4vN
nydGUbWt5EDrzN4tChXAAUIHmMCCmWOK1bpjBWSqJjnwMwgNZk+W2UpvfkGBf2uICSgerPRaCycn
r0cBzyM4s14cRxiD76XBHDPv8Y9/C1MvurJc5UNbOvfi48Lk9zZat3DP30zk9pI0YNM0qCdlCzLR
ZwM/5jQLQUXJhUNSkO2+FSfJKPMcykhX159DZ3aYD2yB7VH65NA77QtHiAyM36j5n//t/6avpXIK
8m//Q59xQHn+Ait9sdpHSIbpMKjbFVldF3ilNXSaxswlYeCbjb3sM/KwFT08SL3xpC/IMjB/zi3b
zcjx+LNxOs/1/F017y8jixfzzTReC11DiGRUcQVRuplb5Wn8AQGLIGPyOIKNHoGoXGf0rwk1hIOO
wKwBM70YQ5fwDlRxLaKL89+6BS3PNqxX6POsPfX1frWULIX8WLMULeWLcxMdyyKx6HboMdjbfWv6
rRrCn8JoxQPySKSIKY8oEnsKC39LyXZEspcalmJ9T/LvMZmOSwBpweA11iMS+AyiMULm4J+Ow508
yz3eywVPmxB6GJ2XXT558TP2x8DpOjXEbi59fqxhoZKpowpbUHh+tTZnVjIC7orK0k5ps26NbwrN
Yb6gzXuOi6w+7ufnwTQ8B+4gJOhwz37ya2BSLeqEbomkUtjbndloVXZbPBqk9sJJqRcaQZkhd1MG
PDy3d7qBNbBRWZT8dGaUlZGG26PgPBxTYJUak0sPf6wwk92GI3E9A9SMaLua8Zy1tHUlUzJ7Ngxy
K1fdRROiSGA2I5DTwUQll4GCVR+KpFBWJZq+BFpr+Gf9mMyVu5QYSqbikX0q6l3ttqrgojFyNFCZ
plGyzdbxmjk6/jycgLwVNTuyV2FHNm7S7JvcRZq9MK7TW7pIixeYzOOp2515Sk+M4fge9T8ZP6dR
/HqXsTcc3uZNjLhM8wyhVUjqdcd3POW5M/rxV3bL15MjVQzqZ5MlXxGabD0tMQjuqAv22Ic0xcS1
LDoPAzb2f/kF5DGPNbnS3BsFKWz2MzhMXjL24DpJEszbzA6jeDGFJyHeVohd9P5WZc2dIIUx1JmW
H6cRYVt6PD+r0AB7BFTt4WkI/YR8gJ2FE38soFErY/JWVmcn5nha3+5c7YA5i/kzmECYcO9ujL8G
R7ha6xOTM6z+5mYcosnhyA09ezbuNEStuvRsAEN+H+0OAzTgvkBs3QvdE45Gh9mlkWvE3J8z4s1q
Riws5B54I2a2yMnhyHSOlgDd+FNK3um/iAbTpGYUheMnLnsbjT2nVgSFbL6SxZ2T1b0fafhGF9ib
GPkjDKOlq8ylJNYR8Fz8z9QfAyvKTYlPmPOf/8cdHk7L3w591CfjtiRcPUyzDdsooqyzCVzZAUZq
lUSLGvcAr240jc7tpyfjLg2RHzPgOpuayuUs9pMLZ9Ng53jdnihuxey5GReigCw+GxfyGiYeZhxW
6dSrbZJVmBwinbkwxcL8JlGbAeeRkHMjsP9ADEAuYU3ETQyV7nsan2PW4cV4Etgqz1WHK3gTo9xt
8ijbl0h2XEzonvJk2F0UNLpyWogVGfHU8ChwmOXRzJfNn1ay3tQjr0OaeKv5qanMUyVzq50GRTvN
/j0j3AxxUnbgTJIOn5Kwa+dlMPK9+AQ4rdyJEXUNxHeYi8SvcW7q7tZ95PTqzNQrLxxypx+1KOgY
gB4VlPdkTHaZ0h1fQySVU0Qtld8TWTaLsEKOrOdLREO5XqKqgJYuYV4FI48J/r0TeNEj+iVK/un/
SqMMyFdCO7Zu3uXorqQsDrXz2Yjbd9wwySUDOCrRpJbAdYBTFbIUPr4IeIZrBicPbcg+SltlSXIm
GMA+RHr3s/OWZ9y5RFe46Gen5DhW48DWAMGYoZzKKamOMCFNm3UxOy78uwL/rneOZ8ARzeP1e1N9
lPwRbpl0xl4FYTET4uyYYumnuTJH+PF6Xe5N3jEcW4ogYAIz9qHoitvEWBscTD4aLpPqDihdZUHO
a90mLCueSzmvcwGPzpV50OSnTZ9lUsu98gJHt97RvTgO6rgmzC2EWTECa2QaXHjRF4R5nQ2/O094
l1xsse3mWuu5JDk6bfMHe9HM3jzgK7s+jaAvc5HmID2f7lUcq82mT8d+HLBkOuLeNlmypzpuGPLe
byM9HiCXTu63Y38cxYGnHFq0fDyLuWmkXgpfY0sCY6/CYSNf9la1iOLi94Z+TT+d7RC5cT0f3kun
rjjJG9OYY8q5ZfLFHytyu22Kd9yNimD2bp0RE7iFdTixDGQz/1GeT8vjDU+BzUQum5TT0jEXiCdx
ECCckCNQmwwxzJeezwMoivxpMiUhI2g1avI3OZ8a3l4RjiBjYEpZSTnqcypgG/VN+Jqi50xCsFkF
xJFS05vd90Zma8gmAPM/8t4HR1j5MRremh8/tWrWSkkgJtC3QTCh6H3ehJs9ouuukrpji4/enP4Z
mEX30htN/aRp7WDLTaCHzQHShIHWQgsVd7k1Peocc28fbB0H1ppvouMA2P/pLxwPJJvvD4KZdK6M
2BwR4TPHSsCnQZXtj1vmLpHcwZn/+KlNVrqj480K23nMmvyzMYvOmGaQ8y69YIT3LMZLJTjfR8et
mQCyVFWMFyE58aRN5185LZjXaiMdGisfUb+P4uMW1xnQ74zvgk1pL4wrsUE/VditCeO0xFZo/26G
KVySdOMwSxy2pvlU29jfIkZbU9uHzgyIP/P+ULpQswFt5+FGazPy2PV/+YUjwGmO0tkCc6wLEcsK
H/3uxpZzpenJnSuRUYg9Y11Sl5dNTi3/trc++l9mH9WzriOybH3zukFJ5PXULK50mzlaR9q0V28e
hVZj893ZTGcasCjhWnOn5s58G/AoM+aNtHCZOus0p27hyOG5AlD3tC3yBjjHbXbkKKaS3qi/+DsU
efEFyb782XBKTjP49N05xrU6x3WVFAc83cbdayjEtlcfHHWPZyfEwc7BR7kdK29ZubLkLiPmr2UK
mEed45oIGPMfGLWx2kZ7rTuWh+Yg6c73inoCqcEVwGSX1bFOC2xkRGJxe6gnc+E/vd/q1rNdHvWu
jfx+pJq800SrZyl3keWupxb7hnXcTveuNiM24ukb8T524YtRpTZ2MWSCWVleDZlq/Za2cGHtgt86
+ay9V01VYim3dVcbU2viPrfnDYV/DjR8h2YYzX9L5D11Nk0+xJYbtVS5k1XH8bbLKuPJZ2tUs6/U
XmVVaYqx2dW94oqzsrqEXu0wShECOo1eBFf+sNklssy+/86p0cLzIBlEZfVjyF/0LkGdUaFyNoXn
qCg0IKbpi5v05w9+jDbnl0E4vSrr1ntepsbgeMBQvh7nR4qBb/5wPYlHcNFD9zJbaMuZM6xjhMHf
urrN+ReJ4nxUSlt47gLnchICpRJAqT/uv4Y/pPAFr05GPNalPasa6VSa1fWq4HCqV42CUACvr0+i
s7M6DQCjHw8DL4yWYv88IrFNNPS9fENxBx4qDXytqeQi8EfDOk0M0B/2DC1qWeU7+jNDgVujwg/A
ei4B5QCpfjwOskr35SOpTdbq/kBPanV3OkmyOimwFrO8a3WhFJfWqerqbOCvLsEivR97oXcO5Dmb
XWSjUerw0jS4xPXUGhjDuUkjVKLVaSUwXRFEA7qDAhuMYL4pm0/WSDqFy7TkKjzGIwiHoEnGg0eP
bLGGl+ik/lcOXL5+y8Dl1Rzc8jK6g9gXhjW9DDwDxKxrb9hqkz/EX6bw0J+pMCzCYBr7olWDu1wI
TodcYpayDXZcI3ChTmzFpxqaVfQvqwyDnR1HgVMHcpVPI56mldEan34L4POrNcHne3Mged8Mfv2v
HmB95bcKsA4kMTwJwpPQ/5CDV++uf0549VtKZDXxf/kFHbnG05BLygMlSh0K5jS3t/ImJsl2ZkoX
vl3MdRA7D6iEDHHIDlHFTjHLGIj85qvqfVOS4ySbymkoBGqk+xiJgZGe5OaGjpQZ3mE2O1wstPuG
ZRbVRnYdU267bPaAgfQSkWlyihOIfQxDnmfIa9Q8sdI7TF6mqhLzRSPv71UK3l4O82jCOnbzz/UP
TdTFGQZ32eWGjeZWJ3s1QmdUsbhgw9QS6ZadJVxm+BD4By6ToZV+EgAHxfXSmXtIG0OBYRt4aME3
kgRne+MtVZRL0YtjxRbKD5IUBp3SIqbQ6MzeXdRNmBlgFaId/teN9hfpS8feVXNto83V0Lmdhh6K
qxlHWnYpz7yErYFU6+WrX1KmNKledeo26SkYLCodZ/noGnNc1XNcz5zG4n5y+X6wlvoQexMOLkoB
Rj/Bn43PcVfPvp8/3dE8KbMkTZV2fspi3nOTq31xjzPcrTeLvbkinrSzyJWjGlHY1JKKFDgOrpKx
u0DLQ3iK8zRWNJj/eYckvQZ9UEkqGmWTaN5TxpWQEXPpaVB+1U+gxBzsUb6EVAZkJZLgPERHe6Gm
10IV8/RYi601HMX57t2fFt3H1wu8gBZ8KyYH/Wbh27m9tVU9egITqhO23A7+O1/+kmKMgLxE96fW
3VDpqF1ia5L8vqIUuJxcCBM0QmbIyl4UBYG5ksdbEwQKqkON0KbZvD1fb4ugsniXs980n2zlb70/
3bTe7psWR+nNGl7Qm7qLM01OdiysXBw3ZTECo2RNzWrVZsrQr3kjtTgHGqNdDePAgKvzH/NoPY8J
cPEcRTgQ7odl9ID3YBGKQG6I0t5HHrJz0ISftMgR3sWq4JECJekVCcN6njDwrpUEeIg2bxDjYbny
VczGgTmptU89P1XC0aTIe9wkN4g+KZ5rzs2MOIjqM8THeofnSHS57CRpWx26fhbFFXJu4o+L+5jT
fPqvTyHGwwqZxj8Po5rXnxQ+s1tPXfKrhe1buNZ4f+YUaGEyh1783o+b/HPykMl6JG6P+fdlhgGI
C+6PzXNjFOW3D0y0S3NlvDPuISunY0nAtN6quxH98Ty7UN9hOKLi9vrU+C8efv7GftxlPx0sXw3P
l/+ijBvLBOW+LAHx3b+MRzdqowM/66ur9C/85P9dXet15e/8eXet+3T9v2Cd+5iAKbr6Mva3uv5w
6Z+PPXYQ4O0BbFkDGDUd3J7DAbPmAAhOSnD2o7PETS7a7IUHHES303KZcoxAa1zioTcSiA/4MRef
nD7WKvi3acikZdpDdAYBIdUMRsRAktv4eYBOwa02gigpoOlLCgjjTCRHfPaw2tBLBmhrY77AdfAV
qtqmuKWgWYQKQKwMeH752I89t4EmujgFAkxGPfWnOgTFJ64cZ6OhpktcLkiS5ZTxW7o8uob3F29e
TCIDI+3DdEWpxFy2h3IQzkFfzTSq6kc+CGWJCGbhjZ5NwwHJb95k8jxoprpNE+14KTp5gwziXdNy
6X+48MneUKK65Z9v2qoZeUm6NxnwoBrLoyOHjJ7OsVarvUBWvSgIYl0juwDVsPhEeebAxCePHqnh
RfF7FCf93J9arI5Yg1ZZK9NBgGiyQRz88kuUn8VH2pu8oVYtEKLFeOngoukgZm4aqV4kwQh5N/SC
kt2gEAxvOIz9JOnji6yBig5uo18Egr98bJhG35RtZf3gIEOHYrtY11G03JIDdzoUeKReuLE/GUHP
m8v/0LlabmP0SVm/8MR4xX33iKAWH+lN5eaN9xzGDX2v0b45jmxb5I34vNoPiT4jZwi45A9/Urvk
2/J36CoArJtp8Z69xrS60KplXbWuf6raNdQT7pPDyquwfEiZgX4hLhlI3qSk/dzKSdoFRAPOe3FL
xbm4MIoDAwLIMHCsswn/fMNJlAgogSdPnpiuL7hQgixhwaPguAVU7GX0wY934CZp8ogCBG81nsJW
4aFc6qsCsYg3TW/TMPRpVIk2DLjjz/00I6DZSOQUROFb78PuJZzNpo//jfJ7Ce4aZxyEwRikzeGz
Z3uvn++93fv7v3/T7jp981YTVxoZK+EiTAJ5ERYmhLeUEaasAas/Cl8MuOMoYO+ALhRZBxqOWjKI
ru1YvDSwQfpWRf1ssR6SAHp41D3mXeiWBJfJPeKaZIJ/3DkupxJ2hbd1+GjPl45oQDEK7wejKPFF
gUZJmGdxTuFw8m8ue86MEpaxqzMmsLgkLU2ahbP8VyhCVfD/38feGWzbG7P/M/n/ztpqjv9fffq0
98D/38cPUDWxzkCkRnDEUS3rpwYkQ6uK/c8z0o0dL7z0Eo0xPuf1Nwz9EjK1lOUnUCjTlne94ktT
e6WrOsvL9Yq4hqocDGzExuicN476rGMS/A6QWW+aRmgWgRE0bLrZjU7DoujtCfT82A/hJgZS7aX+
+TX6e+LsuDtRRCCEwJvxWqPwRxrxzoUXnqOOBh0/obv7XgA3Usso06suRD2oLsL7XlbG5A1oUzQH
6VWbXbaZ1LONPfg7DvzxJChwe5dIZC/lLfMN65XxexNC99gSWVGXWVN9tGRkcYDG3VP/PAj3vfRC
J7s2PuTS4EGsDOEVlA7YV7z9TUuBayjAlZfQkx78f1P9Rfl8uadFEGKC9EtgSqDvMCG5+w7nggPx
dFo0BLxmDqMmTNx1rijcJn7pfX81gd5ATTgn9k5rHZ/M13Os1N77bN5/CYAZm8a87xO68nHZllkP
BjJpw2wuGY/gSXGENgsVVg8cRfTeP0ivEcRB7C5z4XH/cRMJsCublo+bBXEgvyv1qmAQtN3aYppy
/dSKdSqKECOS343ZMpzjWLAYkk3/JZ6g+HtUfSN7qXS91trPUewhc+wBsO9YWOqI+eS4sTyE7rn6
7RQVxytrreq6uvXr6rQsg0Yds1ypc/trG08kaA5Rl35BtIAvsTo/3UFvuytgXntDJ3f2MetuqleN
Rx62LOJGcMpt7gB89Q0dO3MP8E9y4pyVhhCdNQkJ/1j5WBEB5OVMqaS6zl7dSnvFWrHwV9B/t7tm
kyJ1Qs2rkGvaE/SajJb6NOa/yNF3wifYfLAO/G3q/8l6dnPufyb/31sFZj/H/6+urTzw//fE/78L
H3OHGsIPlQZ2JEp+HMCjg+vxaTRKqm0ABz4LRqiPzypAa8Dgsf+YjSNS4E9DBqT6FN37Ep+4ZR+z
WiXTiHu7FXTyDc3lAAUJrkNp2OzUIh5gEMQDCR1icvhGwEanUXTsmMDd7Em/jgpNfBxgBngo2czu
FieB+31w4UAP/vl//V9jwA/xB/T3f8f/vvAH7/nf/wH/xuwt8NcT/F2kVcOX/8t/72TRbPjRZRyF
J+hGR6//zX8SddFj8rvjz//f+Ny/mnjh8GSM0cTUk/9Sr2wy8q5PMBHsB3r53/w/8JOJNxXd/Hf/
L/w7eR9MTkKYdf7s/6aeTWL/MoimCX/+fzcqRmXdCVzQ6NKQUCgGFfqf8GOKWIQ//3//x//q31Nl
ohgV+d//7/CRBEImlZ0o+1/pDSTTMLymD/63/0bM7XTI//6f0fwBYyHe/8/x7w+wSy+wS2H0gT//
P/yX+Dy9mKIsBjstHvP2/3u9mUv0OvZPphPRh/8VfiMeYqwof/q/oNWbTPgI/pv/M/6JLggnGIDD
O/H/pYHj4mgP/z98U36S0lXBswU3t//mvXRRwQJIgH1mjbrIO79k2zt7Dbs1QA+A7Ss/KTTykTkv
9l6+hM7RxocnXWipg9PHd9VqB/+IJskvDkqz7BO8/siZDe61k6uQkKz65NOF5yMDeoPt+X8SajW7
p/EFMB6/oH+FPefCD1rOhdrJGbjYfXg9kb6/f0zf0iPYfHwFbugF+S+FG6q6/zVUzRuxAbPu/26v
k7v/17vdB/v/fd3/Bnoqx05dTiaoUWsT8ujosYdHgsfazKMJ1GJs6PrW2rFcwBK1NfOslK5mAqm1
ScV4avBWw6Z0W123auh6AhLU5iVXGesindWECmVZCxgRpEwfk8tHUHTAzDlZ3sgRe+wPA48o0Ezv
fw6YOgIhz/RKEz51wpM4Uw9Z/fOpsPFGTopU2plul9d5zImrskkS7fNqlpj8d4Xla5g91bo/p/PF
Gf2Y9iF9qq9gVl9Px6f+zHneZL6XwI3hpnSR7PI/3kzT7zz0LhEv0dcuuYgidHR0ewWQ3JutslWZ
YoPbrtzIc+BZa26CxoyrU/jIshCtBx3Bv7z7n2cZunv5f/1pt1OQ/x/sf5/P/29vxHgCxYrLvq/5
7uXSP650MGHCNA1crOwgYMBMnAPrAGI/wm9j5hEfPfsoOdljrNxA/Fh6xlQSzIXc9PYiu4Mejalh
E/0pQZjOeRSjQlTOsD6ieTjWUvDHwJ8EaRYvli+hZRcrLUMpw0rfZomOUAi2FpmOg2FVJ8j7ofgW
lRuUUIwsspkN9Ogjf4wZtIJQaIa5wujTcc5WSI/3yR1/GAz8oiPRgG2Ju1cWMTX3A563qruifAaF
+G8vtp4VQz+U0fUJzcv1ydAr++RrlEnFH71e9j2fUPObo+7qShuE3w34z3rnWKXDHZg5cJlzFp2f
5xs86qEEvbKxjv/5Gv7zdQ//s1ZRjaGhyHflKdTR6z2F/2B+nJXeCv4HK+9h5StY+Qomz1mB3q6s
43+edivaMrUk+cY2oLruBsKMbnTxP6tQXbeL/6HfnmKz2Is1/M86tr2ObT/Ft0+f1mh2HFw5RbdP
rsox/Lkyn9Ys3V3O3mxkfS3amqlMHCCxAiLjxrCf4Bigu2PukUQP15sXCH0FqADxqba9xxirC0fH
AWZrRKA/yRnH/oETs5QGY8SWcrprjg2vyrlI00nSX14WlHQZXav8EM6I/+7tnkJQbBoZMwko79sz
2CxeuvXn7u9HIAVsBamTIcMm6TCaAl96kA6DaAczHgzSKI/cFoUHKdD5cZaXs2iJTuPrknBvfq7R
b/NfH7x57cIxTPxmehEklPWyBCyIf4RZFbfY0B2gs3iYnsBTzBAahaUA8ONCBsctrIWenOxUfaNo
s/jihe+PkpfBe7/yK0FKxTcX/M/rqi+IuIry6FIGd58//MN4clH1kZ50cos18Vtcy5OAPHS1PzO8
7k45tOe3+hfomUcu4iAaUZ/4+XsOLapXVV3jhH5L/wvpu1bVDuzRymXGWCVaZ7SCw6E5oQcwMPPJ
jEWnaxHdcfDjb+kfF/+D2d31QRonpKpbYTRG6+yRM4zGpLGdIiChM/Zi+oew6BwgOaQG9uld4p06
x1V1nlfkT7DZhIdyEqt8ViwOzTSd4tOjoCJbgjidhEvLQv8De+6lfvMDeouS2/lht9fvdOD/nNas
SjCrNznruBcRULhrXEH5e7YvV2Ft5NOj1WNYkHA6qsi5fs69e6vRsTj/0WdBlqcLLlxK1IWreITj
c8/99Ll33Wwdt6uhiBGM4AO6wCDR2CF+hh54V/xBnfwAfC6+zZ8KemycC2ayalaIqdY8WSZ4i5xP
K7ph5GgeT3yr32pGA2yALuME71ZO26OR746i86ZDdeLVlxCzTuY9OHTB0LPtnVowWYdwKeq3EWkW
oM4+yhBfsfUOxw3PgIHERZ1LBK+xEQhNmgMcAaaXEpkO38A9B0xi7nUUHsoCQkTQEuvWdywXHbL5
lWPqeE/42iHzUmhFz1GifUfyd53vbqJ3qZL/p0kwuA0HgBnyf/fpesH/d331Qf//+eR/9K9CeFU2
pi0wwnQGl8EQNQKv9t/uHczlEFxHZD+AYw/CYOK+mgB9KRHfqS9VpnnR6z6jWly0ePuxipAr/44Q
ZiOd7bXd1aL26ggXUQjuZDdI9qEDXNIQ6YTUy4LkY1aO/B3cLrJ8x7xGP5UMheNTTOmC4kMiiBT8
EO9q/ijrVnWYosQxExV9y5ri+zT2Bu8Pg3RE+UBkpYjHB5wx2XsduvWc6voxaiRJvbIGtul1/eoG
9GcQVlX4Lh4ZFebES4yb4tIlj1Xi1WQTN/DCQ+A6Rr5aVlm//jSjylnNlwiPXFnx99FrFJbkE/TA
sFSEYYFImWdUtS98NVR10nmDV2neFRX0X6VnvOkVMDP+u5v3/1pb6T19oP/3ZP99qWXgBmoRXfpt
jLT2EDBFYihWO38htjDhoFNEtvjCp7zWGPY9wooTf0B5FZOJFyPqPxRvouyH35WkjW8tpP79iQcu
V90yr3WXo0Zj34MOcET0Yjy3uHHyWeklkLxOsTGDFk+ZOfGAV8S8VtkjnkVTuLwIYx3iSkUTCdAh
UNXwD3HyBaixLLauynQ7okTOAL6SC0YpIEN222yEdNfl2KaiAL/H/KvBCO7YS//vST3d0V12HFzg
hFsVOSn+aRS/pPuVphZj6Sj0FTH2kXosqS1lK043c189dN9c+jE841P9Ejr4Y+B/yOncqN/1zJ0k
R/DI5wJSk0LSa+QyFhwM4mCSIlzgCAHHiGkoLLdud9fT01z4Q4+KRhYjfEKvG4vCugt7PV+3oj3e
o2bLctaA+HERTDEPpBgJBZ3DRdLUksTk41yTgIlivkhS7yFrw6Yg68BVxuS5hSMCQ3tMoiC8HlBL
rVwCjLE1VYSS5B7x2XF53RSz/4jQbdBVogJ3x5QXRSV8LrAO44HrX01gtrEviLD4jHUqhPxvtRiZ
tQ7q8Kvq4gIqchTruqBqlS7zKyDqLcnWY0rQVRm2FSCQ4V0yF6R6jTzZaOmfpP7wO7T8I9L6H1Mg
pPyvUmE/O69DqPcQiUjAXR6MT/a92BuN/JHmElFov+iyIc8OJpJwNtlZjBiXqz3g19G+Bf/kvCoQ
eGF+n46Ou2HRxVT2JkIik16rPokedTdL/DxmRkpxF+G7nkDsI01ffV+YvXBnehoMFp8g+0rVnReE
PcCg86q9VdkR7MJcnj/54f61Y2dV8P9Sx3bH8d/d1dVOAf+pA8Uf+P/PpP8BgYDnxAbeKU39goeG
JgtwXg+DH0AkwDAQSpnujS7RvhBQbf+4jLf4WXAutpWeG8X9cxKFmxzQE/kHHxlcTKuE3MVIh6FC
RqNQ4cX1JOa1Lhm14mtgWLAKuHsVgkNrUXeSCigo8coR6cNhQA7zEib+tGuyIqErnqHS8BKvb6Sc
CS+bzg9vXu06LdJjLKfjySy1iBeniJXap9rQ4GMuxozPgWXw5UgtVVRNv5NztOGY95iPrY/mqMBV
mf9yRfjVIEuJv2wFlVNyIMpmD2zFk7NoIBx4qLT621r32VkAW06WlX9a651Am7JO/N3e1/NolPUT
/7AVQ9AyUQh/tTZHYrRqkP9lKyjMNVQss5LkcxCgaUIUot9thYC7fw6yxzQ+9RBygQobz2wfkbgb
vSI/MPGN/sg6NJCTMY87HJ3vqKgcZP657WOeuSpIZQfV3/YRjf1XFJSWRmpA2SOLixgcpIAn5dQC
xF7A8bAIqnhqMkBVD2W3SBqlxXmkY1QghJmN8AMa5rjpJ8mx45RbbTeOgaXPy7ZRiD3SUB1GkTfU
AFqj8CU8IAcPvUc0MGklVC+8CSW7liCQppWK1/TCC0ZFdxGg0NBHuFMuIwJiDkY0I1k4IJykCFN1
oAMhCjQYYxCIAGQoFY+9kZnaoayvppSMi7099CaYlS1nkCwfk4WnjEJRy7sJWskL47txQ+rXf52o
tixaA9yWxkOLUyI6+XnDDx6QSMdeloIfFU3tuGsb9nI8BEMjqQUZMGdnyMjpjJIZLTV3q1ES9rSk
pDkcZ6OIpKO5JF9mg5yKzuq/pKMVnaKCgo6WVyevWk5KHaeirhwlnTEfJgnNZeLMjaZIOmd22CSC
Zf1GrdM3/ItnOpEt5vd00iheOo2jDwl3nUFnRi/WAi9Pg3iIf0bxuTuOfgmADrqH+qtilaPgNPYj
2EADf4nOXSwrwMyRUMs08Sce1XoGwro5huPSfEJLS0vsfBSQYge4tD6ymoLjHQYFb2SRarmN/r3c
w5l/F8nqmnkWN1HMYBQC3YTaee5QrF2BpSJ767GMbyx64/IuHchONj9+atkKidfKZzejw8CgO8ik
DVLYxzxlJvAioxFb+rPTsGHb07BeotlR350ZFBCw04Hoj4nySP6BZodzHoHEs378tGm6nRQ+oRKZ
tlbrUYHqlxDZT7PuZsmbl13RNkbZWNL7u6dlp8yJJ+tgq+Qytn7ifPzktLTZsXu1+iP0OM1Pj9LU
GsPT/F3FDiOvObHJKEh6xL1g/3xn/qhqrIl1x2U+qOaeK+qqalzbdi8mldkiklsVba4eGXow3kH8
2keNehzgkqB8rJEezGSGr868kEu8nFDMgWTpyjm3uRD9SFYM3YfIWOO843N+XGbieeeH56/2lraX
uk4u4Tz7FVEARPYO/hds/kEw8Ub8z2TgjTALs4zdNHppNsLz2Q88oMGqfCGKIDFXmn7ld1Rwdt00
SEorH2CANXPUR72Tv/+90TnDD0S4i6JNNGmx5Cg8drNPoSd0uHPu5gmPf6fiFAhPlC07B/zpEfUG
X/LGtQI5sphomGcZCQP5L8Xo9sIMtMnro816+vBL6aVcbsmpwy0F5CdJxJWHjPsZIV9wBjzONCrA
RnG+noIDWYj4Vn4V/UWauq3lbSnSX13nkGV9QBwJpHJFQlRCZ83LXuqR+hh3hJEiXNlkqoew5Kwf
c+sShoH83IhLQN8hxGF2vmA7SllmKtGGPC8vo+zyrT7N4zgakmE6HqHpHQhs1P451OIkUvaE6oRF
Sqc+hURM0Wh2SeQDNmhONwbLB/cVTDY9LVal6ABRnaYgSm1z+7Xy7XtSlw506eeQTMfccoQDhruz
mckR6KqLy4Wuug6tjkNRCz+HnywDG/ooGXItPa84joA/5BQKa+b8P6+g8DXfKNNYfmvpmJJayvtF
m8fevXM/9GMQp0T9594kOYE553WT0ZC62yRBBiOjtSqpMBoMeWlexDIRRD2kyGQSI94JjlMbTzHc
m1fNcWyFKlbu9CVgnf3Y5yXGePn1CWwdCrpf8adnwHZgf679JN8LidduUIhCnNkoDcZRph8UIoQO
Qm/Sm3zcjpLnERxcZ/VaOVu5DTsSe547f3l0c6TyZierKzbLYv22GjUS5uZZMVut5UnDkwtikAY5
yccZvx8GMVuasJ+dL5vwKy0w/N792Wn9THcVEb0z9vh3yWN80YOnz0QJfC15fs5ZsmfLQ/9yGW+E
fEtcCdw2FL1tlh637CFYeGm9Q7eR4mLq0qTIzGabFkPqzC/pFKY8r+9+d7D7Vui7i/tzavpLTt3B
hRdvp80OQou/m0wUtPgTeJcg4FSzy53/HkDtatj/kuFtRH/X8P9bXcv7f3fXHuK/7w3/ZcQ4zBUm
UhZSjEjWgipaZO1u299b+uiVuN5FydAWp81x5Kxx2pY4btNtT2DQYexvFE8iYVi6Rsrhdro5pzyZ
L9Xqiidfdkud8Dp2J7y19Ttws4OpmsfBjg8leY8p486JzzJDcYwQnE5n05T+N01/JmjbjDES86Hq
gjLS2WlTq7m7jjUXqhJLJASqemE321M9P7oedCPhSvKxTcR5aD2HHWH6bBYDiElFoHewaH2Qw3TJ
NS5OS3FwyzL10a68LVQiiSA3jPZBIotuniVenBZjnQRinCayenjQiiXcr62IR/IE1gXjMeBw9Iqo
4dvB9MkBKxUy3M6XyjZnpZC5bDlWJe1cW8La3uqmBKPkZ+4m2WvLsKH0fI0bRbdFif60UfTbFJtv
tdTPsFY3G1Xpsy1QWXXGo3fcALeyliwfSBEji2NTfcWafNHGU0ol2mF9A06dv+RXaas1M0m4nrUg
/6Nvb954je1tydFcJ/N4SSp3MQMrxfnh8I+avFucFmMquI9scUIqsrvayxpp7u1F6mW9n53xfvHN
/FfmGljB/++LC/GO8z+urawW+P+1HvzzwP/fG/9vCb5p14r96aOzH557H9El2uie5xALxJJLBHpC
5UIMcnc8wNrQyc+bTNoilrMtxA0P080MIrQnBUCXJ8EwaAuRhGrMopN8jiWFtyVwbIgt5U1iX6BU
cqiKQuRSxLh8kTzZLvX/43+6wCtH0zS5YZhR3jdQ/ygYAttaGnIkWdCc7JKLKQKONSHmrlqI0SKL
dHmmXpyREnI6M2OOVoXDxu3KNXK0dYSbw2hiKfXevz6NvHj4AjPpFSbxWyz9B72I+yaECwMVf/3i
u9eIrNzQ04HR8+9j71S7O7luFho7UkvJjlH1PvDSpggD82LdyCSDlMzeGWCMCJEyLPR/q2jrOLhO
Un+8g6YSIXxFcJIjEPM20XNjECTEK2jFXHIu8RPNWkIxeyPKYTdNUFGO4VCyVTKfyDOLdCFKgsdo
NlLdUk5eIbm5nUVSmWvxWYAqnkNrKsVTAQ1iSMG8fiKMg3poUyZMrq517FgOZXpX2VfX6EXLlhZR
lWhieI0uSRrfZqg0R87yNImXYW690fJpEC6rcmQRh0IOxnJXFNNCw+0rrtnzzLnJi54zBE5OQuaT
OIlhigmAolzkvEVps3BmTYmTiArCX4nojxE6nX/Mo88WKkEGdXXjLuFhRZCINWTlJiJwjQY1CAML
2VNvgbolbhTuguw88fcxQegMGiPyj/ErSbmuoDJFXFMtRrc8mUTQyOVkXdnBqzzkl2uJQF0anCYL
iCuqIFRnwnanEMaIll+dPalj4C01+qrBoHBqkZf48Ggg4mK0RtGJYtyTDuiUVA4+LYrab6MP1jmb
K7BPL4h5JF7RPBamMV+U7nxVdt1aNpv6nvX99qWHrPXHwpgVWvdm6XSsrpfgH1XspQVWozCUXmmR
EjH5Bo3yxG/BUKYo2MXf35YqLEzx+4D2tXsWo4FL3vME64XWLoUTaFjsuFkOTd9tMkJbC/ULlrub
yO2VMvza7OL15Pn5ZPtqgK2aa81XwZh4SlyMukiRmPePqUs3vN90gvRk79BpYa4Q+GFD9gp+7mua
e/PNV2/OCbM/nTGFi07fDz/0x+OKiVtk0vIT1ltv1N+Tlfux3l6cra6zXWyGlP1bvtnWfss32+pC
N5upyXcG0dmZ7zs5NX5PqfE5W0ULdiDW67Ncbp2bEzznraHcWZSAbVoUupt/FRTfspZwn77M/H9R
Ak4U5rkv/+bwL+Ru9jZATcgYvkR/snMfUwuLuCf/Nme0+znovpFMpnxCZbKX4nSWfpLZdPvskm09
sy3FFru8RRL7U7D0ImDNhGes43qNaegJPBD+usXmprM/BWdBxhXnTnFJV7gGlatPFyX290PuV1eB
szwHKjsKPJlc5glQw8YCxG7ueyCTEjszCLv9/Szz4gLUt2yeVsq5DKlu6W7U4izIXPoiitPyTpiq
GC6oc9UjqTELmpWS7+uaL+vc8XOvceWd36v1iXn3V39jAYqqwQqIRJAmK9Dd2LSQ24rbSN5Ie+Fk
5vwpBxJc1JklFxBRbyKL1DTdLn6jq9XyR9xJaGeOLWp+7A9xyvXvVVqp2R0eBZOaU1mD01j4aMgf
ZTnSVXIk/Nf6XLB6O3TnTMPHcOfU+xCXWjaKv9f6qLDYs/fHp5klhH7zLXlyKf1mvWlHpaa8wGDo
OuZ+zRrI4T+rAeHp0QQxTQshZVU/s/T/N5uh2nM4n454vqbm4Sy/j4NhxfwjDRRzfltX94A4lFIf
IR6f8uFAXhTrMyqqUbAEn3gCxGWbR1OIIFU8Ys3sdLfZRrlO5C2holtR+PQfAYOo7dvK4hn6YR2m
KRtgfdzDCr8sdT5l1sDuRostV6xT3j/saWd2V4tGr/1ggNSq7v2F9j5YNhPEUOYszLg2ZrOPV/3c
MHXtrOo5Yz7nHVXpETmTx1qrVRx5rb2xd+7PQYZl/7IkwzlXrvyL2jVLNwjO1ays1u9Scg2diqMw
miY1mQY1YdE0RicJgxiQ30sG50l/t27plpiTY9GO6Eav9hdzJICu87OATaXI/WTTib4ptT++CaNc
yjB3a386P+N8W8xCFT5p2XUt6OPd8sI1kE2tM1k/Y2rVj5ZN9aOkONnWypjCMmbvxmtzc96rjqaM
+/Mtrpi6P/XU+vo9WyM6c1gjegtZI2CHTSZQYA7lVdEUP7f+arWG/qp3W/oroWWppeSZixPJJGWZ
QILg5qYJGcuJ2XDfAlN+XVmLUP7QKTgJo3SGGt80E92tlp5mrwbPxGOQxBzcrsIOCyKsel/MJ4qS
fnzpbycT2LE7cVR9A8zJLkkWSWQvmj2meWTQOzbQdf9avE/E5GapVsQDnjWGorUP/PAXT6SR4RlX
XhM6CDpoxwGIf0OBHvO3ZEP8LayRyLyDi2QUsSXxeeEFBJcCIjubhuyUsnxE+Culg/qrt1YWI/ys
57K8sf3pKPFgV0szQD4UuLdZCAOmZyKLc/I+mJzI9DzOptVdflMwkRxISiyZlgro08KdW7d0bl11
TrRECaXQxj3xgMMnAzYm1jrx4jj6AJ2TybNkfHChq1lipU93Oo2YNGmeKVRpmW6TEc6c43/znPBv
2i9nMfNt3hg3iH1gtC6i9ESApBV8dH6bjjjSAqN8+53N27wJLdbImdea6hJhu1OY1d4Y2LkgDObu
XHcOc6j96XcYnhTCZEbUs4QQTAWEnJPRhbPpaMQ3QY4EFGNAmiRvt+ZpD7UdWmMDYGRnN4MbpLUg
cTFD5G7F5w+NKqXbvOb2VmaS4jWpm0c2GjPMIsUCh2hzissEvzlOn1ijzOFZw+HFu20Yodh2MuQP
T6KQ7rn807MzO8MjcyU6r6OQDVXF9sIJbiX5RWmHtsk/inpxMEETtL0yunzLBtYoV0jB9iydji32
qF51n+58vRyZdiu9rjH7IGN6UPSf/iM7g5vdS8ZejRU4CDAaznPlJzj5h+i+Boc3STyMeT2Ee0Mt
hFe9EPnqZq7Bx1LNXzluWC54TI32uLU5k7LcxTJxgn8ReDE5Q47wyjlBLSc/RV78nv9VuXy5SvBP
xv+kWujvZDCNoxqLyr0/BEYbMgOVa6a1XPvI4CLDUuU6HY1BQqLukk7L+RxHRoEzzjgt2wqjcQ46
ZQI7vhhNA7HIdDb8ekQql6ejznRr7WrkqaKie5hohJo8mTnNBxJxco5ZNlAqd8/OCP2aQ/XVpUOF
qmpPdda4NtPl1dzDRCcwfmAQkhkzraOr1phsovJ+hvzuzJwhTqi9SRzoTTUlLKhvCUupw9UJ7LXb
tJ1UyXE1F6BK1OL2L//mK8xRjyVcTAl+TNXe0ECUSpbvgFZK+YyLD/j6NS9btfZzqVqvxJqyYncZ
nWHmLtfrLQi4g/Cyv7Nv6/nktd7catUa6ro6RyMD/vhtHY7ZW6LO7ufLKpKCIuAikCMOZOqo1Nus
iYGaZhlY1hZdBK+B0mI8gpgm7zbWeuXu1zovUDcqDXOF+SmZSy6T73jhAJEnnMobZYCgGieYoKCa
6Eeq+YGoly6NZmsugC1LPmPd6kZ5fXkzN1TxYTGp3bNL6uVuyhXu7nXyI6c4LwJit+XGPqZP9a26
1VpZk5X+YAF3QT1dsuhdMWmy4pcqkydnW3w88Si9j3XuioMsZLu93Xyxtmm1Z0K9m+yn9VThGVIT
+y0yNsWNfqD1+KMiFgiUg4lqBYX5jgfybRIOOCr1+lJgj8IXHmXO0RO+W89AWUPnMACtqd1kEDha
veUaAS0FC24EhHvH3/2rIHWO6/dAIMgAZdS78TbAU+LV60kyHUaEah7if0lTQQA3BDokuhj7p5is
aY6OTaIPfnwiBYGT0P+g9Y9/cnvdo8ZQ3VTo4KfSjFITYcBiE+4iTJBkmSEZCUgUwqC0i69fCs1z
qiW3yKd8S3LJuvIl5IxlJRLgLb0R0n660rTLq2BS6xReiZMUB+fed67xEIP6OgWEIA3TQXOChkFX
OEET0icrdwa6JXfnoq0X55pGdgOM1zUrxKviXk65cCKgNzaFZerUhvvaXbsZ1KthpznlrNjmbXD6
r+BKmI4tNpvF+5v9pvmNKp9Q2C6bVlvjpsWbc7OGq+am7od56mZHofwcDwP9AqMslpjVMqJzhIpJ
f+irK6CNr3lGwYj5iX8u7p3s2B/odZVCcs1xquegDDyBqbqtctlzjEI0rHy6MkFAMBe0Tj1m3LcF
9PNeFZwY7rECppiYZUEr4igBPrHPCIvtoEZQRfakdXNMslsiQtbYivkoTs9KceaOc5C0KLFiUHfU
cU9ctQzOF2f047AK03GJbHzzOAxO2PTuHARoD/gWu5OUeG3NbZguI39lGMIzp6dXyUHQjGlw+V6I
aVq8zQIOvwFtqBrNsPJn+eFL2nowH/zaDO/5Ob3kdW/4oixMedNcSagI5lSMkxJF5sa8CU8ESbJZ
vXycFuMrCaZOE6yBJc7k8f5F54ipwn/WnbJuAgI9I/9Lr7PezeE/r8P/HvCf7wn/Wa4zS4l/Qcll
Ggo05TnyvjTybA0hGou6G1VczSCIBxL6xkxcnd1Je7ysEDlyGaaFC6IlL4xoKZki6ZT8l5Nrit/n
9F/ZjvKaNYEAWMFFuChdWTGS7RlhxOOShB5SgDK64qmOEB80v1jFeSGRrIOqmPDQbrQkuF/3GLJF
jVtieRZK08HrqIt1mg8NmclMcbZHbsyc8UhnglSR3C7Ms6mqnLaDMgabQ4CpMnw1danDdmPL27oe
PG/FJT3HBa1dztmITKXBQ760v6X7X0CM3jwF3Iz7v7P2tJPP/7a+vv5w/9/HD9wR58BsHwR4cQMD
0OAJIQRsstRpjB5HsXezJHAN1YSgcwplnWPYDr3UK2Z6vgDGHd+45376QwQEK5/l84I922JrlPSS
fcO6KzJ7F3O+m0bhOdw9YeRYPumuqG82zG/YBC4IlLUC+4cb8sNerjEP3V6KSSr5uzACofM3mHay
6vxr9rkbUYHq89/tra8V+H94/HD+74n/f6e5EPQ5U95G5vg89sao2+QeU22uYmS+5A4sSSFbt5lf
RaRKKb458OPLYOBjUg7eaUoOaJc/OFRjMQOFtPuiMqBh05ZKg28mU0hO/yKYDgPJ5xcBe+j7aXyO
7GdftEPqf2wKSQd/5FKRwTXhcukDecefuztxQLrzkmZ0EWob8YFyuZV5KxmBypEy0QlvMkF2VeuW
fFKRwtcs6ZIeJfkpSC+azrLTQkUYphPuLy9Txm6jcNG6bhjrcDT7HlRkfkVWTW8UnS8FIaZ74O6t
rQKltdVU8eWnhlUo4yndvKsmsvNh6LlmgTZb2UDXqt5qY6YuW+qxxW4yxDNmT9NoU1Cbymmxt/Jq
cU1n3SgzlUuDVz2xogiqmekydUyCRl0gAmEx8DLvtz8K37fDXAx4Pce6UmhNs5iyTZquQzUgCKoA
h2rDDShb4KMmp0auIApw6IwHsNGgqaJvkQk0ZEEnrxEhL6PiRYOSbFR4Lc0ad2UMYDbmRQe9AGjA
/NNQ2Sc4YLan/TyKoq4wrpPyhCMtEGlpzOm/Uv8AqfO50vhtOj/OEdYuDD/Gkn3LzH2FV8Vrb+xT
7DpnWXkE+9w+keXlZ0er14Cy/DR3StMSWlgCHFJGE0uKK9pYOSBURf1dDVXjbBi7vLkyTz03Fab+
KErykProIVE7cLQOIJVUs/1d41bATuaAmroBvJQBKYW8nHEQWjmiNQyScZCg2CxfSAZ2c+HA9xrU
oCYl+BB7E07liRD8BH8W3U+9q2A8Hb8MQn8nmiLR6zUWpCZ2SmJOWDIFoSe+ttOO32rK2ttcE3V3
E2zwIzts8GILJ3dgxg+juWHtJsv5grh6UfYgvR5xGOeFlv40Gt7FuvdmL2axyCgI39fBso5CmN/3
24jl7qU+uZOH7zHSpdwH8mp4vgRSJHpAYuHjVsVWejGyIqTM55eeRhMJ7LBavt3MtdEl5txNT1rD
RINlLvfxtYC9VYPhCl/36n0iesBU5spyH/c6mGyLYuJKLNteOUK9ECNpj20T3FLRiXN1No7b6iwc
N0Jy5PUv7uc5B6OpX+Da4G4fHy4PBpraaMtNOMs5qEb1zVHiplT/DpmNulGXrdJZqzkWpjag3JyQ
njeE8tTtonkAzyC8jN7b4oGqJ7I+i3XnPkgz9P/xOHD/nNyt/W91ZW21YP9bfcj/fj/2H2EAHAWn
MbC9aP576cOVdB6NyAlaprtmcDOxSTB9LCCuDO0/T9mNmU/QCOBiDdPEUyHlfxmPsF6sIRnEARxe
n/3jMnn6BefLGLvCd9xSoMVV02sXv5PZloM+tiVjXZiAdErY0p8d1kSU5ja/79riZmzJjzG8u8+o
fZQuQWyK4RofcfxB4Pe6X/c6V93ORgc4IuhAIJ/zBPIO+5U5SRAG4g9eq/pxErzWqNBwSqjcWEsc
hINgQj42SJ+WyYzQJh8YD4g7nGhheEF1LPUsOg8DlUQMIz8p3ZQHfUgikN0ITZEPBY2zyOyxkAMq
InKWz5rk0RhGWPHI00fIxoiVjwHbPr5RI2TeNI1QJT7wWm6joeyxIC9OY69JN4S0yHJr7JhtseV/
aP48fNK6ov9+uUzMJS8rcAM3G5pKfgwcwEcGZJ17/TTHR93jVpt52oMehtkwborZBEKXdYTvwqZY
/bYYvuySmIwt+Qu0/vHTptZb9GtCREMqwkkZXDFwEzcTZJATYi0J3lv0mQwn8is3ga0iSlIDR7zs
catVsPA6ZrNy7aFhVdtZEA5ttXH+Vn/iZhW0cFCyiqPOsd5MMlFDP8q+EJUW5gLq2MfyE1ffGFCs
qX37QbCEzhVabrQX4jwZzeNOxirFOkLN9Ii63NVLjrGU2FPYDSpBeyLfNO2LQrNMDGTkp2Krb7Ej
R5x+zDRt9hUnAMfAU9zSuOmvzlWHP+I9F3N5BlU0xYhYdKYmu5Wzp/G1IWNdrq1WzqiArMVUy9LC
Kx9kiyWW2bTHPRrkc8vQUN3JNLlo5gabaGNUer42neY26zq5DDPFHn0yWh64GUGgHEGSit1Wh9qw
+HEcxW3bSs3RWbWRodVBYRsnud2bmJs2t3GzfTsobluT3mU7N9u4ibZfk9w2lVsVZnWzeqLVnWJu
ISgFzTaXNLyHsTtiy7znLYJ1uOpo9lxydbe3QFeTrXqnQ7OUa8XLWjGrt9Sgf7if9W9f9U8LB+YX
aWO+nSSOb/YHtqv+4N2UhlyNGPPK/ww8ftP5OXSoO/Dv5oPr4tz8P5qmg7v3/1vtrqwX+f+VB/7/
c/n/YTZbcktARRYe3vdpNKny/gOOXzCnnshLHVBFGZPP66O/2ugP4RPPG2S1D0ZekgSDqM+A6+Wl
l+Q7DwSR2McK/4KIbizgwKMkZABX2wxC1NAg9p/3WGH/QVkE7CDMOORvZzooFh2N9qKi1yI5FdHB
aFgjDQTqXF8ElycX0MPlU2/w/pxoZbJsjs2dhOdO0T3JH/khzoXQL5a6/6CjzQHNe581dY1veNl0
fnjzatehS8tZTscTTgptK+I0TIdM8mLhkM05ryJofAAiV+TG0zCEDrRY/okMtDK/IzCO7CPjT+OL
T7muwKYC2aWJ49Q7UxHgT8AHSwOnbdxZzvg97CG2NGE/O1824Ve6Z+D37s9O62cHuXDkTNIz9vjg
xZvXz99s/S75+efwMRbpwftnomy+Wo7K1tYWgv9+rF2gYktg4Bq80byWYL/Gw0gLRdOnYD+OBiD7
5bx35HRrjMoYQWFhq+RhIc2NRrOyJD93Mr11kg6jKSW2HgbRTjTCVJhRXj0ehQcpbMLxC2RZLuzx
e0L6weW8CBLSlLqwS8e2lIe4KSbSx0ycJzebp8lmHdgF+wzR3rJNT9nOQBHgDPGMSw7sV3hGy1/+
eXKODIlZJ2wWPH0/w3HjC8K/5AMVNc4qAxVvMqDBhcqP2NIZfn0G+5JEPcU1swESZPEKRvSV3ASS
KGLDv35loUEtVQnb3GR+4g02iw37g4tI1I49C/2bbyOx9JzeGVsnASkk5SycFNtjFJ9jsakKHor5
UP6RupIm0+gxTA0mD4frAtXNPt5iZ9MoDlhTB/OT19CF37ZcKbytF3CIc3BOEw+tLGIsGSlQ7z8g
IMvOhRee+0khAB+ozi7KR0k+7j4KsSn+GRn7Y38UeUO03BdJhzl8EVKcc/yjb7JneoSx1qgeZywO
proP9DZ2JLiBi1l3xxO4JfEbrfADx/3Xz//fQ/zPyvraWoH/X3uI/7kv/387u59M2TSMpEa6TWHB
I+TEkyQaXZI6GjH5MGCYKCtrzogBqHT2967RyNBo7HuhP/opgGo/aAz3GTD7SoNQx1zOQf91WLeG
ZmlElJxoIuFjThGRaSz/wowV8vc4g9IT5NW/Goym6I3GfV929T/dvfMwElben0bxS+/aj/noRvhr
Xz10v1MMhKUwMqbov4AiBLeK8MVxdI9y54tuB/7XcxqW4AXCqSFju3bX5CWHcYQTKqKhTZ6br2eB
5xbqs0i4n28Zbv4mZ0saU1UQ7mnZmoxHyIrKN6gfFV+Y9WSjaclwNJe78Vo/IWUYfVNWqvr6EoM/
MFjSlvgiDH3h+pFNC1CPcx8ZHy4UKgO9nM0o3OaViIschSq1oV17c7nbPO+KTYIADrGeH/8crtQV
LtQDlLAK0EA0xeixICMW1MhMzEWtoHRbUSX5g4wD4WCIWoFsC7BvWZfp+VP0AHPxYZ0Q8xEiaLOv
WM8eZb4XvpkC9fKGBnYPcq+YGlBxZLTNebbALTNbIFl1aMhuGh3QiYN1x0JqUNmRsI1zK5v8T6V7
QByHv8Vd0GE6etO/3F2QTfQd+YBU8X8il8WNGcAZ8Z+rq2t5/e9aZ2X1gf/7XPpfoVgBZgakYH8M
UrLXRsZvAGwg3N/wdMiZPwwHfcw8ylVTqR/mbiUgVrJlYEQG3NmhJwhYICBn4KwQcCYqbKLbVdgG
ScOCLjOYTOEuKXhnQV87rtu1fCAmI//RzA/eJZRAoKN98P135cUPo5RUyJ0ZxWlJiiMo7w59gJ0x
v6qsP9+Z8uLJwIsphLgwO6fXwAd6I+PCyi2F/NTyLqUeHPAiWddlvUMliKi9WFrJTlaHrYw/hr8o
z0WfLXW1AZyjK2wbn22xENXSAUs8Sw3nuKOyL3MrUqMC3v/CmkIF4qwUbQVJintmB1sW5gLL6wM5
weVFdkpKkEwhVWBVIEvoW4Wc9JRg/fIgS6LQez8O0cO65PVEkR5VpNT4Ae1QjHXe7vHuYPetsHvw
InkpCcd8Aod/H25azxYDTgWQ0pWWoMU6wQ0TiTKdks4GYcom0zANCO6paGiZhudBk5TWbXZZlLdG
sGG4uUSAq2teBtyEfqk9+nABchhI4tI5/hvedAvKTsPkIjhLm52K4s+y4rxwMcZ6ZLfTcCds2rxN
i9Ao/QXORlEUN/kmL3hmnJulErbMNtZXO51Wm2BAtFfw7nfiHRRaWacyY0sZegVF1js52JBzjBtQ
0fHnaBkjNT4jD5KLIvCHVpoXodJj/HVcxPyg52wchI59ugjiKki95mnexHZKGCOd1Y21p+uqRXi6
rB4CL/kiuAJBsksGPfbqu+Uk119RSW9V1aB5a/C68B1+/Qfza0txXi4rlh8L0MZw6P/yS/lgnq48
Xe1uaL0RfVDP80P6/jv7gMxZKYxJvOaTUj2o3ByUDM0LvVGAIzN8IZWHjxdzPYhjev7EV3BnwvNO
m6Xy1/xel45sVLFu68gKkmsa1hdQBfDPN8K5hZ9WePLkSd5JS9QOX1DRo+DYaoPDOY0N5IYvnBYq
JuSY4k3NqvSp+C33L3JaFo8t0+ktFoNb/jl5smzphWgQa/vi4HD7kEyxg6POMX8GVLrgiJY1EJIr
GCeM3ZY79iZNLvRZTI78iyAUcHpwDR+tHKMLVHi0Sla0TulHnHfAT9zYH06hsSYQa9jtW8+YB1Wc
tq0f4/DUNaMCmlolgRO8qSHuFtHeUnZJufzRZtWXuE3U8PRv5UP719hLaJUIHHwiiSgCYMAG5r8H
YROYly7UCq0sQydbluEWgxqywW+RypUzkvzftuprP+v1p5zdN3Nt07fJq91X1j1BLnBq57zyx8S6
9qGswVdrvn/ojJxRjs3ZNW5fesEI4076tE/NemkKS8LKNDkAfQqN75Zq90erKquFV7psVjpreUqm
9vXuYdVxQ7+dLTqdcBAo3UjT6aNV3SnZ/vwLrHoUOWSqzjiTbqeMehDNJsr5xFyrYrG0UOzrfLGS
ob7bt45UCLNahZ2aFT7fO/gDp16Kndpiq7Y2NLlqjs2YCW/6R70aHyGGmtYkzzGlVbdsvO7rt1XF
eA93X9mnUBOjcvNIPe3Uq/77/XfW2s+JRhVrrVXpi+3Xh9sHr7atNSvPsS3tAkoCZ3Mmgjc/HhGN
97mXYs7RD83iaOlCUGKFEeKK3z7TBQr7xU7XA5Zd0suaHRRieI6QN/mBWtLkGje+anFqnru8rd+n
xe/T4vfZnGgDReofX/X5mUamqC/OrUbvteHwIWavcvI/MhX4db7ATvY+Nd8rCRleKZFLPWzjtdfK
lz5Qs5D7Qrxoy3kufLlT8uGO+M74rNqVCRN/anGjNZyZyEXnMXFSjzfZBUijbCnscq3bMmqpy9x6
HuO1Cp+cA2FnS7vs8T805Q36q37xtfqPRW1w3yCoVnmFcJlAhSl8CH1gT1bEd6GfLg/9y/Lv3u0/
Rk+mVJSfTtJg7JcXR7oLHwzP2NL+e9iPv6omu+UfIfGSrSTXyTL5/SynlKV9JP89+SUK/c4y7kzW
e4adXqYgpdJagWYVKx3G42VY8+FXWAFwqstAwU5Op8n1CXrjYXIQrW7ovVi0qt5LMgaNHbEln5EO
X5KvZcFMUWgRfZAEePXSr+EtuP4lQeJmkpF02CpxxCp4Iimvo15HczsSvqA5a1NMwfq5h6n0T3qD
lpg4/9pwYOLOp/wYae6n5gPT2FZxHnG7z+hxjSNK2wMX7CJKUnJDNdb/Vzalh0vhpvwttuwEBOyG
TfI4Wf4HcnJgWPToqM9dB46Pv+qz5eWJPKtA4bDz+u66OxfQuMyPr8ie4FbS1YYY+BLj3ctDCUv9
R/E7rknkX3RrfZEpF/lXvcqv/jYSQVTZ/yiN3c3dv2b6f3W7K3n/r7XO2oP973PZ//44BeLOJl4I
5wt+SaIwYh5qs4NbhoAm2xzuMqsbE29f5nXQTCF4acYR44ZD+A0KsaYnosxaNjjXeAryDaUG1Ota
RqE59dG5DfjHcAiMWUQRjNId2KwKNfkcCGYnq8+aj+LyMsh3W/Y8BtYQhCxPYC+aH+rx79r38KH0
DkAXPfhc91m221EwQAZza6jk5JbmeIbK1DLD9EY5/1k+pTk6uMTgjMjs6Uh9pgxdmPsMg8/F37xZ
5abts1MvBpIchMwbwdZqYkpjjhVA1bT6TIS2iywbpwFsSmHym4Zqn5D5D7sYFY051AKZtnKuboSF
hkl9TbOFqlMmG8oueLn0xVe07ObjgkIZ/dhDj/QieXWynzl8mCJjpkSR3QLxlZeWDyzBoNlXqsvq
M/Wk8jsaj/qG/tLmQZ85s78+uurl/fxKB6JNtRk4NGMk+kLM/FAORS5RecCRN4kDdbwFtJ5h0LKP
O0cXBOTA0LNvnOrm9cPdnNRonLQcLXHmzfAZnaJUNqyy1c5sTVKNXHUPzv7/0vi/w1tx/prN/613
Vgr5P1Y6vQf+73Pxf4Q7GJCmipDLAuZzGATfiBBwfqTgx5mOX3vkWeMRK0DhnOSzY4RdLT1j6IcK
lMZdkI3EFhrV/iIcWVaCEtEHFRD+QP28GDMEZLcPQtaV+aSQQwj3PfU0DPmO21vTrGgd92v4U3ZB
FG+V5hJA1gX6CbzgkSK/PE+k4w0/ePCt085SWjnb+jMKGsBIgd4q/g8eCghJfLaytrHqrzrsUztf
bzQ+jUUNqt43+jNVb/cp/M8z6/UH/uCsY6v3PPbOgtQ3+vu9/iyrd9jr5PvrfX26OujZ6h2j5wFP
rtKW9b7Sn2X1rnbXe7n+bgy+XseEncV64yhRQ5b1vtWfZfPbhXkYmPWenX3tna7b6uWbyJzfHf2Z
qvdsFf63btbbO1sfnmG9VO1xxbZRcegfKx0KcHcZ/gQFAz2WQDeCYEingHOuwqNCvCt4WtBzCVeU
RWRSkANsXY4X5qAD+zgAoUYgRgPFUWhjyVk0ECH8GhrWMMAPS0bNU9SdAuXpy9Hz5AqV5cV0/zF1
4/NTr4mfu3GbqnHPxb+nbXmyW7ProlQOsyvUDeuicvaEIbloVTdCG6gvyBP7VjXUaTPxf25nDaHP
5YsuYfB06cV6jboJlHNGA1+XNNDt1mhAhCZVNYB5nOwNPK1ugBJgLNh5eDG77hqz010v6/xGKaXn
LaiTLvevjvpb9pFKTtnXJR5Ox1G/mT2TNJhytHzR7cH/VjFZsUpcXNmOyDCuRo6UGv5H6Y51UUtc
QrmEyPB7D/635rRmN9IzWlnDnwGvw1uH//k1+rliVLGxDv/zeRXrg/XB07XqKiinCp+XtbO1p9WF
zwOPtFRQ2j8d9Gb07tKPMQYHruDOsLu24TQq3EZ5Opm+SjVTUYhyzvRZd2Nmyf1ggD1RCLP2skCS
fwmiLL1LKVOl0G0z/oMdeGEyw3d3HCGRVF+8gj9nfIGIt5g9gC54RHCGaWcH1+PTaJSwt+jV5w+d
KoYOc574b97TycTKXiBIb+AnzZYbwMdXb86aqo0W+m501MVFcUNS9+ZhQBFnW5sduMJQvxWmBZ62
VTG7PMNpxotqVX7LuusdVu1OPIbF9kq+7m3M+pqinkq+XhVtPwjzD/I/yP8JZjS86/ivzurq06fF
+K+nD/L/PcX/O2KhHSBwgYi/CuC2mATDQOUDpAve59YaLpIkHos47fNqZAK0ZudLecPzJwcXZXhm
wtJgkgTVrWVlsszh1ix/PPGxl8/nLdPprPdqZ3/jbcyfv5s4TQMuv1UzQ5xq0cjHY+aIE55i9iTg
6zdLAk73033mAH9rJKmoldQOcR5kUgoNa1++JugH9b5jyXvXyRJrlSV5EEu0YmahkJHPuccq2YKZ
zUF26BLNrzB7O5S9QEHRm49t+e3EGXPVprBJLL0Wm50Jz7tJFjyu6pCdMZOuZ86qWa6nXjGrh0il
bg6oLLdKYdg0OiUrsRqpdArp3HLjX3xpxMYQBTlw7RIwX/CfXJLCbL/VyfBjqbckEY6cHk4dF03A
89nTId3CKt9wOmtlSzLnXLuWPsvEd2vPpiQV5qyiOiv35LzwBGNi3KctVp7lqATVz5ZgRCYTqUfi
K9KDzJEKREv7IedFYwr+xdg8K/j/n4Kz4B7sf73uytMC/u9K7wH/4b74/70R+ylYehEwdKe0+lZV
ZvqI/TQAMjhAQF7MGeI9RqNfDoyUf/cBdhRrBh+G8CWeLg4y5hGoBLn8DND59BxYkACNA+jRA/x6
6mOuOML/RQ8ixAemBBgeqvj8IU9q4SXJB2BsXXYAncGHBCaRCMMBNsIdMvhQ3VtMVI6gE2TB0QQb
HKgl6BynqiTAnnsuFZzGYMwCG5Mrn2iybV5OUh1HM4LSjul4NhKTjKYUjyytnj5tdogwIHtCA1ka
io+jEouGSiXsHk91IbA61TuKx6c4+oZxbdIXuVRueWHLnoib5y6TKrqlpSXYfeT3zcQ89TnMyKoB
MzJ6LOaTT2Ibt0gY8ZLdNayG/1SGZcCk1ADgzfY8OoLzZu/C6zqNEe0I23Fpe2yxf33w5rULt2Li
a/75uABHx5sgNQ0QjpQ10QPN+Izezrijq336qTY+s6hNBGKOkuSa1dOfuxdL969b9/mHNdI9/rU/
Lf7+YgNJ8pOgx0Oi/bU030/F5hHwNhr+q3no8JQaKShzXgmY1p6f2TwKVx4EkNPNIqjs7lVASHfN
QTQMBpiUKCUAKjivHwvWX16GLDvW4FZacEUoMDQLqQxng1EBsSPOP5w3kdAh5Sm0N+1VCYq+VSih
BfTpTRBut7gh4PdH2vyUdle1gRVtzh6Sc4BJqwKdXuL9KIdTp5+1pk7rO06d+j059c5HAd53EZ8/
ICuTScRGqDoKPacye13hByb/NeZWCnyMDPXUnh8H2hJZx1RjCE5psCT3ci2ewk0rhckcdHnvmiBy
TCzryrcoB4xShz3veqoK+BzagCJOiq/VPsIi8o9iMX2VtrINwddZw7XUZ+VVIAaijgH1AcEnXNd1
bI3QpVJswJjPb2fdOWL24FfeYDaJZt7S/rwVHVtm14rmnwPzF6t50yUsnejKqZwxRtk7Z7HBkUrr
wEftsd9M9BEKp5iE4sHxZHMd8wk2fLJ6curFqJvl6IEr+D70U1ij97zAChVo5M4wL90rlO7J6szH
XXqcwz9FlRZndAt3FPFbVp2pUofgH3a1qSoSG7oLWYagd0WJVEedFO/HpHVNDLWsltC3oXG1Urcv
uVugyjxhXpsU+CRSoEc18oSC71Of76X+OEfSamQ1FkVUlivJoq6YWtu30YfCzM6V7tSmpu6V5zm2
ZIst09hmylh+GUoGHbYSPTD2sVnETfhj1Oo4tK8i6TRSqcq1p7IV6txcL2RQfA14kZIdPOeKFuay
01ggGTHX8DkkXJZfyBVqu02LgnRzHo3ofEl+Py0yyDlmcw5dpjmFOZZCcZLm88YsHqdZ2NwFVjS3
t+lCFsyRfBo5rVtay2799eotlDJ4jiOv5DPHvwLxa3gygmmlO0P8PY5if+FjXWM8nyp4xKr80rUo
5wLZnjVV70djirbYI+3PTeJVtAd2ubJKhtYvL6WJyDQ7mkXRmqVeZKc3VzGT4Av56LM89DNoJd76
lyCuFmF45sxNX5NEKGK72ii8K7OmLkCFSm/rdWtxizVfeMtV7XQ0TLwF7qOGKd+wx1vrrGIc5joG
VYzExszShvm7vLhuDS8rU0WULMTJYD9wS2rZ1iX7UVmXTqK6G9WJ4fkC5lrRL42cy8aMS7X8Yq1x
uS5wwS5wyWYXbW7UuASVX83Ju8yuS7I1FdNvcDxMcECvI8RmqbOwN1quOvtWabFzY5Dagxqb3gFx
9L1Tf0evzjfwlbvZqGUDV4tXYwM6B1LgvsV9112IZ85Pne52X3/u7E+rGJq8fRuvkdsh+xU28Ftg
mCyMU8UpJrqu6X5MmS9H5NtGTrdZHHDhETd1SS1Xm1sBUQ2gG8BG0nI4N++h9r2hSAYZpS41vQ3m
ZbWSeek+ncmWl/h4qQBvw8FQWVa9QRpc+i+iwTQppGGxfF73PEXhj3xSjYQaYqJbWfNnUTzwt7M+
NFulIuxeOKlkoCh/jm75vBMuq4JU270My8tLV7LtUXAewmWQ9rNxuvTwR4uXmcEmQIM8+0v24f6s
KbitK7/+dTwYBZMZ5KrG7bS4Y17peVfbkNy8tuxuXpY7TpkKfLYXIgbFzLuur2/5ML376/4P/nXi
RuFb0lLvczdgJQiXEWljPlqb+flBTfzsJneTAVw6hSY1E6DVwlT7+v30N4jndYv+X+Tkn0R3Hf/R
W+us9QrxH6vdB/+v+/H/+ldMYEBsTyZ7QxbF5262FVzaCq7YCpTGxxPATBQRFzDxqtJJzEMrjI/Y
on46ZN5o9Jg4ApJp2ljpkHudTcMsAjxF3BmWTKFm2qLGnly6EMUof3lLpJTn2T6wPoea8mPHZQcE
OcFGj/lbxG0tWPMxYyDICJxE92U/kU0UPnAeVtrc337VYsKzDGM+Y0/g5Wt57Js5GyMiDnky0zLH
w+DwGlBRhq9BEGvYsTRFaKugz8KAggqRtC+LUL02Z17983MsPfJ5emOfz99IDpDqHZ8GcEmfnvow
qaPHak6HWDliaWVLOMsTbvfsDHji2p5wxYcHfoyop4n7Pc1qVfLPA/zzbRSlmied3HlFZzoarsWd
jsO0wcyUoLMpv8aqXDY+ZmT2SyOLht7zQHstgoaUo0azdctRs7nwcAXgobyXcIvzCUFmEWbl3d5z
PIoIQM08tvY1/MDOID9InGUs5bEmbNwUTpjPHIkeK4QvZdYmDfc7qrmYBSNLUXN0nEtcodJceCw6
K6a5sMNbD3jeCk+W7DuWjBEahPzT6vwTU8SsMKDSi7VhGcotAvP0+9/TJ9+w9Y7489FyM4SpB/78
V9orrS+XidGC2taPW0UJRKTkyYHGZ5yHWKKtLI0O/rc0o7hDlI/I1NDRXLheRt7Qzw6Hay7SVdps
tawgX0hlvWa5I410+P3114w2cl6XcGmpATn7wiWs6KkhKynAstGRynlp8IOk+blkrzi9cOla8Q9g
nDCCJu/DET/fx62cR0NVflZBftQm1fKzTtOLV8Ri+k3FaraZT1nZ4cKIg4TCupGSUV54gpm0OMsZ
BW0uX2JIwPBOonDYlMvHJ8ECWmsWqPaKE90tzWkA1agVUKOcDW2fm6cXXjCaxto85duTben7IIdp
WGtkhT5b/OFKPtHI8Gb1iChL52H00oNHF838UMRqjfjbgveQcbM7x7PaouVp+vc3X7vyCmNPWK42
ebRAUAbxXRyt1qY9IAduF0oEzlOEoy6NnKUFOucmMj9x8JepN4y5KVPjq7gP/nSkZSv+0YsDuGr0
EyqsmhpHwNN3Jw2bHVNkbc5NYzFveF7hY+QQv4mJswRegoaoZRwnAlkcE9wMRWtoIVt5iUZj8cTl
hi6oZhJzi6bB+aIzgP9ZvANmJTEX+3PWh/lU6W+AT4FnM75671+fRl48JMWgyI3NvsVCf9DfuGKo
l2iLLbx8DfuqqFA+uMYkuDtopREQXlFMHAHsfBAaBkFCQctaMeB4Mdwgsamn81mc85s0GI8RxNOu
/aqtkZwj1bOxDSlVcV/ldSd6l1xAO8unKmN9IrwmCV7NnYTnTkVdekrobm+jM6uoDI1+2utUq99N
n/ZyDdCr6SgNuAhTMuu1J1XOTuUSncLlONvqgqVgQtxO6dtX3lWfrdsVwqd0uoGYwU5f6rjdtTp2
EWsAc3FajRzUjbvRrV5p8IjrnbYZBf0VRqOvtqo99LoWr5HaPnry+MJVmmJe7pd4ofsiO/cfU5cu
eL/pBOnJ3qHTajPnhx/643FdTzB1n1doylc7NivldyM4ZLN06AoW8Pa8+hadliH8sCF7BT+3OTkb
s6bAAqy2sVZmMrQ+NuTlPncVjtihd8pjEFF74sV+mX9OxVSqHVo+CLi/973hsMxrd4YDWP5HsE5y
XvmIqp0JFCs1y9Z5Ex5p9veopSHYrZnfivsDTaok4voqDpAsqMDdrvRmVnJh99OuNKR+PbOo2JE0
DuL3lAhC8imwIPJB5kNkwwXstWY2VcPspTMS2WzV+qQ2jEc5Aam/GRYiC2sLO3YUKagGdlj182lm
iTq+HQvblG/JR6PU0TW3V7f4Nt6ssrhv1piT6hKf5vapKaPg+ejlAqtdjO/IH5JfbCA0ObKz0it3
bZREZa3ccm/iQyeDKEm8MscJOkvoIAoTD2LdIf46AlINa3XFO+vyCipm8QAILd4B3kgDV2rMohbJ
YBrNuDeKiE1SsYYd21QD7VMgFXTS2WSoql7qrm5q4E5rnRkbZNF2uj29mad31czSxr0009FbWe/M
fWzK1aHWTSf6JG0tlYQ702gdZHo2GBjfQy6laokxc/ycPgHV/oizXHpqu/XkvXXs8WwznXZKYtzu
1htlIScebk3ghXZAmPcG1Lrzz//tv5vD8bIW5y6eYXo9Pz7IXPxv7VY+4/qdGmKqmjIpjD8qKFor
v1N6RhfuTPgdxiRd08zWW6ymY1p2ByNE0iTV7TfcLmNmUbR/iwtvOMppsFMtixK4ej6FHw5IPsoJ
p8AVNHNPnrBui/0uE+G77Zz4IQxE1SOpyc7e3tm5mTdXxuYW9fUUWib+wGjumuH4/WxmxXKpWLfc
874VgcDwWXBmCxDzaynsx7lTVyoqGx0e9Q1vg5DHLcLQ2lrrVjnIOm69n/dikHp88SH/s1FHmq2W
e5Ug27jhahEGum21SnyDUSGD7sHuauvW2H1KIodOM3FAhrebaGcqPG119cz6LWlnjo6cf/53/xNC
DEyiD36MMdPHbQYP/y09jP3TKEqd4+PfoN5GCEGr9RUsNYrKfdnr1iYlID0dFuLrLMSj1ytLvXCr
GpbbVJfYDIKl9Fujz73OX4vWQ0a3HN6tjmSOkJe7Va1oRl//yh8891MPoeeaR05CVsJBOnLa2gbo
Hh+37l2t8uAr/fAzw/+bb+G7z/+83ltbLeR/Xll58P/+zfh/N7RSGBd7eOGPfSYcV18CXzK4Ri/k
5/UTA/bRbWgyRZPIMOBe1OEv5E+uUU+s8w1yfRP/l18ov28Qoo84+icw4XvdRndp5F49RB1GuZ2y
F0CTcDOPA4wX72M9jP0lYUsTVrrdWTAZYB7oUZb4GqGDVH7aX1UC118pi+yvemrVOVsQ6ZVFIuT5
vhV+WOR8F4fe7HSJNf20pZO43Q0bebaBrxzCkqnhBNYXvWpTomVPpnJusyG6zcBfp57UK96e/xc7
4DPx8ZMBHXeLDXxHg6ldv8yoQ4P+1tKcCdBhb/M5ORp9Ml3w9mWO5I/8cZZnWDzYprzG4o/XURqc
BRgrIB68SYby1+/4zvsoKn7p/XJNzsS6KMOFOQnQGeRTjXOPZa4DM5J4fvxkgdQMWOolmDgezhMe
TU9FePQRpzdgzvkoOvVGDm4TM6qDlSFrfk9fHACbmA5QK8zQ3awvszxvYizGIA4mXHvu7Gg51+Fl
lMW48QHKnNwqSfSnykZU6upiOwXk5MrmtBzY1S1mWa8LTWpvyhvSs2ZXtxTKnVNo6bX25haGpG+q
Qlt75stic/kc2c7M9jilLbREp8HTUtbbmlOZsaubiIPhdFAczFt6jJo7qTc22xAnyXf599sEvT+z
sfE0CQbe0mTkXRda3IeHyxNvmuRaekXfqMWq2YR3CcSuOKzvYi+EvR5NInsj9FXdNoKQJ/YsaQX1
7PaxyA+pIRPIV7EBZ1MMtmryVVwS69wWF5Z0324jOzL2w6nM8TaZ6ORHVk0O/uHQZ0703lEI4xip
FrAg4xsSEdA1gKti4BHxixisB+Mu47IcF/r2JgMUNUcGCZYWOe486xT9ySfolgVclIgn+ihBJrFj
m8Z9VV0/50QsDchdj8gOwRBvW+MwzNMGn2pLG5KH0VuhHLFu9maehuTE2pqCTdTkiCt8ylSThSiO
LJWlQaVaFdTH9K5XIRla6miNBGfVKPLd7NiqMIkrJd6tjDEYXATTYVBYMv74EMMp9emUexr2Kkbo
/cK5cIpDnJ4GwFo01W3QlrQLta9DdPxtw2FJ/ajVqLCVZTOL3EkSgFQBREGLRFCkL/TQ+K2/eoW1
I4wOMPWbDxqIO5X/0cv7bttAof7p2lqZ/G/5fX19DeT/tQf5/57Wn0c1/XbW/+nT1bWH9b/v9ceo
tt/E+nc7a92H9f8s629ENd7P+q+sdPL5X1d6vQf97738fPGIlv3USy4aXxCn5ulwFqTJLcf26Gd4
HZhcR5OBdDXuF+xlBBJwOAgo6ZAdPoSDbrRIpjQcXc4DXCKsZW8EYs55kAg1i2qaK4b/cdkdoKFt
WWmRRtE5a/5lSpozHpl6GY2gWRIo4ROosvDREr3ET1tuw78iLen+9uEPW7nw3/6X+NSBKhTwhoRQ
6IsGoL1xNPRGQeo9Vi9ZkwObwFQeRjHw45R/KESZkWIEhogmArXKBcB3HGSkicEpIPZOY/+XXzwC
IglYilISgpHYp7UBYsgRc75sgjywNA1bDkUXi54cb7L0wg8bPCaURnr491vvDnfYD3sHhy/2Xu5u
LQ/9y2UFxw6VPQLpYBixpVBP8JXgDpLVLnnBFDG2aTCB1oT0YDTzjwzlsGPfPmF9Zoxb35xqblyH
Pft95njgXwWp8Ho5CxrwfztvXr/Ycr78+HfPvz/B3/e+P/nhzavd/tKX+M8yqRuD809OY/x+GMSo
iHe+xHK0Kxz5B5fF4S/xEe4bp3HEls704svQXZD+vREBAp857JjgFEDmTM/Y4y8wY1o69XGgQkmb
aURZc8TxXXgyNIxdBJnv5/Axe1bVQrEL/JDq4qvel4FmZ6gqXqtK2KpxkESjKT7zdWNOH/PJwYDG
sMAXmBzuMojTKawu637d61x1Oxsd1jSxgNgfd1+9gxrRWwX/TCZEGzY6nav1TqflAlXx+Vb38RzD
oTcU0EvP2AHX77BLzDOcTEk340ONTcwaR/g6HlGYNn5cMqYWnhpuqh/CTZj6g3QJ+86W/sJ6z9SR
0E8PbesxVIAZvLZYOxtim3lTtIR0ndwi8saFPkrMpS+jWnmFX/D8eGx/B+FaRJ4LbbLHwfkoQG+t
IZE4URdrcswmGkqdVuGAEJmgTaTtbYOQOpJcsPHlrJL2dxlldTbxXKJvRLb1lwa2Tcn34bPK1nrP
ft99UA3cLv8nr/H74f+eFvDfVlbWOw/83/3zfy89dh57cC95SFPqc4EZt5fjA6FOILSlZm2XHRAb
QzpKceuFEikoDugqIRZJwDwBqwM1ynsfkVBwvyYe+YXCrXHpcbv0SkcmfRR84zhKg8sozylm3Vni
3QGCUofpE0X+eHjy0/afXm6/fn7yfO9g+7uXuyc/7b1+/uan57s7b95uH+69eb3V1Qr/cX/7ZP/l
9uGLN29fbX0QqGf7269f7758ubdVOkkNyfRumWTQ1nuDhTH4FFwJzUSh2ye+FdBF4ZDUvzmzBnlb
FEwap37otxrSIKKwc4jZ5L4MzpdyaE7mvcCdGdB6oV+lxJdG79lx41OjQasfnMTeJBgGW53Ghwvs
QH+TiayJQRjA9bf15QFM8uvnB9p9iZafL5sYwM4eP/ndC/a7w8ctxq267BleInIiuYEgm798d83C
dMOw33MguGC49eUj+lVOxRZ3xETUsxPcXV82E/8vrMt6nZbqM7kfj3x/ojljvw+w4Q60BJU6+nQg
k3YKZ+29Ds8lp1rcwqr17iYvS3cq+RVEApxC8P6yJM5x12D6ycPXA16ZdyHjnxPgY7a+/LYhTRE5
/t06z9rmCom/lxvKOvdqAoqjt3XN+p53U/H5+M8XREkSAm5kzm4ygFEbLgeK38A+UmrgSTB93Mb9
DfKIT96nPu4MvtoglE7Y0lX2mblIJGh0yia7U5hsc2t/2WyaTzCjLWu1GB+JkAp5jSH62ASKyCGO
H5dl4bR6Yp2oC1ipOBlsSZwVrHNplGJ+2/l71GUCTM7cCLlDqq1BxR4RiyOzin5JK9iybhAxn0Y7
DlsC0WilOIjyFuVVEeEE8tmLMMhWuyFK9yfZv66XEh/Z0ylD6QGDjZjzXL8Wgd3dM7e+tb1JNIDb
bq6byL7rORlZ6dRZCklyiCTU5/8i3of70v9219a6Of6v97S3/sD/3T//tx9HwP+NxwFBzUqDcADS
OTp8ehUcYd7B09T6ZRoOlPqWohBOv84X5iS+eqq3I6TMVvHFmw6B6h0jgmfFe42WixveVuP51IuH
ARDgJWI1A2u1hUL16gYm6tIPUV1mqzR7W6ztCwFVM0EeOECFyenIHyOYTZQgew7MtJpzJD1CrfqY
jjdrjimExue+eX7st7FCQcMya3+bTUbT8yBECOeIxd5gEJ2PAp85pAN0l/maS50sXbUcT3Z/x200
BfXpIT7VR0Gjt7YKJNpR3NOA62RiVAUxoUxJYMcRfDAjZLgEwXp89L7E3KaEMJeICI5JlDCH95eN
oD+Oxnxh45tZF3C3DdIR+3IAhbI/dO7pU0HpwEUeWOTzMEoCN71KBWPYguUgXUalJN34K5H/1aa7
P/vfyvpqXv7vrULxB/p/7/T/O0VyCqQdpHxPoFwqo43U04489uP+ayJJ5Msj1PmP0T8vDtB3f28f
LwTGfvACdh54j4mDhW++RfDsx6i5TThOezDiAqevWUToS8sPXE34ZUoetwkqQz3o3Csgk5ceXDXR
ZDKNleoA/ZwwxAAabTUOdr9//SYTp0n9n239pTMPXbWQZAOx+5IKO5xEC46/KGRTFU6D07zVGgFj
X+iWDKC4AYofQn0ORL3xGuoFhpy5/JaMkqXYH/l4uxo6aE7Uvvz4ehvtGbAQ6RQNQMjJfnJYqyG9
Tgmj4xqmZWkpDVKYYEetNbDVSx8IOnUJs+8hXzwFXvd66SI4v4B3PMoRfjkLrvwhFUbcrbVVlF3/
FbkbqmbgbUAYl/lKTtHqFaLtp991tL8PApC+BrhZLqJ+B99QTL7zzWlw/uyb02fZjkTRGifl0TfL
p8/g/+F9o7FvbjmBZw7f6VsPP4ANHUTAdA9R/3/p802DuU0ughabTKMAHTRjjpAOn8Muwa9c0cBl
cI4v+Q46wxUC5h4ajWDRcIuhIEnbGj49hKvsuzj6kPgxVkGupaf8bwzZH/q42GnkNhraYWDe6WmE
XrEh5acVp4O4MJSYoNqfYFN8j2wGVvqt05Bg0yinp9F0cKF2amOAu+RLWQANnYx1uBCXz4A+wWS3
uHWnsHab6GonImULCyryiS/hJ/pytjPdnDpg5hJvYxgNTAIKe7jDxQE1V/vZof0Ui4VAd8UlNgjQ
lX+N+dMYMzAgjjUmdKBmyekezy2VDLk/JPJB/tgLRm1CRGMRC6djn5uPUzhOZ7CEqjxwQqGvuBnu
yJ/gcgdohwnwEMAkUPGzaYgmGK5nUCvT5qvJ3RZxv1KyhQgGjrYkr9H4EfeZSEhenJBvNcn3y2+B
9vyloEIAXnkpmvgwqRdpOkn6y8tj/q0LPVsOUsyPEU3DdJmjpjsWzlFCxOaWFxgbEDmXghDBpzhY
kVrBN3/od/Sl2sGphFPg85XpuuxgKkaD7TIy6WE3WDNFH2za4Hzi+7iVcZ39+BIaxArQkj3xzj23
0XPZa5+fYFkBhWB9E2S7P9uu2MdvlgM4YBwIA0p9DwsYI3f53r+mVw1CV5YXy77nE9ebcJ2Kumug
S0TA+YlfcZncseQRvj1BtMHMxJhRB6qKKkcnA6oLTvU+LjLMDiYJIW0SapjQSXkYIFRgioFqlktJ
AIecBXgM/cQbNMRdc8/8n+Enfy/8X2+9s1Kw//Qe+L/Pwf/lA2KsfCA5ZPCNgpeiwqZB1sOOT4PM
3+uCQQlvtkBFQw59TYXclHi0aI+Cuz1zlJF6cBRZI3QxUJUORtA23MptqjhBAwsG0yGJxgGlxLKK
8EnNusUZU3PfA7VDXBwMIWHCICKqa8PAvGSC2V2RiELxx1xTSxVcBA2qf2vpTLrefOz2lz6hOjir
MqPpvLCjLP/wjdA5T5XXTssp00ATRf+ZU3TgTRcLP81XaDgFCfU2qRNLOqbmWasnY5TRt2B8Dnxs
jsyY4TcwN7CnBiDuR4ZZCDlwuOu+hCoE/y28FMSDX39lWHsJULnZBmKVczld9fhLvheWAlnjUkLY
6XJOgeMFMp3L0IM3JiziAA5FvMShTNhGx3iaXsDMI0A3W8+qQiXa0F/imXw4GMfKivYcePu49O2l
L991vI3Vs7O1tULFH4DrOFcVIGQPFFpawlgXo9rBQD3Vm/RPBz3/7Cyrlork24UC4k2xOXoHF+/S
xSj/jar0NMneal+NgBuR34gf9VTrpHqn6qMiWidzH+ud1N4l/gRxr6LyepHVMWaNusmfFhYqe5f1
RL0xqzRnjf98Xs1Q4f7nksqSJqncuf/3ynoB/2F15enD/X+P9z/3/p1wuURKqxUOH5qQ20YP2DDA
C4U/EN5kBW03HjhZtXQmsylO9XJcwQC3SKkxTvTCYY7WJ2XeNW1owjH0weur/PwPgIfyzjA39H3p
f3vrK0/z8R8gEjzw//d1/nED4NJPrtOLKASuYw9owY7aB4IMeDYygHoqzCZOXrmD4CzGcijzJgFP
+YnMNxZSSIFQ9buEfON5cdQ7DYXwLJxugSikq6x5BoLF9SRt01nHJJnCNOSzXptt7x4s9dbWW32o
D+NKh2RR5/4Fbem0hJYxuGkj1P0ElIdqGKDTOXkyBSPKmncajAIuAWQ734Ajw1FE0kGtScKEryxk
rfyXOFW/otLiVx52+2uCMbhoWcUc9CgTofJR6BFFJX22s31wsP3izdvD3ZN9+PWnN2+fb7muCwPQ
3uxsw39fvtzGNxK/BQFKrtvsbBCmoza7ACFuFJy22Z9hhG0WJW2GRjxoYzqAeUymp9A8au7bONMg
JsUgap26wAyB8NGAprbRDStxMfmg61+BMDacAjFtOv/otBqyeV7EB6kOeBn33E+bjqWTTltV9Oco
CJtYeZs52a5yWq0Gd8XX2tSLSpU6/JrNr4sjg84c7h2+efkGAW61GtHFDZ1AgPWbXi2L7eOi8nmp
8eLgZO/NzsnB7uHJ7uudt3/aR+e8k/03L/d2/oSuOlcbnc7O+np3RZb83lbyZPfvqPBOp/M1FF6X
hbefP9cL/2H3T6LYWgeKPZXF3u6+evPjrr3kKpbcKGkdip0cHG4fvjsQpTew9HbjYH9352Tv+e7r
w70Xezvbh2/e7kKBXgPLvjmBVYE3u23G/9x/u2v8/Xbv1RtYt5M9GB2uGrqHtfFswRzsvdzF5+8O
3lCD3UYDmEF0xx9g0IIH8p8fpnD4OMYkIQ/wXQbrOHjfdLb29lZ6CaydpYdt1oETShXwauGkeJf+
ydA7kVRCpaiEjeqNfLMhsctdvr6qKGzJQYSeiPRNuoUftlm41WNffcW6T+EobG202WSr265A0ht7
V2N/vAWUhcFHnd6q+KfNhu9Hfri1vtrCXfbS550mqAfEKpiGlJNXhOSM6A+Q9mMPaRaFM2VUEqgj
bPzDvd3Xu/yF3MBIy1LUYCL+hB+nnvmaazDoIepeT0+RjoxPY9TBOAiMlUQOU8FEnGBRMZdmmXAw
mrIb5pTK8zcMYrRBNOXf3mmC/2ZfiRUTQw5O+NKp922xlqL20+kZbJ/T69QnOtXM9s8pQrY8seyZ
K9gzMNFNUU8bU4w+kbVyBemQEwxUgzdzgyKiAzv7+ZvXL//EfuV/Pd97u7sDG+9P/Ps0vu5n2AlI
ON0gGqSj5hnsttLz3MbBtNlhPPWVfcQbjbSqoK3BKEp8qKelzy0OP2nC10cb/d7qsZjBFD0pitOn
n6vy2eOlYF543b3V1v1NjZWGLT47YgdMQ9wDJ2dxNMaN4IgKVzsthEflxAcv0luasY2Ne5yxUlp+
V7MGRErNmghuOlHMVsnUfWFwV2idQKNrIPmspb87PGhzNko+2cEnceCPJwG3WqL+lkp4bKVHE83d
pDn3FpkrYxz87/Bn5aq7jjdGjxB7geJ2rjor2l1hWbBsKLezUlbuQPGfUf2l4tcaZ4dPYDLzZNdx
nKVnfFy0P1MZxOUJUif/yAbIfRleU1QcJ/LI7/ImHIFeX9j/xiz/ESd3dRbZuO05LeOjCpvfv8Ks
COzNAeWtzeoVW/619GpfgPB21/srveMWateJDh+zLeCSOMgOz/rJGUeFctO89oYtOecKR5IYye/f
biMjg/McRaNmnhXW4kH2X27/CW65KC7wy+plS6gHuUN6WsVYS7nAkVcw+hlGPCU7HBHYZN6WUzTi
OmLHwdBFz7OJy+QBN56GzSMHRo3stvAQgV85m02PNAcRYskpB0WCasJL2MX8M7IkO6I35WyWw5Wh
UFD03pGWZqwGjc28Ou53wn8n1xNH9GSYXuCvq72Oc5z5pmcDo2DbZuy7MMJm7Hxz9A/Pjp88w09k
m5KR4ZFGIrE9r8CcWDmlVFBkWQDZyUVNUrMrahkS2pgnv0kCJJXZxOPKFiZfbNJDCVONYaN3tiBy
FOSPgLtiwcU5cz6G0ad+1yk8ToJPuGxV1c6xnGJyYpf/gnw9HtmOkhf8YZAJC/rqlU33pFps1U6X
FnIzYUFCBKJvgoRx2RvqwC4Yr7AZ8dwV/1bvQ6DGDtNaFSOf3N+ekNM4555AsMtrXuMFmp9EAeMo
b4eodfUK+0Wc8RtvFlRtDKMpyHrZJO3v7e+2CWN/K7tbMHxK30uPYC9pdFCe505u9/Ha3RjdgSZN
5+dQEV+gMCdBeJJeTEMvbtajsft0vx45/CMYhNSVWMfxfPfH1+9evqRXQHwsr1ry2tID2FH2vUQP
mCbKv6gBM5iMPhcPKczPP4eBBgRzSIMiddgJ17rIIRk3/AC2I+pf3FHkDZs0Gq7BaRX270dH8hFO
nw2Osr9grA72DB7T/ewi83rhXzWhED0/bhX3hWMOwvZtrsRx65POVDQFV9FmP3qjqS9+/4N/Tb+1
7MwGlzpwOuWkcJWCzjYDSRl774EaxUkzL0SLuWmjKTxJT6L32oZMx0gphP4LSIAbTqNLEXr0IUgv
GM0ulILp+oCJnRJ2lvWSFmE4HU+axjzL/ZRNMf7j4gxhvt7CJNID/voTEPGWHNHgYhwNeeOdCHEX
5IvYn4y8gc9fieFpwpncNLhPzM0kj8dAElTkigTDQ3MWJDBrTWOjFFfFIaMO6aLh9AyKGzRBemmI
iebOs+2TOrynw/XKqlG5yU29GgIQk9rGKdOwidTqXLsTOJ/oGkraqv4WNiAOtUQwlacTx60RGnN+
cVpxOs27SjA3zktDi+STNyJ5KrqOWplM6wtvk6bcSi1iTeElRlTgEqkXhWbOeDtCy/VRFvykN8iU
5HI5jVIPNihRLigfgSiJwiPw2SB6TCIV6qj1EUcoWS1yQyRfQ31w6JT3c/hzeODF0JiudcPiRjEC
J+EuS6rQRTT2XWZNkeL8sWBkQAePKcLTTqPHHLWFQnFohVHJNwgQJDNFZtDnjoD2mkkV5GPlgTRQ
YBwNbIDJFO5AFwdk/xIGtY0uRYQG0qdRJejJifJ4AN3UYZSUUeT1m9eoH4SJp2sg9gdT2I4ecCn2
G9nBadZuc6dwMDnVoihtpHAa09WFA5nn1pwD7jKpQzxJaTczOXkjGETENpjMUBa0+iZzhlrCSbfF
vmEbJnsmGHjcjpkz2mOgFCDPoeNljBuP0HgLbbgaX/TBi8MgPM9lVivjLwu8RC7hkPD3zAJoJz3b
3LwNkkKmt9y4cVK34HOzbTNcXE0B7Iapn00DrfgwQFWP385OWNWgqwacH6x+G2aXEaLjb3Wip52O
9SpUF072BRUWshZyMcS6T9EPMBo3u+sW5QORdSiXV0xnddqMDF1hXtBGW1CXZTUIk0XxvsDbWdv1
MGM+plGjwEnW/HqtzXprrb4e+bH7Zv/1m8ODd/v7bJntwq+Hf+pL2yR3Zpftm6jAgqDvSTpB0cZ+
jGTGN02qTSCT6Mj5OJpwrKDHfkj2ksfocI4G1parrbKi4a8lexgDkRsEFIyAVw9H59JsFewjiDVp
TB9+ctRi2ZklXbB2DFIs7nMmTR6uJOGvfA19IjS0YUViniPaklhfeAHjLkwCG3nkEWklt+7mN8Gz
HXqav0OCZ7BaZoUZRAmn5JSNTtJsRanFNOSlg0xmkBc43PkDyatk3FGCB1tncgqMCGcCzPKC58jK
5pvf1Mk0xlkiWp1HQeiwP2MUEZsrLVNULhAmvGrQKd5+3VbSLKHR3LIeQWLKBOM/8zTn2TnNKiSm
RHy5ZWP1+nMRcq5D0szLcoPmLoTK2S7QKZ5iUDf9mEMSdgqJZIHzlsgsy31uXKQIXA7RrQHe2flX
mfu3FjWX1GVf3RayZX3M8hQXS9W4UKqboGMymQKrOQhOUgw39i2K80M+A8hGh6mP8Yi+AO0PxmPv
PKAkkQF7TIQDuBvcBI9lOPuIshbkuA1X6s+T6TjAYwlceUudFp75pi2pD4Ghjyh6HS6lD97ofb6P
8kMKOApEtqIn6ntz0qcxtkhiQX952YFyulOG+xdgkzNzLLlHyP4QHjxeYGf+lrP86MvfP262vnrS
3tzq/6sl9+Qfc9sUh+Z6w2FTWs/Hw7UmNK6s5i0UBIfBuZ/A4Pm3pxhGVuacQaBC8Bvs+/Fp6AWj
xCnO2UlxsrDS3ESdyVkqnNCzo/7S6jG+xv4XD2nhbGk2gWk4CsL39rk7axUT7lWdocJZEvuqbHbI
nQ5nh5zSeZJP/GB0vTRN/KF7deqPHAsbQ+o1rBSlf9FGC8Rub6gllZ7E/lmAoQxb0A3XTwZAmJoz
dlBm1SnfL6iHWNa2DakkeCOkv3z8c/LVN6dR9H7sxe/ZBfRiy3kMH6n+PGHxY/erb+FWEIWePdZU
nTDrI+882YLqDkz2ktp5tMWLmROvTwRXhbgf0BrXpI+qhXdaLKkw5okRFrt87XK0AhACjiCKgTrj
TaAzGATQgKzTSBdieTtC4O83LEKLLquLqFJeHGoxbpc8qTS0J5K3Tq7DgaRmMP8w8Kr7p1RDgocR
P/89032D4PDOq2/B4ZdoRwoTvj0aTEPBAhZEROJS+dwLhYrIDjcRGCawJHzhMTovUI+Dohju+KRx
EKXh//iWzF0SlVwsXyDJEO0Jd0ZCTCOePOBRU8An+UM/RpANr8BOqa2TXYbAhAyCCbBHSrdG+g88
lih8efH55VH3WIrD8lGLPWNdbt50VEyp+hK2Hy2akzeYiRNx1Dk291nuY9zTs1hTvTwOtFies8PW
+mkZLC2IUywP8YntEKPElanhDHUb12UVDXF3amQ5i0aw3hSz67QrU7hmRhbcWwU6oIlHeWvKjpBt
+r3ZTWRfvYoo/pcfr7om15WNjsGonxVsdDm9hG3tSr7s9CsZa5vSydxLGHdwcoK695MT2kknJ2MP
ajgRe0k/TQ8xACX+/xJ2+zbbqPb/73bW1tfz/v+91Qf//88Q//vKgldfHgSkJbWj200iuY9Qn8NV
JMj8YGQRAsbAhcyx7wUkP8pkCK4QIafOtZSewMVvSyQPHcZDurbiFYrRvwLzfkiA90AKyNw54nIX
hhRIvYxELh1Pz8485CM/+KfwF0MA7UEcnZE1dIJ8itvY3nt3+GarGtu+AlNFzN8//Uc1f3lwFTWv
tXBVCPY+onZAbmCPk+XfL//8e2882Vw+32TJ8jfw1yiFPx4TCguPeBXF0yQYsuqw23ws8TdMi+HF
CkXE8gkwbwLiVcL/O1/SVDlMBjVzT6ZfdWQJYrkwDFaCTGiDR1T0JfLb0tFEOJJLgNAgP+evMg2A
4pUEb4l46gNafNg2rksXZOM5otWOSO8XoKkJUeh9Un0jgzgOEE/GZXsCi0Eie7B/+h9ETDSKIdy8
A/sRShA0KNfM0i5Fbz3ap66DiLUi14GYIZptNk7OGyJjAvy69WWzOHH8K5r5lhZ1XQbNQVxxDpQj
N0naFM3OsaBtUj5rjW/g19Ho2ZdNma3gd8lj6C/034GFTUHIxwGswO98X7a+WeZfOPpt3JUB43yz
wS/aLuJzUpgLkektmwQj3M8rOVhBtqEsBThKlYeBgUR1dPpShNYszLq2V0tgUEqbdDPEmroEr495
+IKUA4gCgeMRSgUSSHUWiF6R4iliRx+U0rs2CwNKXaJAb1SQFOyGU6kfR3BtEld0Keo8gIFz1prj
KyXRBM1oNOBAxoK2BIISUb48bJJANsoBJkkjMcL5xKj7D3AaAgkJ4zbe+ohqxKda6OMJ3XCKO54A
DtscmuGf/i9UE94TeBkFBLGiYGzLzplQWZav+2EUy6sIKIYQQTk9wnyLfPFfiA5ohUWRjN7ENBBJ
clhTLIZGbTBFDFxKAm8ChdvocbYc5M6X3cHKS5iPtuSoO/x4fkJHA1HwiKuTjzFXJ/3myJi6C4lQ
hVgeCMJ1wL+QXeUQup40y7cavEZBCU0EjEdbMrPkcQ1qV1gFzZtMhw+j9iz3hbZeB5wTKaF93/L1
2uPHD/Pp+LEXom6BGI0MVMwAs3MQe0IQPIWQUZfyi2m/e8IvmbDPQ/bnx5gyRlVNaYmA8REwVpNO
8du6XkqkBe6DAwyAAEKfzwclpvmP05IjiVQk8ccYaCqImp+/MRKO9E0Wu7E/jmCc/YZHSV9oL/EI
jGTixQQjSETYpZhTEVA25Rr2NrfR4ndTHrxLirs05XQhA23hGHKObfOiyiUH3k8Ic9R3oZP9Qh51
2DuT6ShBUw2HDZJSQVtaUn2dRCp1akZPWZPyxshqA4m+c0nUEdcJN/oK5+pwD/CguEseaSfqnUQY
O6eEkswtdDYnIrTyW0IrY18+7d5nrMhuCGwvDUG9dp0cQnDssepbp98ou1X0mzC7hBTaWF3mR1La
nk59+bnTgfy+pIHNSU1xE5iXNMsg8Hoc+EfQTLGtCKmQSEDUqj0C6wWyzbnwHBhhkeDwM8xLo+Ef
6iHeCgrTaaOln83nYVblUBxlBbQhdLtC4kAcPWDMYMnEVAG1JCxkggeVy9zmIM8KodCXyJbUK2wJ
dolIrBz1CerOVo3kN5HPGpOMhJ2ndOXB3MymYif39i/Xb8B57snOgaQFSzAJ/uk/oX4bBTGQ9wbT
kMbND7dAYuS7rNE8mJDggF5HoxSJf4R+cHwh2vLjUyI9LbjEYWNJMYy21FetuW9iuWvs51hHLIP2
JLTfb1f/l0cyvwf9X3dlvZD/8+lD/s/Pi//xvdwHwvJGp38J3S44r+/zAysUSaVKQlT+7XvcuMXJ
nsz4lyQR5vMjMUO32gl9jbinYrzwM2oFLARX/PEMm5QCBc86HVZNHdmXSIbLyASRGy6lmtKOY0AS
JrYNNXKVUJt7c1HDnKPKS2h0TwlhR+TexJa7HcF+tBQyxyC9nviJgubIEDmSaPDet6FxpBdo6AeZ
B34Fhq7RQMdyG9zG9++23z7f237NXc8RasNZjqf60cXFcrEhp9XYPjzk1ax3GjtvXm2/fv7m5MXe
692Dw7fVlctCWD/aw4Rb0kQDMmk0Dnbf/rj393tQ0ceNDsiPE/TA8ZHuw2erqyvGI5HFE96s4QsK
FsaoYeIVms9fH7RMA9ZGSTFhU42gOPv6a2pDAB0jIEpwGdHzNdtzvfruqv3Tbrdjfb66jlUGiGfJ
6C0OZONp/pneRK/4Ra8Hjw4OfsCGetgBhXTZfH24T0MCmthHlxGu1MRWuhs97NOP+6+dT9w0DDv5
BDayTzDEp0FmIXYc5/sRHJoRXqqZGDTUBBNyGxX+39JxnRTkpwFqXIRaQcgZyjvKjAWi7e3uPH/5
solRB4i56Z+Q1yv37XUpq0JzlSK4xf+1pP/r/luKtX7+7tU+Zk1DjBF7uM52CqOA29bPB+pkzh3T
8ATpygkpfpSZXLqKFjc45oB9++714d6rXYxn5hG6Z85yOp5oJ+hjRAF802DYbH1yCt7NmT/NDO/m
M+nNY/gJZZ87+fsWfYfeYyQIOruURVmfYaHmmaAu7ss3O39AaJpf9b9ff1ftHqNFvZXg00vvEy9F
Z1Fd1j8TUT/cOlEEgoFHKljI+T0SELJZONrTb+jpKDUekmn79+f4UO7ysX8CW/cEmeKmkhnaHM3E
FqRGL1xvAnM+bHJaiwt5AafvFKjYMM5qIU8H+757h3h2w4pdR/ppRJbQg0/NYKRi5J+m1Ca7Orko
2C5aehuQA5mE0R9FHyqt+2X1UP8WjjCs7V8Fx6I5JOAIuOY4vqx0twrIpe3omE8ROiDJi849pN+a
wIDBEm0Ziw3MenyebDWH/NSqRaPoWfR7xMxhbeAqgEqFemSdi/xcio64KT9sXXeNv8J7GSmCqJL+
dNoSGR8RySlZ2hYTlxoVo1K8xBCDp0OP+9Nvyd1v6+C3GNr/hDXPHMaaH0VB7DHuuE+oMDnj8yJ8
dETXhfcffAZSJSVA+Gg08hhn6HGbPf72cav1iadAILmzgmWyhQ+dOfuZjxTLtaEYMdWQ5fsfEdYI
v9XnxFZwn4fbsI80j58sjaUR9jvC1qAxdwonN1Y0V/3wyYS5FKskJ1EumpxI9sT8zsHhUx6qZKCU
H7H/rZjyzJ3qKM8bGe4/5ac07w5k5L0onljdN0gVHcPpmY6Fw5EeaN2ocuARHC7XHPZX8l5B/DXG
XlfWItljoUgbSRMKOhOVlBQtdqw1I+sKhMYh2LkmZz5bbe1NhpOMlZ5GUP3YWpPuixSFSyBmlPsl
ra13nOMiDbb4dokVX5Agai5L1YGjCKbGyQpPVQ78MTGVYg5P+BwiO6g/jWIkSMgUcpFDFuORonFb
PceCFu6AQoc59e3nw89CF+8dkL6aTRU/nDQ/OjJNiNNnwyNHyDY8Tpu6jmHE9Msn8hDGIPjMadx+
e1oCq7PLoujTaGFluf85DYQzdjCBOUYv88b0iGq+8KR2FTeaS4l4mr1WafYdDCvil3hlprvS4EYK
Nub8Bf9HchvbL07evd77OynpuQfIjQFF2d1+1SqPCkkQ7zD0B2mThLqc975au9PHH51B4EUORhsT
w+gA2X3cqhUKIoFyrCGNciqLnu+K18HAM8Wvykhezh2KpAAk3/3yi2dYYHRxwylnYRz7/cXeEkHy
bJFWhbBPvhUUqIqa7WxHrM2Iy7TuqGw3GuzLS+TCK9aUQiECsvgyLjygDabpxKd6EO3MYIahjruQ
NLHG0vCFDN/AXldhvNouUIcf+zu0f1/Gu3EWUDFtbXTQFWygyaRJ9mz+2KXi7tWWtfvg/nnb+t/Y
Pweu8h7yv6z1Onn/z5X1p70H/e/n1P++pdXXlb8VjqA6tcfrFN1GiKnBsKBI6U+hWoeuCc7VuGx3
FCDkA1cBYzPQptfm+l24MJSKF2l/dvGIvF4yTkOpXGfqWG9LpZqhDxdmyWkc7O7jm5+vuohITBwP
hgA1cTIwoFXJxQvzD1ZWIbGyd1mjJbybShK3VbihKO4M7WZN1axGf4Wyx7iXeFVCdaOcZL+COyEi
SIqcnugGQRc5KUsTF45hoAhW0sxarVKb1ACQyhRREjDcbxowt4GEMOZ3W4JceNOBHvv9IliGKHq0
1j8m7C/W/ImGlrScisoS7jSH3se2Op3MeqKVNNxzeKVlLLiNwS3wI/xCgJ3CNzQwolyWckhZje+c
T60j+etx/oavDcKkW2CbFsQyjsWnS8smY6rRLNP8WrIRSuAHy+JfWo1ZgB+Co+YTUWNclt1chnk2
B5CaGVD0mpwLJI0VMGFZxFotQ5zTmJHT1PE0/4Q0YJeUURHpNaVB9BVYRTyK8jx8LmweuNwLP9Mb
qhzRtI3bUqxGAAPLLPOPn8DXXGuRIDQ2qouEML6VydyOUB19J+4op11y1iXewLEh5OvrSVmnzSV7
ui6W7MKHLqXGKpYt/8zV3K9z17LsonVL8IOM6jkqT4ieYpHK3Qb7RlzRuE/6los5pbQMMY9RpVVW
13LFSGBPTce0gQ+4jqFtPlXqyfwLvgT9H55XVE5ejNo3QjOmkj4hPNfufh1aINybCvCFYk7YSB4n
Ihlf0a4rD3F7VAhxy215BZRhRR6Uf0DfjTbElDRmipIWqu3zgWQz6/RFfZ/Mw1lBwlu2llDZ8yCO
/TXKf2aE0P3k/+xZ8n8+fcj/de/5vw4KuTEt6T9ddhCItLfk1LOno48uPWM8WCFizZGHEQb8xvUf
41X9jyrVOt9l9FcLA7Gk65weeIg4ZfCrdKpM0G6EYX+DCDPGizhA6RCa8CBp7oZLSXlyoW5mmg8O
mKWygTbDQm7SEd5kiX8eIkeZJSZt2erWslcyng7V575Of5l6GS6NzzOM2yvAnJSn59Q5+I73Dwj1
NITRUxIlXkAk08RYwKUQwwH/4eDFm9fP32wtL0/QZ/8jejdwZM4TTEzfXzLy03/SJ96IgWK/sgsf
IxnD7u1n3eT54HyemlSu7zJXHGsNVFeovOmhRs1Pf3ZP9A8pH2khL6tavaxaf3ARiREbfvFfmNuk
r22ibMewP6rUqyJjFO5m4M9GlxjV02oUAmPUBqDZWCgF7DwJYEWPSTOAPmxlKWAn7zEbqjXl6+m5
MS/VJVXaVRihlm11TNlWHy7/39L9ryVfvKf4fwQA6OXj/5/21h/u//u+//UEmpXa3hqRqngJv8Rb
24uDAUY0AXlMSR0gqQ5UDptN5psdeVN0yo/bHDs3Qt9cVOOQU29M7ABF0kC1dnZBJBPHMSADQ6DD
CF8g4gwc/oJcftGpkjIHHr55e7L/9s2Pe89335LArM9AdwWDiabkqhxcBm0qffCHvf2Tl9vvXu/8
QB8QcxJwd2R3xkWnyKre7FaI3kS5qre6/MmbnT8cwD1+cLgFJ8LtwP/0F/tv3h5ufd1d6xAlJhW4
MaB8f80qcxUhEScybVkTgiN4INN/E/SfH/ZTL479JXlS75j+P+0+XSvkf36w/30O/JfvcN2JfqYg
VY0igayZJUYqvxXQNwPx7zDiczQFeYddAL8KGylpiKABL8sxBsRccbNBiBDwI0IQJWY54pkOSQyK
hqRRxKomY9YMeKJYqJE/cdNojJIbAoojokiM8G0DXwheWXO+6hTGhUIjvIDsQ0vcVvD7IMgNjflt
Di8QYfyhPBIi5Vk2jDaIiIOxF7LmRRS9b3EZ1HaYyjSwcv58KUEqPh6Hqp9Lkt7K60d96XgcpCjW
sB/hHkDEPqZiDvlLfUqwnFoN+AA1AXwKKbqQ7nkP/aWoIUbI0mFEQanCB2gaCsw+CjSUEpIIzfOy
FXUbiZ/CBQm8wiSY+GdeMGq83X6+t7O79eXHH3cP37454X+CXETZYbecL/mD6slwGvsv332/9zor
TkQtOKXiOK4lPtZkWW5KN4mcxtvd/TdbF2k6SfrLy+dBejE9hfrGVOjDuPBxg7QPOH0nYm4P9t68
3qUJppFzOIRIm2NUEaMHEIWEBiFFZ+P+c75QnzuNrE4BnCChBPBTYaY990Du53LhLnN+Pj466iew
4/z+8fFX7W/1v77Q/wAZc3nZXf75Z/eT8diBO72nh/d3WxqiQVdpaDkcwM8hKhewE/gJ70W0yx47
R52lr72ls+OPT9urnU/OY8QIELqJ3gT/SmO2NISCj+V3rtEMYhahSHxCa6lGP34PjCTKsiBNinQq
8CtuCEeYSbl8XiRYPMHNIOCYT80vuyCHPpPfal8ePXp0bPn4yy4U/31PuDWScJshBmgaA+2E6WAW
2uag6XW+XHFUXRRWL0kSLKagF0t/ZHKf5RQy3of37PFHWgX2Ze8TTuFgCsdnuMSWzjI1jaxSqGa0
+WSOOtbioCpaC5s/hT6M3wOTDIs5bDXS2Juwx/GYLcWo60lhyXb/bu+wgRRWnc4f/rT/dv/VyeGb
Vy/xiHJ+9xcsDqUccy6mMWyss+TgJcwXLHh8zVZg12DZZTQEuHDtuue/4CThMVxGcgtkbzn2z+CU
+t4wMYtl2BD5QYYG4gUXOBDy4rE/QmcHih3jJ1gEMsF9v3T1y1mxK0s7NHJeCseNJfJUYAk/Wdbu
HwdXli89TKmxB7K1EVMkM/7lx2DQYPUZ0+41HOUFD6Xnsf/Sj9q8WBVZB7JSsQK8TNkafMkHkZv7
mvMeZD0wZjrXpJxrdDoRfxSnWnREUW0Hw0fZM75w7313FJ07mg4Mu/hRkbReh5kF4WRvmkPImBUF
j0C3MIGvicPClp6PgXut10HjfoFP+L0Ea+GlGR1i33zDHIwzcG7GcuX4LGSfgFB+//rNq13kPw5j
DHrgdkocrycQOFBdzyFhMuQg4HAmAVxco2BApYLwHPNtBAK/b59jeKBj7lAE2HJIz7YqCU0hAvxw
Oghcke+eg9XHI2QLdO0/3eETDCHBtJr0lIm8J2JMfTmmvh96pyN/SCAt6I4rxrzFal3xDVme3yvy
jfiTg5zHJ9w4D3WurBrPB7AcaOSPz0+95koH/3d2piU2iEYuxf6LEmf0M9RMwFgJljhJgl/QsNvt
Fl95o+Acx8P9l4z36JV+Ep2dcOcndD3WHZupBGJjD4HK+ScR0ICT0yge+rGtJLdeJ7y5Mc+vgAbr
NNfiEJ17sasdy+fa+43MBh16gxSohixjzBqfk+5qNidQYhhNYU1PcLO9h4K4KoOU0B8mXjq4AMZx
NIL94PuSExEJEbBi4MbHQTLFPZsE41N41GYqpoOXEPofekkiA2pnKHUT/h5MH6tdnPVK7gwJ7WB0
v7fewrjdNvvn/+6/bhe7i6pvPgXtso1Qs/r/5r9vV8/GTRv4N//B0sD5KDoFZjMzF/T5MbY29gkY
IiRdDcFHvflDkY/iIDpAumwChrrcWg8qpd+s/udDcBbcXhuz8H/X1/P6n97a6oP+/7P6f++N2E/B
0ouAcwMjup5i0nhI3XxUgfqBmB8jrmkJPgyhOi8FcosnP4IHQH10/QhuNiZ49cIPJXEhV8IBQfgA
OfnXB29ecydxpOUcIZ1jhOXqlICLyBCxI5nj91jHYmxmqK6Ut4i7jXKwdRbx+HfhK9nKV5/ISvI+
xdkr+GRXivwd6aQQDjHj1amPw+nybO50TY0jshNAEWSG0IcimYpYxJbh5C5/jxL5W+zL3zJPZvUE
Hd+3Xx/s8VwenMP1mzG6qJ/+fIQi/ObxV2MHx0ceoqivILgIviZtmZMML9egz46eHfMZZQd7O+/e
7v7932/Dr7vfv95+udt4u/f9dr6df/g5+ar57OfkSevbpvvVty34rfnzwRPt36++pNYxZQLiIgRC
kCFjOnKPZGUR6Hio1gvPUbrnGDAcioru/XPoehA1DjBh226+F82fv3rSan7bN0f981dfQa/yT1vf
ij4d7O5vv90+fPO2UN0/LH3sdtqfsJBIAu6dDE/HTQTXi/0Mi2NPDYOiqr4bsyYHvrvqImQEcezI
9MM+g5PSwkIpjPOCfGu6wKmsKgAOqB56gZkaRCPSYdw7TZrwEtM+9DqajyH/AP+7DPxcRxbHB8+2
2NJ6p+BIvloo87RQZiVf5ulaoUzPRIZsaAmG+aYycBP4NKXSfdQhCkFAgwgR+XzvYP/Nwd7h3o9v
MLf2UuincFTfgyy49Ixc/SU6WaBmiiiG8h1Wnp+BAhpBV+JzEakY8pbdZDIKUtx7SVMPXJ2inRE+
xBNEiXAwow3/VvlkGg6Z2Z5xx8hfNXkVriia85fUOvdkS2N3rcF6FPGuyn/DejKPrtlEv7oW3BR4
To3uFbzXxzNqQS/pdhbx2VbbfIuNXXTBwehb2aO2erai/b5aaBQr7c+cAziIyBTz7sfO0rc/D584
qgO54YvTtCUPqCyVhSeAWJlbE8SAICLiJj7eaU2+3mq5W/YWKAeLGFu31eIZSci9XDTqEoJx0/nK
zPiu8Eo+GvUi8hF65NJMm29EffBy7F01OygThYi1w7vSyoW8YHhIipiZGMutQnQfbTHHkpdEhuFS
6bEajZ5iOPvgkwoGCkDajtPme/96a+SNT4F4xX0EO4S76Uir8rjNluCB7P9xy0y5DvVIckrRRAHe
iBqy0UuJ/CVgCTmL0qT7gbMbep5I50MQA7lJEgQMiajrikSI5GbOMlyPy4MR3P/LQFgsSEcEP4Wh
WlDpsKmlQqZMZrXyR1M6cZUWjpG2SU9npuVf5omwDbAgbKfNwrY+nJY1y4qRFIXnMKe5JHqqxWG1
CZE98bZWOzNCsuhL9G1X33IomSC0ASdUBBkMvAm04J9E03Qy5ZFVWpAVRzzDQCzeMXmnirti6F9m
oVaUBdq/LEyyIPYEESsiBJGbwVgE5GkGfjzw0HclDpLpCK8WDuzlcdSL8wCZ22gSWXLL0uw54jqC
yYDWCR3Bwz/ETK6VQCFos3SgfrWCI2gRLr5AHoMFMC48zCOXJMESkLH/f3vvvtZGkvQJf3/rKmrK
3eMqWxKSONhWt/p9MGA3OxgYwN0zg1ltIZWgxkKl0QFD27zXsveyN/bFLyIzK+skZLf7sM+imcZS
VWbkKTIyIjIOU+ykzGs7ZXreeQusQ+FInqgWzViaDb/cd2upAeWXZbmcP6pOilHQzhApQkFQc65s
WTdDHddAP8ZZaX6cNs74LeeLkpbYC0IIFXvl6O9+Nk9Wt9uPe90u4LlzhMHJizGfSmWPT0Y2cCU5
YgceZIrLz+J0U8UdusbxZRNEw/nZ44GThRpKtsuWS6i1p6pOOJpiV0JPHHU43oGf60SjdOepHKna
tcymyUsPLr3VCkZkpmtZfHY5iiw7yNoZjocqSVqCJmBeVzkpWNJo66y0mVoN+3R8OSF67FZTdapO
rhO6B3bB5tm9/WktaL5PrFAtmL53v6i5LJOjFu8N54m20uYkwY1KFzC3iJ9DJTLZsqUbA8Xz2/6a
SDF9tzQeLfa2klZSLLwQFgKIfWyIjOHSeXenYulrR8irUuTWG6aQ0gkjCFnoHsco41Fq0bYk2V8b
LNNvqf8bj766jum++A/ra42M/q/ZWn+w//oD7L9+OtxfdOGoYmVXdTR2WLrgRm8u0XdR+2fiUTlY
mtLwjUdOkf9zYunF+ZXgYaOuGE21BLSj/I0cZf7lyJWhEKvZXBoOde+GQUkWLwJ6bwIvRFjNZOxS
/FUNfSpN2rX2PEnatTgf1K/NBpXuTkkqCkxIKhfRAad6ZLttZbM9fJwKwS+TSfWqTITFonuZXDsc
V1kt/lQFlp/EV2PoaiVxj4kNUuFwyogBzwpFE9XZE5cuZUV+HU5sU3Ir6RsJu4iwzBmFTCKJtmTb
3RyPh1EvcUOTScDgl8v6syi0u2RpwABVZ1Q6LTW3W8ZYHUGlp1OE003SV1jjDNkMTCOxmXGCGGij
jutgGPXjijd8HJyfx9rO0ITZ+i/2llPgjH3dCOlUhigaamUtga1/VmaXxdnlFqZ8IYw3ezWF8zxM
QXw+L7/xrNnnl3r7PNvAbKt7+PVWSSaY4zQVkLsIaVeCctJCGfrDgTHTJMKzLfCoLJMRlEMqgEyL
aAF/sNndV2jOQHY8cVykaXuiPOky5ZEBJFKpVVHKzRrXKYc6vFdmW9bLRamDRKcfON+b2r8mi5CF
4H+fs/qVe6wsPnFDoVC8BIPuw5pK5TicXIcLViyZVGwNmjQowpMlqxenGFLEssg2Lzk1lDFa8uQ7
NsP7DiAqfO50lkpvw3ZPXFzSg2tws8DVWXIkn7KVBifwlyHeWeqSeLBKIpndglQpVEZn9agXJL0y
mVk4mLfk9m3lE2YR2VwtTOSiomfTqL75LxkPPqu+U5bEKuM6WMmf9EulV3tXoDvKnGepjE/586z4
9OBUXZzag8Ox+xZ+qKfIx2Hlkwn8JdOSFSxeqoe7y/bu89fQxKXI57HhWBTFi9jw07lO7p+QJ/5n
sCAl+dlSJDuTZcc6VO3ET2Z/KeJzEnGc3+XIiKbNKcpfxxntvKHuXQf9NmeuUFl2QlkXlVuw6nwf
/WCRJNMVauT7legHMBbao011xlrAv/41PZl/skwvy8l/CFv1+8p/6xut1WZW/ltrrj3If3+k/UcS
ZEjFJ+O9Mgl7ERjShfleFCuhY2uPJ+CV2fYu1je8wDIX6VToB773BhdVxNIJ+xFtwqtpBFfEer0O
b1O4D+U6cxFNODDDiJX8v8SSyg4+oN75/Px8GH6YBGOfE2JpEnx8sHfQZumyhs4MYzZngW5nq+14
/71SR0cQrRR1WJIRW/lRrCrZV0v/vaJ6Iv6q4eP0xZMk2nAxPN1jbzvuzeX6heE5zrb4yVSd7fjD
CDH0ZMBDEoUk0LZiIGmSkdVwInxrKkSXAi72OhO5QDeEz3Tnkq9qh6HJ9oc8XhcFSULYTQvzQiSZ
YIZwoqWpqzvIKKKPrYhTuWDUAez86FBjq3Sgh3IcVQJJiJywJOPDwWaFvWxg5BGmokUahwQxvQ6i
WIFioc7TsqaxOWIE0+x1Hi0gXgoAavf4ZOf4+CDBWRwiMaei+xkWJirWs69xwu0RKYj7uFTlJBI0
7wbhq9BVKKkP0bGYB5dS3NEwPTsaog5Pj9jaYj8VWSAHAcedxsJGarfIbpDJVbdT2oxHJRK6DKaX
w+jczig0/tDH5oHoNwx7CHt5OZ9Fw89JNfTTztFB9+fd/Z2C2JhHO1u7+yfymgNjanrBm9hP6iJt
ws7RPRCkUA4OH/ATgvby56PNwwUw+H2q+jm2OtU8/OfJjwf7fKeboWhuBWFRDg539rvbO/snRwem
kJx7sCJHJ2pqaeBoVuOr8aTi5tHWjynYSZm/v905PjmQPvO1LU3uEF8StW3jzE8FHy84dLVd0FS2
6VUgJDTU9JGEqbe729KKzkxTeXtC48GiEQ7g6fgDnlM5vz7+wDrmytZmYcRThIWR3DeFVQmZESz1
1S52UDIyvpAGRFqAulr/rc0j2EpsdqUzWOVsDQ0JlzPwbez2sIJzWnRcako9v3K8tfnm5W5Zc2qL
U4Mqe89n5vb5SEO7q02IyyOMr9H4XNPzbIsKRFXOKY0VQLEkfKzdP4FShZ0FEo4TEu8dbG0dLCgo
mjNJ9VPZ293/24Kyw2iEUm929t+WrQRjEl8LIQiOm+t4gnhyuImDKVNBTwiTwO9iLy/fSCA6N3DH
03yjld2tg/0dgNxZHiQ0rrzGO693j0/KO9MLaK9k22QvH8Kjk6O3NJoTzkrmEjPRRzIyV3EV+DqK
Z+FYos0qpkN9nV5PVlsa7Hkcz/R32oDZkIPynLobD01P+ucX+itrZ9T3K+wU9R1j0d8V1bvTmKg3
j+cq3gAFNd8wlR/CKvCPN/NpxOM5jHqwruCHP0X9MOZvJ+HVmE7WEPOJncW7EzfROQtNb29z//Un
/Hm7+Xrn095W93Sz9q+zp59Asbd3Xr59Ld/29g5oOY92t3eOP8Esb2/zn59O/uWbLHPdn94eMCVs
rtvUTtxiI6WazJ3adILFkXUyKguOeV+Fq5WQ/CmLQXV5KXRTVSPWyXWeqswpxRd0X5SgKccJJ9mZ
0kqBxfmZisD8HsmZZH97OsZV1bCFeipzL4pOMl0KhlTZdwagraszMbU6nQQwThv13A5vbN4/BfBp
OPbhad35eh9h1ZTBCO19mJeoRu28eXuh7mroJNy65tOJO7f5eXYwNsWvofTnKHJKoqjq1CZ2Qklw
3EOk57Ya8pgMIytmNOJURknMXSfQls99w8f7xoItZzVWcBBbtiuwLUKwBcemNRmTgLJTyIJI8lEu
fUjSDZxV3rggJCgVmY/U20rmhcmqNy5MoWdZn+iGhlxs6imOIdMecOj2ihsrHICupZLYsT9kF2x8
9zrsEeGxMOLtSAe6nSLMK9bmOu5xNkVh/FkOZhGNlzExSde0jJM/Iyh1MEykGLOGsIOMF3BL9eQ0
zcy1mgEGkAsIzj9lMPGvO85VwxzRNwsJHMPiajkUVX3yHfFJn2VRR79PBmTjhy6sQgJ43Ct/EdJk
ZksqZIx9WViiw5CEhUkY6i5UZcyE7tRyN9UChChGr2mmQQvc5MoGttDYWCpcEWOWaVtq8dHEyyw5
IU0U/srro839bfBWLeeJ02y01pwnT5xVZT1L2MledlauSQT7nWnz6Fk8S1nDTwIETqk6XTk6QSho
8j4Ew/de5sDQNQYow1rd+2MPo7WnjD5D3JWkDVx10wMf5jfsK1sUfLgwQ0wuS4xaeDT4gxpxvoY6
o6hQJfNT8hnG4wi5t7qSEnUWe9N4ciHXq3AcLUr3SPN7LhuEB6gryHnJj7hmytRNjxZn5Ln5ITFx
Zh6/voK04qMAHp0nj0ojSS/kCDII38oOzB6/XvbiwRMF20IxFVdGXRwS2kYmlSyy9U4iiakzCdOK
KzH04oboOJwR92Zooo2N+pTMI6WZ4GSE/5lHWRKFDtscizAsGrqB4ReSG4JXSlsWbIBpthMJfpcf
nJx2Y1pKF6cFR2oBllbTDfMAaFcpU1korbqKHcway8IFJ6tt9MJp3fnvlWO58JhFK1PCsjHRUkJI
7YPFnUAwQIv1YYAJU6dFFot5Ila9H+RVYvriF3yObfeRHJe6K0sxKpawZLI9zkeo+zHP3/q8pGMs
6ak6IqE24HwipwUH6Mg31vyZlfFcM2M5ie24x0q9iAWLAhkvygh8ubSIuxJLODLiX2BkPtdWkpzd
VUw23ISz7w6Da6h34RpVTbslqFTXCivaltu9xgrGH/bzHnHkW8XJi+J2CI8rz4oi4dPBNZ6zVpKd
GRlFLKizcILQ80M2EyIaEomjRb9Iq+sZxKsahXGdxHnoy7MENcmZsiLqHxJ0lRPPxH1X9wjIJ6r6
6TyYfepd9T9R5z8NR+/9b2A6CzVqfdcv54qD8ymjS3DfVh4nW1kLYFVHM3Z+4XW3Y2oEo1svqTUV
TJuKrTo0h6z+jMesnEBgrJw/SJaSmX1TSs9MLbhQcnrbLLNVsGX8oixyGkI00vsNgkfCj6j3VUfY
FzgtyreS5HdEwbO73RqOfg4nGe5mUa+KqeVYn3m5VHrg0UrzRiZnmLp8mlpXLW3xLdanWlDcFSr8
OUNSM7ZwYOawNtOLJ/7SU4rSS85mKsN28Qzm6U32CeFEFsFKQBUlLCzdbwV7rb14AOOv1PvxEl1P
NZxWlxQTas2OsTbA+9WJw9Lqr7KEo9oXbHH2+FwyxpTbGavtpuxrGHTV6W6J1bUfHFaVGzPJAD5Y
Jplz6qbZunhjR8rJdehrfsCmcYnG/Cruh51G/Az+1QXkjpPkslQlanqIsC67JWQz5/KVW30ANb0n
76rq2R6mducffiobrFmnlL9uoYfTtNxRK9GUyLrkKRB0DOz1HLAZrpoovv6OHdy7Zr23YL64H89e
ISz+vVk2c1pRuVeDznOXDhy57OKEOKrlmr43ZUUmQhaNwg9Eaaeg9yIwVxblXyv2JfwineiChhhd
u4N+VmYfyGnHqUTxx0OmvFYS/Egyo9mvv+c67bIEs416y8/JA3nUKEaPHIqk0KMPH17c23cEf/Ul
iaTq8/zT2lqj0T6r207pZRvYgqU2k1Kzu7uW8gqxPwoYMs7oC1JVhdAF1T5HWbKFO0n9xYE04noq
/RSncn83+qh7cMepuUx/dCZ3v5JNr8ZUhU5JcVdMMnlrotlh32TayEhAEsg6y4Bp2ZNwAMYJF37T
zarTWuQ2SbtxwNL7yP8OYDT1Hi2XwNaqQZB40ejffngNUzk+bw+6R9s/H6nRmnSNfHOVJGoyQ3X1
WPHQ0qoblWGlICcb8TtsjdJ2Pr5vO9c8Ae+r9EXEaX2DGs3Cq6nHXuvp2yLL2f69f3dnJhE2LgGH
LMFkZmYSE54/ARbkv1YnGk0Vdilk2dMlM1kS3aEaGfe05fNa3reGFqhz111wAsLrS5VdQiWmtrnx
zswk0ZQL7RBmikR1m35xPi47k+LJ7bg0I1fKVS5HsNb9El43fSdH3boO1M0cYSPzukRoJvF1kAn3
wVzLkLHOkzgRBc652ct73DAyHv/DFWYuJ3EkNU7t0mc+vP1ypQs4QEXiBu5xxPkCdExk0Vxo6qai
JRDv8VHDuPPFLeaj1YXHSRcen93Z6QyzOSFtNiVR7hewJplrDqW1LrscoGZoy9KAL1ICoKbjhxOE
CrHGt9WWUKh5+XqowyrIXUcv0rkfo0mPmQwS1efQ0dXtYSak+FSU/pl781rknpWXVnffKPdBlyu4
nJNToOCOJpmwK1ag2kDbVoxGMUJEKkirALQ6BiUrxh+XYRExMxYE5YBUnsgiQLaGP1ctX0EVgWsn
olopkSOlrbOK+IVe06qcmAb1PvQRcaVEAjItWIWXVBxrtC44gwWqzxe3tVrNUTwhHfUQbPx2oZlc
ys7NNrcDCDFI2XzzZuf4eIfPQxA41nZJAEF83SfRC/++JmaDeqV/bsVXmF/ODKsyBh+DM52P9/mG
v+CmXhf4+c0WgoEwlICQMYb/LzcVbxNtHga3+PG38BbhwpSZhWiy3LvKzj92trQZnW1g8dj7rzaR
DSehGB3XO/2f7tkT33X8/xIzhvpT/7Ff+Wl352TzJBur6/Hp//rmu79++h65Widnj/XVZTCKBlEv
6F4TF5yNqPQTPcvcUwb6npJJt2RjYRI4DXXo+0LrUtZqWkKZX2cTTKW6nbI9sDJf3CNCcVPNGpb6
ih2ElgOuMkmgJqTMhOEim/ETTZyGF3NOu2rpKDOaysl9IZs4+GiSO3PiZnJy2krCUzezPTjEkjgV
WBFv8ifqOU3o+1IlEc+qoaoaoHeqVL7ODm3X27OcNDDRrDsH58mUdkuPdTM9SVApabCTQPxO5lpz
o6oEPS4OMmVmALDZF77j6oAZxmM+mcZH7n1Bp3TiXgldJj3D6nkEGPyNFW2WA/PoJNhS5pTLnDbS
so3qrdSgCduBeVe6H4h1ZXalxchKN+qF8Zx0ACwMU21HrUJOIlv5y6/Go0RVztvDGUm+CqNsF3RJ
rkMSq3RxjJ2zFYJs5wxk3twsjs1jJEOaiD5QGaNockq7Gl4u4IGxx3CrU59OL1dSCnS9v8YhXJM4
s7KaftCv7//y7h0i9j2uOgsngSbPJS7B4bCvBKhYq1s2VRrCSgLAaMUzUb9WYKIW1H45Q+gvLlmm
VrdV61zQRt1ythFyxorrf94A4OBdGDOrmKO9sqKFLcnD3teDFAkd8J7oFJkbf0yW8c7NZ8/WhCIB
l4ldwruOFil1TOtpzmybVFDEop3LRzvXTm9MpoObiYHJZ9DAFHh9RJc1wbHF3fZy2ufU/Azcjypj
cuejAL5zU5pdyKrqHpjzQyvxFf2zloq1HonuVLn5Mserj7YiS5hSOxz/HtVnEQBlj/xV9KGwBAAC
fryrlF8tLWlFtISJir4iaeeoWcklvUXnByTR9dU5Vle5a+TqsIDqnL774NSrnv/0ce3s6TtTHNfs
7ZLrmQIMKlUK8AvmqDoF65QYElQl386045KQNwx6oVJreBvr66sbBVda95jQLOzp+RzuVZ1CdrNo
Url8cRsirCmrbVjrKneW+vQyaHpZO43SwevlNiogv34Z3vSjC+qT55+2my2IWclqFvcFKHoqQlxH
Ol1oBmIM4+83BrGiA5paeao30IwU92CRrWRuo6h+DPxM48qU2ADVyrx77DtTIO9XWUFpA6Qca4Uz
iCs3/BkY9dnWXAnRGvOism2cK8ZwoFIXeRgX9Q8TmoEiHKXxqy2TAWdd4D1y4IYQKr5MpW+OnMP9
1844IqoHLoojw8BiYQor+6gXJRxpLy6lctq9YUmyxqA+j6hpm6YljZDkoBqmTL6V75Kx+pJelJHP
DIG8jDgY88q7/tMb+m+F6Pp0hahmnenlGFbyaNC371C1kVPepOvXUVLrmvginMG4LmkDsZIts0mO
pCumlmbcibbYe85swrn77ub5C0KDdxOSw2+awbsihuTe/pbdwSf+MjJFZWMqUBHy3bkZgli9Wd0X
5rJ0dH75IBaZ33Kj91qUFNjZirFbxvLwS44s8XLY3d/ePdr9178Osm4t7HP6X+2VldP/+W76zn38
/Q//6927s4/NaqvRaIBN4+spFSmar6xJXu8aFZVXZOdZGg4WXlxLhYOtpHZxOhJsjkIDamrTFjEt
88mwQI2RKgJTNtGq21eZtcQid+wb21LaGhuNzzDhzyF6bkMO+jIuoeLm3utgf++fzif5tX/w6mBv
7+Dn5Pc+ruf/5hecBdP6oM+gBv0CRqjkTEAyrA6dDIzxa40XG35Ol7AI5aS6df+z4OJ+vBzI1EkX
9DnlZeomOnnJeHraBqNyOpPLN7bXE/yF6ZtUr9Hz72n1UkFXzf6wCDUNR9CBQ1AyGNxsr7f1CYiQ
Zbi/u4qddf7BNwCp/ks1Y8/CPchcfeddrIzbbBVTevbV7/nFqKDICsEYN7PKOmuVAgb3lJ2L2bZh
PmK3iBp8VPmOotaPpshExU9ERElKjaN++sE8bbxpvemx0F0j7JEa1Mua6qVuJ6wBzWtjKg4ddgoM
0l5G4p22ov84pWrIyOTBbmtb2qrJdMZ2cCng/fCaYap/+QE3p7vLsX76kyj9PQUDK8Wv1ZdFn0fa
eFwtb2R7zqSgEvka8JyvwDZYOpc8A3HLPLoOJkWPJ/ORq+NEw4Ky6qxcjfgvHXEB/TudXLez2utq
Km4ClHOXkSHiY2WWqc0xr0bqXwDkbwTSps45n5isu1QAT4lTq9vjswUzaHdN+i0dbOswUVElBVQh
kFlRmpEVuUjsr0xCWo/rcMFztCh2uqFEX7J6XgJ8rrEq+bG4Epy16/9oNmnLRDeFT3KTkMqXRwX9
dAtqxyRXp0XmEkm5xJLMfCsst4wS5ktcr/zlm1PyRPUz3asLGlDTX+IHj2y9iD5fa+QaKyn02S3M
oYHz732fhjsNZ+GI0Qv6/a4KEoHfTdn66QLKYKAUAZLSHB4BCMAzab/JxhioOrqTaVhE8JO2N/+5
t7m/3VU+0+asMAW2X7497h7vHCMhcBffN7e3j+hndq/0LhG4oLj/99rpmWgkmgJe5KK6INRx5ipW
7ibgiRq1JU70FNcU+hxPwvsooCbID7uu8rfNSe/S8XKRMyR0jrr24FOJ+O/w/DzUDigjtiApc31M
heZIW4xkS0jUD5sIwzqpTmMPb7xkdS2G6zRqR8xtpc7cDEDrAfpwZqt9A8VtyD245jKME65lrios
/mcTkwwFqOSY9ZSsZkwFC+0CbCmvf68B7SS8iBgHMmaIopJJFdF6GLY2mk0GzNe63/6z9u1V7du+
8+2P7W/ftL89dlkrblCOgyDGsPH6LoE0GM6nl4onhpiU4y1zjF31futSDd3wmvqB0pez8ee4Po6H
Q8/X16ELzAXTevvvcgJlVi7Y4X+Q5YijopfwcNqYAnuEDlCOg+sMwslVgDtFGGn+h0NuZSyNU0sw
0OGNOKz6grktHNe4/iGIZp7O0tHKDcSa4xMptHMzpj3cLxF50hP1xTgzcLP2z97HsRV5/c7HSL9u
NAFFsSqcNMY5VkS1rVI1ILZ7NIpm3a43DYf2rQB+1uXaBGKeDsFU38N1ip8uxtF+k3RV5vl8OINE
lpYSTctyn8TtsoJyZHvs2iawhWvcZ+8TKseqyG7iZUAzfM02mQCJlHXff++0iDSsZmTzS4kdO2NI
ifLhnK018wI5uNVYIraOuA1PQS5VNXKNRfexuVfoCThfrpkzDLDsLlEwq9UwlluEhd6NeGHdgHhf
nRrb3LOzTFIFbTsDgyW+w2o7JkBWOuqL9UKCYt2xHaS29WrkzUMs16PEMGPIepApq/hWC28wR2xV
GxAJO3/8UZmUtp0mEYHHTARyM6cthjnrSG9m2V36heXq8zHNX+jBvBhzde2nbIyvxL7T2CFXnY93
/rLmxplFSUKUKKjGINrPS1boS66Y78tlqz4G8/ola6MW6Net7YmEbd8t2Jj3KqkLz7FTs8y4xEpZ
B8p5RqtN2GHOMPxsnpkTDD9bZ/doSMx8fuh3kgABtMgdvUoFfl9QWTLzQk0U78JYG0UP+gX1sxQo
sViI+MJTHTL+Z10X6crN1rNKJtEAYXzBnN+/xNllrn3GMqe2m22/nmw8/vcub8a+IOmSbeb9t/BW
fdsF+3qP8XdKx1g4J/csa+mS8khNLAp9BLEKoqv1Odkj0HXzYZB03F9m+qK079eMAz3OJsFoFKaM
0WesazRmhEwfE5vWcdTPO6adjhN9jaW2V4oqph5jphsXwEEThWHsmzxRzaoTFdx4FwgeA4G68nF8
txLekNh6lsyQndUlPTv3uoL9Kr+uL/YaFGcHSECqG98xUlySlCAPqk4j3mg06LlMK9GwpmWDIHwB
xIdsAqKYwytpZoODV9blH+90ivxm6r/1opMw5aVuI6UCVwdCjbPk5DMpwL37ndfNsHIn/M2bBRPC
wg5DEJ6MHSCmHeGgEGM2CK+0Wlqs0bwlXV/v7zwEg1gmNGEkkYAof/tjj/EHx47hlrtMYqDavEtA
p7e6X0Jql/K0TPV/eSujnOFuKQo1YDwKdmnJrmfXoFj5iqjlbL5ONOk/82DYm3Na4pj2eKyuZMrO
yeKNnSnUZXP7hp/Ldad6rMxpcm7bdtxRUf+aJHgdx84ltcgXx2jT2MzDbbpte+icGTsXwaMtYbAQ
5j59Y7nIR0MNFsEZr70MT0yrl3mScqBIBW7JALCropKnbH2K/DyEJTw98/PAUznp2k1OSndaqFVr
5x2A3Ixlby6c10LQxrE2l+zSqJVslVOZx9W9GcewdRKkaC0Yoj7slkAW02UtIXt+3cbgAmeZ1Ov/
7+Hze8f/Rxzk36KNe/K/5b83G+vN1f/PWX+I//+7r/8gGM2C6VWw8oeuf2u1sf6w/n/o+rMbaVzT
v3/D9W+tPlvNrP/66uqzh/wfv2P+R87+uFWc1KPNSry4HwyjWQAnI8GIqo52Gun7ulf0ZxDfOLFz
ckkiaTg5jyZ95Y9cecS3feN4yoFzB0h8wBEAR/G0h+C5nsnB04vj9xHsTq9YzJN4qkYpxhkglP82
x8fPOLcMVCdyL2ZJn+oV8EidbzzNMTvuNw1iysC3dpIQ/9+glCspxmoEL5z1rP3BCfl0lrGKSrjk
Sh0dFU51RrOpqVSTb2RG/8//NjOazTypn5cnoSrJRrneSGfUsnIuHYeRtZxW4yrZkl5DjlsLVDiB
eunKZNvSC5gsHT0capVMxdOLZ1YztYoqQYhfdw45TcgojwgVLCx1lNp1XkpxyeKYGdHCtFObhJCO
BSGdP4vf6oGavuvEWQWpszh5lkmaxWmzIGzkMCye1HQKFCQDtas88Tn7HInh5mGSaMuk2vq/AkX2
AkcCYuRwBHIOX5pk8mpxWD9UqfQuIwdeGpyGcagBYStz6gtkDP2ClbbXEOn67JnmLFyDqMIL5n6D
Le7y6jxIGAvP/36EoMPB12AA7jn/nz1bz+b/Wl9bezj//9D8X9uy/Ly1BjH29LQ3nyBV8/AxKE+g
YtLn+QLHO9x/XRW7oUMG6Usu6CxGacCvdvd24Bki+735otW4aTaeN4rrSNumyt7myYGjHv5nHvSR
NlAC1649rzoba1Wn2Xru6xxKV8HsEhdlkzmnSUIqpF8I6ZV6bXRhZUkYBpOLy/CXXwIOZiBfxkRB
h/g90LGw2aUT3mO3szCYTIJbpdfATcMt+1AHo4vQUxDsGAW2D2nDTz/HxSK3dXp7Zu4NRBXqzaIx
gpIHJpKOHTKMB1YfB733nvsDrMBwOcxlodhCVfpH7sQLCmMq6r1Jb7XlWUV9569O42agPlk/0mTC
3A/notsdWEYHypajyHHGz5eSEZ67uz9uw64u08Pdl/i4xUuDxWZ9Gq2NKPNaVach//f9RW1tb56Y
scdXCEs49bCcU+WvW3VeLAaws79NAM45ZJmVcaOrUda7qTq3SVyOV/I40tnrNNrGTqNeb7bZny5w
6GzrB2CFJ1ju83jS5+LEr05jh97NhwijwTBrP9BRp+JHNnWNlhMjTI6+IOvdiIcgItzqAGON+jpN
Tn31Of6q21PgbXwjwdHqa028WX/ht5e4SX4kDdpaX8+7gYfJje+sEJzG2rovnlZP6c0tvaG2n6l3
G/rd9x2nWRgxsVVJQe0ZqDmg6y31KgWTu3hOfQwcN750K6XgNXQNFUB56hJoagrxM7cHmxqQrCOV
vsWfRv3FenupK3lYM49+mYN6Mk/EOUMI4wOz/qbJq5CjkunuOF6TOkxr+RzfrX6vYDVfrJsH6aDJ
51MzZuooYGYviMUMplF/vsHwG+sEH6S0Po1GshxeD39R1+fm4FrHv+jfVh3lW7rOOGIgG7k7PZ4n
buye+GXqR0MFweEqSYIaqbxXdZDlCIcJ7QqcJsrkCLspEE8br3HTogOCThv+uxrQXqdnDWyIm8YG
v1GWbthtVGOVmObP/bAFXyIzm00csN/bRDwwLmh/XtxSC3ucZxIRkJzmWgODSH6rqJR8MqTDGVpH
zWb6kAkKDieuhcZusVRooZn2SL1JwO1lvU9vqN4N6u2l6/FFKCJO3NBC085eh3XeLX/fWE8bDqDv
WInTiK9leDrwveaop8Aa8XKKkp6s+mnLkX4LS+gNbnjTt1qotEcd20y27kAIQksTAuPaBNOp6yge
BlkcJKDfO816gffbe94Bqwb1w5uxV1urN+h3v1Vwd4tB9tQICak2moxioLg3z1d9GW5PjfX9fWOl
nl3cYHvQH3x7KjiBy5iLW0Vj8E2e5zt/7XRypxLv2wsmo6hUFYpxcasfFFrhXeN2p1nin5sZcg9n
7805/w2fZ4bcqDef3zfqKS8w8OkZgQQuNVfBjawKgNa6OkPWs9E52NlFznA6Z73W+jqk0xvE+4RJ
xzW4HyZC67AGQy/YTq2XDJn3mGbPAFHZHadYRNAYwxS+QgQRxQAwO5riJU1grl5wNY5iTkKw9tmE
BGxARBz35DzqR0vQAqvd+8hBetdnKspFOPEVuGvGKZ8yTNX1p1bLephF0bdR9GapogtQl1BseqPW
kBDWALGxGWVuy8uUhVPHOAl/BNWLb+Z5DnSZVqrMiMOFq0V+Yr5mPLw6CO3EDQkw9GmU3fIBm20U
HIYpDPcaFqO7nA3Je7OOK9l+5Ck1dgzt5oHs416VhQHezcxw1Jz3kC1wlgZ8YvJf4vWkxHv/vl2e
Hk0P6TY4+w14hvV1/+wzN6WsvvxVW1M5f37RJbhwF6m7feE3TNnWmZ8EkCyAwMTABiDUwaovVMk8
WD3ziy7HE5uCt9O4vVCYdj5ZYjKLyG7pfXpW/8Oa/698C/z593/NjfXWw/3fH6H/k/XX2NWb06aa
RL/p+rc2Gq1nmfVfe4b73wf93x+v/4uc8RxhvjkhOqKJxvOpxBVVwZUQj3UGnbrXM9eHw8G0Pr0E
U0Rlmw1ftIEEVfSBbWcwCXsIN3oeBaMep4FQOo5RyDrG+Op8QmDCi4twwmqQK5KE59pkuO4cSwbj
ObLUw73d+YdgKqeLQDVcUf14O54MiUeuOq9P/lZ1/j6D8jI4/9BTKd8zSG68fRPT8nquDE8Wu9Ou
sOfdCg/ezFekQlMFw6iNgw/dVvGBHG8cDyPqWIRMfKOQTbT46KeBIcLjBdUc0py01iCWEshJSLMn
3B5GHyn+D9c+azdrCZcBBzA5G9N6TuSGt3SdlcrJ5uu9XcSm9SD3rraqztpz5O9+c7h7sI+Qs2uV
l7ub+5y52iMpqOroP35lXzJDew080X+Q6fqt9XTtGf4+X/Mrr492X++qCuusZ1rndxskK6kYwb/+
41yEhBizSRTYmW6hbkNK4aFmKcHGMHte0Qwa1KJcwHDNFoNie03dkNh22+RwzMOIOJrkBU3ebUu/
8KDTaPrOt84oFXnDo7o/OLfsm+NRcf4OqQ1y3E1Tq5dum5BovJsWfb9psgLltiXP2zmGDPa3vZTZ
X0WpHeGoSUgIoz89C8hKqANcICwvpH4Res/p5zl+nouGmX72+SfEwkBe0pdbUX9gpH1IYn0w3X3I
Yn15xVkkSQym0aIU7IxZ/cryFrACEhijkUicAVRrAsaTFvi3iJ0txfmMqf0x9xXlZlKB5oZHoB7w
xNnzIBqp/0xm3hg9HaPqGD0d3/r2FDGhyWNJHi80XOQRLJhbhRLVPAr4eZTSPZjM41nAbVRpwwd9
BJe46TRbmKDerfoypcM46GDbJbFJeHSoEIymHtdUOe2qLCfz61489aDEMrq5dI6hU2jpnloKVBJP
oLvDTPZ4Gab8B62jN5myU71kUrZnyuZDyGKCOIArjfNMjZyIXexBD92juZvgCoPRE3fIUaeph5ru
6kRrWzCy1Az0kSyahIQawUFHIMowKD/rCs3jmNgay2UB5ZaRn/Myn309IgY6xicFATzACYIfAUzL
cSjAn4JNbBC4Nqrq82jGvcJxgLDSw8fKhp/v0uPxJFAnnOdiBRBCZM6uFpOIDqOIkVhdKhD2jHFx
PiEJSWrgbAokGd45Tl6ENM2XCkZw7nerjllRVkInBZOq/aCrMF198Suvjna2tnahoD311DXEOitf
8b35rN7Cj7X6Bv1YlTfP+M2L+hp+NJmwNJ/XV9OLTaVauPCrb3CpVn1V/aLlerO5z8fRKRWiw69F
kMSSnLDyBaq18LhZfw7AcG7doD8bPozknaemkVOvybTsOXXRVJeGnnN38a0Fv/lVaG/XfKuulF2r
v6g6L+rNZco+Q4kXqNDkHkrZ9UxZ6pO0vV5v8LifcY3n6tcG3rUaqV9qhp5jtOkfjfoLe069DQXr
GYqs87RvCKgWv1mVFWnVn/FUr+LHKs9kU8DKKjYBIAW2weVfyNqi/BqBJVG6sn1weKhQo8mL3pL2
NvDjmfWdsGBNjTf3S5WjsRkIFqLoKs/MhK3zUDYS2KkfKEco9Pe3mycnzAWdekKom2ZWaXnWBW2b
PPzUj2ZDYSTPcfrXs/rzDBK3VtXkNKw6Gwqe/FKzrqCnfz0HQN0n+ZUCLz1HIzL3z606DV6s9C8F
fZ3BpX5wn9Kw7Z5zoWcCSyrogQvg1C81X9wdfNenhhIUvOzxoAmboiRVRxjXqrPP0Uyb9aYBcRWM
4tL6IAtFldOHSEIVzf6XvusB45dUzmygTOVVjPUF4OsfVPn5kpV5RV/IVlTLu8rTllTWY+bAp3rQ
fHSklcRZss43vp6eBoX8ejbW7DjvAgzBpOyuMU4plFIIJnsjd34UOSZbkF5wXXt2ZYifC6e5bgNa
/XJAL9Rg1pIeEZF8/uVdaprdugBUKpQMT7nmoma0tIE3IMG6iHOcdJ4zA6ngdDDmtgrMI0c2i5nI
0Ruz8QEOGud8OOe75ouIhG6Phe1h4CAXz5B6H9iJm0VYAEOKLhC/ROckcf8rznPioF40MpsszyVY
KEd8FDaARjo5c3PovwgEcshCzPzCyiS7ChvKPGCz2TDbR7LZ8CynCYchRzj77aWgM2JD/+Ujr1Vv
GakDWZEDTzFBWeY+R5JERJBj0AgJUkvY7UXETjIllZI7dYQtJJfRJBr9GtqxZtOO1SVpRytFO1pf
RDta9unTsn8tv7+uoxDKrvwEGlRqGsA43fRy34PFpo/Mf20osiSMzzOeMQ1gDe/K0DjXNjOtivx/
actSnRniryjVKEkllihYoqrCnShLMZZFlF4aNtzqqHw/RFLSARa5XiqG4hj+vLjGYcxOq0m6IpMr
eceSdKCvSRsRcIiTIqVAzjIA1+wEYcW2+Ulu2VKDUO016+lLUr4hKlNSLQCnRmGDY1BmCmSNc3Ng
JLjCoUcLNEafMVYGn+7aNMx1JUV/VZ9YAVC4IiygX96O45lSP0CdwHqH3BXpOUnw9GqysMskvGuo
/fBiEoZKmRDMglFLqTQIKUXTUWj3IPoB54cO9hjcyD3AFJ3Bt/yMmtdahLLw5eXzpjV5VhFFj1gR
XrBtHikVuaiHIfUjHxed2qw9qKpzYBaU2BsB8UDVx5ktlt9ZZ3ZiQjzJWbzpzcqr1HHEHueFLBkd
LJmNnIKQ2w+nzTO/0PyvUV+VVhg/tEYutWtRN91QSvsFCKwFUnpJmnssF2EMOLKKzrvCsf5DPeOc
kjawEm/LA6DZWr3QHGusjMuazBVp3XoyCZaRRAq4KXCzoIDObgZ0Pod6VJSvOf3bvxMYugcllhjR
UiV5eaE9YaWqF2mjiicyXOhup4WVbrkSaxL/vXQl3hrBMDGkSG+AsugPuETKRejLBx2D7UNuUy2I
/4AKOCKLw46Bm6Ey2DJPCHhhoQtdqLmg0Lku1FpQKJBYZjmDE3OF8ySNcYnpkLofazubR69fMvMf
CbmJJJLDVTycRSraJF8oDR8zFbKhQCkjphkr1CqbZ6g1Tcd1sc00vE2O6bbmO58Ib6jyJFcZBZob
psBFYYHn5UsEaweqd56rl9r+3CvNJOP2MLKMRgbxzMR65utOsA6zgIhLp2EILifnMPNITcKWVuUt
RIhHZNcYxxGkKhXlD/MYQ6WryYrcvAy1DZXFVCu6QptRLukSDL68URRPFakhZzVHJkJHBfFSVMk6
wS5vF9ZtLqqrU8ExhUgmqJ1dayBFMdVMlVSjNnghZTJG/t+/gB/C6oYYGQ36sA7Q4DhXt/6q/l0u
yJn1uaTdfnlrVtfP+kF8/21/16UTnS+Cohvijp/gHzUtYtJNtB120E1YNKOcGpkK6WEQYSr5opXd
fWahxYODD2epbZ2JDAEbPd2zVUxN0bRQU5aNFLX7tJP4fXyhuwbQ3M1NDnehKYbRMNSopsaPyZTO
p5Gou2CwdqvSX0ggHJ4FJga85Wo/OF75BnWupjrdKAKT+5WTnTcgVB/F32IYDmbd8QzRFr1TI72f
8V3DBl9I+xCd8oh06hKlCOZDjuYeTCbxB3yZxeMugzRP0r9gbhfezGoIa4rfl+Fw7BahqcsRW4l4
JHU/XAazaXd2GXGo+oDWdiogxxwXvT/q1+zvCB/EHeB/i5pAqatY4rnjezB9r7+OYknX/I+u0DN8
h7uLzBVaZa9R+VUE+5c4vqpFnLKAv8ZznqhxNAlm0uAkGMzcMyWPupfBqN/iRRB17Bmr1lpahZ5b
gVPiPkFiuTOo3NRfuBm8i0YXXf2AcONc/3secZIhFwgv77MDcDlsXV9X1hNS0w8Gw3A+kV9mADfU
lysegNKtnrG6AtI49596jJXnIOvnYXCFL9dwju4FQ3atTUB9QGxLBqVVSH6SD0Z4sedp8M8YPqIj
JlA0ZncTcFptVQLOwngByD71oSQ7vqTjvnY+n94mLUzPu5fdfjw/H4YKS9GI0mY1shOwgBafuhk4
1F74oUZNR7+EguND6xePbBr1wwQr5dcicu+GFgQbNv7tXgqKczrT7mVqiNelQ3zxeWO8zo1xNLX6
Qc+sXyAkeojnkN2ulhnjyB5Xdowqm7qMkaPKp/qTjBmFB/0ouLAHu8a3sM83lhnyqTv6MA0zo+FV
o8NlJN1Qg5LlSx6PkkkoHKmbgnvez83pfNgllB4KokzU9/TYzrNjq33m4MJpdqmyw1Cjy4x5FN43
OBvuoGBwE2tww+zgmCzxuLSWN0+DNL0PhsMasbnxcGjwgx4lsOjVdHoZRAJP63zz8Lgcz4L51gsF
6Hg4598021fxqN9VBT6PJ5MGupOQsHdqjXUUz2rU4fhD2OceGr1svoujuNafcA5OARZSV6JJT2ZR
f/tsTtEdsGalz5mK1BEh7aCPd+ZukZhr3xiQgx3Sdtxs9NW61367wPiQ3ZeLDQ195TZrxUFOTM6V
r3A06fayacSSGL+uNKiTEKYi/6NmYcT/ASdDRVS5BZyYYsN8FmKICcvnoFRyV6pnqlFA9xcJYmme
kiUlbu6eDJcKfJDTHOpSQxWydewXxr6dhNhR2Yxn9GJ6e8UBHGVaxgvz61qzzykn6rPL8IqTnegc
lgVMuHu6CzH9BEXP3o32g6uwwzjwbrQVX0Fl2zlMWeZqe1wulLfGVZHw73ODEIx+iI3xYP8P6sS/
fmP/j+Zqo7WWtf9ffYj/8eew/0eOIHYtir7M6F+b/Kcs7hmtkiAep3Taz8JPwfA8+DQKSYALzhDj
S8UbodZ77M4FcjgLkJdgOO9FxjJeDBZgLInTQyIh4G8v9tvMSJBAirqwqI+Ih4INJ/EJAXNJ5wG9
C4Y4vVxp2lUWEvW8SX9VZSTihjLG9hz36KowuEjeF70g3ogEm1BZRAIO1FsUVGTCQh3KJicGp9vI
hxLRuS8mJSFElo4fkgoesmzkkD9f2BBx14WR46+ODMKqqs8PDCL3e95l2rhgNh8PQ1Z9XyLrFE0e
XAKhEV+BMrveSC5qEIJ+FfHQFUDZArF3oyCyqjhneH+T1oTDOB7/ebTTOSzDDUEjhm030ZrJpmk7
zkcXLvn0zX3UWmutt1jJwveJ/KzRa/SbjQIFCzYolTh1Hw02wnDAyptHg1Zvo9/ir+Ha8yBYk6f8
4a+9F+fP6evZnRICeHsiaobdjfPWaquR7kazQR05X9yNQfisr7ox6K2+CNTXF8GzINuNwbN+4/x5
0g1FF9qpbgSt3mq2G63manNjcTdag9XBOrfSf0HCxSp/PX/ea/R62W6Ez+l/AXfjzrgvgHxau4fZ
ZpWlOOSsM1hIDsssjCl+nqr11LHAU0EwFE6i9qkM78wYzKinMkJVm0kvHP2lRE90TT1gp5Tmwaq0
OL2A2xDaWD/ifzyapIbKGPFIxfsgGj8nMjqfMF8P8T0messpLUcXuKoeR/PHHIBKHKmP0ANCcvZB
3qM/SErwuujhy/zD+6Jm/GahMfRuRUQM6slAfNM5pMTgJl3cuOOo8BZrRLNUNIu1dLiD6+hiFM7k
WoJvtFEC99yqMcuWgh14mjA9ZwceXHtzoJxn2fwKPH5E03jq3KTeHJ1yUjyP43Q0rOgdDRO9oyHR
O/BHdy0F4rUNommBaBoQzXtAvLRBtCwQLQOiVQDCHINIkJpyReELZ1pdjijFtlbKZqjDwUMsdzBQ
06YmsnKVxpFvJiClvi9Edy+5Z1NeLE+dlnVS3DaUU5kN5TYLZdOCclsAJYPBCiicUzJpvQSdYeOS
99NJ6quh5esvMMoRr61JkcFMH7YyhYFUSqMSJDEuYo29Tsg2qmK4OodRx2MhBch6CyF3qHhBm+kr
DN3Cq8sRC3iT6N3BxkMcxYDb5eBF+tu7wq4rEE91r56kYcHbUXbV6nqRKVHp1jLb6ynHhhjKljrS
EWJyZV/bZXnvvC4t+9Iuy5vkpSlrZe6JR2HxrrAw4hHmO5QQbBHSgwfMoYN6B46n2GOZwSV2TemO
WWq3lO6UL90lxrsti9SftVfYUCaJUZbfHv1yb8p8OKIv2kY2xhdEK0r2QVHooj8pjj6CKTTEUCAq
vKknMYuls+Cx5muAwHsSfopDZ/G3Ndx24aqa6MTpGlLB1JuNfI1nLV1jo4XAkbpGU2q08jVerOsa
DbhktXSNBtdoqABnj4RAhaN4ckX/INrflFNaTSW/O40EtjdxnoSx0jVBOvscUicYcVf1+SiCyR92
xh4Yt8yzzewzdiJrPW/kjKm571y0dxlHvdA7hbR65stoOHKVOHmv64FZsvhwTnway+AJ86blcur/
FQ0vouEtMcy1DTsjFtuAUZeEg7QCFvVuOFjaE3Y9F4OfF3LiP5UaF8GcxDW2lrZk4h62+aZUa0q1
jVZJvbWGzz4NtusoPI9X6xZvN9E91JPWei4GLGtwAnsuN63P4WPVFJgwu7ZTO4qBWeHkN9jkRf5P
OLl6ZkXOkd3dyax3vbHG2PpMbXEaIlGRifO9s6HcsuFvkkWjYkYoC1mCRa7ncKzefF61j7tHkgkJ
sd7hdIqESFEP0kLRare+9mq3vnC1U/XS85IaLknf8L/i9Vo9y88S37A34dOjdsuGEnV0pNhfF7Vv
sQRSTrkllNoysdQSrYM+8NWhLgMA0xMacS1cEMmpMPSaJ8eHOJpblnr+wgu6QkivvxqklyWQfL84
XG9Z6ClR4S0TaCp9T/j9EteE92tMlWZM6wisa8GqYwWbyjf/g9MS2qDUBA+XP/8v3/8gQ5tO/PW1
woB9fvyv1WZz4yH+1x++/jf9ixr09b/x+j9r5OJ/rT9rPtz//d75f7azeQqdfhiZzDtJxl7r0i+V
KMhvg92HDfAk+uWX2PkQnhNUj68BL2ez8Qr+0DF7TRxFKNlDjEQgka7HE2YxdJ6YurMP5uOxpIoP
p72wXtHGFB33m4//2H7dPXq7f7L7Zqe7vXvUrq3MrsZ3aRxm+9iKSs7TVJl50JH2ysqTT9wjfFP5
XZCmhVhwx90OrHTD3DOEFOOh6AFGGKDjWSNznR/+2vpO0o80AVCSj3S+8a7ez8KrMfVAd3/lH+pT
py67vsla0qwgC+Js4Dz+dvpu9Fj6/AP9M3Cdv/7VubqWrzT4wbeoelefT4a/IpeJvf+nwITfAMe+
IP8fiewP9P/3pv+8/jqgaC2I5rP4d1j/1nprI5v/bXX9wf7jj7X/eFOQ16WM7Ned14gcwfqeSRzP
oPoZOdM5HGxCqi/GH2nE4nzvUOeR3I9UTuxQNRmFs1RWKfjZcmSKYaScPMxp5FcZaulnSvX6HLti
EpL42guu5oNBAItC415yuOWMAhL1p7gQVWLu7uH1xj2QJ+FFNMWB1EdOtClfvKqDwbkKr+g0o0bo
aKAmafhXUY81lTGiD4xmUdFc0BsYmmAu4skoUDMClWEwDAsrwO7P+SR50PEFngSYzU+cbi/G5djw
MU/xFB5qPFwYMcxpkv0iiHTyjgNaRIcXZsoTRydwFLbFbDNUQxSfHO8aGj7CEPQA1wCxtAvQP+2c
HB10jza3d7d21OHPDoUhyl6HxCRgeJEGRYerDtgZSlNy0M44pzYbueozE2mE/j7nBGPIvC39nLBT
lvoh2NKPx3xdRAuBTlWpITx/zAnnCJ5MtzHguRjG5xItk2NEhITmM4TOnJ+rDOHKmgdp0ysVNbBO
Lg2yPW5c4LvKSOPI2Ja6rrs7dLTCgLNkUytD0TdhqjBmBV8ULTJjdZ3GRVlwqCJPnXGlYuyGO9SQ
m0pRSB04PkF+pIxNrK4CAyhOYkgFDw+Ii+q+2d3ZXVB6jPsG4lUKQtPzKwxtCuVv5HiDoBcPCUuj
60hDPzza2d55tbu/e3JvIzVCR5q7aBShwcrJ0ebx4cHRwnqsUqflRPnjnf1/bXa51QU1puHol6Cm
BlU5OTg62rJmkXaimck6/Zj0qNDewesuFaRi7spkLhn/TMa0UTyLiEMdxhdu5c3m1o9Ii7273X2F
vNgKMOqY8ldB7xKcatTnLr/mAHVuaRpOXBRkabLvVhI0PHUPN09+dM+4d4qot8WOnL65lQqHA9dG
PuxmFzGHj8SObdypwiXNUYQXcxk42/vHoAT0hONKSjIapqiC0TxVtDuICPZXaCvGw+uwXyfyP6j3
V168MJPDj6wQFQP3I4/47t3o9Eiqnb0bUWsd+dtsPas36H/N9ovG+io/O6D9crJ33BnF/PN4Z0u+
xtCuTTv/XX83StL6uHt7b/aPuMAbBEck/n8GuHigLHQeLUPIC0b575j2YDBcMMrU6P6HFKfRHRO2
BBdh5zoe0r4YhlZPrMPH8TD9/5lLhlPuDj1eo/WJp9FjXXI8jx9TgR7SrhKioKKf7mtvNlx6CejY
rUfj6w0ZEi1xnUhSANcUPIVpSbaMco4sKGfGVH4CJv2c98Nr2hTDcIq+NpK+8jO7s49NZ4/fvjz+
5/HJzptOx72O+mG8RiLe/AbB3A62dzouWEg3XWwaz9mz7287R/s7e/Rg3LvaerL9pJet9NjYWtFh
iYPGe9IjvKcDUrwhlKnV5DZvO2lOC+r7yENY1lk/ns861ovtnZ/23+7tQQULkKJ15Yg397inEKhw
MlkKlF+XDvXifsjheCWVwE0vHM+cg+OdySSe5Dov0ZGLfePZ3bEK0n4F09lOI95YW0sONF2wLXEE
wPip46kfXAcgrerssj1NNEWmH9CTJ8mbCr1P8majdPS59dE8vo7dhT4U3Hfj6NK7JAJaDEOPzpQl
bmgY9MLS0tJdFWwvJva0Ow27oxjUJJuKKoUt8DyxR4LlCvqeX4cUMptiqB4jeuZqh7o0H7HDSdL4
ooUFE60iKBKl6YJge8miHerABMwae3Xa2x/iyXtizaD7icEkIiVvqLm+4eNEqSNpHxV37Wm2Olb3
LsxhPY4Q1SUacDSJa9z9wtbQZkGzHM1HIkajU9xLCPL47bO7DEUoIK3bP24RZSTKujUEVdxVrYaT
Dh2tRAGII/6RlgQoJoQ/Z9TBV5Hg/+r44+mzX5N6NS8rT/QMub5/Z00rL0gyrZtpnjuZJi2EEFcz
6odpJZlHrIKPe8Q5sdRmXtC5Ppv8ylEO1SwTS92RqpO8yHTXtXAHCa5zPlFUl84FTcJZQZZKCadL
R1OMkmYFUPwMRvLeAmigsy6isDnrbDUJ69MQbIw3cf8njXez34c19WE8jHq3HdcQGSr3psCkRjcF
MPPzQhj1J99gSnLP5So5aWEwDC6mHW4nE5trGpY3zP8amuCe7tGUnb1jz0D9vaRlLpSxBdU4jylL
gJrV5KUFFnLNtiOcIdEfggVDfPTlLrV57jTpJmQz2zxFdpjV69BmJkGqD/KLuNKEgYzxhD4rvSER
DCCQq6897zkyTlMh9E5HyXbithAwCg6Q7jB2OeK9xinlbnfkDTINr3wc3a0QhhPZoT6caf/KXldt
DT2u89TduJLWiEF/H466cvO8oUZwzoGsHI//hTfCqx1EmWncNFrlufrMvnRZJwYnUtC0Psd1odO3
D9FcXXyrwbttVzYW0aabdqN1c+cmN/XnfjISCHyekISiRQI7x4a8GV7i1I3Yu7XWT+I9kPRyKT7D
NGVwemCobJAwxsV8l4g4UVo+RYH8N/IV5wy4kmVWGNyEuASqrad3MA7LgHDd8U4btRdBbdA++9h8
dudTN2QI6fD59Qs6UcZe02dmJeFUKjo04HkUdGl61MxAzOiZ4IDChKkJMEMPZ9mRs7f7B+0e8ln1
Atm2rjT8+fXnYy3pC+/UZWHRy2QIPuVtDLt+5xj57i/CUTgJSNjiczg5NdrIuJIRpomPkmyx2P+J
pJ7hGt3tYBZsk0DQow7cOivXgdCTmcQ+2IsvHJFQRe8CWEqczQI6jnvviYxNZk5KDGN3h8J3zfWc
E4h7QgQwD2St4exOIf+E20THQDHt3yieA0RiW74v7DixSZzvVTDGGT89GCkx0mlmXx0ThxLdhFOn
Ho9oiqtsX5Fr5qdoMiM6gy7tyzkKsQthqpsvWmh4pckTILzG22nIwho/2ryOo/52NH3/M7jOKfUg
SdsM3VaU8i5O7Xmbhk5oc06isecnnl7CK/LOSd6CnCIa36Q+VI9s7tF95Fp2YmV7PE/JBelgoGSz
AIpcWwoVX3awJwNLsNFHWET7oaXu0Wk9dBNjZvXcl5Oof0GYSNweBx5MDcO8lPbsSIUAY+IS8q92
PoH2qUtrJEB4RZAck3tnlEmwAjs17UCdVtiGkohYP1TlU1iovZj7qINZUQBWQ2ajx2bnEjo5XZ62
9i+BxN8sOhIyTJbarxCTsJzTjqvYBzfFed1D2EUkHM2vwkkkpH1Axx5J/UTbX8bxDFEix+Ow73jv
+k/9bzXzlKLqMJwSCKc1+GvgvBeAYmYow2PtOp2oXREIksDEhsBeKv6cySwOXDxQVFwFnbyK2ctd
sea20iwZ2SLhMquKKxYyrZXOVjA6YcVlXIY3HtzzZOWrTiNeI4nYsuhUY7uK5yM+MGq184j1D3nI
RwXDMs59Mu5F4qRajWB06xF9QOQXzz9d4/CdR0nFDD1xV8BdrEzD4WCF+xiNBrG7HNtnaQrUBY5e
UnsJEiVrwUynT8kkMiahGbr48ckT6CmrzpMnluhqforIdVcaXALadoKkBHkMl/ebqAnqHPjJ04aq
4wn8F5CemU7ND7QB2tClBX0EidaKNhgd0PoLE5i6k8KunYT8ZMrBFIm8BBn+IXe5qhqq4WICjoes
WlK5Y1M1RYPH2PMf/gtOxJJPS9R7fh4MTZSCFI6gq5OYNonemhi7iXDd6aqD+VTC2tSY+amNJAwM
c0R84vtWgmvMgkvzeU0Y6yqNsfNSrDiwf5yAsHEWL+gc3+NMZsv2rqyukoVrRhf9hfWNljddv4Ci
GQyeAn3TQphK+Ws43Gpaosn0ScnvplPDOOi798Mvqw6EiC5IGAC3mmkKuoSgf6Vj1k1iQbVaqtGi
0sRwICmflCZBReardoUgZJ20OraggChiFTcAOxfPLbholss8N3XggH7oEPe4vdMzYE5sSLQeKAcI
M/+wyEf6mdAQmyXLaPBARPw8tU2UcOoMtwjmKwK8H89eYYBFurivRxYStFXKd5nqkY5QWLp3TKJr
D+GhRJKREIfs4M9u6Bq9ivArR5LQ4MBNXwx8vL5LXQp0Gn+SnRsNluIkEpzXx3fxEZ1DjiKWRrFt
Ut889y2lr3D0IJ5Z7mehZvceksA3yx1L55BS7+FRJq9gikTh/QNlKqRMfIFVSpnY2qBcH2wrwOG/
BuZDtOkgUn4bx+QQId11s8bIoWqfPWFiwGKghU5G5e7llc9sSMHaegezllgVRFm5ZdFBlx+0WJ5k
bhcQiZ42C0QJdMCScxzvNug7tZoOPknj1pKDUdLCaygYkuzd+NbuJaSBfE9TnCljJJLiddhco44/
nK2l+VzEHpUpr+PUJDL9h0soQ+yy3zMAayYQaN2W0+y9xEpOgZmJRMY4hGuNu3ejR86WsIcyA+YO
HVxS26EiELIGw/n0MiORpHo8SjcMz9BGo1Ck59UxhxvGNh2GIXRwlWJeXln/2Li7hBWQIG+Cr95U
Lq1hexSNiDDTaw6Q7dcZ7Ct1zFUx7mohGmdxNrmYp63Elk2ooJ4x0P+IQRB1hGjFtWYelOVwqChF
BDsbNeltJ9M755INh2KVG+E8msYXIzYKMDZpyhSrXnSZ+X+FsPMrBIL7+LRyY7AiOrn5L5Vr+KOr
BEi3rUVJjl4K5o4eyReoZwEKZcSUy1X0Bk/km63IcxUi01v1LfWWzebo3ZDOu37Q1kMTmuLahFB5
RDG9J9kYJzSr0tNtwfjOAmcqQ0OXIhlqs94t4xxGuHVBaDCPiEMAdWkYhZ/cjRb5ih3TiontZZt3
IBtfZk386vV6wgvlQ1VijJbXGLdIKCoLVuqgVmzV+UmW7xNP+CeZqE9qvT7xSn7SK6X2iYbKmYSl
zVOrN2d6SZoP7mm/sf13Shb5Hey/m42NjfUH++8/1v/nPGAPIH1Cl9p6I2HzBNsYr+iYD5Henk5l
MH18W2VAuHxSD6NzEkVe7r06ZqvjGijKzv7J0ebJphh6a6eaITyMOa5x6BCjGsWPOSXhZRApw8SY
JFTimhH9BXYfjrKWo1P6XNL0sc02sZzT+Yj7LX5FbCinlHMTOPIMCU5sWA7TqbfHW7vUJ9vdCf1H
WSrHJnequzjoXs+DCfJHxxYDX+UOz6S/fTHbhmpM2RbF3znMS11Hv0Q2E+N4UjkmSSfmFMrb+8c+
9I6wmBPGA6dIKF0l/p5Obeenw/02G1sN+buDZZiE+kSO0G97KAra8cHeAa8bVxKAbw62N/do6I+d
V5v7J5vHbzaJj9OQiDk/eXtycqDUoFgoUYLWnV09q1ccxSLlKSZjvw5HbNaNtJJcgr3LmPWL0san
4PNo9fn6Tt4P2a6bhIW324dV2yhf2EK+mk/mzIeoxIH3CGfrzg46S7wZwj7x1EnPWVM7w1LUK1Ni
6mph5e0JIeNuB9ksausv6FM53nlzeLTTYYn9A4G4wEqvyPTWZFIqeqI6KXPrFTGmrlSoUgztnvPR
eeSsEV82JknX2aBzjl3LHoO3I9R7bB60d/cP354420cHh85po904s169Ojj6efNou/jlwdsTVNzc
2to5PMm9BV7Usk9rm460VqNZj53av1XtohJXwDBatKD3ngS23gyneejsEI/5cm/3+Med7erRzt7m
yc52Ggwd4Kfit9ah4Z9958wuQ5Fdsg2MSRIdE2g23HY2ntHXvnx9numZlu3yEKBkqkW9q3G6Rr7o
1BmEzxvt9kqzkbQsza2vbaRrDyJ7OtQ01+LyGdNF/o2NVfjmCydTvBFTcOIPI5KVajXiEGvy/RvB
Y9Tcf/X3tztvd+j1f+bhPKyRbO00XL0qNThBCoq7+ZVBM4w0i9r4C+bhejxCY0c7/2Nn68RNT9jW
wZs3u9T3O70TunqH5LZE26IrtDt/ux1S+O6P2h/25oBP5xfvikd0JvXo0IE3jauOOzgzuRJCXrvB
9GzdAx1Oc9wlsjG/1BGKvjzO7u7/RCcGDwrz+ni5rVJOFR45UfosyR0YbbaHT1RadFbMhzMttWs3
Idhosf2RgurRKfIe8jvCFvcQKtit0dwYxRvagckxvJM4HQ97+jLBD9AY8iVGI9ERpCmKHmU/MUpZ
WW1h5Wa9hKqwtUsZUSoHYRMmWLrcC6Jot5I8f2+9dFPAsyJIWq2udLgFdNJGQ0yrmnN2rzE8QcAq
SWy5n+lUZf5J7gVFwemIuwmOaLXsUtqvLBjwX7BJ4t77cFYT24p7ibMQrMdFtGoUzLKEKoOWJ8x1
ZlkXMc5KcDUhYgTRojZEco+oI7v7r8vOa9n+JS8XH/WHB8cni6Evhy9HOydvj/YX7ugFRTKH6qoU
3949ojmnx7O4hhdTxuoSALJ/prej8rprjcL1C8acvhBLlzrtNLOWPu/s1UYCwfEMmjDOqWOZd6ZO
L6JaSxbc4IIbBSX5rjwRHkRSUF6LcDoqcLoVcsUFhmlSDpTjsNDwzhK9juqdU0NYcmSPcWqv1OyW
FjDT/xe9yEUI4qrz3y07FfZ3fs6GzMyuZyFv8sf0K4+oZZ0zrKes8n1YsGDx7UES/iVL47R+WGHb
/jlJ3p8+OTOtvl+0niWViCLTZlDhLj4226LGuVNxL/iHCmUo+0XCXsDP1Jjtlg4T+5C+3Ttau9x9
G/HerWgDW25PLq5xb48HkcURH8kwJRmh0o0QzwHRMnRl7q5gMxD49402Nc7vct2ixWq1a2t37nei
51Tzaz0eRCaiyG+p/7vQ1KkGUft30P+tra4+W3vQ//3J4j8UabgWRICgGofmoBJPCcX2ZbRoxlTu
MuIsTjrog9wZy2F3Dc9x6HuyJ54EDhrA/wDnnzOyMpJAoxdM+Jq7z5ddQds5hOoNbGnsvGTtEPq5
Z2kaXVHsuBJFQIzsWamT3gUrshtROxvpQmn0Yiddw/8OGk11BR7iu5AJx03KgRhPI9fEIQgnk1Fc
df49jUcSjkB420xOkdkljEei0YUOSLB1sK0zM2dDErx+S4Lx7ub+QReFcM/XgO2KFTNgQQ1VyLgj
pQfo+pWjndcHezsLHOxl1hBd4GjneHFrXIKbgot8uqk65oGgvD56e3h4sBCMFJFsqmE4dKF0jqBf
IIZ9HloKUY5PGk+n0E8yNoz6Ia2TRycqHkHJDddqaFjdZF8QvM03b3aOj3cX9kKVWZR1zjYBS1Nd
wYp26Xs9qcrc122jUycnMsEbjbQ70zRkIw7eXskwJU91dnNJIA2tRa0cbr5VIDMwWa3gyn6SFNeT
wHW8WOneA727Ap+NZieR4nJRtNlACM75LEKa31qtRnVmuOR2Vgz/5bGRDjzCRAm0MhqoQl1mzOqX
PmpW9ndO9nb3/9alf1/t7p3sIChDs1XZf7W/1xXf764A7DirlTfHr7uHm1t/2zmpOvj+0w4t1Zb6
sXWw/2oX2SMk4G6rsvWKHr7Zrjr4crh5tPnmWL6/2Tz+m3x7tbf5+hgtcmhexPqtUI3uy939bTyl
TXn4T9Ui/W5VNtWP7o/bR1VnU3dA/zzc/OfeweY2vr7d3TZwOWbwRuUVHnZf84vGTeN5ZX/vTfdV
92iHBnhMg5CfBJ/fN5GfeQ1laGw7R0ccrgIT04W2hkqjKIuIMmJjxjPRmYGQ3aatsn2MWF3zNJNR
uihhUOfHH5ExaD6qcrIgGN1ICiLn3H3XcBGG11tzagzzW2fN5z/EqsIB0NkiyadtnGa6XUT+6HY9
2KhXxT4ots0f6HFdnsIuhr+kX07Z2xHksy7/eOrX5quuwhxNX+vHB1t/6x5t/kxTk8UpPwO1DkN+
z5PcQdl303AGiPHYNHZ8QLh4IGhnHnWPtn56+fYVYQ0S29txhwVO+B9Hu+2bhyqhfCeh/vU9gudl
6tK0EX/vJUhtmqVhv90/PtzZqspKGxRPLeFfXr7EGmpM1kmSLAz7ggYLiaDphN5e6X7sImHTOvJ8
WhupIJ8CPk8TYLwrc7AIlNlB98OQPb4QRGo+EqSVuRCUvZrS+TwIriLJ0Q7o0TnRPfFA7jQsZObw
BtYqpy26DE48BVlJR/+fjIESRSuYtNyo2rvFVyPlvuTcuYMstM7ujz/uStJ3RQK4UZoAL09nCZmf
w78WQ7833WqKglElzErVDBZYVzAL9Ip2n/T0qYzfmv/rcNInZi9WK8B2iwBJLOYolcMii7nmMCjZ
KxlqnUENTI9uRLUKF2rTLaMb5X5Z3XBdki6ns2g2j3AJEllaVCQ3nSASVtvxor69nOPgFmawVWce
9RMLzsSQEUZKGT/9rLuhlWFOTesk7F17zSw1yhshI8pGgZc8Cb1hnZlXWDTxl/rO/gHRuON2wjaQ
uDAepwc5jcIrWBZCiepItJDPy3MxCaJp+ikxHinqmcwM3jwFIn/fSQ6z/GDM+VV1uvL/ZFPMR1j0
7mASX1l7A4DAUU39opnBafc9NVucweOcqPn7omqcRo9m0zrFiyHQdJd1MLI7x2P3TxtnhVCwhAQI
1mbt0r2rrOUYFcTeT2n6PcWg+W3YvE9h1s7+iV6N/vHLLVsl8II12gVUJeHgijuotwhSq9CYT/WQ
i8eLPMFSotUonhChHvZ2oyocqwcZ/aqJd3z2o7CNQK8B1aQVwoLyeQ0Y5wKZhOKlZNZKraVfCgj2
i4Jva+2FFLgY7Yz3QIDUbmYiMZI2/gL2WfkouP9/BQe6OhgMFnZSr7fNFS/uMa9Hyezw8SydLkVw
g2qptpnpXtywwgBHpzVQ7SzdCDENixsQzPo14xpz3hxe+acOZ3X479WyXS7zGE3ZuhM4XN652ygc
9vVGKD6BcnUZ26kz6b4oWY/kQASuhHA9DDjtH9sMqwOBLf4TtRFEPOM/3zWFvKQj54mxeu0Hzgc0
iyHQxuoysauthExMjy6yec/Me/5FUqqyRsBs6AM1G7MpoS4di0vY3c9So+hymIo40niFpBJrGc+A
WGLdSF+Ga8Ct0xdnhv+IiJx2SSIfe+mmaMindJC0GsjQeH5KbbUtR//hwm5utJfow8b9fdhAy621
9prqxFoj1YdsEJ1sKBHts4/mtYGxt4GcOCp8wMgbrvl5AlYEh80jiCqy7iyzg2jziDS6dtpes7Lt
KDge+7EmPaHp2lAW3/P+GInZFXA9QdyI7Zbl7SKROx+FVecn2nuh+q66weefXxxThfE6GsX9sIuk
soGnVsPaYyn8TWGr8nrEGdNxTgfKl5vj5zCYuw33bDHGqpEW1WV/viKIKrVIdxJB3xmoo9C4M2A4
3KdFUS5UIBR2UxgkLnDQYg2hJ/X802Z7ucgVOYawLDUyF0aMA+0cn41MxTINEK5ZwPgU8p0gosg0
d9o8q0+MDg6hmjjVCgID/KWTWsFlAY84ZJ+C/uLMzzerY/p9bldbpV3tdFLolQds4j1Q2+mMeTY2
WD+Qq9gUVrWT19rdiKMbxV2+W1C7gGvp+BDhpAe4A1dwt336kV/fnSXh0cYRB0izglkJ6trenMpp
jIrWo2k/ugAK3INKOcRlBM82pbfJRwJ9tzJIuZAulLwSJw9sAHbwycJa+Tjo37m8NjwP5Ue0FYyD
6hYw1wv2UM6f9L4KpmCKlu3un+wcHR7tcKRdT+nKoYBXWnOVIvlSQlbxi3AibqDz81v8i3XFv/8m
CZDDgMz1P/+O4Az7MxEtho20Dqzap3831vQ3hAoGQyKen/LOembCb8HbjFCOJ8owDm/tmypXW2q7
RD3BkNi3AL24j9BJ0YjIHF+BicGPt7eNuwvwkfV6XTliOcpxdajuypDDlDNYJG1BM85uU3yVxAZs
EhCaxWGlMe9HDoecrBeyJfDZ5Ss1TVNTaKSuJniiz900ufVYIWtHLEm6S4fKJBMvJA0YVhXzqWti
EiURe04mAeHrYdRv6whE9wQTsfxPR7fetQ2MupjMbIfTqNPvzbfbuycd1xcPK9DuazOijiZsyGjV
SJzd9TTlD2MXWazNygbEZ86J42k7ScNnpoP2FKFt6zfxeib0SvOMg9413JLGFmPFWSomJs2OZP0O
lROhppppFAbvi3S416G5qb2IhybMfaAuHvnWRwczxZ2sadXX2AU5JNdYF94VCXXh1L4kPqRFhyx7
Ft7gqrOT2XX24Ly+5I/mksRfSSpo86slIYUEDrMr/ZLJSPpXEB4nvFHBL0toLb13/c+KhcedCuvh
qK+QHleGw3AW9n37CJCG6e9pu9ZUolt6804uYrEqpA0XMLYGJRuud4Wuh9md3A8R4tfLB4JSBz12
OG+txVsx1REpmokZip8cSImGY5CAy1B/mTgjfAEn3VmBmRGGbYUrIDSDA7VuBsuOXplmeXWpSm7D
AGCbw3IRiCr/TaJlvnvHl8WYDjVeCZeJaFQIzOR4KlkRohKiqopOexV21fAk+qZEYHAbzdbq2vrG
s+cv6nbwKV2aBpWcc2kv3DFkjxEhqudZy5gMtymxzdh1PUUtay4uEtx05FWBWCj7AKUwMMyIFKvm
l0hecISrbOlKGlaVJ4ALavlcmRxB8pZLOTF+KrmWyyrUlQdSx/l4l74vVsSJ6JQcsLNZ5DorxBXw
DbKbhhIz3UiDyEDxEjCihvNNwACT8MHT0BGnkfgAXAAs5vCS407MGgr4uQkLEhpl3o3cQoWv+27G
u2BixenLhOcrZsSmvRBmL3qkidACiLkgsimkQUUJ7GJNjZ4Cv5x/tBbuVJpFwFSBtzxPaPADVvYc
6kJdwQjINDuuRod4IWq9M/ddahb0sulbCiqou1jJjV8VVecS6FE6oIMuUSreZIYsAxqWt6yrJfPH
NiBqwMmMTIPhdZDdLksHD2BkvYKuWpnaJEHI07eHjLdUsjAYuh0Q3X3kWBaNRTZebUej0Irgj/P9
yebLHxJ2IYf32D3WqkqIYWtmCvBPd2fgfixAwbt3s4/y9S7VmAnhziOVOPT2S3048Gu1izVti4aJ
gZZF4cwMlNoe0CGbuzvEM+Qqpn/SLxQF7ahJzl7PF9ziHxVd48NRfhosJKUf3ajvtp0R5Cl9o0a/
T0kIOUNgJ0RAQMY5FSnagBbTuDBvYSBmR0qxk2ozHsGwhwNlgF3OWirB8oepsIX1Ep1CT+AI5mwX
F1DfLgqDioJ8w4tIlB6s4Or9+dV46um6OtQmcV/M+vj+vbFPlgh/qqKgZK9rM9fIJTewFmkbDbCy
5epqVS913HOlHDedwrO6udZWPTHmO36yRrtbb+CawuJEm2VLNmyzXJmDRGLJZm3maahkNMNjrXw0
KnNRELF+apAY2zA/bqsD05qsRTpOo95Ums1KVtWVOWr4nmSB5ih7LFCFgotv1d9iocrugpQsXBwN
hOgX+1VPe4h90cZNzkf6I2rURNa3yjieMoPlcuBN3f+yBXHe3yK6WeKa6u6SFiN9fWQqo9XkVNbH
U2aiCqZpCfQTURAhTBKuTmJ7i6GZX3LWZlvPMARC+0p6JC/1OXFqkb4znZxbDDCWbNumfIUrfe9c
8EhNpnQVfIBjDiTmlu3EqHKJbqXIdM7op2AaOJYOnwZ21ezBwF1OjoaEPbpLI4+YTjNM9T0PWBp2
2wZfXSAsjiPG2wT13bZB4lKTINdcz1FpTW1cVkpLFB8QBwGq7vf4cTyL77LLCWZb+InkAFLLW9Uj
88sW+DKa96OulPasw0ytY5SyRawqjnFpMy7D1Iuo+J65pvdVUVFZi6pDPXGcvlMsKwfzVdZbSt4p
20JlGFyAZdeaSKhmx/G4kDzovW3EgrSY0VX289WECnRjE9QnL6PY5ELXLVkQRb1y0klCbr5LF2RW
O5vVI9207MMvbVjJU5/fbGpqFrdqCRuiT8+IuvmkJc79n0dm5GyqnbfU/qwuGck6HWCP7cXzkoEy
OBgBmy1y/cVHjkHI9Flj8Z4s6oVZoavUPC4XHW+5DZ2XfE6X2tT2pNUwKURgz5wfHGXC/9RZPysx
cLIns2Tr3jPFy59oldJqX4QUZnXSVDa7RAsnPH9cl5uwlN68WRBS4fF+1aVZsQyV2wk5rLiG2QDC
+tk7VfMQmn1wEPHIcBBRZSFaXC+BAJ+5+HaHe8MwmNhnY8DcbNSLLVkvbeF6LOEirxHfMyc5hk7W
rYWDBDBTj4g+nFFOXRwj2sPQQL6YzMfj2GEnH5o/7aFj5XEUb2pIVzFfuHi1XZPjl17MhxyrYPhY
+HG/aknDUCUhbhXiXuoLvzB704dYlVyy4HIPzkVD6xYwZacrl7+lblAHP21mNXZFgu04Egm0SpPU
z1u/rOLAYIH6YkmnhMOdnaOto53tqtNs+Qt0pfZ9wfKXFYXXjp93Q/P1rz1/06vPz9I+FORe09kr
cOliLKVMWtck/Zv2EKNevcvtd6TkoqqFNzmp/uvLen+5TuLm1SACFKyraMq69OBr0HO3tusW9yop
2jorvckyESjFnW65ri15k7y3+/Jo8wieJSc/FlwvL7o9Lm1dPTyP46Fn4ZV/z4Vxhy+MLQ4GHqXF
BNWWcRLamylkdGnqgPsuy/+HXXNQZQcg2WbOLXKVIwBljJTlVsCts1PBxvr66kbhNQnGgeKfYxcv
/XsqhsmVYsPrc06Th/sXFC6GPokugqoZLf+bUIhR+V1LKVuhs6Sx0hJavimyAwXFUBRVSIwGy2GW
Oj7ogPZyfvSiIBZ7IVf5FJeDvJ+r/VKmaymx+t4KBjWBRN/ZuJo6/3LilqtlGV78q3uYXyPUw3Tq
6jSpDKtWOks9NbMixJmciIUt60WQCMtqHZSX7tdah3AInXeSwTEvqGoZw7/nsk80I6KU/2i6qRq4
+9xh0puraBR8tXEWjAvijbUiSvfkF+pC7pFYvhqsIqH/vqlmkzKaaaCxNc9LWdypqPbBcHibE4r0
DslP7HJTn9/i6PF9wuOCbV2cStU+kSwBYtpDrIesJJgjtEnmFQ4UkJu+BdlXchO5yDX47f7uP9J+
wccnRzubVrJY5QKc6Uauwyqkw8VknB1H7zL+MJL67J1JRYCNF2D3PIlf4NcvJt0L+z5CW53/LbxV
duYIbRHxtdxOxtQ8N2Bzb6objTc2bK9jNmoljm7dv1dbIsjMLnF1RG4bZ02qk5vNE/7mESNGo+uo
a17ibKpg/qYd2Rc+vJrCq3hkspMS3+YZm81olCSMY6U03MQ9xLKQVmFZZK5wPb6qrSzqxUVdIVxJ
s4vratXSgso660Nh9BSJD+twP52PGMUdEQbw0hdpmuffKVscvyAthBH4yy4lcf6xfJ94ni7aWhf1
5LZy8WVnFht3+B/CQPELtbUYCC45pLmOEJEF4WCMk48IzYWKx5R/IezUw3LXwcUKjPui7AtmPQSS
L4r/dD0eSSz/r9fGPfHfV9fWnmXiP7XWN5oP8Z/+yPhPm4QCAdQsQsAQuLM8+lMuKhIMRZCCoqqj
gNJ59CGe9AkwwsDAGsfW4EGZFhDZmahYwByNFeYm4CQQ9tsgpTpYA87SQwQTmaRsNY5kc6Szy0QZ
dVgXxxxbBpTKVeF8UslG8AX5KjLFpnN6cRHN0/yMN5RcN9HQMSGgqI7OnYLAQ1tJeHYTlz0VXV5r
H00kIoSvpTlIh2nXeaEkYjvOoKoJVyWza6JoRaPrkEOfG6Nv9A/RtzgjWJLcfPfQRJ1CoCkYhydJ
xznQVGVRlCjqSj4+lImW7voVBANZEBgKEyXpKlW89QVlU6HXUWHrxx0OeAUobiXp2qkLZY7LV3Ua
pyWMEuiaC0swG7mu416kY/q3tWb4kKbt7XjlcBJuE5fmeLwqOoUQ1LoXNMhJeH6O6TT4rqNCYRgf
xS5/F0sygBqrTby/JMYM34e39NM9lF/Ey7lW+nF6sWkykbv9ET/Z3j/Gr6vZHL/enLwtjCnlCgOH
5USxPf7FubTvpLh7GIYT6cn8fBj1dEf4h+oHtO6XhDF900v1W/dzOIw/hP1oLF2VX7uH01wibdpT
Y1pD7sqO/i4XxKycH83eh+E4GEZsQsCJI+Tx38xj6vZdZevH3c2fdiRBMYK70a72Ju7pZu1fQe2X
Ru3F05Wzj2utu9PNnd03f3/7z97F+3j6obH2/KxDWPLT5t7B0cLKnXq1/e703VnXqZ19bFZXG407
7Sw0ntOE9iJP0h4LyzANOQ50VTwMYZwTTkxEgNOzqrKnI3mIlUrTcGale2KF8izRMyl/R8vNwDb3
fSSW7NASSn7ArP7vPm/IK5XVeT4ccnI7GjmNdPrEe/fhqU//vjujFiYpsFdZ8zPJjKXtFaZJmj+N
6pAb60CCice6AJKpJ/Ect6j6aZm5ggZebq+AsB6Wggx2VqpOYksVOKcfkzbvztzSdsAAJvuRtbH2
b9ybRYW6wlw/3F4klnUIJifgI+fUwMr2gXHkaSfVEd6JaVMMNF4nMuCpcn7eb1ZbNw3cd6PTj6pc
bsw5RMhPNvtqdFytWs9eSuQGrI9T2BSGjzng4iCW8IvmhLV6IQZAJoCEd5NKaX/DTWo0F4etdF2q
o/DrVHX8jE8cvDNold4OVyWIpCdjCfsIEliE8JNYLZS/6pwgPmy9XkfiO5LvbIWz2oVCYqxdpkI1
3DOlA1dNj3IBjPox80QfMZQ7t2B0uPhJnxkpwp0i1L7xOhDy+QXdUxYNpnuB40nffKtzCdLileVg
n8ZWqYhjUVq/s5KGjkIwG8EkimWIyZasZs9I62Dk/ZOdAvuYsU6mzM1J0p7C/oJtXzAfdPj3SF5P
qt+19XaYj7LMJs6aYYiUcSlXvkfpyPeOp9hYomLgpjWv6ePuQqychQ/i6SSCavmcqPdyUum0fk96
qZzB5ZniEy6vPpmPvB603f14PutYL7Z3ftp/u7fHxwIYYLG0wUF3j86fQIWTyVKgcDOLDvW0S/sX
JJ+fmnyV6r1JchhxknLoC8XtmFMjC+Oo5kk0CgxKlKNdzoXRpaXwRE+TeFjuBVbWpXQoaO+aOCIn
nTIN9ggRSnfK+H0Zq6RkUjmVFK//nXM9FyvrfP4nY0XAzu9wq+Nto6NfY6QmrnVRRmNxo3Nr+yhJ
bbmpqSgr/UqXThEmmaIswU3X3EzacWucoZcjtkv6XRPAHT+T9EslIVPdv3Ct2FpFt/ZvPFMZaNRS
TucaIxSN1kKFpIfwIJb4tm8iK5z2ZGHVnta5iQPc+3yXv+m17ugVVBFhLLg5jEqm2M5iG3gJtTao
++Gi9p85cegY3HxsBrwo362pqzJn6+zgo2lMYt9sOLWnbRSn1t2R9CskZ1iCvrA4dhqO4tS/JBRb
853ekqmO2YPq07InwyrJKSyS+VddzLYKLj3thRfDSOsJCpdYMqnyqhakUl2wuvdlWbUUBPndd2+C
c7u2Xz7rWXOh/MQgDR7PMHLhSlLri7iaqBEkErDoFpKtL0oSryyFsH5dcPYktzdqq1SWu7oxtxjF
U6PSzAtBGTGNXzzDjK/FayjnZjE2qrPaDE3ZDSA7KYKBjMTIyDJ1SA2e/fXguZISKlOxhOz4QW9H
Ec5EudTJBFyUlQwLUbbQp/CKIHUa8bNGo9C/UHwLWVeT8Swc9EUjkzgW0o+D7s9HB/t7/3Q+ya+t
o53NE/3j5Ojt/hbfLTXU3ZJ4Jk7rg76YUvULvRO1KyA37leKXPl4o+fwfRE3z4aDUrJNLCmnrGTn
NSPOoLXEmhB48R2fHsUYwGpBvf5qP404dERyViyiUiq2lNJh2cOw8wwH9+RLVnjotjVGVp0lcyjr
vMf8L35DnTSd0zcaOn2lv1+Wmnj5XMSJPvU3SUOcUxB/KsxEPJ1/wogfcg4X3/9AjFz5+m0svv8p
+N5sNpD/Y/3h/ucPWH+VGAgXu9OVP2j9V9dX1x/W/0+w/rN4cj6JPxBLVVeJVr5w/TfW1krXf20t
m//n2epa6+H+93e5/y2/1nVGsJaBD8oQOXnkYjFBiNowmCNx3aTNauGrcDR3eo/DxxXFf7lI5vhS
yrqORxVrGVTyJWU2X8KpJHiiCcnnwaucbqs8Pzsklt6eVU5ux2FnM0HVyj4xLh2rScfjWDB+Zecm
7HUy6VSszjjfziu7NMxOMrLKfrwdTYkDve1wVrX/h/c/gjD9ip2/1P5v0tvM/t9obDzk//rD9/94
Ah0B57BHWmFs/yTV7s8Iz4V3fcT1j50eIQ1sJeYjGHkYXygVhgs2GAHiQ6kwUaAYk7AXIfGQl9mc
wDl/yQ1/aPSruiEE/qLqW/EVtKZUYxKlE5LpglYXCmkEuuGw8sVZmY+iG+fbgRAKvKicwP5yFAw7
A5bBMxTjTXQVcoetzbRyU7ua1vrxtBZSa3NW1H6XfR/lntSmlyTPUPncG2jSYJ2XenE96tevot4k
nsaDWZ1FIWrHbrJyjDHNx/vxLBr8P0DhHj6fR//1kfv1BMHP5/9bG2vNB/7/D17/XjD9OkjwJfLf
euNh/f8M6w+n0UtESYLe9Lfh/xob61n5b6PVXH3g/34f/u+t2KAmGcfL+MG2M5vDhF9Fq4a4NgjA
EkpaD77Jhu9deBVPIhjbEvs0Diac3QrWg0ofzdkm686uSf3K4p+ApjYhwnl5AZBkxeHjeAKw/dC+
Vw8fa6aUmLTrcDJFVG3v7ckWrIojY7wJbyyEDWGzFtx3cYyFXjyBLykSu+4mqWTBq+Imny/HIOFe
saGG3JpNp7GIlkFNl1eXaeqC0ZZf/XolvGEzW3E0TrOY7W/YYlUXOflXh7qtf/24e4wkhDsdk+W7
8ofsf7njWPl96f9649nqA/3/U9B/tf7n4Yi2zXwW19iR8avS/9z3FnGAaw/0//db/9/q5ucL93/j
GYo/7P/fef2//s3PF8t/a2sP9P+PXf8e2LIBwg3UxNv7y9XA99H/1dZq9v5nbfXB/+93+SynZt1i
DABrm6CFUbFuRYNJYJLVSCF6D5Z8KyldpGJNgKnIcKJgFSuvGpV7XyO+PQxHWXXrVjALL0jKCKed
t7OIWO3b747D3nyCLw/KzK+8/3/r+5/GarOVlf+bGw/8359p/+d3/Z61zXugADCxhWXpWGXMGkKo
t1x/FxMA2fm9y2B0EU6Rv4ukjdnDtv/j9r8WA3/17l/m/M/6/69vrD7Yf/yJ9v8bUWj9n/+dGGRo
OnBSpBOMYe6tLTtEqdc2oU2vkduOkwGHUSFVMG0wTTC/yonBfjgjEvP+gRh8xf2fDc36G9p/rbay
9h/PWhsP+v8/0f5PkgapYEZm++9aqnhiBOaRc0n7X2fSdGKT+8C4lxRu+Sy2KUFA7efaZXRxuWD/
H7PA8LD9v+b+L7DX+63O/41m9vzfAEvwsP//NPvfsqusvA5H4STq8XNta0kbdxRdxYYq7AfX0QWH
nxklF33iUDag2QYHkMSmscPSfIm15v18wc/hueqpRSOMjdYsvJmtXM6uhmkLKzx5ekNPb2q4BLwK
aySc9IfhhMrOxsVPpykQ4/6g0NpKPfr5zRaSkKUm98+z/+FJ9+tZ/yXl/6z+d21j9eH8/xPtf7gA
J3ubrcKjou1ruaGpmFpx4iSnfYmLtjhhm+zrkWzZGh48MPy/7/6Pel/54sfa/5/r//Xswf7rD1r/
fjgI5sPZyh+5/q315trD+v+x6090Pbypz8Dj/Mbnf3OjmTv/19Yfzv/f5fzHqeucYJXP5KzflvU3
5/3hfATf6QmM7ohvHyA9bmRbCQ4HUzEPZCUgR7pxOAfPTzAfrOyOLklemE078vPhyH34PHwePg+f
h8/D5+Hz8Hn4PHwePg+fh8/D5+Hz8Hn4PHwePg+fh8/D5+Hz8PlNP/8//D3M6QAIBwA=
