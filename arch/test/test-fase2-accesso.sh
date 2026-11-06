#!/bin/bash
# Prove della schermata di accesso di oversicaOS: e' il blocco di Caelestia (stessi pezzi),
# ma la password la controlla greetd e poi parte il desktop (piano oversicaOS, Task 10)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
N="$F/usr/local/lib/vetro/caelestia/nuovi"
QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}

sintassi() {
    local f
    for f in "$@"; do
        if [ -f "$f" ] && [ -x "$QMLLINT" ] && ! "$QMLLINT" "$f" 2>&1 | grep -q '\[syntax\]'; then
            ok_prova "${f##*/} senza errori di sintassi"
        else fallita "${f##*/}: manca, ha errori di sintassi o manca qmllint"; fi
    done
}

test_greetd() {
    contiene "$F/etc/greetd/config.toml" 'vt = 1'
    contiene "$F/etc/greetd/config.toml" 'command = "Hyprland -c /etc/vetro/accesso-hyprland.lua"'
    contiene "$F/etc/greetd/config.toml" 'user = "greeter"'
    # Hyprland 0.57 legge solo Lua (il controllo completo e' in python/test_lua.py)
    non_esiste "$F/etc/vetro/accesso-hyprland.conf"
    contiene "$F/etc/vetro/accesso-hyprland.lua" 'hl.exec_cmd("/usr/local/lib/vetro/accesso-avvia")'
    contiene "$F/etc/vetro/accesso-hyprland.lua" 'hl.env("XCURSOR_THEME", "Vetro")'
    # le scelte di Caelestia per questa schermata (italiano, sfondo sfocato)
    contiene "$F/etc/vetro/accesso-hyprland.lua" 'hl.env("XDG_CONFIG_HOME", "/etc/vetro/accesso")'
    # la password si scrive con la tastiera italiana, come nel desktop
    contiene "$F/etc/vetro/accesso-hyprland.lua" 'kb_layout = "it"'
}

test_scelte_di_caelestia() {
    local j="$F/etc/vetro/accesso/caelestia/shell.json"
    esiste "$j"
    uguale "it true" "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["general"]["language"], str(d["lock"]["useWallpaper"]).lower())' "$j" 2>&1)" \
           "italiano e sfondo nel blocco"
}

# accesso-avvia con comandi finti: QS = cosa fa il qs finto
avvio_finto() {
    radice_finta
    mkdir -p "$RADICE/bin" "$RADICE/log"
    local c
    for c in hyprctl foot; do
        printf '#!/bin/sh\necho "%s $*" >> "%s/.chiamate"\n' "$c" "$RADICE" > "$RADICE/bin/$c"
    done
    printf '#!/bin/sh\n%s\n' "$1" > "$RADICE/bin/qs"
    chmod 755 "$RADICE/bin/"*
    OVERSICA_REGISTRI="$RADICE/log" PATH="$RADICE/bin:$PATH" timeout 30 bash "$F/usr/local/lib/vetro/accesso-avvia" >/dev/null 2>&1
}

test_registro_salvato_spesso() {
    # chiudendo la finestra della macchina il registro andrebbe perso: si salva ogni 5 s
    contiene "$F/usr/local/lib/vetro/accesso-avvia" 'sync "$log"'
}

test_avvio_caricato() {
    # l'utente "greeter" ha la casa in / (non scrivibile): stato e cache in /run/user
    avvio_finto 'echo "stato=$XDG_STATE_HOME cache=$XDG_CACHE_HOME"; echo "Configuration Loaded"; exit 0'
    contiene "$RADICE/log/accesso.log" "stato=/run/user/$(id -u)/oversica/stato cache=/run/user/$(id -u)/oversica/cache"
    contiene "$RADICE/log/accesso.log" "schermata di accesso"
    contiene "$RADICE/log/accesso.log" "Configuration Loaded"
    non_chiamato "foot"
    chiamato "hyprctl dispatch hl.dsp.exit()"
}

test_avvio_che_non_si_carica() {
    # Quickshell con un errore nei file QML non si chiude: resterebbe tutto nero
    avvio_finto 'echo "Failed to load configuration"; exec sleep 20'
    contiene "$RADICE/log/accesso.log" "accesso di riserva"
    chiamato "foot -e agreety --cmd /usr/local/bin/avvia-desktop"
    chiamato "hyprctl dispatch hl.dsp.exit()"
    uguale "" "$(pgrep -fx 'sleep 20' 2>/dev/null)" "il qs bloccato e' stato chiuso"
}

test_avvio_che_si_chiude_subito() {
    avvio_finto 'echo "errore grave"; exit 1'
    chiamato "foot -e agreety --cmd /usr/local/bin/avvia-desktop"
    chiamato "hyprctl dispatch hl.dsp.exit()"
}

test_f2_accesso() {
    radice_finta; finto pacman; finto systemctl; finto usermod; finto chown
    f2_accesso >/dev/null
    esiste "$RADICE/usr/local/lib/vetro/accesso-avvia"
    esiste "$RADICE/var/log/oversica"
    chiamato "chown greeter:greeter $RADICE/var/log/oversica"
    chiamato "pacman -S --needed --noconfirm greetd foot"
    esiste "$RADICE/etc/greetd/config.toml"
    esiste "$RADICE/etc/vetro/accesso-hyprland.lua"
    esiste "$RADICE/etc/vetro/accesso/caelestia/shell.json"
    chiamato "usermod -aG video greeter"
    chiamato "systemctl enable greetd.service"
    chiamato "systemctl disable getty@tty1.service"
}

test_vecchi_file_tolti() {
    # i pannelli di Vetro sono finiti tutti: anche la vecchia schermata di accesso
    non_esiste "$F/etc/xdg/quickshell/vetro"
    radice_finta; finto pacman; finto systemctl; finto usermod; finto chown
    mkdir -p "$RADICE/etc/xdg/quickshell/vetro"
    : > "$RADICE/etc/xdg/quickshell/vetro/accesso.qml"
    : > "$RADICE/etc/xdg/quickshell/vetro/AccessoVista.qml"
    f2_accesso >/dev/null
    non_esiste "$RADICE/etc/xdg/quickshell/vetro"
}

test_greeter_file() {
    local a="$N/accesso.qml" g="$N/modules/lock/AccessoGreetd.qml"
    # la schermata e' quella del blocco di Caelestia
    contiene "$a" "WlSessionLock"
    contiene "$a" "LockSurface {"
    contiene "$a" "AccessoGreetd {"
    contiene "$a" "import qs.modules.lock"
    # il motore: greetd controlla la password, poi parte il desktop
    contiene "$g" "Greetd.createSession"
    contiene "$g" "Greetd.respond"
    contiene "$g" "Greetd.launch"
    contiene "$g" "/usr/local/bin/avvia-desktop"
    contiene "$g" "/etc/vetro/utente"
    # stessa forma di Pam.qml (quello che usano campo password e messaggi)
    local p
    for p in "property alias passwd\|property QtObject passwd" "property QtObject fprint" "property QtObject howdy" \
             "property string lockMessage" "property int state" "property string buffer" \
             "signal flashMsg" "function handleKey("; do
        if grep -q "$p" "$g"; then ok_prova "AccessoGreetd ha $p"; else fallita "AccessoGreetd senza $p"; fi
    done
    sintassi "$a" "$g"
}

test_accesso_installato() {
    # Caelestia installa solo le sue cartelle e shell.qml: un ritocco aggiunge accesso.qml
    radice_finta
    local s="$RADICE/sorgente"; mkdir -p "$s"
    cp -a "$QUI_TEST/caelestia-originali/." "$s/"
    ( CAELESTIA_RITOCCHI="$F/usr/local/lib/vetro/caelestia" applica_ritocchi "$s" ) >/dev/null 2>&1
    contiene "$s/CMakeLists.txt" 'install(FILES accesso.qml DESTINATION "${INSTALL_QSCONFDIR}")'
    esiste "$s/accesso.qml"
    esiste "$s/modules/lock/AccessoGreetd.qml"
}

prova test_greetd
prova test_registro_salvato_spesso
prova test_avvio_caricato
prova test_avvio_che_non_si_carica
prova test_avvio_che_si_chiude_subito
prova test_accesso_installato
prova test_scelte_di_caelestia
prova test_f2_accesso
prova test_vecchi_file_tolti
prova test_greeter_file
riassunto
