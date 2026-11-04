#!/bin/bash
# Prove della pagina Account di oversicaOS: avatar pubblico (lo vede la schermata di
# accesso) e registro delle pagine delle Impostazioni (piano oversicaOS, Task 13)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
AIUTANTE="$F/usr/local/sbin/oversica-avatar-pubblica"
N="$F/usr/local/lib/vetro/caelestia/nuovi"
PY=python3
[ -x "$HOME/.vetro-qt/bin/python" ] && PY="$HOME/.vetro-qt/bin/python"

png_finto() {   # un PNG piccolo (basta la firma) in $1
    printf '\x89PNG\r\n\x1a\nresto' > "$1"
}

pubblica() {    # pubblica UTENTE FILE: come la chiama sudo (SUDO_USER = chi la lancia)
    SUDO_USER=$1 OVERSICA_RADICE=$RADICE bash "$AIUTANTE" < "$2" > "$RADICE/uscita" 2>&1
}

test_pubblica_avatar() {
    radice_finta
    png_finto "$RADICE/face"
    pubblica davide "$RADICE/face"
    uguale 0 "$?" "l'aiutante finisce"
    local f="$RADICE/var/lib/AccountsService/icons/davide"
    esiste "$f"
    cmp -s "$RADICE/face" "$f"; uguale 0 "$?" "e' la stessa immagine"
    uguale 644 "$(stat -c %a "$f")" "leggibile da tutti (anche dalla schermata di accesso)"
}

test_pubblica_rifiuta() {
    radice_finta
    png_finto "$RADICE/face"
    pubblica "../../etc/x" "$RADICE/face"
    uguale 1 "$?" "nome con .. rifiutato"
    pubblica "" "$RADICE/face"
    uguale 1 "$?" "senza utente rifiutato"
    pubblica "a/b" "$RADICE/face"
    uguale 1 "$?" "nome con / rifiutato"
    echo "non e' un'immagine" > "$RADICE/testo"
    pubblica davide "$RADICE/testo"
    uguale 1 "$?" "un file che non e' PNG rifiutato"
    { printf '\x89PNG\r\n\x1a\n'; head -c 3000000 /dev/zero; } > "$RADICE/grande"
    pubblica davide "$RADICE/grande"
    uguale 1 "$?" "un'immagine troppo grande rifiutata"
    uguale "" "$(find "$RADICE" -path '*AccountsService*' -type f)" "niente scritto"
    uguale "" "$(find "$RADICE/etc" -name x 2>/dev/null)" "niente fuori posto"
}

test_sudoers_solo_aiutante() {
    local s="$F/etc/sudoers.d/40-oversica-avatar"
    esiste "$s"
    uguale '%wheel ALL=(root) NOPASSWD: /usr/local/sbin/oversica-avatar-pubblica ""' \
           "$(grep -v '^#' "$s" | grep .)" "una sola regola, solo l'aiutante e senza argomenti"
}

test_patch_registro_allineato() {
    radice_finta
    local s="$RADICE/sorgente"; mkdir -p "$s"
    cp -a "$QUI_TEST/caelestia-originali/." "$s/"
    ( CAELESTIA_RITOCCHI="$F/usr/local/lib/vetro/caelestia" applica_ritocchi "$s" ) >/dev/null 2>&1
    uguale 0 "$?" "i ritocchi si applicano"
    local r
    r=$("$PY" - "$s/modules/nexus" <<'FINE'
import re, sys, pathlib
d = pathlib.Path(sys.argv[1])

def voci(testo, nome):
    testo = re.sub(r"//[^\n]*", "", testo)
    j = testo.index("[", testo.index(nome)) + 1
    prof, inizio, out = 0, None, []
    while True:
        c = testo[j]
        if c == "{":
            if prof == 0:
                inizio = j
            prof += 1
        elif c == "}":
            prof -= 1
            if prof == 0:
                out.append(testo[inizio:j + 1])
        elif c == "]" and prof == 0:
            return out
        j += 1

pagine = voci((d / "PageRegistry.qml").read_text(), "pages:")
comp = voci((d / "PageCompRegistry.qml").read_text(), "pageComps:")
i = [n for n, p in enumerate(pagine) if 'label: "Account"' in p]
k = [n for n, c in enumerate(comp) if "AccountPage {" in c]
print(len(pagine), len(comp), i, k)
FINE
)
    local np nc ia ka
    read -r np nc ia ka <<< "$(echo "$r" | tr -d '[],')"
    uguale "$np" "$nc" "stesso numero di voci in pages e pageComps ($r)"
    uguale "$ia" "$ka" "Account alla stessa posizione"
    [ -n "$ia" ] && ok_prova "c'e' la pagina Account" || fallita "manca la pagina Account"
    esiste "$s/modules/nexus/pages/AccountPage.qml"
    # la barra apre le pagine per nome, non per numero (le pagine nuove spostano i numeri)
    contiene "$s/modules/bar/popouts/Wrapper.qml" 'PageRegistry.pages.findIndex(p => p.chiave === root.queuedMode)'
    local c
    for c in appearance network bluetooth audio; do
        contiene "$s/modules/nexus/PageRegistry.qml" "chiave: \"$c\""
    done
}

test_pagina_account() {
    local a="$N/modules/nexus/pages/AccountPage.qml"
    contiene "$a" 'import "../../../utils/Avatar.js" as Avatar'
    contiene "$a" "/usr/share/oversica/avatar/pixel.json"
    contiene "$a" '"oversica-avatar", "salva"'
    contiene "$a" '"passwd"'
    local QMLLINT=${QMLLINT:-$(command -v pyside6-qmllint || echo "$HOME/.vetro-qt/bin/pyside6-qmllint")}
    if [ -x "$QMLLINT" ] && ! "$QMLLINT" "$a" 2>&1 | grep -q '\[syntax\]'; then
        ok_prova "AccountPage.qml senza errori di sintassi"
    else fallita "AccountPage.qml: errori di sintassi o manca qmllint"; fi
}

prova test_pubblica_avatar
prova test_pubblica_rifiuta
prova test_sudoers_solo_aiutante
prova test_patch_registro_allineato
prova test_pagina_account
riassunto
