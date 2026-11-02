#!/bin/bash
# Prove della fase 3: i programmi (Task 8)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"

# pacman.conf come quello di Arch: multilib spento
pacman_conf() {
    mkdir -p "$RADICE/etc"
    printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n\n#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' \
        > "$RADICE/etc/pacman.conf"
}

test_multilib_prima() {
    radice_finta; finto pacman; pacman_conf
    f3_programmi >/dev/null
    contiene "$RADICE/etc/pacman.conf" "[multilib]"
    local sy wine
    sy=$(grep -n "^pacman -Sy" "$RADICE/.chiamate" | head -n 1 | cut -d: -f1)
    wine=$(grep -n "^pacman -S --needed --noconfirm .* wine" "$RADICE/.chiamate" | head -n 1 | cut -d: -f1)
    if [ -n "$sy" ] && [ -n "$wine" ] && [ "$sy" -lt "$wine" ]; then
        ok_prova "multilib acceso prima di installare wine"
    else fallita "multilib non acceso prima di wine (Sy riga '$sy', wine riga '$wine')"; fi
    esiste "$RADICE/usr/local/bin/wine"
    esiste "$RADICE/usr/local/lib/wine-recinto/xdg-open"
    esiste "$RADICE/etc/xdg/mimeapps.list"
    esiste "$RADICE/usr/share/applications/tor-browser.desktop"
}

test_pacchetti() {
    local p
    for p in torbrowser-launcher thunderbird libreoffice-fresh libreoffice-fresh-it thunar \
             mousepad foot yad wine wine-mono wine-gecko bubblewrap xdg-utils; do
        case " ${PKG_FASE3[*]} " in *" $p "*) ok_prova "pacchetto $p" ;; *) fallita "manca il pacchetto $p" ;; esac
    done
    case " ${PKG_FASE3[*]} " in *firefox*) fallita "firefox non deve esserci" ;; *) ok_prova "niente firefox" ;; esac
}

test_mime() {
    local m="$F/etc/xdg/mimeapps.list" t
    non_contiene "$m" "firefox"
    for t in text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https application/pdf; do
        contiene "$m" "$t=tor-browser.desktop"
    done
    contiene "$m" "application/x-ms-dos-executable=wine.desktop"
}

test_script() {
    local s
    for s in tor-browser browser-predefinito; do
        if sh -n "$F/usr/local/bin/$s"; then ok_prova "$s: sintassi"; else fallita "$s: sintassi"; fi
    done
    if python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$F/usr/local/bin/wine"; then
        ok_prova "wine: sintassi"; else fallita "wine: sintassi"; fi
    contiene "$F/usr/local/bin/tor-browser" "torbrowser-launcher"
    contiene "$F/usr/local/bin/tor-browser" "TOR_SKIP_LAUNCH=1"
    contiene "$F/usr/local/bin/tor-browser" "TOR_SOCKS_PORT=9150"
    non_contiene "$F/usr/local/bin/tor-browser" "/opt/tor-browser"
    contiene "$F/usr/local/bin/wine" '"/usr/bin/wine"'
    # gli indirizzi web dal recinto: l'xdg-open di Arch e' in /usr/bin
    contiene "$F/usr/local/bin/wine" '"/usr/bin/xdg-open"'
}

test_voci_menu() {
    contiene "$F/usr/share/applications/tor-browser.desktop" "Exec=/usr/local/bin/tor-browser %u"
    # la voce del pacchetto torbrowser-launcher non si vede (c'e' gia' la nostra)
    contiene "$F/usr/local/share/applications/torbrowser.desktop" "NoDisplay=true"
    # doppio clic su un .exe: sempre nel recinto
    contiene "$F/usr/local/share/applications/wine.desktop" "Exec=/usr/local/bin/wine start /unix %f"
}

test_strumenti_wine() {
    radice_finta; finto pacman; pacman_conf
    mkdir -p "$RADICE/usr/bin"; : > "$RADICE/usr/bin/winecfg"; : > "$RADICE/usr/bin/regedit"
    f3_programmi >/dev/null
    uguale "wine" "$(readlink "$RADICE/usr/local/bin/winecfg")" "winecfg passa dal recinto"
    uguale "wine" "$(readlink "$RADICE/usr/local/bin/regedit")" "regedit passa dal recinto"
    non_esiste "$RADICE/usr/local/bin/notepad"
}

prova test_multilib_prima
prova test_pacchetti
prova test_mime
prova test_script
prova test_voci_menu
prova test_strumenti_wine
riassunto
