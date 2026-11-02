# --- Fase 1: sistema leggero ---------------------------------------------------------
PKG_FASE1=(zram-generator python sudo)
FASE1=(
    "leggero|f1_leggero|etc/systemd/zram-generator.conf etc/systemd/oomd.conf.d/vetro.conf etc/systemd/journald.conf.d/vetro.conf"
    "utente|f1_utente|"
)

# il tuo utente: quello scritto in /etc/vetro/utente, altrimenti quello con UID 1000
# (lo crea archinstall), che poi si scrive li'
utente_vetro() {
    local f u; f=$(percorso /etc/vetro/utente)
    if [ -s "$f" ]; then cat "$f"; return 0; fi
    u=$(esegui getent passwd 1000 | cut -d: -f1)
    [ -n "$u" ] || muori "Non trovo il tuo utente (UID 1000): crealo con archinstall, poi rilancia"
    mkdir -p "$(dirname "$f")"
    printf '%s\n' "$u" > "$f"
    printf '%s\n' "$u"
}

f1_leggero() {
    installa_pacchetti "${PKG_FASE1[@]}"
    installa_file etc/systemd/zram-generator.conf etc/systemd/oomd.conf.d/vetro.conf \
                  etc/systemd/journald.conf.d/vetro.conf
    esegui systemctl enable systemd-oomd.service
    # servizi che qui non servono (la rete la fa systemd-networkd, vedi Fase 2)
    local s
    for s in NetworkManager.service cups.service; do
        if [ -e "$(percorso "/usr/lib/systemd/system/$s")" ]; then esegui systemctl disable --now "$s"; fi
    done
    if [ -e "$(percorso /usr/lib/systemd/system/bluetooth.service)" ] \
       && [ -z "$(ls -A "$(percorso /sys/class/bluetooth)" 2>/dev/null)" ]; then
        esegui systemctl disable --now bluetooth.service
    fi
    ok "Memoria compressa (zram), guardiano della memoria e registro leggero"
}

f1_utente() {
    local u; u=$(utente_vetro) || exit 1
    esegui usermod -aG wheel,video,input,audio "$u"
    local f; f=$(percorso /etc/sudoers.d/00-vetro)
    mkdir -p "$(dirname "$f")"
    printf '# vetro-arch.sh: chi e'"'"' nel gruppo wheel puo'"'"' usare sudo (con la password)\n%%wheel ALL=(ALL) ALL\n' > "$f"
    chmod 440 "$f"
    esegui visudo -cf "$f" >/dev/null
    ok "Utente $u: gruppi e sudo"
}
