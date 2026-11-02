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
    non_contiene "$F/etc/xdg/hypr/vetro.conf" "vetro-accesso"
    contiene "$F/etc/xdg/hypr/vetro.conf" "env = XCURSOR_THEME, Vetro"
    contiene "$F/etc/xdg/hypr/vetro.conf" "source = ~/.config/hypr/vetro-schermo.conf"
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
    PATH="$RADICE/.finti:$PATH" VETRO_HYPRPM_TOML="$RADICE/hyprpm.toml" bash "$BARRE" >/dev/null 2>&1
    uguale "0" "$?" "senza versione del plugin non e' un errore"
    uguale "0" "$(grep -vc '^#' "$RADICE/etc/xdg/hypr/vetro-barre.conf")" "vetro-barre.conf con solo commenti"
}

test_blocco_pam() {
    contiene "$F/etc/xdg/quickshell/vetro/Blocco.qml" "PamContext"
    non_contiene "$F/etc/xdg/quickshell/vetro/Blocco.qml" "vetro-password"
    contiene "$F/etc/pam.d/vetro-blocco" "auth include system-auth"
    contiene "$F/etc/pam.d/vetro-blocco" "account include system-auth"
}

test_aspetto_gnome() {
    contiene "$F/etc/xdg/quickshell/vetro/Tema.qml" '{ id: "adwaita"'
    contiene "$F/etc/xdg/quickshell/vetro/Opzioni.qml" 'property string tema: "adwaita"'
    local g
    for g in gtk-3.0 gtk-4.0; do
        contiene "$F/etc/$g/settings.ini" "gtk-theme-name=Adwaita"
        contiene "$F/etc/$g/settings.ini" "gtk-application-prefer-dark-theme=1"
        contiene "$F/etc/$g/settings.ini" "gtk-cursor-theme-name=Vetro"
        contiene "$F/etc/$g/settings.ini" "gtk-font-name=Adwaita Sans 11"
    done
}

test_niente_lfs() {
    non_contiene "$F/usr/local/bin/avvia-desktop" "labwc"
    contiene "$F/usr/local/bin/avvia-desktop" "exec Hyprland -c /etc/xdg/hypr/vetro.conf"
    non_contiene "$F/usr/local/bin/avvia-pannelli" "xfce4-panel"
    non_contiene "$F/usr/local/bin/avvio-vetro" "submap"
    non_contiene "$F/etc/xdg/quickshell/vetro/FinestraImpostazioni.qml" "scegli-desktop"
    contiene "$F/etc/xdg/quickshell/vetro/Stato.qml" "property bool bloccato: false"
}

test_f2_desktop() {
    radice_finta; finto pacman; finto systemctl; finto python3; finto vetro-barre-aggiorna
    f2_desktop >/dev/null
    esiste "$RADICE/etc/xdg/quickshell/vetro/shell.qml"
    esiste "$RADICE/etc/xdg/hypr/vetro.conf"
    esiste "$RADICE/etc/xdg/hypr/vetro-barre.conf"
    esiste "$RADICE/etc/pacman.d/hooks/vetro-barre.hook"
    esiste "$RADICE/usr/local/bin/avvia-desktop"
    chiamato "python3 -I $RADICE/usr/local/lib/vetro/disegna-cursori $RADICE/usr/share/icons/Vetro"
    chiamato "vetro-barre-aggiorna"
    chiamato "systemctl --global enable pipewire.socket wireplumber.service pipewire-pulse.socket"
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
prova test_f2_desktop
prova test_qml
riassunto
