# --- Il PC: la macchina virtuale con Vetro su Arch ---------------------------------------
#   sudo bash lfs.sh fase10     la prima volta installa Arch e poi Vetro; dopo aggiorna Vetro
#   sudo bash lfs.sh avvia      la accende con lo schermo
#   sudo bash lfs.sh registri | controlla   (senza schermo, risultato sul PC)
# Tutto sta in ~/vetro-arch dell'utente che ha fatto sudo (cartella_pc). QEMU gira come
# quell'utente. Un piccolo server (solo 127.0.0.1:8765, dalla macchina 10.0.2.2:8765)
# da' alla macchina lo script di installazione, le scelte e lfs.sh.
ISO_URL="https://geo.mirror.pkgbuild.com/iso/latest"
PC_PORTA=8765
QEMU=qemu-system-x86_64
VETRO_LFS=${VETRO_LFS:-}
PC_SERVER_PID=""

pc_utente() { echo "${SUDO_USER:-root}"; }

# i file della macchina appartengono all'utente (QEMU gira come lui)
pc_chown() {
    local u; u=$(pc_utente)
    [ "$u" = root ] || chown -R "$u": "$(cartella_pc)"
}

# pc_come_utente COMANDO...: come l'utente di sudo, con il suo schermo
pc_come_utente() {
    local u uid
    u=$(pc_utente)
    if [ "$u" = root ]; then esegui "$@"; return; fi
    uid=$(id -u "$u")
    local amb=(DISPLAY="${DISPLAY:-:0}")
    [ -n "${XAUTHORITY:-}" ] && amb+=(XAUTHORITY="$XAUTHORITY")
    if [ -d "/run/user/$uid" ]; then
        amb+=(XDG_RUNTIME_DIR="/run/user/$uid")
        [ -S "/run/user/$uid/wayland-0" ] && amb+=(WAYLAND_DISPLAY=wayland-0)
    fi
    esegui sudo -u "$u" env "${amb[@]}" "$@"
}

pc_qemu_pronto() {
    command -v "$QEMU" >/dev/null 2>&1 && command -v qemu-img >/dev/null 2>&1 && return 0
    titolo "Installo QEMU (la macchina virtuale)"
    if command -v dnf >/dev/null 2>&1; then
        esegui dnf install -y qemu-system-x86 qemu-img || true
        esegui dnf install -y qemu-audio-pipewire qemu-ui-gtk qemu-ui-opengl \
               qemu-device-display-virtio-vga-gl qemu-device-display-virtio-gpu-gl >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        esegui apt-get install -y qemu-system-x86 qemu-utils || true
    fi
    command -v "$QEMU" >/dev/null 2>&1 \
        || muori "Non riesco a installare QEMU: installalo a mano (Fedora: sudo dnf install qemu-system-x86 qemu-img)"
}

# dalla lista sha256sums.txt (su stdin) la riga della ISO con la data
scegli_iso() {
    grep -E '^[0-9a-f]+ +archlinux-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-x86_64\.iso$' | head -n 1 || true
}

# pc_iso -> il percorso della ISO di Arch del mese, scaricata e controllata (sha256)
pc_iso() {
    local c riga nome
    c=$(cartella_pc)
    riga=$(esegui curl -fsSL "$ISO_URL/sha256sums.txt" 2>/dev/null | scegli_iso || true)
    [ -n "$riga" ] || muori "Non riesco a leggere l'elenco delle ISO di Arch ($ISO_URL): controlla la rete"
    nome=${riga##* }
    if [ ! -f "$c/$nome" ]; then
        info "Scarico $nome (circa 1,2 GB)..." >&2
        esegui curl -fL --retry 3 -C - -o "$c/$nome.parziale" "$ISO_URL/$nome" >&2 \
            || muori "Download della ISO non riuscito: rilancia, riprende da dove era"
        mv -f "$c/$nome.parziale" "$c/$nome"
    fi
    if ! (cd "$c" && printf '%s\n' "$riga" | sha256sum -c --status); then
        rm -f "$c/$nome"
        muori "La ISO scaricata non passa il controllo (sha256): l'ho cancellata, rilancia"
    fi
    echo "$c/$nome"
}

# pc_parametri_iso CARTELLA -> i parametri di avvio di archiso (dalla ISO aperta)
pc_parametri_iso() {
    local d=$1 p
    p=$(grep -rhoE 'archisosearchuuid=[0-9A-Za-z_-]+' "$d/loader" "$d/boot" 2>/dev/null | head -n 1 || true)
    [ -n "$p" ] || p=$(grep -rhoE 'archisolabel=[0-9A-Za-z_-]+' "$d/loader" "$d/boot" 2>/dev/null | head -n 1 || true)
    [ -n "$p" ] || return 1
    echo "archisobasedir=arch $p"
}

# pc_kernel ISO: kernel, initramfs e parametri dalla ISO in ~/vetro-arch/avvio
pc_kernel() {
    local iso=$1 c m p riuscito=0
    c=$(cartella_pc)
    mkdir -p "$c/avvio"
    m=$(mktemp -d)
    esegui mount -o loop,ro "$iso" "$m" || { rmdir "$m"; muori "Non riesco ad aprire la ISO di Arch ($iso)"; }
    if cp -f "$m/arch/boot/x86_64/vmlinuz-linux" "$m/arch/boot/x86_64/initramfs-linux.img" "$c/avvio/" \
            && p=$(pc_parametri_iso "$m"); then
        echo "$p" > "$c/avvio/parametri"
        riuscito=1
    fi
    esegui umount "$m" || true
    rmdir "$m" 2>/dev/null || true
    [ "$riuscito" = 1 ] || muori "Nella ISO di Arch non trovo il kernel o i parametri di avvio"
}

# pc_impronta: la password da stdin -> la sua impronta ($6$..., come in /etc/shadow)
pc_impronta() {
    esegui openssl passwd -6 -stdin
}

# pc_chiedi_utente: nome e password (e quella del fantasma) -> condivisa/installa.conf
# (solo le impronte: la password in chiaro non esce dal PC). Nelle prove: VETRO_UTENTE,
# VETRO_PASSWORD, VETRO_PASSWORD_FANTASMA.
pc_chiedi_utente() {
    local c u p p2 pf i if_
    c=$(cartella_pc)
    mkdir -p "$c/condivisa"
    u=${VETRO_UTENTE:-}
    if [ -z "$u" ]; then
        read -r -p "  Nome del tuo utente nella macchina (minuscole, es. davide): " u
    fi
    [[ "$u" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
        || muori "Nome utente non valido: solo lettere minuscole, numeri, - e _ (es. davide)"
    if [ -n "${VETRO_PASSWORD+x}" ]; then
        p=$VETRO_PASSWORD
        pf=${VETRO_PASSWORD_FANTASMA:-}
    else
        while :; do
            read -r -s -p "  Password di $u: " p; echo
            read -r -s -p "  Ripetila: " p2; echo
            [ -n "$p" ] && [ "$p" = "$p2" ] && break
            avviso "Le due password non sono uguali (o sono vuote): riprova"
        done
        read -r -s -p "  Password dell'utente fantasma (Invio = la stessa): " pf; echo
    fi
    [ -n "$pf" ] || pf=$p
    i=$(printf '%s\n' "$p" | pc_impronta)
    if_=$(printf '%s\n' "$pf" | pc_impronta)
    [[ "$i" == '$6$'* && "$if_" == '$6$'* ]] || muori "Non riesco a fare l'impronta della password (manca openssl?)"
    ( umask 077; printf 'UTENTE=%q\nIMPRONTA=%q\nIMPRONTA_FANTASMA=%q\n' "$u" "$i" "$if_" > "$c/condivisa/installa.conf" )
    chmod 600 "$c/condivisa/installa.conf"
}

pc_crea_disco() {
    local d; d="$(cartella_pc)/disco.qcow2"
    rm -f "$d"
    esegui qemu-img create -f qcow2 "$d" 40G >/dev/null || muori "Non riesco a creare il disco virtuale ($d)"
}

pc_copia_lfs() {
    [ -n "$VETRO_LFS" ] && [ -f "$VETRO_LFS" ] || muori "Non trovo lfs.sh (lancialo con: sudo bash lfs.sh ...)"
    cp -f "$VETRO_LFS" "$(cartella_pc)/condivisa/lfs.sh"
}

# il server della cartella condivisa: GET per dare i file alla macchina, PUT per
# riceverli (solo nomi semplici; dei nomi col punto davanti solo .arch-ok e .esito)
PC_SERVER_PY='
import http.server, os, sys
CARTELLA = sys.argv[1]
PUNTO = {".arch-ok", ".esito"}
class Gestore(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=CARTELLA, **k)
    def log_message(self, *a):
        pass
    def do_PUT(self):
        nome = os.path.basename(self.path.split("?", 1)[0]) or "file"
        lunghezza = int(self.headers.get("Content-Length", "0"))
        if (nome.startswith(".") and nome not in PUNTO) or lunghezza > 200 * 1024 * 1024:
            self.send_error(403); return
        with open(os.path.join(CARTELLA, nome), "wb") as f:
            f.write(self.rfile.read(lunghezza))
        self.send_response(201); self.end_headers()
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[2])), Gestore).serve_forever()
'

pc_server_avvia() {
    [ -n "$PC_SERVER_PID" ] && kill -0 "$PC_SERVER_PID" 2>/dev/null && return 0
    local c; c=$(cartella_pc)
    pc_chown
    pc_come_utente python3 -I -c "$PC_SERVER_PY" "$c/condivisa" "$PC_PORTA" >/dev/null 2>&1 &
    PC_SERVER_PID=$!
    local _
    for _ in $(seq 1 25); do
        curl -fs -o /dev/null "http://127.0.0.1:$PC_PORTA/lfs.sh" && return 0
        sleep 0.2
    done
    muori "Il piccolo server per la macchina non parte: la porta $PC_PORTA e' occupata? (chiudi un altro lfs.sh e rilancia)"
}

pc_server_ferma() {
    [ -n "$PC_SERVER_PID" ] || return 0
    kill "$PC_SERVER_PID" 2>/dev/null || true
    PC_SERVER_PID=""
}

# pc_qemu installa|comando|avvia -> il comando di QEMU in COMANDO
pc_qemu() {
    local modo=$1 c cpu aiuto_dev aiuto_audio drv
    c=$(cartella_pc)
    cpu=$(( $(nproc) / 2 )); [ "$cpu" -ge 2 ] || cpu=2
    aiuto_dev=$(esegui "$QEMU" -device help 2>/dev/null || true)
    aiuto_audio=$(esegui "$QEMU" -audiodev help 2>/dev/null || true)
    COMANDO=("$QEMU" -name "Vetro su Arch")
    # KVM (il processore che aiuta la macchina virtuale): si guarda come l'utente di QEMU
    if pc_come_utente test -w /dev/kvm 2>/dev/null; then COMANDO+=(-machine q35,accel=kvm -cpu host)
    else COMANDO+=(-machine q35,accel=tcg -cpu max); fi
    COMANDO+=(-m "${RAM:-8192}" -smp "$cpu"
              -drive "file=$c/disco.qcow2,format=qcow2,if=virtio"
              -nic user,model=virtio-net-pci
              -device qemu-xhci -device usb-tablet)
    if grep -q '"virtio-9p-pci"' <<<"$aiuto_dev"; then
        COMANDO+=(-virtfs "local,path=$c/condivisa,mount_tag=vetro,security_model=mapped-xattr")
    fi
    case "$modo" in
        installa)
            local iso
            iso=$(ls -1 "$c"/archlinux-*-x86_64.iso 2>/dev/null | sort | tail -n 1 || true)
            COMANDO+=(-kernel "$c/avvio/vmlinuz-linux" -initrd "$c/avvio/initramfs-linux.img"
                      -append "$(cat "$c/avvio/parametri" 2>/dev/null) script=http://10.0.2.2:$PC_PORTA/installa-arch console=tty0 console=ttyS0,115200 systemd.mask=serial-getty@ttyS0.service"
                      -cdrom "$iso" -display none -serial file:/dev/stdout -no-reboot) ;;
        comando)
            COMANDO+=(-display none -serial file:/dev/stdout -no-reboot) ;;
        avvia)
            # schermo: due uscite (per provare piu' schermi), con il 3D del PC se c'e'
            if grep -q '"virtio-vga-gl"' <<<"$aiuto_dev" && [ "${GL:-si}" != no ]; then
                COMANDO+=(-vga none -device virtio-vga-gl,max_outputs=2,xres=1920,yres=1080
                          -display gtk,gl=on,zoom-to-fit=on)
            else
                COMANDO+=(-vga none -device virtio-vga,max_outputs=2,xres=1920,yres=1080
                          -display gtk,zoom-to-fit=on)
            fi
            # il suono va al PC (PipeWire o PulseAudio)
            for drv in pipewire pa alsa; do
                if grep -qw "$drv" <<<"$aiuto_audio"; then
                    COMANDO+=(-audiodev "$drv,id=suono" -device intel-hda -device hda-duplex,audiodev=suono)
                    break
                fi
            done ;;
    esac
}

# scrive un comando da copiare nel terminale (virgolette solo dove servono)
mostra_comando() {
    local a riga=""
    for a in "$@"; do
        if [[ "$a" =~ ^[A-Za-z0-9_,.:=/+@%-]+$ ]]; then riga+="$a "
        else riga+="'${a//\'/\'\\\'\'}' "; fi
    done
    printf '%s\n' "${riga% }"
}

# senza KVM tutto e' molto piu' lento: si dice perche' e come rimediare
pc_avviso_kvm() {
    avviso "Senza KVM la macchina e' molto lenta (anche ore). Attiva la virtualizzazione"
    avviso "(Intel VT-x / AMD-V) nel BIOS del PC; su Ubuntu: sudo usermod -aG kvm $(pc_utente)"
}

# pc_accendi MODO: accende la macchina (senza schermo per installa e comando)
pc_accendi() {
    pc_qemu "$1"
    case " ${COMANDO[*]} " in *"accel=tcg"*) pc_avviso_kvm ;; esac
    pc_chown
    pc_come_utente "${COMANDO[@]}" || true
}

pc_fase10() {
    serve_root fase10
    local c iso
    c=$(cartella_pc)
    mkdir -p "$c/condivisa" "$c/avvio"
    pc_qemu_pronto
    if [ ! -f "$c/condivisa/.arch-ok" ]; then
        titolo "1/2 - Installo Arch nella macchina virtuale (solo la prima volta)"
        [ -s "$c/condivisa/installa.conf" ] || pc_chiedi_utente
        iso=$(pc_iso)
        pc_crea_disco
        pc_kernel "$iso"
        cp -f "$VETRO_FILE/usr/local/lib/vetro/installa-arch" "$c/condivisa/installa-arch" 2>/dev/null || true
        pc_copia_lfs
        rm -f "$c/condivisa/installa-arch.log"
        pc_server_avvia
        info "La macchina parte senza schermo: qui sotto i suoi messaggi (ci vuole un po')."
        info "Non scrivere niente: fa tutto da sola (le domande di pacman hanno gia' la risposta)."
        pc_accendi installa
        [ -f "$c/condivisa/.arch-ok" ] \
            || muori "L'installazione di Arch non e' riuscita (il motivo e' in $c/condivisa/installa-arch.log). Rilancia:  sudo bash lfs.sh fase10"
        ok "Arch installato"
    fi
    rm -f "$c/condivisa/installa.conf"
    titolo "2/2 - Installo (o aggiorno) Vetro nella macchina"
    info "Non scrivere niente: fa tutto da sola. Se compare \"login:\", ignoralo."
    pc_copia_lfs
    rm -f "$c/condivisa/.esito"
    echo installa > "$c/condivisa/.comando"
    pc_server_avvia
    pc_accendi comando
    rm -f "$c/condivisa/.comando"
    if [ "$(cat "$c/condivisa/.esito" 2>/dev/null)" = ok ]; then
        titolo "Fatto. Ora:  sudo bash lfs.sh avvia"
    else
        muori "Vetro non si e' installato del tutto: guarda i messaggi qui sopra, poi rilancia  sudo bash lfs.sh fase10  (riprende da dove era)"
    fi
}

# pc_comando registri|controlla: la macchina lo esegue senza schermo e si spegne
pc_comando() {
    serve_root "$1"
    local c; c=$(cartella_pc)
    [ -f "$c/disco.qcow2" ] || muori "La macchina virtuale non c'e' ancora: prima  sudo bash lfs.sh fase10"
    pc_copia_lfs
    rm -f "$c/condivisa/.esito"
    echo "$1" > "$c/condivisa/.comando"
    pc_server_avvia
    pc_accendi comando
    rm -f "$c/condivisa/.comando"
    if [ "$1" = registri ]; then
        ok "I registri sono in: $c/condivisa/registri-vetro.txt"
    fi
}

pc_avvia() {
    local prova=${1:-} c t0 esito=0
    [ "$prova" = --prova ] || serve_root avvia
    c=$(cartella_pc)
    [ -f "$c/disco.qcow2" ] || [ "$prova" = --prova ] \
        || muori "La macchina virtuale non c'e' ancora: prima  sudo bash lfs.sh fase10"
    rm -f "$c/condivisa/.comando"
    pc_qemu avvia
    if [ "$prova" = --prova ]; then
        mostra_comando "${COMANDO[@]}"
        return 0
    fi
    info "Chiudi la finestra per spegnere. Schermo intero: Ctrl+Alt+F."
    pc_chown
    t0=$SECONDS
    pc_come_utente "${COMANDO[@]}" || esito=$?
    # con il 3D QEMU a volte non apre la finestra: si riprova senza
    if [ "$esito" -ne 0 ] && [ $(( SECONDS - t0 )) -lt 20 ] && [ "${GL:-si}" != no ]; then
        avviso "QEMU non e' partito con il 3D: riprovo senza"
        GL=no pc_qemu avvia
        pc_come_utente "${COMANDO[@]}" || true
    fi
}
