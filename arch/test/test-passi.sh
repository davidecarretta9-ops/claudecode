#!/bin/bash
# Prove del motore dei passi e del file unico (Task 1)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src

test_passo_una_volta() {
    radice_finta
    aggiungi_x() { echo x >> "$RADICE/conta"; }
    passo prova aggiungi_x
    passo prova aggiungi_x
    uguale "1" "$(grep -c x "$RADICE/conta")" "il passo gira una volta sola"
}

test_impronta_cambiata() {
    radice_finta
    aggiungi_x() { echo x >> "$RADICE/conta"; }
    passo prova aggiungi_x
    aggiungi_x() { echo x >> "$RADICE/conta"; : cambiato; }
    passo prova aggiungi_x
    uguale "2" "$(grep -c x "$RADICE/conta")" "con un testo diverso il passo si rifa'"
}

test_ripresa_dopo_errore() {
    radice_finta
    export VETRO_EUID=0
    printf '#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' > "$RADICE/etc/pacman.conf"
    finto pacman
    uno() { echo 1 >> "$RADICE/fatti"; }
    due() { [ -e "$RADICE/corretto" ] || return 1; echo 2 >> "$RADICE/fatti"; }
    tre() { echo 3 >> "$RADICE/fatti"; }
    FASE1=("uno|uno|" "due|due|" "tre|tre|"); FASE2=(); FASE3=(); FASE4=()
    ( principale tutto ) >/dev/null 2>&1
    uguale "1" "$?" "con il secondo passo rotto lo script esce con 1"
    esiste "$VETRO_STATO/fatto/uno"
    non_esiste "$VETRO_STATO/fatto/tre"
    touch "$RADICE/corretto"
    ( principale tutto ) >/dev/null 2>&1
    uguale "0" "$?" "dopo la correzione lo script finisce"
    uguale "1 2 3" "$(tr '\n' ' ' < "$RADICE/fatti" | sed 's/ $//')" "il primo passo non si rifa'"
}

test_non_root_non_arch() {
    radice_finta
    rm -f "$RADICE/etc/arch-release"
    local msg
    msg=$( (controlla_arch) 2>&1 ); local rc=$?
    uguale "1" "$rc" "senza arch-release controlla_arch esce con 1"
    case "$msg" in *Arch*) ok_prova "il messaggio parla di Arch" ;; *) fallita "il messaggio parla di Arch: $msg" ;; esac
    ( VETRO_EUID=1000 serve_root ) >/dev/null 2>&1
    uguale "1" "$?" "da utente normale serve_root esce con 1"
}

test_file_unico() {
    local t; t=$(mktemp -d)
    mkdir -p "$t/file/etc"; echo "ciao vetro" > "$t/file/etc/prova.txt"
    bash "$ARCH_DIR/costruisci.sh" "$t/file" "$t/vetro-arch.sh" >/dev/null
    bash -n "$t/vetro-arch.sh"
    uguale "0" "$?" "il file unico non ha errori di sintassi"
    local aiuto; aiuto=$(VETRO_PROVA=1 bash "$t/vetro-arch.sh" aiuto 2>&1)
    case "$aiuto" in *controlla*registri*) ok_prova "aiuto elenca i comandi" ;; *) fallita "aiuto elenca i comandi: $aiuto" ;; esac
    bash "$t/vetro-arch.sh" _estrai "$t/estratti" >/dev/null 2>&1
    cmp -s "$t/file/etc/prova.txt" "$t/estratti/etc/prova.txt"
    uguale "0" "$?" "il file estratto dall'archivio e' uguale all'originale"
    rm -rf "$t"
}

test_errore_a_meta() {
    radice_finta
    a_meta() { false; echo dopo >> "$RADICE/dopo"; }
    ( passo prova a_meta ) >/dev/null 2>&1
    uguale "1" "$?" "un comando che fallisce a meta' ferma il passo"
    non_esiste "$RADICE/dopo"
    non_esiste "$VETRO_STATO/fatto/prova"
}

test_impronta_cartella() {
    radice_finta
    local t; t=$(mktemp -d); export VETRO_FILE=$t
    mkdir -p "$t/etc/x"; echo uno > "$t/etc/x/a"
    fn() { :; }
    local prima; prima=$(impronta fn etc/x)
    echo due > "$t/etc/x/a"
    if [ "$prima" != "$(impronta fn etc/x)" ]; then ok_prova "un file cambiato nella cartella cambia l'impronta"
    else fallita "un file cambiato nella cartella cambia l'impronta"; fi
}

test_installa_cartella() {
    radice_finta
    local t; t=$(mktemp -d); export VETRO_FILE=$t
    mkdir -p "$t/usr/local/bin" "$t/usr/local/bin/sotto"
    printf 'x\n' > "$t/usr/local/bin/a"; chmod 755 "$t/usr/local/bin/a"
    printf 'y\n' > "$t/usr/local/bin/sotto/b"; chmod 644 "$t/usr/local/bin/sotto/b"
    installa_cartella usr/local/bin
    uguale "755" "$(stat -c %a "$RADICE/usr/local/bin/a")" "permessi tenuti (755)"
    uguale "y" "$(cat "$RADICE/usr/local/bin/sotto/b")" "anche le sottocartelle"
}

prova test_passo_una_volta
prova test_impronta_cartella
prova test_installa_cartella
prova test_errore_a_meta
prova test_impronta_cambiata
prova test_ripresa_dopo_errore
prova test_non_root_non_arch
prova test_file_unico
riassunto
