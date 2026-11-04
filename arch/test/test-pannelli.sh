#!/bin/bash
# Prove di avvia-pannelli: Quickshell che si blocca va chiuso e riavviato da solo
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
AVVIA="$F/usr/local/bin/avvia-pannelli"

# prepara: quickshell finto che resta acceso; qs finto che risponde "ok" le prime N volte
prepara_pannelli() {
    radice_finta
    mkdir -p "$RADICE/casa"
    : > "$RADICE/risposte"
    finto_con quickshell <<'FINE'
exec sleep 301
FINE
    finto_con qs <<FINE
n=\$(wc -l < "$RADICE/risposte")
echo x >> "$RADICE/risposte"
[ "\$n" -lt "\$QS_RISPONDE" ] && echo ok
exit 0
FINE
    finto_con hyprctl <<'FINE'
exit 0
FINE
    finto notify-send
    # dopo la prima volta Hyprland "non c'e' piu'": avvia-pannelli esce dal giro
    finto pgrep 1
}

test_pannelli_bloccati() {
    prepara_pannelli
    HOME="$RADICE/casa" PATH="$RADICE/.finti:$PATH" QS_RISPONDE=1 VETRO_OGNI=0.2 \
        timeout 30 bash "$AVVIA" >/dev/null 2>&1
    uguale 0 "$?" "avvia-pannelli finisce (non resta appeso)"
    local reg="$RADICE/casa/.cache/quickshell-vetro.log"
    contiene "$reg" "i pannelli non rispondono"
    contiene "$reg" "Hyprland risponde"
    if pgrep -fx "sleep 301" >/dev/null; then fallita "il Quickshell bloccato e' rimasto acceso"; pkill -fx "sleep 301"
    else ok_prova "il Quickshell bloccato e' stato chiuso"; fi
}

test_pannelli_che_rispondono() {
    prepara_pannelli
    # quickshell che si chiude da solo dopo un po': nessun riavvio forzato
    finto_con quickshell <<'FINE'
sleep 2
FINE
    HOME="$RADICE/casa" PATH="$RADICE/.finti:$PATH" QS_RISPONDE=1000 VETRO_OGNI=0.2 \
        timeout 30 bash "$AVVIA" >/dev/null 2>&1
    uguale 0 "$?" "avvia-pannelli finisce"
    non_contiene "$RADICE/casa/.cache/quickshell-vetro.log" "non rispondono"
}

test_avvia_caelestia() {
    prepara_pannelli
    finto_con quickshell <<'FINE'
sleep 3
FINE
    HOME="$RADICE/casa" PATH="$RADICE/.finti:$PATH" QS_RISPONDE=1000 VETRO_OGNI=0.2 \
        timeout 30 bash "$AVVIA" >/dev/null 2>&1
    chiamato "quickshell -c caelestia"
    chiamato "qs -c caelestia ipc call oversica ping"
    non_chiamato "/etc/xdg/quickshell/vetro"
}

test_tasto_di_emergenza() {
    # Ctrl+Alt+Backspace chiude i pannelli bloccati (avvia-pannelli li riapre)
    contiene "$F/etc/xdg/hypr/vetro.lua" 'hl.bind("CTRL + ALT + BACKSPACE", hl.dsp.exec_cmd("pkill -KILL -x quickshell"))'
}

prova test_pannelli_bloccati
prova test_pannelli_che_rispondono
prova test_avvia_caelestia
prova test_tasto_di_emergenza
riassunto
