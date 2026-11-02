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
    uno() { echo 1 >> "$RADICE/fatti"; }
    due() { [ -e "$RADICE/corretto" ] || return 1; echo 2 >> "$RADICE/fatti"; }
    tre() { echo 3 >> "$RADICE/fatti"; }
    FASE1=("uno|uno|" "due|due|" "tre|tre|")
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

prova test_passo_una_volta
prova test_errore_a_meta
prova test_impronta_cambiata
prova test_ripresa_dopo_errore
prova test_non_root_non_arch
prova test_file_unico
riassunto
