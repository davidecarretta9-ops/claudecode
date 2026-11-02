#!/bin/bash
# Prove di vetro-vm.sh, la macchina virtuale di prova (Task 12)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
VM="$ARCH_DIR/vm/vetro-vm.sh"

# un qemu-system-x86_64 finto: con o senza 9p (cartella condivisa)
qemu_finto() {   # qemu_finto si|no
    mkdir -p "$PROVA_DIR/bin"
    {
        echo '#!/bin/bash'
        echo 'case "$*" in'
        echo '  "-device help")'
        echo '    echo "name \"virtio-vga\", bus PCI"'
        echo '    echo "name \"virtio-vga-gl\", bus PCI"'
        [ "$1" = si ] && echo '    echo "name \"virtio-9p-pci\", bus PCI, alias \"virtio-9p\""'
        echo '    ;;'
        echo '  "-audiodev help") printf "Available audio drivers:\nnone\npipewire\nalsa\n" ;;'
        echo 'esac'
    } > "$PROVA_DIR/bin/qemu-system-x86_64"
    chmod +x "$PROVA_DIR/bin/qemu-system-x86_64"
}

prepara() {
    PROVA_DIR=$(mktemp -d)
    export VETRO_VM_CARTELLA="$PROVA_DIR/vetro-arch"
    mkdir -p "$VETRO_VM_CARTELLA"
    : > "$VETRO_VM_CARTELLA/disco.qcow2"
}

test_sintassi() {
    if bash -n "$VM"; then ok_prova "vetro-vm.sh: sintassi"; else fallita "vetro-vm.sh: sintassi"; fi
}

test_avvia_con_9p() {
    prepara; qemu_finto si
    PATH="$PROVA_DIR/bin:$PATH" bash "$VM" avvia --prova > "$PROVA_DIR/uscita" 2>&1
    uguale 0 "$?" "avvia --prova esce bene"
    contiene "$PROVA_DIR/uscita" "max_outputs=2"
    contiene "$PROVA_DIR/uscita" "usb-tablet"
    contiene "$PROVA_DIR/uscita" "mount_tag=vetro"
    contiene "$PROVA_DIR/uscita" "virtio-vga-gl"
    contiene "$PROVA_DIR/uscita" "-m 8192"
    contiene "$PROVA_DIR/uscita" "pipewire,id=suono"
    non_contiene "$PROVA_DIR/uscita" "10.0.2.2:8765"
    non_contiene "$PROVA_DIR/uscita" "-cdrom"
    rm -rf "$PROVA_DIR"
}

test_avvia_senza_9p() {
    prepara; qemu_finto no
    PATH="$PROVA_DIR/bin:$PATH" bash "$VM" avvia --prova > "$PROVA_DIR/uscita" 2>&1
    contiene "$PROVA_DIR/uscita" "10.0.2.2:8765"
    non_contiene "$PROVA_DIR/uscita" "mount_tag=vetro"
    rm -rf "$PROVA_DIR"
}

test_installa() {
    prepara; qemu_finto si
    : > "$VETRO_VM_CARTELLA/archlinux-2026.11.01-x86_64.iso"
    PATH="$PROVA_DIR/bin:$PATH" bash "$VM" installa --prova > "$PROVA_DIR/uscita" 2>&1
    contiene "$PROVA_DIR/uscita" "-cdrom"
    contiene "$PROVA_DIR/uscita" "archlinux-2026.11.01-x86_64.iso"
    rm -rf "$PROVA_DIR"
}

test_scelta_iso() {
    # dalla lista sha256sums.txt si prende la ISO con la data
    local lista riga
    lista=$'aaaa  archlinux-bootstrap-2026.11.01-x86_64.tar.zst\nbbbb  archlinux-2026.11.01-x86_64.iso\ncccc  archlinux-x86_64.iso\n'
    riga=$(VETRO_VM_SOLO_FUNZIONI=1 bash -c "source '$VM'; scegli_iso" <<<"$lista")
    uguale "bbbb  archlinux-2026.11.01-x86_64.iso" "$riga" "si sceglie la ISO con la data"
}

test_guida() {
    local g="$ARCH_DIR/GUIDA-INSTALLAZIONE.md"
    contiene "$g" "archinstall"
    contiene "$g" "ext4"
    contiene "$g" "LUKS"
    contiene "$g" "minimal"
    contiene "$g" "pipewire"
    contiene "$g" "mount -t 9p -o trans=virtio,version=9p2000.L vetro /mnt/vetro"
    contiene "$g" "bash /mnt/vetro/vetro-arch.sh"
    contiene "$g" "10.0.2.2:8765"
}

prova test_sintassi
prova test_avvia_con_9p
prova test_avvia_senza_9p
prova test_installa
test_installa_senza_iso() {
    prepara; qemu_finto si
    PATH="$PROVA_DIR/bin:$PATH" bash "$VM" installa --prova > "$PROVA_DIR/uscita" 2>&1
    uguale 1 "$?" "senza ISO si ferma"
    contiene "$PROVA_DIR/uscita" "Non trovo la ISO di Arch"
    rm -rf "$PROVA_DIR"
}

prova test_installa_senza_iso
prova test_scelta_iso
prova test_guida
riassunto
