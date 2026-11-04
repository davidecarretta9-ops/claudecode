#!/bin/bash
# Prove del nome oversicaOS e del logo "Orbita" (piano oversicaOS, Task 4)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
carica_src
F="$ARCH_DIR/file"
ICONE="$F/usr/share/icons/hicolor"

# misura_png FILE -> "LARGHEZZAxALTEZZA" (dall'intestazione del PNG)
misura_png() {
    python3 -I - "$1" <<'FINE'
import struct, sys
d = open(sys.argv[1], "rb").read(24)
print("%dx%d" % struct.unpack(">II", d[16:24]) if d[:8] == b"\x89PNG\r\n\x1a\n" else "non-png")
FINE
}

test_os_release() {
    local r
    for r in 'NAME="oversicaOS"' 'PRETTY_NAME="oversicaOS"' 'ID=oversicaos' 'ID_LIKE=arch' 'LOGO=oversicaos'; do
        if grep -qx -- "$r" "$F/etc/os-release" 2>/dev/null; then ok_prova "os-release: $r"
        else fallita "os-release senza la riga $r"; fi
    done
}

test_icone() {
    contiene "$ICONE/scalable/apps/oversicaos.svg" "<svg"
    contiene "$ICONE/scalable/apps/oversicaos.svg" "#d9704a"
    contiene "$ICONE/scalable/apps/oversicaos-segno.svg" "#eeece4"
    local s
    for s in 16 24 32 48 64 128 256 512; do
        uguale "${s}x${s}" "$(misura_png "$ICONE/${s}x${s}/apps/oversicaos.png" 2>/dev/null)" "icona $s px"
    done
}

test_logo_caelestia() {
    # il logo della barra, del blocco e del pannello (componente Logo di Caelestia)
    local l="$F/usr/local/lib/vetro/caelestia/nuovi/components/Logo.qml"
    contiene "$l" "#d9704a"
    contiene "$l" "property color topColour"
    contiene "$l" "property color bottomColour"
}

test_f1_nome() {
    radice_finta; finto hostnamectl; finto grub-mkconfig; finto gtk-update-icon-cache
    mkdir -p "$RADICE/usr/lib" "$RADICE/etc/default"
    printf 'NAME="Arch Linux"\nID=arch\n' > "$RADICE/usr/lib/os-release"
    ln -s ../usr/lib/os-release "$RADICE/etc/os-release"
    printf 'GRUB_DEFAULT=0\nGRUB_DISTRIBUTOR="Arch"\n' > "$RADICE/etc/default/grub"
    ( f1_nome ) >/dev/null 2>&1
    uguale 0 "$?" "f1_nome finisce"
    if [ -L "$RADICE/etc/os-release" ]; then fallita "/etc/os-release e' ancora un collegamento"
    else ok_prova "/etc/os-release e' un file suo"; fi
    contiene "$RADICE/etc/os-release" 'NAME="oversicaOS"'
    contiene "$RADICE/usr/lib/os-release" 'NAME="Arch Linux"'
    chiamato "hostnamectl set-hostname oversica"
    contiene "$RADICE/etc/default/grub" 'GRUB_DISTRIBUTOR="oversicaOS"'
    non_contiene "$RADICE/etc/default/grub" 'GRUB_DISTRIBUTOR="Arch"'
    chiamato "grub-mkconfig -o /boot/grub/grub.cfg"
    esiste "$RADICE/usr/share/icons/hicolor/256x256/apps/oversicaos.png"
}

test_installa_arch_nome() {
    local i="$F/usr/local/lib/vetro/installa-arch"
    contiene "$i" "echo oversica > /etc/hostname"
    contiene "$i" 'GRUB_DISTRIBUTOR="oversicaOS"'
}

prova test_os_release
prova test_icone
prova test_logo_caelestia
prova test_f1_nome
prova test_installa_arch_nome
riassunto
