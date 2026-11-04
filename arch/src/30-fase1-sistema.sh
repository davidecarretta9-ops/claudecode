# --- Fase 1: sistema leggero ---------------------------------------------------------
PKG_FASE1=(zram-generator python sudo)
# il logo di oversicaOS, "Orbita" (disegnato da strumenti/disegna-logo.py)
FILE_LOGO="usr/share/icons/hicolor/scalable/apps/oversicaos.svg usr/share/icons/hicolor/scalable/apps/oversicaos-segno.svg usr/share/icons/hicolor/16x16/apps/oversicaos.png usr/share/icons/hicolor/24x24/apps/oversicaos.png usr/share/icons/hicolor/32x32/apps/oversicaos.png usr/share/icons/hicolor/48x48/apps/oversicaos.png usr/share/icons/hicolor/64x64/apps/oversicaos.png usr/share/icons/hicolor/128x128/apps/oversicaos.png usr/share/icons/hicolor/256x256/apps/oversicaos.png usr/share/icons/hicolor/512x512/apps/oversicaos.png"
FASE1=(
    "leggero|f1_leggero|etc/systemd/zram-generator.conf etc/systemd/oomd.conf.d/vetro.conf etc/systemd/journald.conf.d/vetro.conf"
    "utente|f1_utente|"
    "nome|f1_nome|etc/os-release $FILE_LOGO"
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

# il nome oversicaOS: /etc/os-release (prima era un collegamento al file di Arch: lo si
# sostituisce, quello di Arch resta com'e'), logo, nome del computer, voce di GRUB
f1_nome() {
    rm -f "$(percorso /etc/os-release)"
    # shellcheck disable=SC2086
    installa_file etc/os-release $FILE_LOGO
    esegui gtk-update-icon-cache -qtf "$(percorso /usr/share/icons/hicolor)" || true
    esegui hostnamectl set-hostname oversica || avviso "Non riesco a cambiare il nome del computer"
    local g; g=$(percorso /etc/default/grub)
    if [ -f "$g" ]; then
        if grep -q '^GRUB_DISTRIBUTOR=' "$g"; then
            sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="oversicaOS"|' "$g"
        else
            echo 'GRUB_DISTRIBUTOR="oversicaOS"' >> "$g"
        fi
        esegui grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 || avviso "Non riesco a rifare il menu di avvio"
    fi
    ok "Nome oversicaOS e logo"
}
