#!/bin/bash
# Prove del lfs.sh unico: installazione di Arch nella macchina, servizio dei comandi e
# parte "PC" (fase10, avvia, registri, controlla)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
INSTALLA="$F/usr/local/lib/vetro/installa-arch"
COMANDO="$F/usr/local/sbin/vetro-comando"

# comandi finti per gli script che non passano da "esegui" (si mettono in PATH)
bin_finti() {
    BIN="$RADICE/bin-finti"; mkdir -p "$BIN"
    local c
    for c in "$@"; do
        printf '#!/bin/bash\necho "%s $*" >> "%s/.chiamate"\n' "$c" "$RADICE" > "$BIN/$c"
        chmod +x "$BIN/$c"
    done
}
bin_finto_con() {   # bin_finto_con NOME  (corpo da stdin)
    { printf '#!/bin/bash\necho "%s $*" >> "%s/.chiamate"\n' "$1" "$RADICE"; cat; } > "$BIN/$1"
    chmod +x "$BIN/$1"
}

# --- installazione di Arch -----------------------------------------------------------
test_installa_arch() {
    if bash -n "$INSTALLA"; then ok_prova "installa-arch: sintassi"; else fallita "installa-arch: sintassi"; fi
    contiene "$INSTALLA" "pacstrap -K /mnt base linux linux-firmware e2fsprogs grub sudo"
    contiene "$INSTALLA" "grub-install --target=i386-pc"
    contiene "$INSTALLA" "console=ttyS0"
    contiene "$INSTALLA" "vetro /mnt/vetro 9p trans=virtio,version=9p2000.L"
    contiene "$INSTALLA" "mkfs.ext4 -F -q -O encrypt"
    contiene "$INSTALLA" "chmod 600"
    contiene "$INSTALLA" "INSTALLAZIONE NON RIUSCITA"
    # niente "login:" sulla seriale (confonde nel terminale del PC) e niente prove ext2/ext3
    contiene "$INSTALLA" "systemctl mask serial-getty@ttyS0.service"
    contiene "$INSTALLA" "mount -t ext4"
    contiene "$INSTALLA" "systemctl enable systemd-networkd.service systemd-resolved.service"
    contiene "$INSTALLA" "vetro-comando.service"
    contiene "$INSTALLA" ".arch-ok"
    if [ -x "$INSTALLA" ]; then ok_prova "installa-arch si puo' eseguire"; else fallita "installa-arch non eseguibile"; fi
}

# --- il servizio dei comandi -----------------------------------------------------------
test_comando_da_cartella() {
    radice_finta; bin_finti systemctl curl
    mkdir -p "$RADICE/mnt/vetro" "$RADICE/usr/local/sbin"
    echo registri > "$RADICE/mnt/vetro/.comando"
    printf '#!/bin/bash\necho "lfs.sh $*" >> "%s/.chiamate"\n' "$RADICE" > "$RADICE/mnt/vetro/lfs.sh"
    PATH="$BIN:$PATH" bash "$COMANDO" >/dev/null 2>&1
    uguale 0 "$?" "vetro-comando finisce bene"
    chiamato "lfs.sh registri"
    chiamato "systemctl poweroff"
    non_esiste "$RADICE/mnt/vetro/.comando"
    esiste "$RADICE/usr/local/sbin/lfs.sh"
    non_chiamato "curl"
}

test_comando_da_http() {
    radice_finta; bin_finti systemctl
    mkdir -p "$RADICE/usr/local/sbin"
    bin_finto_con curl <<FINE
case "\$*" in
  *.comando*) echo controlla ;;
  *lfs.sh*) while [ \$# -gt 0 ]; do [ "\$1" = -o ] && { printf '#!/bin/bash\\necho "lfs.sh \$*" >> "$RADICE/.chiamate"\\n' > "\$2"; shift; }; shift; done ;;
esac
FINE
    PATH="$BIN:$PATH" bash "$COMANDO" >/dev/null 2>&1
    chiamato "lfs.sh controlla"
    chiamato "systemctl poweroff"
}

test_senza_comando() {
    radice_finta; bin_finti systemctl
    bin_finto_con curl <<'FINE'
exit 7
FINE
    mkdir -p "$RADICE/mnt/vetro"
    PATH="$BIN:$PATH" bash "$COMANDO" >/dev/null 2>&1
    uguale 0 "$?" "senza comando esce bene"
    non_chiamato "systemctl"
    non_chiamato "lfs.sh"
}

test_comando_sconosciuto() {
    radice_finta; bin_finti systemctl curl
    mkdir -p "$RADICE/mnt/vetro" "$RADICE/usr/local/sbin"
    echo "rm -rf /" > "$RADICE/mnt/vetro/.comando"
    printf '#!/bin/bash\necho "lfs.sh $*" >> "%s/.chiamate"\n' "$RADICE" > "$RADICE/mnt/vetro/lfs.sh"
    PATH="$BIN:$PATH" bash "$COMANDO" >/dev/null 2>&1
    non_chiamato "lfs.sh rm"
    non_chiamato "systemctl poweroff"
}

test_servizio() {
    local s="$F/etc/systemd/system/vetro-comando.service"
    contiene "$s" "After=network-online.target local-fs.target"
    contiene "$s" "Wants=network-online.target"
    contiene "$s" "Type=oneshot"
    contiene "$s" "ExecStart=/usr/local/sbin/vetro-comando"
    contiene "$s" "StandardOutput=journal+console"
    contiene "$s" "TimeoutStartSec=infinity"
    contiene "$s" "WantedBy=multi-user.target"
    if [ -x "$COMANDO" ] && bash -n "$COMANDO"; then ok_prova "vetro-comando: sintassi"
    else fallita "vetro-comando manca, non e' eseguibile o ha errori"; fi
}

# --- la parte "PC" ------------------------------------------------------------------------
# una macchina finta: cartella, disco, file di avvio estratti dalla ISO
pc_finto() {
    radice_finta
    export VETRO_PC="$RADICE/pc/vetro-arch" VETRO_LFS="$RADICE/lfs.sh" SUDO_USER=root
    mkdir -p "$VETRO_PC/condivisa" "$VETRO_PC/avvio"
    echo "# lfs.sh finto" > "$VETRO_LFS"
    : > "$VETRO_PC/avvio/vmlinuz-linux"; : > "$VETRO_PC/avvio/initramfs-linux.img"
    echo "archisobasedir=arch archisosearchuuid=2026-11-01-10-00-00-00" > "$VETRO_PC/avvio/parametri"
    : > "$VETRO_PC/archlinux-2026.11.01-x86_64.iso"
    finto_con qemu-system-x86_64 <<'FINE'
case "$*" in
  "-device help") printf 'name "virtio-vga-gl", bus PCI\nname "virtio-9p-pci", bus PCI\n' ;;
  "-audiodev help") printf 'Available audio drivers:\npipewire\n' ;;
esac
FINE
}

test_parametri_iso() {
    radice_finta
    local iso="$RADICE/iso"
    mkdir -p "$iso/loader/entries" "$iso/boot/syslinux"
    echo "options archisobasedir=arch archisosearchuuid=2026-11-01-10-00-00-00 cow_spacesize=4G" \
        > "$iso/loader/entries/01-archiso-x86_64-linux.conf"
    uguale "archisobasedir=arch archisosearchuuid=2026-11-01-10-00-00-00" "$(pc_parametri_iso "$iso")" "parametri con uuid"
    rm -rf "$iso/loader"
    echo "APPEND archisobasedir=arch archisolabel=ARCH_202611" > "$iso/boot/syslinux/archiso_sys-linux.cfg"
    uguale "archisobasedir=arch archisolabel=ARCH_202611" "$(pc_parametri_iso "$iso")" "parametri con etichetta"
}

test_impronta_password() {
    radice_finta
    finto_con openssl <<FINE
cat > "$RADICE/stdin"
echo '\$6\$sale\$finta'
FINE
    local p="la mia pass 'con\" \$simboli"
    uguale '$6$sale$finta' "$(printf '%s' "$p" | pc_impronta)" "impronta da openssl"
    uguale "$p" "$(cat "$RADICE/stdin")" "la password arriva intera da stdin"
    chiamato "openssl passwd -6 -stdin"
}

test_installa_conf() {
    pc_finto
    finto_con openssl <<'FINE'
read -r p; echo "\$6\$x\$$p"
FINE
    VETRO_UTENTE=davide VETRO_PASSWORD=uno VETRO_PASSWORD_FANTASMA= pc_chiedi_utente >/dev/null
    local c="$VETRO_PC/condivisa/installa.conf"
    contiene "$c" "UTENTE=davide"
    contiene "$c" 'IMPRONTA=\$6\$x\$uno'
    contiene "$c" 'IMPRONTA_FANTASMA=\$6\$x\$uno'
    uguale 600 "$(stat -c %a "$c")" "installa.conf solo per il proprietario"
    ( VETRO_UTENTE="Davide Rossi" VETRO_PASSWORD=uno pc_chiedi_utente ) >/dev/null 2>&1
    uguale 1 "$?" "nome utente con maiuscole e spazi: no"
}

unisci() { local IFS=" "; echo "$*"; }

test_qemu_installa() {
    pc_finto
    pc_qemu installa
    local c; c=$(unisci "${COMANDO[@]}")
    case "$c" in *"-kernel $VETRO_PC/avvio/vmlinuz-linux"*) ok_prova "kernel dalla ISO" ;; *) fallita "kernel: $c" ;; esac
    case "$c" in *"script=http://10.0.2.2:8765/installa-arch"*"console=ttyS0"*) ok_prova "script= e seriale" ;; *) fallita "append: $c" ;; esac
    case "$c" in *"archisosearchuuid=2026-11-01-10-00-00-00"*) ok_prova "parametri della ISO" ;; *) fallita "parametri: $c" ;; esac
    case "$c" in *"-display none"*"-serial file:/dev/stdout"*) ok_prova "senza schermo, seriale solo in uscita nel terminale" ;; *) fallita "schermo: $c" ;; esac
    case "$c" in *"systemd.mask=serial-getty@ttyS0.service"*) ok_prova "niente login sulla seriale" ;; *) fallita "login seriale: $c" ;; esac
    case "$c" in *"-cdrom $VETRO_PC/archlinux-2026.11.01-x86_64.iso"*) ok_prova "ISO" ;; *) fallita "cdrom: $c" ;; esac
}

test_qemu_comando() {
    pc_finto; : > "$VETRO_PC/disco.qcow2"
    pc_qemu comando
    local c; c=$(unisci "${COMANDO[@]}")
    case "$c" in *"-display none"*"-serial file:/dev/stdout"*) ok_prova "comando senza schermo, seriale solo in uscita" ;; *) fallita "schermo: $c" ;; esac
    case "$c" in *"mount_tag=vetro"*) ok_prova "cartella condivisa" ;; *) fallita "9p: $c" ;; esac
    case "$c" in *"-kernel"*|*"-cdrom"*) fallita "comando non deve partire dalla ISO" ;; *) ok_prova "parte dal disco" ;; esac
}

test_qemu_avvia() {
    pc_finto; : > "$VETRO_PC/disco.qcow2"
    pc_qemu avvia
    local c; c=$(unisci "${COMANDO[@]}")
    case "$c" in *"virtio-vga-gl,max_outputs=2"*) ok_prova "3D con due uscite" ;; *) fallita "video: $c" ;; esac
    case "$c" in *"usb-tablet"*) ok_prova "tavoletta" ;; *) fallita "tavoletta: $c" ;; esac
    case "$c" in *"pipewire,id=suono"*) ok_prova "audio" ;; *) fallita "audio: $c" ;; esac
    case "$c" in *"mount_tag=vetro"*) ok_prova "cartella condivisa" ;; *) fallita "9p: $c" ;; esac
    case "$c" in *"-display none"*) fallita "avvia deve avere lo schermo" ;; *) ok_prova "con lo schermo" ;; esac
}

test_serve_root_pc() {
    pc_finto
    ( VETRO_EUID=1000 principale fase10 ) > "$RADICE/uscita" 2>&1
    uguale 1 "$?" "senza root si ferma"
    contiene "$RADICE/uscita" "sudo bash lfs.sh fase10"
}

# flusso di fase10 con i pezzi lenti sostituiti: registra cosa succede
flusso_finto() {
    pc_qemu_pronto() { :; }
    pc_chiedi_utente() { echo "UTENTE=davide" > "$(cartella_pc)/condivisa/installa.conf"; }
    pc_iso() { echo "$(cartella_pc)/archlinux-2026.11.01-x86_64.iso"; }
    pc_kernel() { :; }
    pc_server_avvia() { :; }
    pc_crea_disco() { : > "$(cartella_pc)/disco.qcow2"; echo "disco" >> "$RADICE/.chiamate"; }
    pc_accendi() {
        echo "macchina $1 comando=$(cat "$(cartella_pc)/condivisa/.comando" 2>/dev/null)" >> "$RADICE/.chiamate"
        [ "$1" = installa ] && [ -n "${ARCH_RIESCE:-}" ] && : > "$(cartella_pc)/condivisa/.arch-ok"
        [ "$1" = comando ] && echo ok > "$(cartella_pc)/condivisa/.esito"
        return 0
    }
}

test_fase10_riprende() {
    pc_finto; flusso_finto
    ( pc_fase10 ) > "$RADICE/uscita" 2>&1
    uguale 1 "$?" "Arch non installato: fase10 si ferma"
    chiamato "macchina installa"
    non_chiamato "macchina comando"
    contiene "$RADICE/uscita" "sudo bash lfs.sh fase10"
    : > "$RADICE/.chiamate"
    ( ARCH_RIESCE=1 pc_fase10 ) > "$RADICE/uscita" 2>&1
    uguale 0 "$?" "la seconda volta va"
    chiamato "macchina installa"
    chiamato "macchina comando comando=installa"
    contiene "$RADICE/uscita" "sudo bash lfs.sh avvia"
    esiste "$VETRO_PC/condivisa/lfs.sh"
    : > "$RADICE/.chiamate"
    ( pc_fase10 ) > "$RADICE/uscita" 2>&1
    non_chiamato "macchina installa"
    chiamato "macchina comando comando=installa"
    non_esiste "$VETRO_PC/condivisa/installa.conf"
}

test_comando_scritto() {
    pc_finto; flusso_finto; : > "$VETRO_PC/disco.qcow2"
    ( pc_comando registri ) > "$RADICE/uscita" 2>&1
    chiamato "macchina comando comando=registri"
    esiste "$VETRO_PC/condivisa/lfs.sh"
    non_esiste "$VETRO_PC/condivisa/.comando"
    contiene "$RADICE/uscita" "registri-vetro.txt"
    rm -f "$VETRO_PC/disco.qcow2"
    ( pc_comando controlla ) > "$RADICE/uscita" 2>&1
    uguale 1 "$?" "senza macchina si ferma"
    contiene "$RADICE/uscita" "sudo bash lfs.sh fase10"
}

test_esito_dalla_macchina() {
    radice_finta; bin_finti systemctl curl
    mkdir -p "$RADICE/mnt/vetro" "$RADICE/usr/local/sbin"
    echo installa > "$RADICE/mnt/vetro/.comando"
    printf '#!/bin/bash
exit 3
' > "$RADICE/mnt/vetro/lfs.sh"
    PATH="$BIN:$PATH" bash "$COMANDO" >/dev/null 2>&1
    uguale "errore" "$(cat "$RADICE/mnt/vetro/.esito" 2>/dev/null)" "la macchina dice al PC che non e' riuscito"
}

test_guida() {
    local g="$ARCH_DIR/GUIDA-INSTALLAZIONE.md"
    contiene "$g" "sudo bash lfs.sh fase10"
    contiene "$g" "sudo bash lfs.sh avvia"
    contiene "$g" "sudo bash lfs.sh registri"
    contiene "$g" "sudo bash lfs.sh installa"
    non_contiene "$g" "vetro-arch.sh"
    non_contiene "$g" "vetro-vm.sh"
}

test_file_unico_avvia_prova() {
    # il file unico vero: "avvia --prova" scrive il comando di QEMU
    local t; t=$(mktemp -d)
    bash "$ARCH_DIR/costruisci.sh" "$ARCH_DIR/file" "$t/lfs.sh" >/dev/null
    mkdir -p "$t/bin" "$t/pc/vetro-arch/condivisa"
    printf '#!/bin/bash\ncase "$*" in "-device help") echo "name \\"virtio-9p-pci\\"" ;; esac\n' > "$t/bin/qemu-system-x86_64"
    chmod +x "$t/bin/qemu-system-x86_64"
    VETRO_PC="$t/pc/vetro-arch" PATH="$t/bin:$PATH" bash "$t/lfs.sh" avvia --prova > "$t/uscita" 2>&1
    uguale 0 "$?" "lfs.sh avvia --prova esce bene"
    contiene "$t/uscita" "usb-tablet"
    contiene "$t/uscita" "mount_tag=vetro"
    bash "$t/lfs.sh" > "$t/aiuto" 2>&1
    contiene "$t/aiuto" "sudo bash lfs.sh fase10"
    rm -rf "$t"
}

prova test_guida
prova test_file_unico_avvia_prova
prova test_parametri_iso
prova test_impronta_password
prova test_installa_conf
prova test_qemu_installa
prova test_qemu_comando
prova test_qemu_avvia
prova test_serve_root_pc
prova test_fase10_riprende
prova test_comando_scritto
prova test_esito_dalla_macchina
prova test_installa_arch
prova test_comando_da_cartella
prova test_comando_da_http
prova test_senza_comando
prova test_comando_sconosciuto
prova test_servizio
riassunto
