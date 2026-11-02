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
