#!/bin/bash
# Prove dell'accesso con greetd e dei piu' schermi (Task 6)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
V="$F/etc/xdg/quickshell/vetro"
QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}

test_greetd() {
    contiene "$F/etc/greetd/config.toml" 'vt = 1'
    contiene "$F/etc/greetd/config.toml" 'command = "Hyprland -c /etc/vetro/accesso-hyprland.lua"'
    contiene "$F/etc/greetd/config.toml" 'user = "greeter"'
    # Hyprland 0.57 legge solo Lua (il controllo completo e' in python/test_lua.py)
    non_esiste "$F/etc/vetro/accesso-hyprland.conf"
    contiene "$F/etc/vetro/accesso-hyprland.lua" "hyprctl dispatch 'hl.dsp.exit()'"
    contiene "$F/etc/vetro/accesso-hyprland.lua" 'hl.env("XCURSOR_THEME", "Vetro")'
    # la password si scrive con la tastiera italiana, come nel desktop
    contiene "$F/etc/vetro/accesso-hyprland.lua" 'kb_layout = "it"'
}

test_f2_accesso() {
    radice_finta; finto pacman; finto systemctl; finto usermod
    f2_accesso >/dev/null
    esiste "$RADICE/etc/greetd/config.toml"
    esiste "$RADICE/etc/vetro/accesso-hyprland.lua"
    chiamato "usermod -aG video greeter"
    chiamato "systemctl enable greetd.service"
    chiamato "systemctl disable getty@tty1.service"
}

test_accesso_qml() {
    contiene "$V/accesso.qml" "Greetd.createSession"
    contiene "$V/accesso.qml" "Greetd.launch"
    contiene "$V/accesso.qml" "/usr/local/bin/avvia-desktop"
    contiene "$V/accesso.qml" "Password sbagliata"
    if [ -x "$QMLLINT" ] && ! "$QMLLINT" "$V/accesso.qml" 2>&1 | grep -q '\[syntax\]'; then
        ok_prova "accesso.qml senza errori di sintassi"
    else fallita "accesso.qml: errori di sintassi o manca qmllint"; fi
}

prova test_greetd
prova test_f2_accesso
prova test_accesso_qml
riassunto
