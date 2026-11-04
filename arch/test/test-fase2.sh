#!/bin/bash
# Prove della fase 2, desktop con aspetto GNOME (Task 5)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
BARRE="$F/usr/local/bin/vetro-barre-aggiorna"
QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}

toml_prova() {
    cat > "$1" <<'FINE'
commit_pins = [
    ["0002f148c9a4fe421a9d33c0faa5528cdc411e62", "6acc0738f298f5efe40a99db2c12449112d65633"], # 0.54.0
    ["521ece463c4a9d3d128670688a34756805a4328f", "6acc0738f298f5efe40a99db2c12449112d65633"], # 0.54.3
]
FINE
}

test_conf_hyprland() {
    # Hyprland 0.57 legge solo Lua: i vecchi .conf non ci sono piu'
    # (il controllo completo dei file Lua e' in python/test_lua.py)
    non_esiste "$F/etc/xdg/hypr/vetro.conf"
    non_esiste "$F/etc/xdg/hypr/vetro-impostazioni.conf"
    non_contiene "$F/etc/xdg/hypr/vetro.lua" "vetro-accesso"
    contiene "$F/etc/xdg/hypr/vetro.lua" 'hl.env("XCURSOR_THEME", "Vetro")'
    contiene "$F/etc/xdg/hypr/vetro.lua" '"/vetro-schermo.lua"'
    # finestre chiare come nel video: angoli 18, niente bordo colorato
    contiene "$F/etc/xdg/hypr/vetro.lua" "rounding = 18"
    contiene "$F/etc/xdg/hypr/vetro.lua" "border_size = 0"
    # le impostazioni di partenza (copiate nella casa al primo accesso) dicono lo stesso
    contiene "$F/etc/xdg/hypr/vetro-impostazioni.lua" "rounding = 18"
    # barre del titolo chiare, titolo DM Sans, tasti senza cerchio con simboli scuri
    contiene "$BARRE" 'bar_color = "rgba(1f201cff)"'
    contiene "$BARRE" 'col = { text = "rgba(eeece4ff)" }'
    contiene "$BARRE" 'bar_text_font = "DM Sans"'
    contiene "$BARRE" 'pulsante("■", ingrandisci)'
    contiene "$BARRE" 'inactive_button_color = "rgba(00000000)"'
}

test_barre_versione() {
    radice_finta
    toml_prova "$RADICE/hyprpm.toml"
    uguale "6acc0738f298f5efe40a99db2c12449112d65633" "$(bash "$BARRE" --commit-per 0.54.3 "$RADICE/hyprpm.toml")" "trova il commit per 0.54.3"
    local c; c=$(bash "$BARRE" --commit-per 0.99.0 "$RADICE/hyprpm.toml"); local rc=$?
    uguale "1:" "$rc:$c" "per 0.99.0 niente commit ed esce con 1"
    finto_con pacman <<'FINE'
echo "hyprland 0.99.0-1"
FINE
    # curl finto che non scarica niente (e ricorda cosa gli si chiede)
    finto_con curl <<'FINE'
exit 22
FINE
    PATH="$RADICE/.finti:$PATH" VETRO_HYPRPM_TOML="$RADICE/hyprpm.toml" bash "$BARRE" >/dev/null 2>&1
    uguale "0" "$?" "senza plugin non e' un errore"
    uguale "0" "$(grep -vc '^--' "$RADICE/etc/xdg/hypr/vetro-barre.lua")" "vetro-barre.lua con solo commenti Lua"
    # una versione nuova, che gli autori non hanno ancora segnato: come hyprpm prende
    # l'ultima versione del plugin
    chiamato "hyprland-plugins/archive/refs/heads/main.tar.gz"
    finto_con pacman <<'FINE'
echo "hyprland 0.54.3-2"
FINE
    : > "$RADICE/.chiamate"
    PATH="$RADICE/.finti:$PATH" VETRO_HYPRPM_TOML="$RADICE/hyprpm.toml" bash "$BARRE" >/dev/null 2>&1
    chiamato "hyprland-plugins/archive/6acc0738f298f5efe40a99db2c12449112d65633.tar.gz"
    non_chiamato "refs/heads/main"
}

test_blocco_pam() {
    contiene "$F/etc/pam.d/vetro-blocco" "auth include system-auth"
    contiene "$F/etc/pam.d/vetro-blocco" "account include system-auth"
}

test_aspetto_gnome() {
    local g
    for g in gtk-3.0 gtk-4.0; do
        contiene "$F/etc/$g/settings.ini" "gtk-theme-name=Adwaita"
        contiene "$F/etc/$g/settings.ini" "gtk-application-prefer-dark-theme=1"
        contiene "$F/etc/$g/settings.ini" "gtk-cursor-theme-name=Vetro"
        contiene "$F/etc/$g/settings.ini" "gtk-font-name=DM Sans 11"
    done
}

test_niente_lfs() {
    non_contiene "$F/usr/local/bin/avvia-desktop" "labwc"
    contiene "$F/usr/local/bin/avvia-desktop" "exec Hyprland -c /etc/xdg/hypr/vetro.lua"
    non_contiene "$F/usr/local/bin/avvia-pannelli" "xfce4-panel"
    non_contiene "$F/usr/local/bin/avvio-vetro" "submap"
}

# curl finto che scrive "carattere" nel file chiesto con -o
curl_carattere() {
    finto_con curl <<'FINE'
while [ $# -gt 0 ]; do [ "$1" = -o ] && { printf carattere > "$2"; shift; }; shift; done
FINE
}

test_font_icone() {
    radice_finta; finto fc-cache; curl_carattere
    FONT_ICONE_SHA256=$(printf carattere | sha256sum | cut -d' ' -f1)
    installa_font_icone >/dev/null
    esiste "$RADICE/usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf"
    chiamato "curl "
    chiamato "fc-cache"
    case "$FONT_ICONE_URL" in
        */10ecc14790612ca8fd164e3f4ffe9c16fc50d5b7/*) ok_prova "indirizzo con la versione fissa" ;;
        *) fallita "indirizzo senza la versione fissa: $FONT_ICONE_URL" ;;
    esac
}

test_font_icone_sbagliato() {
    radice_finta; finto fc-cache; curl_carattere
    FONT_ICONE_SHA256=0000000000000000000000000000000000000000000000000000000000000000
    local msg; msg=$( (installa_font_icone) 2>&1 ); local rc=$?
    uguale "1" "$rc" "con il file sbagliato si ferma"
    case "$msg" in *controllo*) ok_prova "dice che il controllo non passa" ;; *) fallita "dice che il controllo non passa: $msg" ;; esac
    non_esiste "$RADICE/usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf"
}

test_f2_desktop() {
    radice_finta; finto pacman; finto systemctl; finto python3; finto vetro-barre-aggiorna; compilazione_finta_base
    finto fc-cache; curl_carattere
    FONT_ICONE_SHA256=$(printf carattere | sha256sum | cut -d' ' -f1)
    f2_desktop >/dev/null
    esiste "$RADICE/etc/xdg/quickshell/vetro/accesso.qml"
    esiste "$RADICE/etc/xdg/hypr/vetro.lua"
    esiste "$RADICE/etc/xdg/hypr/vetro-barre.lua"
    esiste "$RADICE/etc/pacman.d/hooks/vetro-barre.hook"
    esiste "$RADICE/usr/local/bin/avvia-desktop"
    chiamato "python3 -I $RADICE/usr/local/lib/vetro/disegna-cursori $RADICE/usr/share/icons/Vetro"
    chiamato "vetro-barre-aggiorna"
    chiamato "systemctl --global enable pipewire.socket wireplumber.service pipewire-pulse.socket"
    chiamato "compila_caelestia"
    esiste "$RADICE/usr/local/bin/oversica-config"
    esiste "$RADICE/usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf"
}

test_pannelli_vecchi_tolti() {
    radice_finta; finto pacman; finto systemctl; finto python3; finto vetro-barre-aggiorna
    finto fc-cache; curl_carattere; compilazione_finta_base
    FONT_ICONE_SHA256=$(printf carattere | sha256sum | cut -d' ' -f1)
    mkdir -p "$RADICE/etc/xdg/quickshell/vetro"
    echo vecchio > "$RADICE/etc/xdg/quickshell/vetro/Barra.qml"
    echo vecchio > "$RADICE/etc/xdg/quickshell/vetro/Hypr.js"
    f2_desktop >/dev/null
    non_esiste "$RADICE/etc/xdg/quickshell/vetro/Barra.qml"
    non_esiste "$RADICE/etc/xdg/quickshell/vetro/Hypr.js"
    esiste "$RADICE/etc/xdg/quickshell/vetro/accesso.qml"
    non_esiste "$F/etc/xdg/quickshell/vetro/Pannello.qml"
    contiene "$F/usr/local/bin/blocca-schermo" "qs -c caelestia ipc call lock lock"
    contiene "$F/usr/local/bin/sfondo-desktop" "qs -c caelestia ipc call oversica ping"
}

test_qml() {
    if [ ! -x "$QMLLINT" ]; then fallita "manca pyside6-qmllint"; return; fi
    local f e=0
    for f in "$F"/etc/xdg/quickshell/vetro/*.qml; do
        if "$QMLLINT" "$f" 2>&1 | grep -q '\[syntax\]'; then fallita "QML: $(basename "$f")"; e=1; fi
    done
    [ "$e" -eq 1 ] || ok_prova "QML senza errori di sintassi"
}

prova test_conf_hyprland
prova test_barre_versione
prova test_blocco_pam
prova test_aspetto_gnome
prova test_niente_lfs
prova test_font_icone
prova test_font_icone_sbagliato
prova test_f2_desktop
prova test_pannelli_vecchi_tolti
prova test_qml
riassunto
