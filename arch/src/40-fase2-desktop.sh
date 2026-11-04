# --- Fase 2: desktop Vetro con l'aspetto di GNOME ---------------------------------------
PKG_FASE2=(hyprland quickshell greetd xdg-desktop-portal-hyprland pipewire wireplumber
           pipewire-pulse adwaita-fonts adwaita-icon-theme gnome-themes-extra grim slurp
           swayidle swaylock libnotify jq git cmake ninja meson cpio base-devel)
FILE_DESKTOP="etc/xdg/hypr usr/local/lib/vetro etc/gtk-3.0 etc/gtk-4.0
              usr/local/bin/avvia-desktop usr/local/bin/avvio-vetro usr/local/bin/avvia-pannelli
              usr/local/bin/blocca-schermo usr/local/bin/sfondo-desktop usr/local/bin/schermata
              usr/local/bin/oversica-config usr/local/bin/oversica-avatar usr/share/oversica
              usr/local/sbin/oversica-avatar-pubblica etc/sudoers.d/40-oversica-avatar
              usr/local/bin/vetro-barre-aggiorna etc/pam.d/vetro-blocco
              etc/pacman.d/hooks/vetro-barre.hook usr/share/icons/default/index.theme
              usr/share/fonts/dm-sans usr/share/icons/hicolor/scalable/apps/vetro.svg etc/xdg/vetro
              usr/share/backgrounds"
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
    # l'interfaccia di oversicaOS: Caelestia con i ritocchi (45-caelestia.sh)
    compila_caelestia
    installa_font_icone
    # i pannelli di Vetro di prima: li sostituisce Caelestia (resta la schermata di accesso)
    local vecchio
    for vecchio in "$(percorso /etc/xdg/quickshell/vetro)"/*; do
        [ -e "$vecchio" ] || continue
        case "${vecchio##*/}" in accesso.qml|AccessoVista.qml|PasswordPillola.qml) ;; *) rm -rf "$vecchio" ;; esac
    done
    for p in $FILE_DESKTOP; do
        if [ -d "$VETRO_FILE/$p" ]; then installa_cartella "$p"; else installa_file "$p"; fi
    done
    # l'avatar pubblico (Impostazioni > Account): sudo senza password solo per l'aiutante
    esegui visudo -cf "$(percorso /etc/sudoers.d/40-oversica-avatar)"
    # i caratteri nuovi (DM Sans) si vedono subito
    esegui fc-cache -f
    # puntatori (freccia bianca col bordo nero spesso), disegnati con Python; gli sfondi
    # sono gia' pronti in usr/share/backgrounds
    esegui python3 -I "$(percorso /usr/local/lib/vetro/disegna-cursori)" "$(percorso /usr/share/icons/Vetro)"
    # barre del titolo: file vuoto finche' il plugin non c'e', poi il plugin. I vecchi
    # file .conf (Hyprland fino a 0.56) non servono piu'
    rm -f "$(percorso /etc/xdg/hypr/vetro.conf)" "$(percorso /etc/xdg/hypr/vetro-impostazioni.conf)" \
          "$(percorso /etc/xdg/hypr/vetro-barre.conf)"
    p=$(percorso /etc/xdg/hypr/vetro-barre.lua)
    [ -f "$p" ] || echo "-- Barre del titolo: vuoto finche' il plugin hyprbars non c'e'" > "$p"
    esegui "$(percorso /usr/local/bin/vetro-barre-aggiorna)"
    esegui systemctl --global enable pipewire.socket wireplumber.service pipewire-pulse.socket
    ok "Desktop di oversicaOS (Caelestia)"
}

# --- la schermata di accesso: greetd apre il blocco di Caelestia (accesso.qml) in un
# Hyprland tutto suo; la password la controlla greetd (AccessoGreetd.qml) ----------------
FASE2+=("accesso|f2_accesso|etc/greetd/config.toml etc/vetro/accesso-hyprland.lua etc/vetro/accesso")

f2_accesso() {
    installa_pacchetti greetd
    installa_file etc/greetd/config.toml etc/vetro/accesso-hyprland.lua
    # le scelte di Caelestia per la schermata di accesso (italiano, sfondo dietro il blocco)
    installa_cartella etc/vetro/accesso
    rm -f "$(percorso /etc/vetro/accesso-hyprland.conf)"
    # la vecchia schermata di Vetro: ora e' il blocco di Caelestia (accesso.qml di Caelestia)
    rm -rf "$(percorso /etc/xdg/quickshell/vetro)"
    # l'utente "greeter" (lo crea il pacchetto greetd) deve poter usare la scheda video
    esegui usermod -aG video greeter
    esegui systemctl enable greetd.service
    # greetd usa la prima console: il login di testo li' non serve piu'
    esegui systemctl disable getty@tty1.service
    ok "Schermata di accesso (greetd)"
}


# --- i nomi dei siti (DNS): li chiede systemd-resolved (Quad9 cifrato, o Tor in modalita'
# fantasma). La rete vera e propria (NetworkManager) arriva all'ultimo passo.
FASE2+=("nomi|f2_nomi|")

f2_nomi() {
    esegui systemctl enable systemd-resolved.service
    # lo si accende subito, se no lo script resterebbe senza DNS per il resto
    # dell'installazione
    if esegui systemctl start systemd-resolved.service; then
        mkdir -p "$(percorso /etc)"
        ln -sfn /run/systemd/resolve/stub-resolv.conf "$(percorso /etc/resolv.conf)"
    else
        avviso "systemd-resolved non parte: lascio /etc/resolv.conf com'e'"
    fi
    ok "Nomi dei siti con systemd-resolved"
}
