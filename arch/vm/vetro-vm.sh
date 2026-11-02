#!/bin/bash
# =============================================================================
#  vetro-vm.sh — prova Vetro su Arch in una macchina virtuale (QEMU) sul tuo PC.
#  Si lancia come utente normale (non serve sudo). Guida: GUIDA-INSTALLAZIONE.md
#
#    bash vetro-vm.sh crea       disco virtuale (40 GB) e ISO di Arch (controllata)
#    bash vetro-vm.sh installa   accende dalla ISO: installi Arch con archinstall
#    bash vetro-vm.sh avvia      accende l'Arch installato
#    ... --prova                 scrive il comando di QEMU invece di lanciarlo
#
#  Tutto sta in ~/vetro-arch. La cartella ~/vetro-arch/condivisa si vede dentro la
#  macchina (in /mnt/vetro): mettici vetro-arch.sh, e li' finiscono i registri.
# =============================================================================
set -Eeuo pipefail

CARTELLA=${VETRO_VM_CARTELLA:-$HOME/vetro-arch}
DISCO="$CARTELLA/disco.qcow2"
CONDIVISA="$CARTELLA/condivisa"
ISO_URL="https://geo.mirror.pkgbuild.com/iso/latest"
QEMU=qemu-system-x86_64
PORTA=8765
QUI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

info()   { printf '  %s\n' "$*"; }
ok()     { printf '  [OK] %s\n' "$*"; }
avviso() { printf '  [!!] %s\n' "$*" >&2; }
muori()  { printf '\n  [ERRORE] %s\n\n' "$*" >&2; exit 1; }

# dalla lista sha256sums.txt (su stdin) la riga della ISO con la data
scegli_iso() {
    grep -E '^[0-9a-f]+ +archlinux-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-x86_64\.iso$' | head -n 1
}

serve_qemu() {
    command -v "$QEMU" >/dev/null 2>&1 && return 0
    muori "Manca QEMU. Fedora:  sudo dnf install qemu-system-x86 qemu-img   Ubuntu:  sudo apt install qemu-system-x86 qemu-utils"
}

cmd_crea() {
    serve_qemu
    command -v qemu-img >/dev/null 2>&1 || muori "Manca qemu-img (Fedora: sudo dnf install qemu-img)"
    mkdir -p "$CARTELLA" "$CONDIVISA"
    if [ -f "$DISCO" ]; then
        info "Il disco virtuale c'e' gia': $DISCO"
    else
        qemu-img create -f qcow2 "$DISCO" 40G >/dev/null
        ok "Disco virtuale: $DISCO (40 GB, occupa spazio solo quando si riempie)"
    fi
    # la ISO di Arch di questo mese, controllata con la lista sha256 dello stesso sito
    local riga nome
    riga=$(curl -fsSL "$ISO_URL/sha256sums.txt" | scegli_iso) \
        || muori "Non riesco a leggere $ISO_URL/sha256sums.txt: controlla la rete"
    [ -n "$riga" ] || muori "Nella lista di Arch non trovo la ISO"
    nome=${riga##* }
    if [ ! -f "$CARTELLA/$nome" ]; then
        info "Scarico $nome (circa 1,2 GB)..."
        curl -fL --retry 3 -C - -o "$CARTELLA/$nome.parziale" "$ISO_URL/$nome" \
            || muori "Download della ISO non riuscito: rilancia, riprende da dove era"
        mv "$CARTELLA/$nome.parziale" "$CARTELLA/$nome"
    fi
    if ! (cd "$CARTELLA" && printf '%s\n' "$riga" | sha256sum -c --status); then
        rm -f "$CARTELLA/$nome"
        muori "La ISO scaricata non passa il controllo (sha256): l'ho cancellata, rilancia"
    fi
    ok "ISO di Arch controllata: $CARTELLA/$nome"
    # vetro-arch.sh nella cartella condivisa (se e' accanto a questo script)
    if [ -f "$QUI/vetro-arch.sh" ]; then
        cp -f "$QUI/vetro-arch.sh" "$CONDIVISA/vetro-arch.sh"
        ok "vetro-arch.sh copiato in $CONDIVISA"
    else
        avviso "Metti vetro-arch.sh in $CONDIVISA"
    fi
    info "Adesso:  bash $0 installa"
}

# il comando di QEMU (in COMANDO) per accendere dalla ISO (installa) o dal disco
prepara_qemu() {
    local modo=$1 iso="" cpu aiuto_dev aiuto_audio drv
    serve_qemu
    [ -f "$DISCO" ] || muori "Non trovo il disco virtuale: prima  bash $0 crea"
    if [ "$modo" = installa ]; then
        iso=$(ls -1 "$CARTELLA"/archlinux-*-x86_64.iso 2>/dev/null | sort | tail -n 1 || true)
        [ -n "$iso" ] || muori "Non trovo la ISO di Arch: prima  bash $0 crea"
    fi
    mkdir -p "$CONDIVISA"
    cpu=$(( $(nproc) / 2 )); [ "$cpu" -ge 2 ] || cpu=2
    aiuto_dev=$("$QEMU" -device help 2>/dev/null || true)
    aiuto_audio=$("$QEMU" -audiodev help 2>/dev/null || true)
    COMANDO=("$QEMU" -name "Vetro su Arch")
    if [ -w /dev/kvm ]; then COMANDO+=(-machine q35,accel=kvm -cpu host)
    else COMANDO+=(-machine q35,accel=tcg -cpu max); avviso "Senza KVM la macchina sara' lenta"; fi
    COMANDO+=(-m "${RAM:-8192}" -smp "$cpu"
              -drive "file=$DISCO,format=qcow2,if=virtio"
              -nic user,model=virtio-net-pci
              -device qemu-xhci -device usb-tablet)
    # schermo: due uscite (per provare piu' schermi), con il 3D del tuo PC se c'e'
    if grep -q '"virtio-vga-gl"' <<<"$aiuto_dev" && [ "${GL:-si}" != no ]; then
        COMANDO+=(-vga none -device virtio-vga-gl,max_outputs=2,xres=1920,yres=1080
                  -display gtk,gl=on,zoom-to-fit=on)
    else
        COMANDO+=(-vga none -device virtio-vga,max_outputs=2,xres=1920,yres=1080
                  -display gtk,zoom-to-fit=on)
    fi
    # il suono va al tuo PC (PipeWire o PulseAudio)
    for drv in pipewire pa alsa; do
        if grep -qw "$drv" <<<"$aiuto_audio"; then
            COMANDO+=(-audiodev "$drv,id=suono" -device intel-hda -device hda-duplex,audiodev=suono)
            break
        fi
    done
    # la cartella condivisa: 9p se QEMU lo sa fare, se no un piccolo server sul tuo PC
    CON_9P=0
    if grep -q '"virtio-9p-pci"' <<<"$aiuto_dev"; then
        COMANDO+=(-virtfs "local,path=$CONDIVISA,mount_tag=vetro,security_model=mapped-xattr")
        CON_9P=1
    fi
    if [ -n "$iso" ]; then COMANDO+=(-cdrom "$iso" -boot d); fi
}

# server della cartella condivisa (senza 9p): GET per scaricare, PUT per caricare
SERVER_PY='
import http.server, os, sys
CARTELLA = sys.argv[1]
class Gestore(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=CARTELLA, **k)
    def do_PUT(self):
        nome = os.path.basename(self.path.split("?", 1)[0]) or "file"
        lunghezza = int(self.headers.get("Content-Length", "0"))
        if nome.startswith(".") or lunghezza > 200 * 1024 * 1024:
            self.send_error(403); return
        with open(os.path.join(CARTELLA, nome), "wb") as f:
            f.write(self.rfile.read(lunghezza))
        self.send_response(201); self.end_headers()
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[2])), Gestore).serve_forever()
'

spiega_condivisa() {
    if [ "$CON_9P" = 1 ]; then
        info "Cartella condivisa: $CONDIVISA  ->  dentro la macchina:"
        info "  sudo mkdir -p /mnt/vetro && sudo mount -t 9p -o trans=virtio,version=9p2000.L vetro /mnt/vetro"
    else
        info "Cartella condivisa: $CONDIVISA  ->  dentro la macchina (questo QEMU non ha 9p):"
        info "  scaricare:  curl -O http://10.0.2.2:$PORTA/vetro-arch.sh"
        info "  caricare:   curl -T /root/registri-vetro.txt http://10.0.2.2:$PORTA/"
    fi
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

cmd_accendi() {   # cmd_accendi installa|avvia [--prova]
    local modo=$1 prova=${2:-} server=""
    prepara_qemu "$modo"
    spiega_condivisa
    if [ "$prova" = --prova ]; then
        mostra_comando "${COMANDO[@]}"
        return 0
    fi
    if [ "$CON_9P" = 0 ]; then
        python3 -I -c "$SERVER_PY" "$CONDIVISA" "$PORTA" >/dev/null 2>&1 &
        server=$!
        trap '[ -n "$server" ] && kill "$server" 2>/dev/null' EXIT
    fi
    info "Chiudi la finestra per spegnere. Schermo intero: Ctrl+Alt+F."
    local t0=$SECONDS esito=0
    "${COMANDO[@]}" || esito=$?
    # con il 3D QEMU a volte non apre la finestra: si riprova senza
    if [ "$esito" -ne 0 ] && [ $(( SECONDS - t0 )) -lt 20 ] && [ "${GL:-si}" != no ]; then
        avviso "QEMU non e' partito con il 3D: riprovo senza"
        GL=no prepara_qemu "$modo"
        "${COMANDO[@]}"
    fi
}

principale() {
    case "${1:-aiuto}" in
        crea)     cmd_crea ;;
        installa) cmd_accendi installa "${2:-}" ;;
        avvia)    cmd_accendi avvia "${2:-}" ;;
        *)        sed -n '3,14p' "$0" | sed 's/^#  \{0,1\}//' ;;
    esac
}

# VETRO_VM_SOLO_FUNZIONI=1: solo le funzioni (per le prove)
if [ -z "${VETRO_VM_SOLO_FUNZIONI:-}" ]; then principale "$@"; fi
