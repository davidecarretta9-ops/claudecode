# Utente fantasma (creato da lfs.sh): tutto quello che fai qui sta solo in memoria e
# sparisce allo spegnimento. Internet passa tutto da Tor (modalita' fantasma), l'ora
# dei programmi e' quella universale (UTC) e i comandi scritti non vengono ricordati.
export PATH="/usr/local/bin:$PATH"
export WLR_RENDERER=pixman
export TZ=UTC
export HISTFILE=/dev/null
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="/tmp/$(id -u)-runtime-dir"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi
if [ "$(tty)" = /dev/tty1 ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    export LANG=it_IT.UTF-8
    echo "Accendo la modalita' fantasma (tutto passera' da Tor)..."
    if ! sudo -n /usr/local/sbin/fantasma-aiuto accendi; then
        echo "Non riesco ad accendere la modalita' fantasma: per sicurezza il desktop non parte."
        sleep 10
        exit 1
    fi
    if systemd-detect-virt -q; then export WLR_NO_HARDWARE_CURSORS=1; fi
    if dbus-run-session labwc > "$HOME/.labwc.log" 2>&1; then
        exit
    fi
    echo "Il desktop si e' chiuso con un errore. Il registro e' in: $HOME/.labwc.log"
fi
