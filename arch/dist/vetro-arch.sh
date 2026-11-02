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
FASE2+=("rete|f2_rete|etc/systemd/network/20-cavo.network etc/systemd/network/25-wifi.network etc/iwd/main.conf usr/local/bin/vetro-wifi")

f2_rete() {
    installa_pacchetti iwd
    installa_file etc/systemd/network/20-cavo.network etc/systemd/network/25-wifi.network \
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
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
NZCscwAIBwA=
