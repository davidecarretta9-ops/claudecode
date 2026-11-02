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
