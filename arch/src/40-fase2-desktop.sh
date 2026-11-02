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
