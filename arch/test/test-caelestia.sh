#!/bin/bash
# Prove di oversicaOS: Caelestia e Quickshell a versione fissa, compilazione (piano oversicaOS)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src

# tutti i comandi della compilazione, finti; FALLISCE=parola fa fallire cmake se la contiene
compilazione_finta() {
    radice_finta; git_finto; finto pacman; finto ninja
    finto_con pkg-config <<'FINE'
exit 0
FINE
    finto_con cmake <<'FINE'
case "$*" in *"${FALLISCE:-niente-da-far-fallire}"*) exit 1 ;; esac
exit 0
FINE
    finto_con curl <<'FINE'
while [ $# -gt 0 ]; do [ "$1" = -o ] && { printf sorgente > "$2"; shift; }; shift; done
FINE
    finto_con tar <<'FINE'
exit 0
FINE
    finto_con python3 <<'FINE'
while [ $# -gt 0 ]; do [ "$1" = --outdir ] && { mkdir -p "$2"; touch "$2/finta-1.0-py3-none-any.whl"; }; shift; done
exit 0
FINE
    MATERIALYOU_SHA256=$(printf sorgente | sha256sum | cut -d' ' -f1)
    applica_ritocchi() { echo "applica_ritocchi $*" >> "$RADICE/.chiamate"; }
}

riga_di() { grep -n -- "$1" "$RADICE/.chiamate" | head -n 1 | cut -d: -f1; }

test_scarica_git_giusto() {
    radice_finta; git_finto
    local dir="$RADICE/sorgenti/qs"
    ( GIT_COMMIT=abc123 scarica_git https://esempio/qs abc123 "$dir" ) >/dev/null 2>&1
    uguale 0 "$?" "commit giusto: esce con 0"
    chiamato "git -C $dir fetch -q --depth 1 origin abc123"
    chiamato "git -C $dir checkout -q FETCH_HEAD"
    esiste "$dir"
}

test_scarica_git_commit_diverso() {
    radice_finta; git_finto
    local dir="$RADICE/sorgenti/qs" msg
    msg=$( (GIT_COMMIT=altro scarica_git https://esempio/qs abc123 "$dir") 2>&1 ); local rc=$?
    uguale 1 "$rc" "commit diverso: si ferma"
    case "$msg" in *"versione giusta"*) ok_prova "dice che non e' la versione giusta" ;;
        *) fallita "messaggio: $msg" ;; esac
    non_esiste "$dir"
}

test_scarica_controllato_sha_sbagliato() {
    radice_finta
    finto_con curl <<'FINE'
while [ $# -gt 0 ]; do [ "$1" = -o ] && { printf x > "$2"; shift; }; shift; done
FINE
    local f="$RADICE/scaricato.tar.gz" msg
    msg=$( (scarica_controllato https://esempio/a.tar.gz 0000 "$f") 2>&1 ); local rc=$?
    uguale 1 "$rc" "impronta sbagliata: si ferma"
    case "$msg" in *controllo*) ok_prova "dice che il controllo non passa" ;; *) fallita "messaggio: $msg" ;; esac
    non_esiste "$f"
    # impronta giusta: il file resta
    ( scarica_controllato https://esempio/a.tar.gz "$(printf x | sha256sum | cut -d' ' -f1)" "$f" ) >/dev/null 2>&1
    uguale 0 "$?" "impronta giusta: esce con 0"
    esiste "$f"
}

test_quickshell_sempre_compilato() {
    radice_finta; git_finto; finto pacman; finto cmake; finto ninja
    ( GIT_COMMIT=$QUICKSHELL_COMMIT installa_quickshell ) >/dev/null 2>&1
    uguale 0 "$?" "installa_quickshell finisce"
    chiamato "remote add origin https://github.com/quickshell-mirror/quickshell"
    chiamato "fetch -q --depth 1 origin 9b0f339b19057f4731bf3b48293307d7ef241671"
    chiamato "cmake -S"
    non_chiamato "pacman -S --needed --noconfirm quickshell"
}

test_versioni_fisse() {
    uguale bcbb5d5139d5159839c7362d8f4954ccc7dbd67d "$CAELESTIA_SHELL_COMMIT" "Caelestia shell"
    uguale fdb3e47038c77ec8e7bb6010ffbcae00501d420b "$CAELESTIA_CLI_COMMIT" "Caelestia cli"
    uguale 9b0f339b19057f4731bf3b48293307d7ef241671 "$QUICKSHELL_COMMIT" "Quickshell"
    uguale 32ad9ce328bb77ed349b40a3be10ee9ea610b8ab "$M3SHAPES_COMMIT" "m3shapes"
    uguale 30b8dde034dce180845b0eaf52f72c5b22cd5b60bd7aff96804febae4e266276 "$MATERIALYOU_SHA256" "materialyoucolor"
    uguale f03278ef9e5e7948fb206453d2f02758f8db216c "$LIBCAVA_COMMIT" "libcava 1.0.0"
}

test_ordine_compilazione() {
    compilazione_finta
    ( compila_caelestia ) > "$RADICE/uscita" 2>&1
    uguale 0 "$?" "compila_caelestia finisce"
    local a b c d
    a=$(riga_di "soramanew/m3shapes"); b=$(riga_di "materialyoucolor-3.0.4"); c=$(riga_di "caelestia-dots/cli")
    d=$(riga_di "caelestia-dots/shell")
    if [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ -n "$d" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && [ "$c" -lt "$d" ]; then
        ok_prova "ordine: m3shapes, materialyoucolor, cli, shell"
    else fallita "ordine sbagliato ($a $b $c $d)"; fi
    # i ritocchi prima della compilazione della shell
    local r s; r=$(riga_di "applica_ritocchi"); s=$(grep -n "cmake -S .*caelestia-shell" "$RADICE/.chiamate" | head -n1 | cut -d: -f1)
    if [ -n "$r" ] && [ -n "$s" ] && [ "$r" -lt "$s" ]; then ok_prova "ritocchi prima di cmake"
    else fallita "ritocchi ($r) non prima di cmake ($s)"; fi
    chiamato "python3 -m installer"
}

test_cmake_shell() {
    compilazione_finta
    ( compila_caelestia ) >/dev/null 2>&1
    chiamato "-DVERSION=2.5.0 -DGIT_REVISION=bcbb5d5139d5159839c7362d8f4954ccc7dbd67d -DDISTRIBUTOR=oversicaOS"
    chiamato "-DENABLE_MODULES=extras;plugin;shell"
    chiamato "-DCMAKE_INSTALL_PREFIX=/"
}

# libcava (le barre della musica) non e' nei pacchetti di Arch: si compila da
# LukashonakV/cava a versione fissa, prima della shell
libcava_mancante() {
    finto_con pkg-config <<'FINE'
case "$*" in *libcava*) exit 1 ;; esac
exit 0
FINE
    finto_con meson <<'FINE'
case "$*" in *"${FALLISCE:-niente-da-far-fallire}"*) exit 1 ;; esac
exit 0
FINE
    finto ldconfig
}

test_libcava_compilata() {
    compilazione_finta; libcava_mancante
    ( compila_caelestia ) > "$RADICE/uscita" 2>&1
    uguale 0 "$?" "compila_caelestia finisce"
    chiamato "https://github.com/LukashonakV/cava"
    chiamato "fetch -q --depth 1 origin f03278ef9e5e7948fb206453d2f02758f8db216c"
    chiamato "meson setup"
    chiamato "--prefix=/usr -Dbuild_target=lib -Dcava_font=false"
    chiamato "meson install -C"
    chiamato "ldconfig"
    local l s; l=$(riga_di "meson install"); s=$(grep -n "cmake -S .*caelestia-shell" "$RADICE/.chiamate" | head -n1 | cut -d: -f1)
    if [ -n "$l" ] && [ -n "$s" ] && [ "$l" -lt "$s" ]; then ok_prova "libcava prima della shell"
    else fallita "libcava ($l) non prima della shell ($s)"; fi
}

test_libcava_gia_presente() {
    compilazione_finta; finto meson
    ( compila_caelestia ) >/dev/null 2>&1
    chiamato "pkg-config --exists libcava"
    non_chiamato "LukashonakV"
    non_chiamato "meson setup"
}

test_libcava_che_non_si_compila() {
    compilazione_finta; libcava_mancante
    local msg; msg=$( (FALLISCE=build_target compila_caelestia) 2>&1 ); local rc=$?
    uguale 1 "$rc" "si ferma"
    case "$msg" in *libcava*) ok_prova "dice che e' libcava" ;; *) fallita "messaggio: $msg" ;; esac
}

test_pacchetti_libcava() {
    local p
    for p in iniparser fftw; do
        case " ${PKG_CAELESTIA[*]} " in *" $p "*) ok_prova "$p tra i pacchetti" ;; *) fallita "manca $p" ;; esac
    done
    case " ${PKG_CAELESTIA[*]} " in *" meson "*) ok_prova "meson tra i pacchetti" ;; *) fallita "manca meson" ;; esac
    # il programma cava di Arch non serve (Caelestia usa solo la libreria)
    case " ${PKG_CAELESTIA[*]} " in *" cava "*) fallita "cava di Arch ancora tra i pacchetti" ;; *) ok_prova "niente cava di Arch" ;; esac
}

test_compilazione_che_fallisce() {
    compilazione_finta
    local msg; msg=$( (FALLISCE=caelestia-shell compila_caelestia) 2>&1 ); local rc=$?
    uguale 1 "$rc" "la shell non si compila: si ferma"
    case "$msg" in *Caelestia*) ok_prova "dice che e' Caelestia" ;; *) fallita "messaggio: $msg" ;; esac
}

prova test_ordine_compilazione
prova test_cmake_shell
prova test_libcava_compilata
prova test_libcava_gia_presente
prova test_libcava_che_non_si_compila
prova test_pacchetti_libcava
prova test_compilazione_che_fallisce
prova test_scarica_git_giusto
prova test_scarica_git_commit_diverso
prova test_scarica_controllato_sha_sbagliato
prova test_quickshell_sempre_compilato
prova test_versioni_fisse
riassunto
