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

f2_desktop() {
    local senza=() p s
    for p in "${PKG_FASE2[@]}"; do [ "$p" = quickshell ] || senza+=("$p"); done
    installa_pacchetti "${senza[@]}"
    installa_quickshell
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
