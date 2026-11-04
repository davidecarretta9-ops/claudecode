#!/bin/bash
# Prove dei ritocchi di oversicaOS su Caelestia (piano oversicaOS, Task 3)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
RITOCCHI="$ARCH_DIR/file/usr/local/lib/vetro/caelestia"
ORIGINALI="$QUI_TEST/caelestia-originali"

test_tutti_i_ritocchi_si_applicano() {
    radice_finta
    local s="$RADICE/sorgente"; mkdir -p "$s"
    cp -a "$ORIGINALI/." "$s/"
    ( CAELESTIA_RITOCCHI=$RITOCCHI applica_ritocchi "$s" ) > "$RADICE/uscita" 2>&1
    uguale 0 "$?" "i ritocchi si applicano agli originali di Caelestia"
    uguale 0 "$(find "$s" -name '*.rej' -o -name '*.orig' | wc -l)" "nessun resto di patch"
}

# un ritocco di prova su un file di prova
ritocchi_di_prova() {
    local r="$RADICE/ritocchi"; mkdir -p "$r/ritocchi" "$r/nuovi/utils"
    echo "nuovo" > "$r/nuovi/utils/Nuovo.js"
    cat > "$r/ritocchi/01-prova.patch" <<'FINE'
--- a/shell.qml
+++ b/shell.qml
@@ -1,2 +1,3 @@
 riga uno
+riga di oversicaOS
 riga due
FINE
    echo "$r"
}

test_nuovi_sovrapposti() {
    radice_finta
    local s="$RADICE/sorgente" r; mkdir -p "$s"; r=$(ritocchi_di_prova)
    printf 'riga uno\nriga due\n' > "$s/shell.qml"
    ( CAELESTIA_RITOCCHI=$r applica_ritocchi "$s" ) >/dev/null 2>&1
    uguale 0 "$?" "si applica"
    contiene "$s/utils/Nuovo.js" "nuovo"
    contiene "$s/shell.qml" "riga di oversicaOS"
}

test_ritocco_che_non_si_applica() {
    radice_finta
    local s="$RADICE/sorgente" r msg; mkdir -p "$s"; r=$(ritocchi_di_prova)
    printf 'tutt altro\n' > "$s/shell.qml"
    msg=$( (CAELESTIA_RITOCCHI=$r applica_ritocchi "$s") 2>&1 ); local rc=$?
    uguale 1 "$rc" "si ferma"
    case "$msg" in *01-prova.patch*) ok_prova "dice quale ritocco" ;; *) fallita "messaggio: $msg" ;; esac
}

prova test_tutti_i_ritocchi_si_applicano
prova test_nuovi_sovrapposti
prova test_ritocco_che_non_si_applica
riassunto
