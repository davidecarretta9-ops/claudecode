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
               "gtk-$v.css: prima riga di Vetro (avvia-desktop la riconosce)"
        contiene "$F/etc/xdg/vetro/gtk-$v.css" "#d9704a"
        non_contiene "$F/etc/xdg/vetro/gtk-$v.css" "#1a8cff"
    done
    contiene "$F/etc/xdg/vetro/gtk-3.0.css" ".sidebar row:selected"
}

test_gtk_arancio() {
    contiene "$F/etc/xdg/vetro/gtk-4.0.css" "@define-color accent_bg_color #d9704a;"
}

test_sfondo_grafite() {
    local f="$F/usr/share/backgrounds/oversica-grafite.jpg"
    uguale "ffd8" "$(head -c 2 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" "oversica-grafite.jpg e' un JPEG"
    uguale "2560x1440" "$(misura_jpg "$f")" "oversica-grafite.jpg 2560x1440"
    if [ -f "$f" ] && [ "$(stat -c %s "$f")" -lt 716800 ]; then ok_prova "sotto 700 KB"
    else fallita "manca o supera 700 KB"; fi
}

test_wallpaper_webp() {
    # lo sfondo di riserva di Caelestia (quello della prima volta) e' il Grafite
    local w="$F/usr/local/lib/vetro/caelestia/nuovi/assets/wallpaper.webp"
    uguale "RIFF" "$(head -c 4 "$w" 2>/dev/null)" "wallpaper.webp: RIFF"
    uguale "WEBP" "$(dd if="$w" bs=1 skip=8 count=4 2>/dev/null)" "wallpaper.webp: WEBP"
}

test_fantasma_non_cambia_sfondo() {
    non_contiene "$F/usr/local/bin/sfondo-desktop" "sfondo-fantasma"
    non_contiene "$ARCH_DIR/src/60-fase4-sicurezza.sh" "disegna-fantasma)\" sfondo"
}

test_patch_fantasma() {
    local r="$F/usr/local/lib/vetro/caelestia"
    contiene "$r/nuovi/modules/bar/components/status/Fantasma.qml" "/etc/fantasma/attivo"
    contiene "$r/nuovi/modules/bar/components/status/Fantasma.qml" "visibility_off"
    contiene "$r/ritocchi/03-fantasma-barra.patch" "Fantasma {"
}

test_avvia_desktop_css() {
    radice_finta
    local bin="$RADICE/bin"; mkdir -p "$bin" "$RADICE/casa/.config/gtk-4.0"
    printf '#!/bin/sh\nexit 0\n' > "$bin/Hyprland"; chmod +x "$bin/Hyprland"
    printf '#!/bin/sh\necho vetro\n' > "$bin/id"; chmod +x "$bin/id"
    printf '#!/bin/sh\necho oversica-config >> "%s/.chiamate"\n' "$RADICE" > "$bin/oversica-config"; chmod +x "$bin/oversica-config"
    echo "/* il mio */" > "$RADICE/casa/.config/gtk-4.0/gtk.css"
    HOME="$RADICE/casa" VETRO_CSS="$F/etc/xdg/vetro" PATH="$bin:$PATH" bash "$F/usr/local/bin/avvia-desktop" >/dev/null 2>&1
    contiene "$RADICE/casa/.config/gtk-3.0/gtk.css" "#d9704a"
    contiene "$RADICE/casa/.config/gtk-4.0/gtk.css" "/* il mio */"
    non_contiene "$RADICE/casa/.config/gtk-4.0/gtk.css" "#d9704a"
    chiamato "oversica-config"
}

test_fc_cache_dopo_caratteri() {
    # il carattere delle icone c'e' gia' (niente download): la cache va rifatta lo stesso
    radice_finta; finto pacman; finto systemctl; finto python3; finto vetro-barre-aggiorna; finto fc-cache; compilazione_finta_base
    mkdir -p "$RADICE/usr/share/fonts/material-symbols"
    printf carattere > "$RADICE/usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf"
    FONT_ICONE_SHA256=$(printf carattere | sha256sum | cut -d' ' -f1)
    ( set -Eeuo pipefail; f2_desktop ) >/dev/null 2>&1 || fallita "f2_desktop si ferma"
    esiste "$RADICE/usr/share/fonts/dm-sans/DMSans.ttf"
    chiamato "fc-cache"
}

# misura_jpg FILE -> "LARGHEZZAxALTEZZA" (dal blocco SOF del JPEG)
misura_jpg() {
    python3 -I - "$1" <<'FINE'
import struct, sys
d = open(sys.argv[1], "rb").read()
i = 2
while i < len(d):
    if d[i] != 0xFF: break
    m = d[i + 1]; n = struct.unpack(">H", d[i + 2:i + 4])[0]
    if m in (0xC0, 0xC1, 0xC2):
        a, l = struct.unpack(">HH", d[i + 5:i + 9]); print(f"{l}x{a}"); break
    i += 2 + n
FINE
}

test_sfondi() {
    local s f
    for s in sfera nuvole cielo onde magenta argento; do
        f="$F/usr/share/backgrounds/vetro-$s.jpg"
        uguale "ffd8" "$(head -c 2 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" "vetro-$s.jpg e' un JPEG"
        uguale "2560x1440" "$(misura_jpg "$f")" "vetro-$s.jpg 2560x1440"
        if [ -f "$f" ] && [ "$(stat -c %s "$f")" -lt 716800 ]; then ok_prova "vetro-$s.jpg sotto 700 KB"
        else fallita "vetro-$s.jpg manca o supera 700 KB"; fi
    done
}

test_sfondo_di_partenza() {
    contiene "$F/usr/local/bin/sfondo-desktop" "oversica-grafite.jpg"
}

test_f2_senza_disegna_vetro() {
    radice_finta; finto pacman; finto systemctl; finto python3; finto vetro-barre-aggiorna; finto fc-cache; compilazione_finta_base
    mkdir -p "$RADICE/usr/share/fonts/material-symbols"
    printf carattere > "$RADICE/usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf"
    FONT_ICONE_SHA256=$(printf carattere | sha256sum | cut -d' ' -f1)
    ( set -Eeuo pipefail; f2_desktop ) >/dev/null 2>&1 || fallita "f2_desktop si ferma"
    non_chiamato "disegna-vetro"
    esiste "$RADICE/usr/share/backgrounds/vetro-sfera.jpg"
    non_esiste "$RADICE/usr/local/lib/vetro/disegna-vetro"
}

# la schermata (tasto Stamp e pulsanti del centro di controllo): grim, e slurp per l'area
test_schermata() {
    radice_finta
    local s="$F/usr/local/bin/schermata"
    finto_con grim <<'FINE'
for ultimo in "$@"; do :; done
printf png > "$ultimo"
FINE
    finto_con slurp <<'FINE'
echo "10,10 200x100"
FINE
    finto notify-send
    HOME="$RADICE/casa" PATH="$RADICE/.finti:$PATH" bash "$s" >/dev/null 2>&1
    uguale 0 "$?" "schermata di tutto lo schermo"
    uguale 1 "$(ls "$RADICE/casa/Immagini/Schermate" 2>/dev/null | grep -c '^Schermata .*\.png$')" "un file in Immagini/Schermate"
    non_chiamato "slurp"
    chiamato "notify-send"
    HOME="$RADICE/casa" PATH="$RADICE/.finti:$PATH" bash "$s" area >/dev/null 2>&1
    chiamato "slurp"
    chiamato "grim -g 10,10 200x100 "
    # area annullata (Esc in slurp): niente file in piu', nessun errore
    finto slurp 1
    local prima; prima=$(ls "$RADICE/casa/Immagini/Schermate" | wc -l)
    HOME="$RADICE/casa" PATH="$RADICE/.finti:$PATH" bash "$s" area >/dev/null 2>&1
    uguale 0 "$?" "area annullata non e' un errore"
    uguale "$prima" "$(ls "$RADICE/casa/Immagini/Schermate" | wc -l)" "area annullata: nessun file"
}

prova test_sfondi
prova test_schermata
prova test_sfondo_di_partenza
prova test_f2_senza_disegna_vetro
prova test_fc_cache_dopo_caratteri
prova test_carattere
prova test_tema
prova test_logo
prova test_gtk
prova test_gtk_arancio
prova test_sfondo_grafite
prova test_wallpaper_webp
prova test_fantasma_non_cambia_sfondo
prova test_patch_fantasma
prova test_avvia_desktop_css
riassunto
