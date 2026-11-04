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

prova test_installa_arch
prova test_comando_da_cartella
prova test_comando_da_http
prova test_senza_comando
prova test_comando_sconosciuto
prova test_servizio
riassunto
