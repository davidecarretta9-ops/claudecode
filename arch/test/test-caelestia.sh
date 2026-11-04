#!/bin/bash
# Prove di oversicaOS: Caelestia e Quickshell a versione fissa, compilazione (piano oversicaOS)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src

# git finto: ricorda le chiamate; "rev-parse HEAD" risponde $GIT_COMMIT
git_finto() {
    finto_con git <<'FINE'
dir=""
[ "$1" = -C ] && { dir=$2; shift 2; }
case "$1" in
    init) mkdir -p "$dir"; touch "$dir/.git-finto" ;;
    rev-parse) echo "$GIT_COMMIT" ;;
esac
exit 0
FINE
}

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
}

prova test_scarica_git_giusto
prova test_scarica_git_commit_diverso
prova test_scarica_controllato_sha_sbagliato
prova test_quickshell_sempre_compilato
prova test_versioni_fisse
riassunto
