#!/bin/bash
# Prove della nuova grafica: carattere, colori, logo, GTK chiaro, sfondi (piano nuova grafica)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
V="$F/etc/xdg/quickshell/vetro"

test_carattere() {
    local f="$F/usr/share/fonts/dm-sans/DMSans.ttf"
    uguale "8cd08d97e89c24d0aa92edd2f0f4c8ee6195eee9b7c9f154865a58b02f0c1c0d" \
           "$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)" "DM Sans: impronta giusta"
    contiene "$F/usr/share/fonts/dm-sans/OFL.txt" "SIL OPEN FONT LICENSE"
}

test_tema() {
    contiene "$V/Tema.qml" 'id: "vetro"'
    contiene "$V/Tema.qml" '"#1a8cff"'
    contiene "$V/Tema.qml" 'readonly property string carattere: "DM Sans"'
    contiene "$V/Tema.qml" "appFondo"
    contiene "$V/Tema.qml" "altezzaBarra: 48"
    contiene "$V/Tema.qml" "staccoBarra: 8"
    contiene "$V/Opzioni.qml" 'property string tema: "vetro"'
    contiene "$V/Opzioni.qml" "property int angoli: 18"
    contiene "$V/Opzioni.qml" "property real opacita: 0.92"
}

test_logo() {
    contiene "$F/usr/share/icons/hicolor/scalable/apps/vetro.svg" "<svg"
    contiene "$F/usr/share/icons/hicolor/scalable/apps/vetro.svg" "creato da vetro-arch.sh"
}

test_gtk() {
    local v
    for v in 3.0 4.0; do
        uguale "/* Vetro (creato da vetro-arch.sh)" "$(head -c 34 "$F/etc/xdg/vetro/gtk-$v.css" 2>/dev/null)" \
               "gtk-$v.css: prima riga di Vetro"
        contiene "$F/etc/xdg/vetro/gtk-$v.css" "#1a8cff"
    done
    contiene "$F/etc/xdg/vetro/gtk-3.0.css" ".sidebar row:selected"
    contiene "$F/etc/xdg/vetro/gtk-4.0.css" "@define-color accent_bg_color #1a8cff;"
}

test_avvia_desktop_css() {
    radice_finta
    local bin="$RADICE/bin"; mkdir -p "$bin" "$RADICE/casa/.config/gtk-4.0"
    printf '#!/bin/sh\nexit 0\n' > "$bin/Hyprland"; chmod +x "$bin/Hyprland"
    printf '#!/bin/sh\necho vetro\n' > "$bin/id"; chmod +x "$bin/id"
    echo "/* il mio */" > "$RADICE/casa/.config/gtk-4.0/gtk.css"
    HOME="$RADICE/casa" VETRO_CSS="$F/etc/xdg/vetro" PATH="$bin:$PATH" bash "$F/usr/local/bin/avvia-desktop" >/dev/null 2>&1
    contiene "$RADICE/casa/.config/gtk-3.0/gtk.css" "#1a8cff"
    contiene "$RADICE/casa/.config/gtk-4.0/gtk.css" "/* il mio */"
    non_contiene "$RADICE/casa/.config/gtk-4.0/gtk.css" "#1a8cff"
}

test_fc_cache_dopo_caratteri() {
    # il carattere delle icone c'e' gia' (niente download): la cache va rifatta lo stesso
    radice_finta; finto pacman; finto systemctl; finto python3; finto vetro-barre-aggiorna; finto fc-cache
    mkdir -p "$RADICE/usr/share/fonts/material-symbols"
    printf carattere > "$RADICE/usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf"
    FONT_ICONE_SHA256=$(printf carattere | sha256sum | cut -d' ' -f1)
    ( set -Eeuo pipefail; f2_desktop ) >/dev/null 2>&1 || fallita "f2_desktop si ferma"
    esiste "$RADICE/usr/share/fonts/dm-sans/DMSans.ttf"
    chiamato "fc-cache"
}

prova test_fc_cache_dopo_caratteri
prova test_carattere
prova test_tema
prova test_logo
prova test_gtk
prova test_avvia_desktop_css
riassunto
