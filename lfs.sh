#!/usr/bin/env bash
# =============================================================================
#  lfs.sh  -  strumento per costruire la tua distro da zero
#  Base: Linux From Scratch 13.1 (versione systemd)
#
#  Uso:   sudo ./lfs.sh <comando>
#
#  IL MODO PIU' SEMPLICE:   sudo ./lfs.sh tutto
#    fa da solo la Fase 1 (step 1-6), la grafica (Fase 2), i programmi
#    (Fase 2b: Firefox, Thunar, Mousepad, nano), il desktop (Fase 2c:
#    finestre con i pulsanti e barra in basso), i programmi Windows (Fase 3,
#    Wine), l'uso quotidiano (Fase 4: audio, foto, video, archivi; Fase 5:
#    ufficio, posta, blocco schermo, calcolatrice, stampa) e la sicurezza
#    (Fase 6: firewall, Tor Browser, VPN, cassaforte cifrata; Fase 7: modalita'
#    fantasma), l'aspetto elegante (Fase 8), le rifiniture stile macOS/Windows
#    (Fase 9) e il desktop Vetro con le animazioni (Fase 10). Ci vogliono diverse ore.
#    All'inizio chiede: nome della distro, password di root,
#    nome e password del tuo utente, password dell'utente fantasma. Se si ferma,
#    rilancialo: riparte da dove
#    era. Alla fine:  sudo ./lfs.sh avvia      (senza grafica: GRAFICA=no)
#
#  Comandi:
#    tutto      tutte le fasi (1, 2, 2b, 2c, 3, 4, 5, 6, 7, 8, 9, 10), una dopo l'altra
#    fase2      solo la grafica (Sway): serve la Fase 1 finita. "fase2 rifai" da capo
#    fase2b     i programmi: browser Firefox, file Thunar, editor Mousepad e nano,
#               certificati https, curl, wget, barra di stato, schermata delle app
#               (tasto Windows). Serve la Fase 2 finita
#    fase2c     il desktop: finestre con i pulsanti (riduci, ingrandisci, chiudi),
#               barra delle applicazioni in basso, caratteri di GNOME, sfondo, sudo,
#               Impostazioni (risoluzione dello schermo). Serve la Fase 2b finita
#    fase3      i programmi Windows (.exe e .msi, a 64 e 32 bit) con Wine 11.0.
#               Se mancano, fa prima le fasi 2b e 2c
#    fase4      uso quotidiano: audio, programmi X11, foto, video e musica, archivi,
#               schermate (tasto Stamp), notifiche, volume nella barra.
#               Ricompila il kernel con la scheda audio. Se mancano, fa prima le altre fasi
#    fase5      uso quotidiano (2): LibreOffice, Thunderbird, blocco schermo (Windows+L),
#               Gestione attivita', Calcolatrice, immagini WebP, caratteri Liberation,
#               stampa (CUPS). Se manca, fa prima la Fase 4
#    fase6      sicurezza: firewall, Guardiano della rete (chiede prima che un programma
#               usi internet), Tor Browser predefinito, VPN WireGuard (Mullvad o la tua),
#               cassaforte cifrata, DNS cifrato, recinto per i programmi Windows.
#               Ricompila il kernel una volta. Se l'hai gia' fatta, rilanciala:
#               fa solo le parti nuove. Se manca, fa prima la Fase 5
#    fase7      modalita' fantasma: con un pulsante TUTTO passa da Tor (anche gli altri
#               programmi), Tor nascosto con i ponti, scheda di rete camuffata, niente
#               tracce sul disco; utente "fantasma" che vive solo in memoria.
#               Chiede la password dell'utente fantasma. Se manca, fa prima la Fase 6
#    fase8      aspetto elegante (simile a macOS): barra trasparente in alto, dock in
#               basso, finestre con i pulsanti tondi colorati, sfondo nuovo, Impostazioni
#               piu' solide (Schermo, Aspetto: sfondo e finestre chiare o scure).
#               Fa prima tutte le fasi che mancano. Non scarica niente
#    fase9      ancora piu' simile a macOS/Windows: nuove icone per Impostazioni e
#               Spegnimento, gestore file con barra laterale e percorso a briciole
#               (come il Finder o Esplora risorse), finestre con ombre piu' morbide e
#               angoli piu' arrotondati. Fa prima tutte le fasi che mancano. Non scarica
#               niente
#    fase10     desktop "Vetro" (come nel video): Hyprland con animazioni fluide e
#               sfocatura, pannelli di Quickshell (barra, dock, centro di controllo,
#               cruscotto con meteo e prestazioni, blocco schermo con l'orologio grande,
#               Impostazioni con il menu a sinistra). Compila Qt: 1-3 ore. La macchina
#               virtuale parte con l'accelerazione 3D (GL=no per spegnerla); senza 3D
#               resta il desktop classico. Fa prima tutte le fasi che mancano
#    avvia      accende la distro in una macchina virtuale (QEMU); "avvia uefi" con UEFI
#    esporta    crea il disco per VirtualBox o VMware: "esporta virtualbox" / "esporta vmware"
#    step1      fa tutto lo step 1 in ordine (controlla, disco, sorgenti, utente)
#    step2      costruisce il compilatore e gli strumenti temporanei (22 pacchetti)
#    step3      entra nel nuovo sistema e costruisce il sistema base (~90 passaggi)
#               opzioni: TEST=critici|tutti|nessuno   FUSO=Europe/Rome
#    step4      configura, compila e installa il kernel Linux
#               "step4 rifai" lo ricompila da capo (es. dopo aver cambiato le opzioni)
#    step5      rende il disco avviabile: GRUB (BIOS e UEFI), fstab, nome della distro
#    step6      configurazione: rete automatica, tastiera e lingua italiana, orologio
#               opzioni: NOME="La Mia Distro"   OROLOGIO=utc|locale (locale se hai Windows)
#    password   cambia la password di root del nuovo sistema
#    backup     fa una copia di sicurezza del disco virtuale
#    controlla  installa/verifica i programmi che servono sul tuo PC
#    disco      crea il disco virtuale (file .img) e lo monta su /mnt/lfs
#    sorgenti   scarica tutti i pacchetti sorgente e li verifica
#    utente     crea le cartelle base e l'utente "lfs"
#    monta      rimonta il disco virtuale (serve dopo ogni riavvio del PC)
#    smonta     smonta il disco virtuale
#    stato      mostra a che punto sei
#
#  Il disco virtuale e' un normale file: NON tocca i dischi veri del PC.
#  Puoi cambiare posizione/dimensione cosi':
#    sudo LFS_IMG=/home/io/lfs.img LFS_SIZE=50G ./lfs.sh step1
# =============================================================================

set -Eeuo pipefail

# ---------------------------------------------------------------- impostazioni
LFS_VERSIONE="13.1-systemd"
LFS_PKG_VER="13.1"
LFS=/mnt/lfs
LFS_IMG="${LFS_IMG:-/var/lib/mia-distro/lfs.img}"
LFS_SIZE="${LFS_SIZE:-40G}"
SPAZIO_MIN_GB=25
BOOK="https://www.linuxfromscratch.org/lfs/view/${LFS_VERSIONE}"
MIRROR="https://ftp.osuosl.org/pub/lfs/lfs-packages/${LFS_PKG_VER}"

# ---------------------------------------------------------------- messaggi
if [ -t 1 ]; then V=$'\e[32m'; R=$'\e[31m'; G=$'\e[33m'; B=$'\e[1;36m'; N=$'\e[0m'
else V=; R=; G=; B=; N=; fi
titolo() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()     { printf '  %s[OK]%s %s\n' "$V" "$N" "$*"; }
info()   { printf '  %s\n' "$*"; }
avviso() { printf '  %s[!]%s %s\n' "$G" "$N" "$*"; }
errore() { printf '  %s[ERRORE]%s %s\n' "$R" "$N" "$*" >&2; }
muori()  { errore "$*"; exit 1; }
trap 'errore "Qualcosa e'"'"' andato storto (riga $LINENO). Puoi rilanciare lo stesso comando: riprende da dove era."' ERR

serve_root() { [ "$(id -u)" -eq 0 ] || muori "Lancia lo script con sudo:  sudo $0 ${1:-}"; }
montato()    { mountpoint -q "$LFS"; }
loop_dev()   { losetup -j "$LFS_IMG" 2>/dev/null | head -n1 | cut -d: -f1; }

# =============================================================================
#  1. CONTROLLA - programmi necessari sul PC (host)
# =============================================================================
installa_pacchetti() {
  local id_like=""
  [ -r /etc/os-release ] && id_like="$(. /etc/os-release; echo "${ID:-} ${ID_LIKE:-}")"
  case "$id_like" in
    *fedora*|*rhel*)
      info "Sistema Fedora: installo i pacchetti mancanti con dnf..."
      dnf install -y bash binutils bison coreutils diffutils findutils gawk gcc gcc-c++ \
        grep gzip m4 make patch perl python3 sed tar texinfo xz curl \
        dosfstools e2fsprogs util-linux || avviso "dnf non e' riuscito a installare tutto" ;;
    *debian*|*ubuntu*)
      info "Sistema Debian/Ubuntu: installo i pacchetti mancanti con apt..."
      { apt-get update && apt-get install -y build-essential bison gawk texinfo m4 patch perl \
          python3 xz-utils curl dosfstools e2fsprogs fdisk; } || avviso "apt non e' riuscito a installare tutto" ;;
    *) avviso "Sistema non riconosciuto: salto l'installazione automatica" ;;
  esac
}

controlla_versione() { # nome comando versione_minima
  local nome=$1 cmd=$2 min=$3 v
  if ! command -v "$cmd" >/dev/null 2>&1; then errore "Manca: $nome ($cmd)"; return 1; fi
  v=$("$cmd" --version 2>&1 | grep -E -o '[0-9]+\.[0-9.]+[a-z]*' | head -n1 || true)
  if printf '%s\n' "$min" "$v" | sort --version-sort --check >/dev/null 2>&1; then
    ok "$nome $v"
  else
    errore "$nome $v e' troppo vecchio (serve almeno $min)"; return 1
  fi
}

cmd_controlla() {
  serve_root controlla
  titolo "Step 1.1 - Controllo i programmi sul tuo PC"
  installa_pacchetti

  # Fedora toglie "yacc" da bison: LFS vuole che yacc punti a bison.
  if ! command -v yacc >/dev/null 2>&1 && command -v bison >/dev/null 2>&1; then
    printf '#!/bin/sh\nexec bison -y "$@"\n' > /usr/local/bin/yacc
    chmod 755 /usr/local/bin/yacc
    info "Creato /usr/local/bin/yacc (rimanda a bison)"
  fi

  local errori=0
  controlla_versione Coreutils sort      8.1    || errori=1
  controlla_versione Bash      bash      3.2    || errori=1
  controlla_versione Binutils  ld        2.13.1 || errori=1
  controlla_versione Bison     bison     2.7    || errori=1
  controlla_versione Diffutils diff      2.8.1  || errori=1
  controlla_versione Findutils find      4.2.31 || errori=1
  controlla_versione Gawk      gawk      4.0.1  || errori=1
  controlla_versione GCC       gcc       5.4    || errori=1
  controlla_versione G++       g++       5.4    || errori=1
  controlla_versione Grep      grep      2.5.1a || errori=1
  controlla_versione Gzip      gzip      1.3.12 || errori=1
  controlla_versione M4        m4        1.4.10 || errori=1
  controlla_versione Make      make      4.0    || errori=1
  controlla_versione Patch     patch     2.5.4  || errori=1
  controlla_versione Perl      perl      5.8.8  || errori=1
  controlla_versione Python    python3   3.4    || errori=1
  controlla_versione Sed       sed       4.1.5  || errori=1
  controlla_versione Tar       tar       1.22   || errori=1
  controlla_versione Texinfo   texi2any  5.0    || errori=1
  controlla_versione Xz        xz        5.0.0  || errori=1

  local k; k=$(uname -r | grep -E -o '^[0-9.]+' | sed 's/\.$//')
  if printf '%s\n' 5.10 "$k" | sort --version-sort --check >/dev/null 2>&1; then ok "Kernel $k"
  else errore "Kernel $k troppo vecchio (serve 5.10)"; errori=1; fi

  if mount | grep -q 'devpts on /dev/pts'; then ok "Terminali UNIX98 (devpts)"
  else errore "Il kernel non ha i terminali UNIX98 (/dev/pts)"; errori=1; fi

  case "$(readlink -f /bin/sh)" in */bash) ok "/bin/sh punta a bash" ;;
    *) errore "/bin/sh non punta a bash (su Ubuntu: sudo ln -sf bash /bin/sh)"; errori=1 ;; esac
  if awk --version 2>/dev/null | grep -q GNU; then ok "awk = GNU awk"
  else errore "awk non e' GNU awk (gawk)"; errori=1; fi
  if yacc --version 2>/dev/null | grep -q bison; then ok "yacc = bison"
  else errore "yacc non e' bison (se hai 'byacc' installato, rimuovilo)"; errori=1; fi

  local t; t=$(mktemp -d)
  if echo 'int main(){}' | g++ -x c++ - -o "$t/prova" 2>/dev/null && "$t/prova"; then ok "Il compilatore C++ funziona"
  else errore "Il compilatore C++ non funziona"; errori=1; fi
  rm -rf "$t"

  for c in losetup sfdisk mkfs.ext4 mkfs.vfat curl md5sum mountpoint; do
    command -v "$c" >/dev/null 2>&1 || { errore "Manca il comando $c"; errori=1; }
  done
  info "Processori disponibili per compilare: $(nproc)"

  [ "$errori" -eq 0 ] || muori "Il PC non e' pronto: sistema gli errori sopra e rilancia."
  ok "Il tuo PC ha tutto il necessario"
}

# =============================================================================
#  2. DISCO - disco virtuale con 3 partizioni, montato su /mnt/lfs
#     p1 = avvio BIOS (1 MB)   p2 = avvio UEFI (512 MB)   p3 = sistema (ext4)
# =============================================================================
aspetta_partizioni() {
  local dev=$1 i
  for i in $(seq 1 20); do [ -b "${dev}p3" ] && return 0; sleep 0.25; done
  # alcuni sistemi non leggono le partizioni da soli: le aggiungiamo noi
  partx -a "$dev" 2>/dev/null || partx -u "$dev" 2>/dev/null || true
  for i in $(seq 1 20); do [ -b "${dev}p3" ] && return 0; sleep 0.25; done
  [ -b "${dev}p3" ] || muori "Le partizioni del disco virtuale non sono comparse (${dev}p3)"
}

collega_loop() {
  local dev; dev=$(loop_dev)
  if [ -z "$dev" ]; then dev=$(losetup --find --show --partscan "$LFS_IMG"); fi
  aspetta_partizioni "$dev"
  echo "$dev"
}

cmd_disco() {
  serve_root disco
  titolo "Step 1.2 - Disco virtuale"
  if montato; then ok "Il disco e' gia' montato su $LFS"; return 0; fi

  local dev
  if [ ! -f "$LFS_IMG" ]; then
    local cartella libero
    cartella=$(dirname "$LFS_IMG"); mkdir -p "$cartella"
    chattr +C "$cartella" 2>/dev/null || true   # su btrfs (Fedora) rende il file piu' veloce
    libero=$(df --output=avail -BG "$cartella" | tail -n1 | tr -dc '0-9')
    [ "$libero" -ge "$SPAZIO_MIN_GB" ] || muori "Spazio libero in $cartella: ${libero}GB, ne servono almeno ${SPAZIO_MIN_GB}GB. Scegli un'altra posizione con LFS_IMG=..."
    info "Creo $LFS_IMG da $LFS_SIZE (occupa spazio solo quando lo riempi)"
    truncate -s "$LFS_SIZE" "$LFS_IMG"
    sfdisk --quiet "$LFS_IMG" <<'EOF'
label: gpt
name="bios", size=1MiB, type=21686148-6449-6E6F-744E-656564454649
name="esp", size=512MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
name="lfs-root", type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF
    dev=$(collega_loop)
    mkfs.vfat -F 32 -n ESP "${dev}p2" >/dev/null
    mkfs.ext4 -q -L lfs-root "${dev}p3"
    ok "Disco creato e partizionato"
  else
    info "Il disco $LFS_IMG esiste gia': lo riuso"
    dev=$(collega_loop)
  fi

  mkdir -p "$LFS"
  mount "${dev}p3" "$LFS"
  ok "Disco montato su $LFS (dispositivo $dev)"
}

cmd_monta() {
  serve_root monta
  [ -f "$LFS_IMG" ] || muori "Non trovo $LFS_IMG: esegui prima 'sudo $0 disco'"
  if montato; then ok "Gia' montato su $LFS"; return 0; fi
  local dev; dev=$(collega_loop)
  mkdir -p "$LFS"; mount "${dev}p3" "$LFS"
  ok "Disco montato su $LFS"
}

cmd_smonta() {
  serve_root smonta
  if montato; then umount -R "$LFS"; ok "Smontato $LFS"; else info "$LFS non era montato"; fi
  local dev; dev=$(loop_dev)
  if [ -n "$dev" ]; then losetup -d "$dev"; ok "Scollegato $dev"; fi
}

# =============================================================================
#  3. SORGENTI - scarica i pacchetti del libro LFS e controlla che siano integri
# =============================================================================
scarica() { # url destinazione
  curl -fL --retry 3 --connect-timeout 20 --progress-bar -o "$2.part" "$1" </dev/null \
    && mv -f "$2.part" "$2"
}

md5_ok() { # file (dentro $LFS/sources)
  local riga; riga=$(awk -v f="$1" '$2==f' "$LFS/sources/md5sums")
  if [ -z "$riga" ]; then [ -s "$LFS/sources/$1" ]; return; fi
  (cd "$LFS/sources" && echo "$riga" | md5sum -c --status)
}

cmd_sorgenti() {
  serve_root sorgenti
  montato || muori "Il disco non e' montato: esegui prima 'sudo $0 disco'"
  titolo "Step 1.3 - Scarico i sorgenti (LFS $LFS_VERSIONE)"
  local src="$LFS/sources"
  mkdir -p "$src"; chmod a+wt "$src"

  curl -fsSL --retry 3 -o "$src/wget-list-systemd" "$BOOK/wget-list-systemd" || muori "Non riesco a scaricare la lista dei pacchetti (sei connesso a internet?)"
  curl -fsSL --retry 3 -o "$src/md5sums"           "$BOOK/md5sums"           || muori "Non riesco a scaricare la lista dei controlli md5"

  local tot n=0 url f falliti=()
  tot=$(grep -c . "$src/wget-list-systemd")
  while read -r url; do
    [ -n "$url" ] || continue
    n=$((n + 1)); f=$(basename "${url%%\?*}")
    if [ -f "$src/$f" ] && md5_ok "$f"; then info "[$n/$tot] $f  (gia' scaricato)"; continue; fi
    info "[$n/$tot] $f"
    if scarica "$url" "$src/$f" && md5_ok "$f"; then continue; fi
    avviso "Riprovo dal mirror di riserva..."
    if scarica "$MIRROR/$f" "$src/$f" && md5_ok "$f"; then continue; fi
    rm -f "$src/$f" "$src/$f.part"; falliti+=("$f")
  done < "$src/wget-list-systemd"

  if [ "${#falliti[@]}" -gt 0 ]; then
    errore "Non sono riuscito a scaricare: ${falliti[*]}"
    muori "Rilancia 'sudo $0 sorgenti' tra un po' (riprende solo quelli mancanti)."
  fi

  (cd "$src" && md5sum -c --quiet md5sums) || muori "Alcuni file non superano il controllo md5"
  chown root:root "$src"/*
  ok "Tutti i $tot pacchetti scaricati e verificati ($(du -sh "$src" | cut -f1))"
}

# =============================================================================
#  4. UTENTE - cartelle base nel nuovo sistema + utente "lfs" che compilera'
# =============================================================================
cmd_utente() {
  serve_root utente
  montato || muori "Il disco non e' montato: esegui prima 'sudo $0 disco'"
  titolo "Step 1.4 - Cartelle base e utente lfs"

  mkdir -p "$LFS"/{etc,var} "$LFS"/usr/{bin,lib,sbin}
  for i in bin lib sbin; do [ -e "$LFS/$i" ] || ln -s "usr/$i" "$LFS/$i"; done
  case $(uname -m) in x86_64) mkdir -p "$LFS/lib64" ;; esac
  mkdir -p "$LFS/tools"
  ok "Struttura cartelle creata"

  if ! id lfs >/dev/null 2>&1; then
    getent group lfs >/dev/null || groupadd lfs
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs
    ok "Utente lfs creato"
  else
    ok "Utente lfs esiste gia'"
  fi

  chown lfs "$LFS"/{usr{,/*},var,etc,tools}
  case $(uname -m) in x86_64) chown lfs "$LFS/lib64" ;; esac

  local casa; casa=$(getent passwd lfs | cut -d: -f6)
  [ -d "$casa" ] || install -d -o lfs -g lfs -m 700 "$casa"
  cat > "$casa/.bash_profile" <<'EOF'
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
  cat > "$casa/.bashrc" <<'EOF'
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS=-j$(nproc)
EOF
  chown lfs:lfs "$casa/.bash_profile" "$casa/.bashrc"
  ok "Ambiente dell'utente lfs configurato"

  # Su Debian/Ubuntu questo file disturba l'ambiente pulito di lfs (Fedora non lo ha)
  if [ -e /etc/bash.bashrc ]; then
    mv /etc/bash.bashrc /etc/bash.bashrc.NOUSE
    avviso "Spostato /etc/bash.bashrc in /etc/bash.bashrc.NOUSE (rimettilo a fine progetto)"
  fi
}

# =============================================================================
#  STEP 2 - compilatore temporaneo (cap. 5) + strumenti temporanei (cap. 6)
#  Comandi copiati dal sorgente ufficiale del libro LFS 13.1 (tag r13.1).
#  Unica modifica: "ln -sv" -> "ln -sfv", cosi' rilanciare non da' errore.
# =============================================================================
STATO_DIR="$LFS/sources/.mia-distro"

p_binutils1() {
  mkdir -v build
  cd       build
  ../configure --prefix=$LFS/tools \
               --with-sysroot=$LFS \
               --target=$LFS_TGT   \
               --disable-nls       \
               --enable-gprofng=no \
               --disable-werror    \
               --enable-new-dtags  \
               --enable-default-hash-style=gnu
  make
  make install
}

p_gcc1() {
  tar -xf ../mpfr-4.2.2.tar.xz
  mv -v mpfr-4.2.2 mpfr
  tar -xf ../gmp-6.3.0.tar.xz
  mv -v gmp-6.3.0 gmp
  tar -xf ../mpc-1.4.1.tar.xz
  mv -v mpc-1.4.1 mpc
  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
   ;;
  esac
  mkdir -v build
  cd       build
  ../configure                  \
      --target=$LFS_TGT         \
      --prefix=$LFS/tools       \
      --with-glibc-version=2.44 \
      --with-sysroot=$LFS       \
      --with-newlib             \
      --without-headers         \
      --enable-default-pie      \
      --enable-default-ssp      \
      --disable-fixincludes     \
      --disable-nls             \
      --disable-shared          \
      --disable-multilib        \
      --disable-threads         \
      --disable-libatomic       \
      --disable-libgomp         \
      --disable-libquadmath     \
      --disable-libssp          \
      --disable-libvtv          \
      --disable-libstdcxx       \
      --enable-languages=c,c++
  make
  make install
  cat ../gcc/{limitx,glimits,limity}.h  > \
    $($LFS_TGT-gcc -print-file-name=include)/limits.h
}

p_linux_headers() {
  make mrproper
  make headers
  find usr/include -type f ! -name '*.h' -delete
  cp -rv usr/include $LFS/usr
}

p_glibc() {
  case $(uname -m) in
      i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
      ;;
      x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
              ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
      ;;
  esac
  patch -Np1 -i ../glibc-fhs-1.patch
  patch -Np1 -i ../glibc-2.44-upstream_fixes-1.patch
  mkdir -v build
  cd       build
  echo "rootsbindir=/usr/sbin" > configparms
  ../configure                             \
        --prefix=/usr                      \
        --host=$LFS_TGT                    \
        --build=$(../scripts/config.guess) \
        --disable-nscd                     \
        libc_cv_slibdir=/usr/lib           \
        --enable-kernel=5.10
  make
  make DESTDIR=$LFS install
  sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
}

# Controlli obbligatori del libro dopo glibc: il nuovo compilatore deve funzionare
verifica() { # descrizione comando...
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else errore "$d: NON va"; return 1; fi
}
p_controllo_toolchain() {
  local t; t=$(mktemp -d); cd "$t"
  echo 'int main(){}' | $LFS_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log
  local e=0
  verifica "Il nuovo compilatore crea programmi" test -x a.out || e=1
  verifica "I programmi usano il loader giusto (/lib64/ld-linux-x86-64.so.2)" \
    bash -c "$LFS_TGT-readelf -l a.out | grep -q 'Requesting program interpreter: /lib64/ld-linux-x86-64.so.2'" || e=1
  verifica "File di avvio trovati (Scrt1.o, crti.o, crtn.o)" \
    bash -c "[ \$(grep -E -o \"$LFS/lib.*/S?crt[1in].*succeeded\" dummy.log | wc -l) -eq 3 ]" || e=1
  verifica "Header cercati in $LFS/usr/include" grep -q "^ $LFS/usr/include" dummy.log || e=1
  verifica "Librerie cercate in $LFS/tools/$LFS_TGT/lib" grep -q "SEARCH_DIR(\"=$LFS/tools/$LFS_TGT/lib\")" dummy.log || e=1
  verifica "Usa la libc nuova ($LFS/usr/lib/libc.so.6)" grep -q "attempt to open $LFS/usr/lib/libc.so.6 succeeded" dummy.log || e=1
  verifica "Usa il loader nuovo" grep -q "found ld-linux-x86-64.so.2 at $LFS/usr/lib/ld-linux-x86-64.so.2" dummy.log || e=1
  cd /; rm -rf "$t"
  [ "$e" -eq 0 ] || { errore "Il compilatore temporaneo non e' a posto: NON andare avanti, mandami questo output."; return 1; }
  # (nel libro 13.1 il comando "mkheaders" che c'era qui e' disattivato: non va eseguito)
}

p_libstdcxx() {
  mkdir -v build
  cd       build
  ../libstdc++-v3/configure      \
      --host=$LFS_TGT            \
      --build=$(../config.guess) \
      CXX=$LFS_TGT-gcc           \
      --prefix=/usr              \
      --disable-multilib         \
      --disable-nls              \
      --disable-libstdcxx-pch    \
      --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/16.2.0
  make
  make DESTDIR=$LFS install
  rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
}

p_m4() {
  cat > $LFS/usr/share/config.site << EOF
ac_cv_func_posix_spawn_file_actions_addchdir=yes
ac_cv_func_posix_spawn_file_actions_addfchdir=yes
EOF
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
}

p_ncurses() {
  mkdir build
  pushd build
    ../configure --prefix=$LFS/tools AWK=gawk
    make -C include
    make -C progs tic
    install progs/tic $LFS/tools/bin
  popd
  ./configure --prefix=/usr                \
              --host=$LFS_TGT              \
              --build=$(./config.guess)    \
              --mandir=/usr/share/man      \
              --with-manpage-format=normal \
              --with-shared                \
              --without-normal             \
              --with-cxx-shared            \
              --without-debug              \
              --without-ada                \
              --disable-stripping          \
              AWK=gawk
  make
  make DESTDIR=$LFS install
  ln -sfv libncursesw.so $LFS/usr/lib/libncurses.so
  sed -e 's/^#if.*XOPEN.*$/#if 1/' \
      -i $LFS/usr/include/curses.h
}

p_bash() {
  ./configure --prefix=/usr                      \
              --build=$(sh support/config.guess) \
              --host=$LFS_TGT                    \
              --without-bash-malloc              \
              --docdir=/usr/share/doc/bash-5.3
  make
  make DESTDIR=$LFS install
  ln -sfv bash $LFS/bin/sh
}

p_coreutils() {
  ./configure --prefix=/usr                     \
              --host=$LFS_TGT                   \
              --build=$(build-aux/config.guess) \
              --enable-install-program=hostname
  make
  make DESTDIR=$LFS install
  mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
  mkdir -pv $LFS/usr/share/man/man8
  mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
  sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
}

p_diffutils() {
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              gl_cv_func_strcasecmp_works=yes \
              --build=$(./build-aux/config.guess)
  make
  make DESTDIR=$LFS install
}

p_file() {
  mkdir build
  pushd build
    ../configure --disable-bzlib      \
                 --disable-libseccomp \
                 --disable-xzlib      \
                 --disable-zlib
    make
  popd
  ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
  make FILE_COMPILE=$(pwd)/build/src/file
  make DESTDIR=$LFS install
  rm -v $LFS/usr/lib/libmagic.la
}

p_findutils() {
  ./configure --prefix=/usr                   \
              --localstatedir=/var/lib/locate \
              --host=$LFS_TGT                 \
              --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
}

p_gawk() {
  sed -i 's/extras//' Makefile.in
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
}

p_grep() {
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              --build=$(./build-aux/config.guess)
  make
  make DESTDIR=$LFS install
}

p_gzip() {
  ./configure --prefix=/usr --host=$LFS_TGT
  make
  make DESTDIR=$LFS install
}

p_semplice() { # make, patch, sed, tar: stessi comandi nel libro
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
}

p_sed() {
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              --build=$(./build-aux/config.guess)
  make
  make DESTDIR=$LFS install
}

p_xz() {
  ./configure --prefix=/usr                     \
              --host=$LFS_TGT                   \
              --build=$(build-aux/config.guess) \
              --disable-static                  \
              --docdir=/usr/share/doc/xz-5.8.3
  make
  make DESTDIR=$LFS install
  rm -v $LFS/usr/lib/liblzma.la
}

p_binutils2() {
  sed '6031s/$add_dir//' -i ltmain.sh
  mkdir -v build
  cd       build
  ../configure                   \
      --prefix=/usr              \
      --build=$(../config.guess) \
      --host=$LFS_TGT            \
      --disable-nls              \
      --enable-shared            \
      --enable-gprofng=no        \
      --disable-werror           \
      --enable-64-bit-bfd        \
      --enable-new-dtags         \
      --enable-default-hash-style=gnu
  make
  make DESTDIR=$LFS install
  rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
}

p_gcc2() {
  tar -xf ../mpfr-4.2.2.tar.xz
  mv -v mpfr-4.2.2 mpfr
  tar -xf ../gmp-6.3.0.tar.xz
  mv -v gmp-6.3.0 gmp
  tar -xf ../mpc-1.4.1.tar.xz
  mv -v mpc-1.4.1 mpc
  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
    ;;
  esac
  mkdir -v build
  cd       build
  ../configure                   \
      --build=$(../config.guess) \
      --host=$LFS_TGT            \
      --target=$LFS_TGT          \
      --prefix=/usr              \
      --with-build-sysroot=$LFS  \
      --enable-default-pie       \
      --enable-default-ssp       \
      --disable-fixincludes      \
      --disable-nls              \
      --disable-multilib         \
      --disable-libatomic        \
      --disable-libgomp          \
      --disable-libquadmath      \
      --disable-libsanitizer     \
      --disable-libssp           \
      --disable-libvtv           \
      --enable-languages=c,c++   \
      CXX_FOR_TARGET="$LFS_TGT-gcc -nostdinc++" \
      LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc \
      target_configargs=gcc_cv_target_thread_file=posix
  make
  make DESTDIR=$LFS install
  ln -sfv gcc $LFS/usr/bin/cc
}

# --- inizio lista step2 ---   nome | archivio sorgente ("-" = nessuno) | funzione
LISTA_STEP2=(
  "binutils (passo 1)|binutils-2.47.tar.xz|p_binutils1"
  "gcc (passo 1)|gcc-16.2.0.tar.xz|p_gcc1"
  "linux (header)|linux-7.1.8.tar.xz|p_linux_headers"
  "glibc|glibc-2.44.tar.xz|p_glibc"
  "controllo compilatore|-|p_controllo_toolchain"
  "libstdc++|gcc-16.2.0.tar.xz|p_libstdcxx"
  "m4|m4-1.4.21.tar.xz|p_m4"
  "ncurses|ncurses-6.6.tar.gz|p_ncurses"
  "bash|bash-5.3.tar.gz|p_bash"
  "coreutils|coreutils-9.11.tar.xz|p_coreutils"
  "diffutils|diffutils-3.12.tar.xz|p_diffutils"
  "file|file-5.48.tar.gz|p_file"
  "findutils|findutils-4.11.0.tar.xz|p_findutils"
  "gawk|gawk-5.4.1.tar.xz|p_gawk"
  "grep|grep-3.12.tar.xz|p_grep"
  "gzip|gzip-1.14.tar.xz|p_gzip"
  "make|make-4.4.1.tar.gz|p_semplice"
  "patch|patch-2.8.tar.xz|p_semplice"
  "sed|sed-4.10.tar.xz|p_sed"
  "tar|tar-1.35.tar.xz|p_semplice"
  "xz|xz-5.8.3.tar.xz|p_xz"
  "binutils (passo 2)|binutils-2.47.tar.xz|p_binutils2"
  "gcc (passo 2)|gcc-16.2.0.tar.xz|p_gcc2"
)
FILE_EXTRA_STEP2=(mpfr-4.2.2.tar.xz gmp-6.3.0.tar.xz mpc-1.4.1.tar.xz
                  glibc-fhs-1.patch glibc-2.44-upstream_fixes-1.patch)
# --- fine lista step2 ---

durata() { printf '%dm %02ds' $(( $1 / 60 )) $(( $1 % 60 )); }

# Ogni pacchetto gira in un processo bash NUOVO: cosi' "fermati al primo errore"
# (set -e) funziona sempre. Dentro un "if" bash lo disattiverebbe senza dirlo.
_pacchetto() { # funzione cartella
  trap - ERR
  set +h; umask 022
  set +u; set +o pipefail    # i comandi del libro sono scritti per la bash normale
  cd "$2"
  "$1"
}

esegui_in_attesa() { # log funzione cartella  -> lavora in sottofondo e mostra il tempo
  bash "$0" _pacchetto "$2" "$3" >"$1" 2>&1 &
  local pid=$! t0=$SECONDS
  while kill -0 "$pid" 2>/dev/null; do
    [ -t 1 ] && printf '\r      lavoro in corso... %s ' "$(durata $(( SECONDS - t0 )))"
    sleep 2
  done
  [ -t 1 ] && printf '\r%50s\r' ''
  wait "$pid"
}

segno_di() { # riga-della-lista -> file che dice "fatto"
  local nome arch fn; IFS='|' read -r nome arch fn <<<"$1"
  echo "$STATO_DIR/fatto/$fn-${arch%.tar.*}"
}

quanti_fatti() { # voci della lista...
  local r c=0
  for r in "$@"; do [ -e "$(segno_di "$r")" ] && c=$((c + 1)); done
  echo "$c"
}

# Costruisce in ordine i pacchetti di una lista (step 2 e step 3).
# Si lancia dalla cartella dei sorgenti. I passaggi gia' finiti si saltano.
esegui_lista() { # numero_step voci...
  local step=$1; shift
  local tot=$# n=0 riga nome arch fn cartella log segno t0 tutto0=$SECONDS
  for riga in "$@"; do
    n=$((n + 1)); IFS='|' read -r nome arch fn <<<"$riga"
    segno=$(segno_di "$riga")
    if [ -e "$segno" ]; then info "[$n/$tot] $nome  (gia' fatto)"; continue; fi

    printf '  [%d/%d] %s\n' "$n" "$tot" "$nome"
    t0=$SECONDS
    log="$STATO_DIR/log/$step-$n-$fn.log"
    if [ "$arch" = "-" ]; then
      cartella=.
    else
      cartella=$(set +o pipefail; tar -tf "$arch" 2>/dev/null | head -n1 | sed 's@^\./@@; s@/.*@@')
      case "$cartella" in ""|.|..|*/*) muori "Non capisco come si estrae $arch" ;; esac
      rm -rf "$cartella"                       # resti di un tentativo fallito
      tar -xf "$arch"
    fi
    if ! esegui_in_attesa "$log" "$fn" "$cartella"; then
      errore "$nome NON e' riuscito."
      # con la compilazione in parallelo l'errore vero puo' essere lontano dalla fine
      local righe_errore="^FAILED:|[^a-zA-Z]error:|^ERROR|^Error |Error [0-9]+\$|^Traceback|^make.*\\*\\*\\*"
      if grep -q -E "$righe_errore" "$log"; then
        info "Righe con l'errore:"
        { grep -E -m 6 -A 3 "$righe_errore" "$log" || true; } | cut -c1-240 | sed 's/^/      ! /'
      fi
      info "Ultime righe del registro:"
      tail -n 20 "$log" | cut -c1-240 | sed 's/^/      | /'
      info "Registro completo: ${MIA_CHROOT:+/mnt/lfs}$log"
      info "Rilancia 'sudo ./lfs.sh ${MIA_COMANDO:-step$step}' per riprovare da qui (i pacchetti finiti non si rifanno)."
      exit 1
    fi
    grep -F '[OK]' "$log" | sed 's/^ */  /' || true   # mostra i controlli superati
    [ "$arch" = "-" ] || rm -rf "$cartella"
    touch "$segno"
    ok "$nome fatto in $(durata $(( SECONDS - t0 )))"
  done
  ok "${MIA_ETICHETTA:-Step $step} finito in $(durata $(( SECONDS - tutto0 )))"
}

# Questa parte gira come utente "lfs" (la lancia cmd_step2)
_step2_lfs() {
  set +h; umask 022
  [ "$(id -u)" -ne 0 ] || muori "Lo step 2 NON va fatto come root"
  [ "${LFS:-}" = /mnt/lfs ] || muori "La variabile LFS e' sbagliata ('${LFS:-vuota}'): mi fermo per sicurezza"
  [ -n "${LFS_TGT:-}" ] || muori "Manca LFS_TGT: l'ambiente dell'utente lfs non e' caricato"
  cd "$LFS/sources"
  esegui_lista 2 "${LISTA_STEP2[@]}"
}

cmd_step2() {
  serve_root step2
  titolo "Step 2 - Compilatore e strumenti temporanei"
  [ "$(uname -m)" = x86_64 ] || muori "Questo script funziona solo su PC x86_64 (Intel/AMD a 64 bit)"
  montato || muori "Il disco non e' montato: esegui 'sudo $0 monta'"
  id lfs >/dev/null 2>&1 || muori "Manca l'utente lfs: finisci prima lo step 1 ('sudo $0 step1')"
  [ "$(stat -c %U "$LFS/tools")" = lfs ] || muori "$LFS/tools non appartiene a lfs: rilancia 'sudo $0 utente'"

  local manca=() riga arch f
  for riga in "${LISTA_STEP2[@]}"; do
    arch=$(cut -d'|' -f2 <<<"$riga"); [ "$arch" = "-" ] || [ -f "$LFS/sources/$arch" ] || manca+=("$arch")
  done
  for f in "${FILE_EXTRA_STEP2[@]}"; do [ -f "$LFS/sources/$f" ] || manca+=("$f"); done
  [ "${#manca[@]}" -eq 0 ] || muori "Mancano dei sorgenti: $(printf '%s\n' "${manca[@]}" | sort -u | tr '\n' ' ')- rilancia 'sudo $0 sorgenti'"
  ok "Tutti i sorgenti necessari ci sono"

  mkdir -p "$STATO_DIR"/{fatto,log}
  chown -R lfs:lfs "$STATO_DIR"
  info "Ci vuole da mezz'ora a qualche ora, dipende dal PC. Lascia il terminale aperto."
  info "Se si ferma, rilanciando riparte dal pacchetto dove si era fermato."

  local copia casa
  copia=$(mktemp /tmp/mia-distro-XXXXXX.sh); cat "$0" > "$copia"; chmod 755 "$copia"
  casa=$(getent passwd lfs | cut -d: -f6)
  if su lfs -s /bin/bash -c "env -i HOME='$casa' TERM='${TERM:-xterm}' /bin/bash -c 'source ~/.bashrc && exec /bin/bash \"$copia\" _step2_lfs'"; then
    rm -f "$copia"
    titolo "STEP 2 COMPLETATO"
    info "Il compilatore temporaneo e gli strumenti base sono pronti."
    info "Prossimo: step 3 (entrare nel nuovo sistema e costruire il sistema base)."
  else
    rm -f "$copia"
    exit 1
  fi
}

# =============================================================================
#  STEP 3 - sistema base (cap. 7 e 8 del libro LFS 13.1-systemd)
#  Si entra nel nuovo sistema (chroot) e si costruiscono ~90 pacchetti definitivi.
#  Le funzioni c7_/c8_ (comandi) e t7_/t8_ (test) sono generate dal libro:
#  ogni differenza dal libro e' segnata con "# MODIFICA:".
#  Test:  TEST=critici (predefinito: glibc, binutils, gmp, mpfr, come chiede il libro)
#         TEST=tutti   (tutti i test: molte ore in piu')    TEST=nessuno
# =============================================================================
if [ "${MIA_CHROOT:-}" = 1 ]; then STATO_DIR=/sources/.mia-distro; fi

test_attivi() { # livello: critico|normale
  case "${MIA_TEST:-critici}" in
    tutti)   return 0 ;;
    nessuno) return 1 ;;
    *)       [ "$1" = critico ] ;;
  esac
}

# Lancia i test di un pacchetto senza fermarsi se qualcuno fallisce
# (alcuni fallimenti sono normali, il libro li elenca). Risultati in .mia-distro/test/
prova() { # funzione livello
  test_attivi "$2" || { echo "test $1 saltati (TEST=${MIA_TEST:-critici})"; return 0; }
  echo "=== test $1 ==="
  if ( "$1" ) > "$STATO_DIR/test/$1.log" 2>&1; then echo "test $1: finiti"
  else echo "test $1: alcuni non sono passati (vedi $STATO_DIR/test/$1.log)"; fi
}

controlla_pty() {
  local out
  out=$(python3 -c 'from pty import spawn; spawn(["echo", "ok"])' 2>&1 | tr -d '\r' || true)
  if [ "$out" = ok ]; then ok "I terminali (PTY) funzionano nel nuovo sistema"
  else errore "I terminali (PTY) non funzionano nel chroot: $out"; return 1; fi
}

controlla_test_gmp() { # il libro: "almeno 199 test devono passare" (test critico)
  test_attivi critico || return 0
  local n; n=$(find . -name '*.log' -exec cat {} + | grep -c '^PASS' || true)
  if [ "${n:-0}" -ge 199 ]; then ok "GMP: $n test superati (ne servono almeno 199)"
  else errore "GMP: solo ${n:-0} test superati, ne servono almeno 199. NON andare avanti: mandami il registro."; return 1; fi
}

controlla_test_mpfr() { # il libro: "tutti i test devono passare" (test critico)
  test_attivi critico || return 0
  local f; f=$(find . -name test-suite.log | head -n1)
  if [ -n "$f" ] && grep -Eq '^# FAIL: +0$' "$f" && grep -Eq '^# ERROR: +0$' "$f"; then
    ok "MPFR: tutti i test superati ($(grep -E '^# PASS:' "$f" | tr -s ' '))"
  else errore "MPFR: alcuni test non sono passati. NON andare avanti: mandami il registro."; return 1; fi
}

controlla_compilatore_finale() { # controlli del libro dopo GCC (cap. 8)
  echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log || true
  local e=0
  verifica "Il compilatore definitivo crea programmi" test -x a.out || e=1
  verifica "I programmi usano il loader giusto (/lib64/ld-linux-x86-64.so.2)" \
    bash -c "readelf -l a.out | grep -q 'Requesting program interpreter: /lib64/ld-linux-x86-64.so.2'" || e=1
  verifica "File di avvio trovati (Scrt1.o, crti.o, crtn.o)" \
    bash -c "[ \$(grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log | wc -l) -eq 3 ]" || e=1
  verifica "Header cercati in /usr/include" grep -q '^ /usr/include' dummy.log || e=1
  verifica "Librerie cercate in /usr/lib" grep -q 'SEARCH_DIR("/usr/lib")' dummy.log || e=1
  verifica "Usa la libc giusta (/usr/lib/libc.so.6)" grep -q 'attempt to open /usr/lib/libc.so.6 succeeded' dummy.log || e=1
  verifica "Usa il loader giusto" grep -q 'found ld-linux-x86-64.so.2 at /usr/lib/ld-linux-x86-64.so.2' dummy.log || e=1
  rm -f a.out dummy.log
  [ "$e" -eq 0 ] || { errore "Il compilatore definitivo non e' a posto: NON andare avanti, mandami questo output."; return 1; }
}

# --- inizio step3 (generato da gen3.py dal libro LFS 13.1-systemd, tag r13.1) ---
c7_base() {
# --- chapter07/creatingdirs.xml
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
# --- chapter07/createfiles.xml
# MODIFICA: ln -sv -> ln -sfnv (rilanciare non da' errore)
ln -sfnv /proc/self/mounts /etc/mtab
cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
clock:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF
echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group
install -o tester -d /home/tester
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp
}

c7_gettext() {
./configure --disable-shared
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
}

c7_bison() {
./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.8.2
make
make install
}

c7_perl() {
sh Configure -des                                         \
             -D prefix=/usr                               \
             -D vendorprefix=/usr                         \
             -D useshrplib                                \
             -D privlib=/usr/lib/perl5/5.44/core_perl     \
             -D archlib=/usr/lib/perl5/5.44/core_perl     \
             -D sitelib=/usr/lib/perl5/5.44/site_perl     \
             -D sitearch=/usr/lib/perl5/5.44/site_perl    \
             -D vendorlib=/usr/lib/perl5/5.44/vendor_perl \
             -D vendorarch=/usr/lib/perl5/5.44/vendor_perl
make
make install
}

c7_zlib() {
./configure --prefix=/usr
make
make install
rm -fv /usr/lib/libz.a
}

c7_mpdecimal() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpdecimal-4.0.1
make
make install
}

c7_python() {
./configure --prefix=/usr       \
            --enable-shared     \
            --without-ensurepip \
            --without-static-libpython
make
make install
}

c7_texinfo() {
./configure --prefix=/usr
make
make install
}

c7_util_linux() {
mkdir -pv /var/lib/hwclock
./configure --libdir=/usr/lib     \
            --runstatedir=/run    \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-static      \
            --disable-liblastlog2 \
            --without-python      \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.42.2
make
make install
}

c7_cleanup() {
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /tools
}

c8_man_pages() {
rm -v man3/crypt*
make -R GIT=false prefix=/usr install
}

c8_iana_etc() {
cp -v services protocols /etc
}

c8_glibc() {
patch -Np1 -i ../glibc-fhs-1.patch
patch -Np1 -i ../glibc-2.44-upstream_fixes-1.patch
mkdir -v build
cd       build
../configure --prefix=/usr                   \
             --disable-werror                \
             --disable-nscd                  \
             libc_cv_slibdir=/usr/lib        \
             --enable-stack-protector=strong \
             --enable-kernel=5.10
make
prova t8_glibc critico
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
# MODIFICA: solo le lingue della lista del libro (italiano compreso) invece di TUTTE: piu' leggero e veloce
localedef -i C -f UTF-8 C.UTF-8
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i el_GR -f ISO-8859-7 el_GR
localedef -i en_GB -f ISO-8859-1 en_GB
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_ES -f ISO-8859-15 es_ES@euro
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i is_IS -f ISO-8859-1 is_IS
localedef -i is_IS -f UTF-8 is_IS.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f ISO-8859-15 it_IT@euro
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i se_NO -f UTF-8 se_NO.UTF-8
localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
localedef -i zh_TW -f UTF-8 zh_TW.UTF-8
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
tar -xf ../../tzdata2026c.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO tz
# MODIFICA: fuso orario scelto (predefinito Europe/Rome) al posto di <xxx>
ln -sfv /usr/share/zoneinfo/$FUSO /etc/localtime
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
# come nel libro: anche i file in /etc/ld.so.conf.d (li usa Qt, Fase 10)
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
}

t8_glibc() {
# chapter08/glibc.xml
make check
# chapter08/glibc.xml
grep "Timed out" $(find -name \*.out)
}

c8_zlib() {
./configure --prefix=/usr
make
prova t8_zlib normale
make install
rm -fv /usr/lib/libz.a
}

t8_zlib() {
# chapter08/zlib.xml
make check
}

c8_bzip2() {
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make
make PREFIX=/usr install
cp -av libbz2.so.* /usr/lib
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
rm -fv /usr/lib/libbz2.a
}

c8_xz() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.8.3
make
prova t8_xz normale
make install
}

t8_xz() {
# chapter08/xz.xml
make check
}

c8_lz4() {
make BUILD_STATIC=no PREFIX=/usr
prova t8_lz4 normale
make BUILD_STATIC=no PREFIX=/usr install
}

t8_lz4() {
# chapter08/lz4.xml
make -j1 check
}

c8_zstd() {
make prefix=/usr
prova t8_zstd normale
make prefix=/usr install
rm -v /usr/lib/libzstd.a
}

t8_zstd() {
# chapter08/zstd.xml
make check
}

c8_file() {
./configure --prefix=/usr
make
prova t8_file normale
make install
}

t8_file() {
# chapter08/file.xml
make check
}

c8_readline() {
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
sed -e '270a\
     else\
       chars_avail = 1;'      \
    -e '288i\   result = -1;' \
    -i.orig input.c
./configure --prefix=/usr    \
            --disable-static \
            --with-curses    \
            --docdir=/usr/share/doc/readline-8.3
make SHLIB_LIBS="-lncursesw"
make install
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3
}

c8_pcre() {
./configure --prefix=/usr                       \
            --docdir=/usr/share/doc/pcre2-10.47 \
            --enable-unicode                    \
            --enable-jit                        \
            --enable-pcre2-16                   \
            --enable-pcre2-32                   \
            --enable-pcre2grep-libz             \
            --enable-pcre2grep-libbz2           \
            --enable-pcre2test-libreadline      \
            --disable-static
make
prova t8_pcre normale
make install
}

t8_pcre() {
# chapter08/pcre.xml
make check
}

c8_m4() {
./configure --prefix=/usr
make
prova t8_m4 normale
make install
}

t8_m4() {
# chapter08/m4.xml
make check
}

c8_bc() {
CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
make
prova t8_bc normale
make install
}

t8_bc() {
# chapter08/bc.xml
make test
}

c8_flex() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/flex-2.6.4
make
prova t8_flex normale
make install
# MODIFICA: ln -sv -> ln -sfnv (rilanciare non da' errore)
ln -sfnv flex   /usr/bin/lex
ln -sfnv flex.1 /usr/share/man/man1/lex.1
}

t8_flex() {
# chapter08/flex.xml
make check
}

c8_tcl() {
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --disable-rpath
make

sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.13|/usr/lib/tdbc1.1.13|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.13/generic|/usr/include|"     \
    -e "s|$SRCDIR/pkgs/tdbc1.1.13/library|/usr/lib/tcl8.6|"  \
    -e "s|$SRCDIR/pkgs/tdbc1.1.13|/usr/include|"             \
    -i pkgs/tdbc1.1.13/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.7|/usr/lib/itcl4.3.7|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.7/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.3.7|/usr/include|"            \
    -i pkgs/itcl4.3.7/itclConfig.sh

unset SRCDIR
prova t8_tcl normale
make install 
chmod 644 /usr/lib/libtclstub8.6.a
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
mv -v /usr/share/man/man3/{Thread,Tcl_Thread}.3
cd ..
tar -xf ../tcl8.6.18-html.tar.gz --strip-components=1
mkdir -v -p /usr/share/doc/tcl-8.6.18
cp -v -r  ./html/* /usr/share/doc/tcl-8.6.18
}

t8_tcl() {
# chapter08/tcl.xml
LC_ALL=C.UTF-8 make test
}

c8_expect() {
# Controllo del libro: i terminali (PTY) devono funzionare nel chroot
controlla_pty
patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include
make
prova t8_expect normale
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
}

t8_expect() {
# chapter08/expect.xml
make test
}

c8_dejagnu() {
mkdir -v build
cd       build
../configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
prova t8_dejagnu normale
make install
install -v -dm755  /usr/share/doc/dejagnu-1.6.3
install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
}

t8_dejagnu() {
# chapter08/dejagnu.xml
make check
}

c8_ninja() {
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
python3 configure.py --bootstrap --verbose
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
}

c8_pkgconf() {
tar -xf ../meson-1.12.0.tar.gz
mkdir build
cd    build

python3 ../meson-1.12.0/meson.py setup --prefix=/usr --buildtype=release ..
ninja
prova t8_pkgconf normale
ninja install
mv /usr/share/doc/pkgconf{,-3.0.5}
# MODIFICA: ln -sv -> ln -sfnv (rilanciare non da' errore)
ln -sfnv pkgconf   /usr/bin/pkg-config
ln -sfnv pkgconf.1 /usr/share/man/man1/pkg-config.1
}

t8_pkgconf() {
# chapter08/pkgconf.xml
ninja test
}

c8_binutils() {
mkdir -v build
cd       build
../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --enable-new-dtags  \
             --with-system-zlib  \
             --with-lib-path=/usr/lib \
             --enable-default-hash-style=gnu
make tooldir=/usr
prova t8_binutils critico
make tooldir=/usr install
rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
        /usr/share/doc/gprofng/
}

t8_binutils() {
# chapter08/binutils.xml
make -k check
# chapter08/binutils.xml
grep '^FAIL:' $(find -name '*.log')
}

c8_gmp() {
sed -i '/long long t1;/,+1s/()/(...)/' configure
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0
make
make html
prova t8_gmp critico
controlla_test_gmp
make install
make install-html
}

t8_gmp() {
# chapter08/gmp.xml
make check
# chapter08/gmp.xml
cat $(find -name '*.log') | grep -c ^PASS
}

c8_mpfr() {
./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.2
make
make html
prova t8_mpfr critico
controlla_test_mpfr
make install
make install-html
}

t8_mpfr() {
# chapter08/mpfr.xml
make check
}

c8_mpc() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.4.1
make
make html
prova t8_mpc normale
make install
make install-html
}

t8_mpc() {
# chapter08/mpc.xml
make check
}

c8_attr() {
./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.6.0
make
prova t8_attr normale
make install
}

t8_attr() {
# chapter08/attr.xml
make check
}

c8_acl() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.4.0
make
prova t8_acl normale
make install
}

t8_acl() {
# chapter08/acl.xml
make check
}

c8_libcap() {
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib
prova t8_libcap normale
make prefix=/usr lib=lib install
}

t8_libcap() {
# chapter08/libcap.xml
make test
}

c8_libxcrypt() {
sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c
./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no     \
            --disable-static             \
            --disable-failure-tokens
make
prova t8_libxcrypt normale
make install
}

t8_libxcrypt() {
# chapter08/libxcrypt.xml
make check
}

c8_shadow() {
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sed -e 's:#ENCRYPT_METHOD SHA512:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                      \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                     \
    -i etc/login.defs
touch /usr/bin/passwd
./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-{b,yes}crypt \
            --without-libbsd    \
            --disable-logind    \
            --with-group-name-max-length=32
make
make exec_prefix=/usr install
make -C man install-man
pwconv
grpconv
mkdir -p /etc/default
useradd -D --gid 999
sed -i '/MAIL/s/yes/no/' /etc/default/useradd
touch /etc/sub{u,g}id
}

c8_gawk() {
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
prova t8_gawk normale
rm -f /usr/bin/gawk-5.4.1
make install
# MODIFICA: ln -sv -> ln -sfnv (rilanciare non da' errore)
ln -sfnv gawk.1 /usr/share/man/man1/awk.1
install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.4.1
}

t8_gawk() {
# chapter08/gawk.xml
chown -R tester .
su tester -c "PATH=$PATH make check"
}

c8_gcc() {
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac
mkdir -v build
cd       build
../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --enable-default-pie     \
             --enable-default-ssp     \
             --enable-host-pie        \
             --enable-targets=all     \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-fixincludes    \
             --with-system-zlib
make
prova t8_gcc normale
make install
chown -v -R root:root $(gcc -print-file-name=include){,-fixed}
# MODIFICA: ln -sv -> ln -sfnv (rilanciare non da' errore)
ln -sfnvr /usr/bin/cpp /usr/lib
# MODIFICA: ln -sv -> ln -sfnv (rilanciare non da' errore)
ln -sfnv gcc.1 /usr/share/man/man1/cc.1
ln -sfvr $(gcc -print-prog-name=liblto_plugin.so) /usr/lib/bfd-plugins/
# Controlli del libro sul compilatore definitivo (risultati attesi verificati in automatico)
controlla_compilatore_finale
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
}

t8_gcc() {
# chapter08/gcc.xml
ulimit -s -H unlimited
# chapter08/gcc.xml
chown -R tester .
su tester -c "PATH=$PATH make -k check"
# chapter08/gcc.xml
../contrib/test_summary -t
}

c8_ncurses() {
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --with-cxx-shared       \
            --enable-pc-files       \
            --with-pkg-config-libdir=/usr/lib/pkgconfig
make
make DESTDIR=$PWD/dest install
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i dest/usr/include/curses.h
cp --remove-destination -av dest/* /
for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done
ln -sfv libncursesw.so /usr/lib/libcurses.so
cp -v -R doc -T /usr/share/doc/ncurses-6.6
}

c8_sed() {
./configure --prefix=/usr
make
make html
prova t8_sed normale
make install
install -vDm644 doc/sed.html -t /usr/share/doc/sed-4.10
}

t8_sed() {
# chapter08/sed.xml
chown -R tester .
su tester -c "PATH=$PATH make check"
}

c8_psmisc() {
./configure --prefix=/usr
make
prova t8_psmisc normale
make install
}

t8_psmisc() {
# chapter08/psmisc.xml
make check
}

c8_gettext() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-1.0
make
prova t8_gettext normale
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
}

t8_gettext() {
# chapter08/gettext.xml
make check
}

c8_bison() {
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
make
prova t8_bison normale
make install
}

t8_bison() {
# chapter08/bison.xml
make check
}

c8_grep() {
sed -i "s/echo/#echo/" src/egrep.sh
./configure --prefix=/usr
make
prova t8_grep normale
make install
}

t8_grep() {
# chapter08/grep.xml
make check
}

c8_bash() {
./configure --prefix=/usr             \
            --without-bash-malloc     \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3
make
prova t8_bash normale
make install
}

t8_bash() {
# chapter08/bash.xml
chown -R tester .
# chapter08/bash.xml
LC_ALL=C.UTF-8 su -s /usr/bin/expect tester << "EOF"
set timeout -1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EOF
}

c8_libtool() {
./configure --prefix=/usr
make
prova t8_libtool normale
make install
rm -fv /usr/lib/libltdl.a
}

t8_libtool() {
# chapter08/libtool.xml
make check
}

c8_gdbm() {
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat
make
prova t8_gdbm normale
make install
}

t8_gdbm() {
# chapter08/gdbm.xml
make check
}

c8_gperf() {
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
make
prova t8_gperf normale
make install
}

t8_gperf() {
# chapter08/gperf.xml
make check
}

c8_expat() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.8.3
make
prova t8_expat normale
make install
install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.8.3
}

t8_expat() {
# chapter08/expat.xml
make check
}

c8_inetutils() {
sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers
make
prova t8_inetutils normale
make install
mv -v /usr/{,s}bin/ifconfig
}

t8_inetutils() {
# chapter08/inetutils.xml
make check
}

c8_less() {
./configure --prefix=/usr --sysconfdir=/etc
make
prova t8_less normale
make install
}

t8_less() {
# chapter08/less.xml
make check
}

c8_perl() {
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des                                          \
             -D prefix=/usr                                \
             -D vendorprefix=/usr                          \
             -D privlib=/usr/lib/perl5/5.44/core_perl      \
             -D archlib=/usr/lib/perl5/5.44/core_perl      \
             -D sitelib=/usr/lib/perl5/5.44/site_perl      \
             -D sitearch=/usr/lib/perl5/5.44/site_perl     \
             -D vendorlib=/usr/lib/perl5/5.44/vendor_perl  \
             -D vendorarch=/usr/lib/perl5/5.44/vendor_perl \
             -D man1dir=/usr/share/man/man1                \
             -D man3dir=/usr/share/man/man3                \
             -D pager="/usr/bin/less -isR"                 \
             -D useshrplib                                 \
             -D usethreads
make
prova t8_perl normale
make install
unset BUILD_ZLIB BUILD_BZIP2
}

t8_perl() {
# chapter08/perl.xml
TEST_JOBS=$(nproc) make test_harness
}

c8_autoconf() {
./configure --prefix=/usr
make
prova t8_autoconf normale
make install
}

t8_autoconf() {
# chapter08/autoconf.xml
make check
}

c8_automake() {
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1
make
prova t8_automake normale
make install
}

t8_automake() {
# chapter08/automake.xml
make -j$(($(nproc)>4?$(nproc):4)) check
}

c8_openssl() {
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make
prova t8_openssl normale
make INSTALL_LIBS= MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-4.0.1
cp -vfr doc/* /usr/share/doc/openssl-4.0.1
}

t8_openssl() {
# chapter08/openssl.xml
make test
}

c8_libelf() {
./configure --prefix=/usr        \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy
make -C lib
make -C libelf
prova t8_libelf normale
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
}

t8_libelf() {
# chapter08/libelf.xml
make -k check
}

c8_libffi() {
# MODIFICA: x86-64 invece di native: il sistema gira su qualsiasi PC a 64 bit, non solo su questo (come suggerisce il libro)
./configure --prefix=/usr    \
            --disable-static \
            --with-gcc-arch=x86-64
make
prova t8_libffi normale
make install
}

t8_libffi() {
# chapter08/libffi.xml
make check
}

c8_sqlite() {
python3 -m zipfile -e ../sqlite-doc-3530400.zip .
./configure --prefix=/usr     \
            --disable-static  \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                      -D SQLITE_SECURE_DELETE=1"
make LDFLAGS.rpath=""
make install
cp -v -R sqlite-doc-3530400 -T /usr/share/doc/sqlite-3.53.4
}

c8_mpdecimal() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpdecimal-4.0.1
make
prova t8_mpdecimal normale
make install
}

t8_mpdecimal() {
# chapter08/mpdecimal.xml
make check_local
}

c8_python() {
patch -Np1 -i ../Python-3.14.7-openssl_4-1.patch
./configure --prefix=/usr          \
            --enable-shared        \
            --with-system-expat    \
            --enable-optimizations \
            --without-static-libpython
make
prova t8_python normale
make install
cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF
install -v -dm755 /usr/share/doc/python-3.14.7/html

tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.14.7/html \
    -xvf ../python-3.14.7-docs-html.tar.bz2
}

t8_python() {
# chapter08/python.xml
make test TESTOPTS="--timeout 120"
}

c8_flit_core() {
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist flit_core
}

c8_packaging() {
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist packaging
}

c8_wheel() {
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist wheel
}

c8_setuptools() {
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist setuptools
}

c8_meson() {
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
}

c8_kmod() {
mkdir -p build
cd       build

meson setup --prefix=/usr ..    \
            --buildtype=release \
            -D manpages=false
ninja
ninja install
}

c8_coreutils() {
patch -Np1 -i ../coreutils-9.11-i18n-1.patch
autoreconf -fv
automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr
make
prova t8_coreutils normale
make install
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
}

t8_coreutils() {
# chapter08/coreutils.xml
make NON_ROOT_USERNAME=tester check-root
# chapter08/coreutils.xml
groupadd -g 102 dummy -U tester
# chapter08/coreutils.xml
chown -R tester . 
# chapter08/coreutils.xml
su tester -c "PATH=$PATH make -k RUN_EXPENSIVE_TESTS=yes check" \
   < /dev/null
# chapter08/coreutils.xml
groupdel dummy
}

c8_diffutils() {
./configure --prefix=/usr
make
prova t8_diffutils normale
make install
}

t8_diffutils() {
# chapter08/diffutils.xml
make check
}

c8_findutils() {
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
prova t8_findutils normale
make install
}

t8_findutils() {
# chapter08/findutils.xml
chown -R tester .
su tester -c "PATH=$PATH make check -k"
}

c8_groff() {
# MODIFICA: formato carta A4 (Europa)
PAGE=A4 ./configure --prefix=/usr
make -j1
prova t8_groff normale
make install
}

t8_groff() {
# chapter08/groff.xml
make check
}

c8_grub() {
unset {C,CPP,CXX,LD}FLAGS
sed 's/--image-base/--nonexist-linker-option/' -i configure
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-efiemu  \
            --disable-werror
make
make install
make clean
./configure --prefix=/usr       \
            --sysconfdir=/etc   \
            --target=x86_64     \
            --with-platform=efi \
            --disable-efiemu    \
            --disable-werror
make
make install
# MODIFICA: saltata la sezione GRUB per UEFI a 32 bit ("molto rara" secondo il libro)
}

c8_gzip() {
./configure --prefix=/usr
make
prova t8_gzip normale
make install
}

t8_gzip() {
# chapter08/gzip.xml
make check
}

c8_iproute2() {
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
make NETNS_RUN_DIR=/run/netns
make SBINDIR=/usr/sbin install
install -vDm644 COPYING README* -t /usr/share/doc/iproute2-7.1.0
}

c8_kbd() {
patch -Np1 -i ../kbd-2.10.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock
make
prova t8_kbd normale
make install
cp -R -v docs/doc -T /usr/share/doc/kbd-2.10.0
}

t8_kbd() {
# chapter08/kbd.xml
make check
}

c8_libpipeline() {
./configure --prefix=/usr
make
make install
}

c8_make() {
./configure --prefix=/usr
make
prova t8_make normale
make install
}

t8_make() {
# chapter08/make.xml
chown -R tester .
su tester -c "PATH=$PATH make check"
}

c8_patch() {
./configure --prefix=/usr
make
prova t8_patch normale
make install
}

t8_patch() {
# chapter08/patch.xml
make check
}

c8_tar() {
patch -Np1 -i ../tar-1.35-acl_fix-1.patch
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr
make
prova t8_tar normale
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35
}

t8_tar() {
# chapter08/tar.xml
make check
}

c8_texinfo() {
./configure --prefix=/usr
make
prova t8_texinfo normale
make install
make TEXMF=/usr/share/texmf install-tex
}

t8_texinfo() {
# chapter08/texinfo.xml
make check
}

c8_vim() {
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make
prova t8_vim normale
make install
# MODIFICA: ln -sv -> ln -sfnv (rilanciare non da' errore)
ln -sfnv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sfnv vim.1 $(dirname $L)/vi.1
done
# MODIFICA: ln -sv -> ln -sfnv (rilanciare non da' errore)
ln -sfnv ../vim/vim92/doc /usr/share/doc/vim-9.2.1025
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
}

t8_vim() {
# chapter08/vim.xml
chown -R tester .
sed '/test_plugin_glvs/d' -i src/testdir/Make_all.mak
# chapter08/vim.xml
su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" \
   &> vim-test.log
}

c8_markupsafe() {
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist Markupsafe
}

c8_jinja2() {
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist Jinja2
}

c8_systemd() {
sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //'               \
    -i rules.d/50-udev-default.rules.in
mkdir -p build
cd       build

meson setup ..                \
      --prefix=/usr           \
      --buildtype=release     \
      -D default-dnssec=no    \
      -D firstboot=false      \
      -D install-tests=false  \
      -D ldconfig=false       \
      -D sysusers=false       \
      -D rpmmacrosdir=no      \
      -D homed=disabled       \
      -D man=disabled         \
      -D mode=release         \
      -D pamconfdir=no        \
      -D dev-kvm-mode=0660    \
      -D nobody-group=nogroup \
      -D sysupdate=disabled   \
      -D ukify=disabled       \
      -D docdir=/usr/share/doc/systemd-261.2
ninja
prova t8_systemd normale
ninja install
tar -xf ../../systemd-man-pages-261.2.tar.xz \
    --no-same-owner --strip-components=1     \
    -C /usr/share/man
systemd-machine-id-setup
systemctl preset-all
}

t8_systemd() {
# chapter08/systemd.xml
echo 'NAME="Linux From Scratch"' > /etc/os-release
unshare -m ninja test
}

c8_dbus() {
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
ninja
prova t8_dbus normale
ninja install
ln -sfv /etc/machine-id /var/lib/dbus
}

t8_dbus() {
# chapter08/dbus.xml
ninja test
}

c8_man_db() {
./configure --prefix=/usr                         \
            --docdir=/usr/share/doc/man-db-2.13.1 \
            --sysconfdir=/etc                     \
            --disable-setuid                      \
            --enable-cache-owner=bin              \
            --with-browser=/usr/bin/lynx          \
            --with-vgrind=/usr/bin/vgrind         \
            --with-grap=/usr/bin/grap
make
prova t8_man_db normale
make install
}

t8_man_db() {
# chapter08/man-db.xml
make check
}

c8_procps() {
./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.7 \
            --disable-static                        \
            --disable-kill                          \
            --enable-watch8bit                      \
            --with-systemd
make
prova t8_procps normale
make install
}

t8_procps() {
# chapter08/procps.xml
chown -R tester .
su tester -c "PATH=$PATH make check"
}

c8_util_linux() {
./configure --bindir=/usr/bin     \
            --libdir=/usr/lib     \
            --runstatedir=/run    \
            --sbindir=/usr/sbin   \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-liblastlog2 \
            --disable-static      \
            --without-python      \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.42.2
make
prova t8_util_linux normale
make install
}

t8_util_linux() {
# chapter08/util-linux.xml
touch /etc/fstab
chown -R tester .
su tester -c "make -k check"
}

c8_e2fsprogs() {
mkdir -v build
cd       build
../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-elf-shlibs \
             --disable-libblkid  \
             --disable-libuuid   \
             --disable-uuidd     \
             --disable-fsck
make
prova t8_e2fsprogs normale
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
}

t8_e2fsprogs() {
# chapter08/e2fsprogs.xml
make check
}

c8_stripping() {
# Facoltativo nel libro: se qualcosa va storto qui, il sistema funziona lo stesso
(
save_usrlib="$(cd /usr/lib; ls ld-linux*[^g])
             libc.so.6
             libthread_db.so.1
             libquadmath.so.0.0.0
             libstdc++.so.6.0.36
             libitm.so.1.0.0
             libatomic.so.1.2.0"

cd /usr/lib

for LIB in $save_usrlib; do
    objcopy --only-keep-debug --compress-debug-sections=zstd $LIB $LIB.dbg
    cp $LIB /tmp/$LIB
    strip --strip-unneeded /tmp/$LIB
    objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

online_usrbin="bash find strip"
online_usrlib="libbfd-2.47.20260726.so
               libsframe.so.3.0.0
               libhistory.so.8.3
               libncursesw.so.6.6
               libm.so.6
               libreadline.so.8.3
               libz.so.1.3.2
               libzstd.so.1.5.7
               $(cd /usr/lib; find libnss*.so* -type f)"

for BIN in $online_usrbin; do
    cp /usr/bin/$BIN /tmp/$BIN
    strip --strip-unneeded /tmp/$BIN
    install -vm755 /tmp/$BIN /usr/bin
    rm /tmp/$BIN
done

for LIB in $online_usrlib; do
    cp /usr/lib/$LIB /tmp/$LIB
    strip --strip-unneeded /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
         $(find /usr/lib -type f -name \*.a)                 \
         $(find /usr/{bin,sbin,libexec} -type f); do
    case "$online_usrbin $online_usrlib $save_usrlib" in
        *$(basename $i)* )
            ;;
        * ) strip --strip-unneeded $i
            ;;
    esac
done

unset BIN LIB save_usrlib online_usrbin online_usrlib
) || echo 'ATTENZIONE: pulizia dei simboli incompleta (non grave)'
}

c8_cleanup() {
rm -rf /tmp/{*,.*}
find /usr/lib /usr/libexec -name \*.la -delete
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
userdel -r tester
}

LISTA_STEP3=(
  "cartelle e file di base|-|c7_base"
  "Gettext-1.0|gettext-1.0.tar.xz|c7_gettext"
  "Bison-3.8.2|bison-3.8.2.tar.xz|c7_bison"
  "Perl-5.44.0|perl-5.44.0.tar.xz|c7_perl"
  "Zlib-1.3.2|zlib-1.3.2.tar.gz|c7_zlib"
  "mpdecimal-4.0.1|mpdecimal-4.0.1.tar.gz|c7_mpdecimal"
  "Python-3.14.7|Python-3.14.7.tar.xz|c7_python"
  "Texinfo-7.3|texinfo-7.3.tar.xz|c7_texinfo"
  "Util-linux-2.42.2|util-linux-2.42.2.tar.xz|c7_util_linux"
  "pulizia del sistema temporaneo|-|c7_cleanup"
  "Man-pages-6.18|man-pages-6.18.tar.xz|c8_man_pages"
  "Iana-Etc-20260805|iana-etc-20260805.tar.gz|c8_iana_etc"
  "Glibc-2.44|glibc-2.44.tar.xz|c8_glibc"
  "Zlib-1.3.2|zlib-1.3.2.tar.gz|c8_zlib"
  "Bzip2-1.0.8|bzip2-1.0.8.tar.gz|c8_bzip2"
  "Xz-5.8.3|xz-5.8.3.tar.xz|c8_xz"
  "Lz4-1.10.0|lz4-1.10.0.tar.gz|c8_lz4"
  "Zstd-1.5.7|zstd-1.5.7.tar.gz|c8_zstd"
  "File-5.48|file-5.48.tar.gz|c8_file"
  "Readline-8.3|readline-8.3.tar.gz|c8_readline"
  "Pcre2-10.47|pcre2-10.47.tar.bz2|c8_pcre"
  "M4-1.4.21|m4-1.4.21.tar.xz|c8_m4"
  "Bc-7.0.3|bc-7.0.3.tar.xz|c8_bc"
  "Flex-2.6.4|flex-2.6.4.tar.gz|c8_flex"
  "Tcl-8.6.18|tcl8.6.18-src.tar.gz|c8_tcl"
  "Expect-5.45.4|expect5.45.4.tar.gz|c8_expect"
  "DejaGNU-1.6.3|dejagnu-1.6.3.tar.gz|c8_dejagnu"
  "Ninja-1.13.2|ninja-1.13.2.tar.gz|c8_ninja"
  "Pkgconf-3.0.5|pkgconf-3.0.5.tar.xz|c8_pkgconf"
  "Binutils-2.47|binutils-2.47.tar.xz|c8_binutils"
  "GMP-6.3.0|gmp-6.3.0.tar.xz|c8_gmp"
  "MPFR-4.2.2|mpfr-4.2.2.tar.xz|c8_mpfr"
  "MPC-1.4.1|mpc-1.4.1.tar.xz|c8_mpc"
  "Attr-2.6.0|attr-2.6.0.tar.gz|c8_attr"
  "Acl-2.4.0|acl-2.4.0.tar.xz|c8_acl"
  "Libcap-2.78|libcap-2.78.tar.xz|c8_libcap"
  "Libxcrypt-4.5.2|libxcrypt-4.5.2.tar.xz|c8_libxcrypt"
  "Shadow-4.20.2|shadow-4.20.2.tar.xz|c8_shadow"
  "Gawk-5.4.1|gawk-5.4.1.tar.xz|c8_gawk"
  "GCC-16.2.0|gcc-16.2.0.tar.xz|c8_gcc"
  "Ncurses-6.6|ncurses-6.6.tar.gz|c8_ncurses"
  "Sed-4.10|sed-4.10.tar.xz|c8_sed"
  "Psmisc-23.7|psmisc-23.7.tar.xz|c8_psmisc"
  "Gettext-1.0|gettext-1.0.tar.xz|c8_gettext"
  "Bison-3.8.2|bison-3.8.2.tar.xz|c8_bison"
  "Grep-3.12|grep-3.12.tar.xz|c8_grep"
  "Bash-5.3|bash-5.3.tar.gz|c8_bash"
  "Libtool-2.6.2|libtool-2.6.2.tar.xz|c8_libtool"
  "GDBM-1.26|gdbm-1.26.tar.gz|c8_gdbm"
  "Gperf-3.3|gperf-3.3.tar.gz|c8_gperf"
  "Expat-2.8.3|expat-2.8.3.tar.xz|c8_expat"
  "Inetutils-2.8|inetutils-2.8.tar.gz|c8_inetutils"
  "Less-704|less-704.tar.gz|c8_less"
  "Perl-5.44.0|perl-5.44.0.tar.xz|c8_perl"
  "Autoconf-2.73|autoconf-2.73.tar.xz|c8_autoconf"
  "Automake-1.18.1|automake-1.18.1.tar.xz|c8_automake"
  "OpenSSL-4.0.1|openssl-4.0.1.tar.gz|c8_openssl"
  "Libelf from Elfutils-0.195|elfutils-0.195.tar.bz2|c8_libelf"
  "Libffi-3.8.0|libffi-3.8.0.tar.gz|c8_libffi"
  "Sqlite-3530400|sqlite-autoconf-3530400.tar.gz|c8_sqlite"
  "mpdecimal-4.0.1|mpdecimal-4.0.1.tar.gz|c8_mpdecimal"
  "Python-3.14.7|Python-3.14.7.tar.xz|c8_python"
  "Flit-Core-4.0.2|flit_core-4.0.2.tar.gz|c8_flit_core"
  "Packaging-26.3|packaging-26.3.tar.gz|c8_packaging"
  "Wheel-0.48.0|wheel-0.48.0.tar.gz|c8_wheel"
  "Setuptools-84.0.0|setuptools-84.0.0.tar.gz|c8_setuptools"
  "Meson-1.12.0|meson-1.12.0.tar.gz|c8_meson"
  "Kmod-34.2|kmod-34.2.tar.xz|c8_kmod"
  "Coreutils-9.11|coreutils-9.11.tar.xz|c8_coreutils"
  "Diffutils-3.12|diffutils-3.12.tar.xz|c8_diffutils"
  "Findutils-4.11.0|findutils-4.11.0.tar.xz|c8_findutils"
  "Groff-1.24.1|groff-1.24.1.tar.gz|c8_groff"
  "GRUB-2.14|grub-2.14.tar.xz|c8_grub"
  "Gzip-1.14|gzip-1.14.tar.xz|c8_gzip"
  "IPRoute2-7.1.0|iproute2-7.1.0.tar.xz|c8_iproute2"
  "Kbd-2.10.0|kbd-2.10.0.tar.xz|c8_kbd"
  "Libpipeline-1.5.8|libpipeline-1.5.8.tar.gz|c8_libpipeline"
  "Make-4.4.1|make-4.4.1.tar.gz|c8_make"
  "Patch-2.8|patch-2.8.tar.xz|c8_patch"
  "Tar-1.35|tar-1.35.tar.xz|c8_tar"
  "Texinfo-7.3|texinfo-7.3.tar.xz|c8_texinfo"
  "Vim-9.2.1025|vim-9.2.1025.tar.gz|c8_vim"
  "MarkupSafe-3.0.3|markupsafe-3.0.3.tar.gz|c8_markupsafe"
  "Jinja2-3.1.6|jinja2-3.1.6.tar.gz|c8_jinja2"
  "Systemd-261.2|systemd-261.2.tar.gz|c8_systemd"
  "D-Bus-1.16.2|dbus-1.16.2.tar.xz|c8_dbus"
  "Man-DB-2.13.1|man-db-2.13.1.tar.xz|c8_man_db"
  "Procps-ng-4.0.7|procps-ng-4.0.7.tar.xz|c8_procps"
  "Util-linux-2.42.2|util-linux-2.42.2.tar.xz|c8_util_linux"
  "E2fsprogs-1.47.4|e2fsprogs-1.47.4.tar.gz|c8_e2fsprogs"
  "togli i simboli di debug (sistema piu' leggero)|-|c8_stripping"
  "pulizia finale|-|c8_cleanup"
)
# --- fine step3 (generato) ---

# Questa parte gira DENTRO il nuovo sistema (chroot), come root
_step3_chroot() {
  set +h; umask 022
  [ "${MIA_CHROOT:-}" = 1 ] && [ -d /sources ] || muori "Questa parte gira solo dentro il nuovo sistema (chroot)"
  export FUSO="${FUSO:-Europe/Rome}"
  mkdir -p "$STATO_DIR"/{fatto,log,test}
  cd /sources
  info "Test che verranno eseguiti: ${MIA_TEST:-critici}"
  esegui_lista 3 "${LISTA_STEP3[@]}"
}

# --- file system virtuali del kernel (cap. 7.3), da montare prima del chroot
monta_vfs() {
  mkdir -p "$LFS"/{dev,proc,sys,run}
  if ! mountpoint -q "$LFS/dev"; then
    mount --bind /dev "$LFS/dev"
    mount --make-private "$LFS/dev"   # i mount fatti sotto non "rimbalzano" sul tuo PC
  fi
  mountpoint -q "$LFS/dev/pts" || mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
  mountpoint -q "$LFS/proc"    || mount -t proc proc "$LFS/proc"
  mountpoint -q "$LFS/sys"     || mount -t sysfs sysfs "$LFS/sys"
  mountpoint -q "$LFS/run"     || mount -t tmpfs tmpfs "$LFS/run"
  if [ -h "$LFS/dev/shm" ]; then
    install -d -m 1777 "$LFS$(realpath /dev/shm)"
  elif ! mountpoint -q "$LFS/dev/shm"; then
    mount -t tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
  fi
}

smonta_vfs() {
  local d
  for d in dev/shm dev/pts sys proc run dev; do
    if mountpoint -q "$LFS/$d"; then umount "$LFS/$d"; fi
  done
}

distro_accesa() { pgrep -f -- "file=$LFS_IMG," >/dev/null 2>&1; }

assicura_montato() {
  # mai lavorare sul disco mentre la distro e' accesa in QEMU: si rovinerebbe
  if distro_accesa; then
    muori "La distro e' accesa nella macchina virtuale: spegnila (dentro scrivi: poweroff), poi rilancia"
  fi
  montato && return 0
  [ -f "$LFS_IMG" ] || muori "Non trovo il disco virtuale $LFS_IMG: fai prima lo step 1"
  local dev; dev=$(collega_loop); mkdir -p "$LFS"; mount "${dev}p3" "$LFS"
  ok "Disco montato su $LFS"
}

entra_chroot() { # comando... (gira nel nuovo sistema con un ambiente pulito)
  chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM="${TERM:-xterm}" PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j$(nproc)" TESTSUITEFLAGS="-j$(nproc)" \
    MIA_CHROOT=1 MIA_TEST="${TEST:-critici}" FUSO="${FUSO:-Europe/Rome}" \
    "$@"
}

imposta_password_root() {
  [ -e "$STATO_DIR/fatto/password-root" ] && return 0
  if [ -n "${PASSWORD_ROOT:-}" ]; then          # chiesta all'inizio da "tutto"
    if printf 'root:%s\n' "$PASSWORD_ROOT" | entra_chroot /usr/sbin/chpasswd; then
      touch "$STATO_DIR/fatto/password-root"; ok "Password di root impostata"; return 0
    fi
    avviso "Non sono riuscito a impostare la password scelta all'inizio"
  fi
  if [ ! -t 0 ]; then avviso "Password di root non impostata: lancia 'sudo $0 password'"; return 0; fi
  titolo "Password dell'utente root del tuo nuovo sistema"
  info "Scrivila due volte (mentre scrivi non si vede niente, e' normale)."
  local t
  for t in 1 2 3; do
    if entra_chroot /usr/bin/passwd root; then touch "$STATO_DIR/fatto/password-root"; ok "Password impostata"; return 0; fi
    avviso "Riprova ($t/3)"
  done
  avviso "Password non impostata: potrai farlo dopo con 'sudo $0 password'"
}

riepilogo_test() {
  local f n trovati=0
  for f in "$STATO_DIR"/test/*.log; do
    [ -e "$f" ] || continue
    [ "$trovati" -eq 1 ] || { titolo "Risultati dei test"; trovati=1; }
    n=$(grep -c -E '^(FAIL|ERROR):' "$f" || true)
    info "$(basename "$f" .log | sed 's/^t[78]_//'): $n test falliti"
  done
  [ "$trovati" -eq 0 ] || info "Qualche fallimento e' normale (il libro li elenca). Se vuoi che controlli, mandami i registri in $STATO_DIR/test/"
}

cmd_step3() {
  serve_root step3
  titolo "Step 3 - Sistema base (dentro il nuovo sistema)"
  [ "$(uname -m)" = x86_64 ] || muori "Questo script funziona solo su PC x86_64 (Intel/AMD a 64 bit)"
  assicura_montato
  [ "$(quanti_fatti "${LISTA_STEP2[@]}")" -eq "${#LISTA_STEP2[@]}" ] || muori "Finisci prima lo step 2 ('sudo $0 step2')"
  [ -f "/usr/share/zoneinfo/${FUSO:-Europe/Rome}" ] || muori "Fuso orario sconosciuto: ${FUSO:-Europe/Rome} (esempio giusto: FUSO=Europe/Rome)"
  case "${TEST:-critici}" in critici|tutti|nessuno) ;; *) muori "TEST puo' essere: critici, tutti, nessuno" ;; esac

  local manca=() f
  while read -r _ f; do [ -f "$LFS/sources/$f" ] || manca+=("$f"); done < "$LFS/sources/md5sums"
  [ "${#manca[@]}" -eq 0 ] || muori "Mancano dei sorgenti: ${manca[*]} - rilancia 'sudo $0 sorgenti'"
  local libero; libero=$(df --output=avail -BG "$LFS" | tail -n1 | tr -dc '0-9')
  [ "$libero" -ge 12 ] || avviso "Sul disco virtuale restano solo ${libero}GB: potrebbero non bastare"
  ok "Tutto pronto (test: ${TEST:-critici}, fuso orario: ${FUSO:-Europe/Rome})"

  # 7.2 - da qui in poi i file del nuovo sistema appartengono a root
  local d
  for d in usr var etc tools lib64; do
    if [ -d "$LFS/$d" ]; then chown --from lfs -R root:root "$LFS/$d"; fi
  done
  monta_vfs
  mkdir -p "$STATO_DIR"/{fatto,log,test}
  install -m 755 "$0" "$STATO_DIR/lfs.sh"

  info "Ci vogliono diverse ore (dipende dal PC e dai test). Lascia il terminale aperto."
  info "Se si ferma, rilanciando riparte dal pacchetto dove si era fermato."
  local esito=0
  entra_chroot /bin/bash /sources/.mia-distro/lfs.sh _step3_chroot || esito=$?
  if [ "$esito" -eq 0 ]; then
    imposta_password_root
    riepilogo_test
  fi
  smonta_vfs
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "STEP 3 COMPLETATO"
  info "Il sistema base e' costruito. Prossimo: step 4 (il kernel Linux)."
  info "Consiglio: fai una copia di sicurezza con  sudo $0 backup"
}

cmd_password() {
  serve_root password
  assicura_montato
  [ -x "$LFS/usr/bin/passwd" ] || muori "Il programma passwd non c'e' ancora: finisci lo step 3"
  monta_vfs
  rm -f "$STATO_DIR/fatto/password-root"
  imposta_password_root || true
  smonta_vfs
}

cmd_backup() {
  serve_root backup
  [ -f "$LFS_IMG" ] || muori "Non trovo il disco virtuale $LFS_IMG"
  local copia="${LFS_IMG%.img}-backup-$(date +%Y%m%d-%H%M).img" serve libero
  serve=$(du -BG "$LFS_IMG" | cut -f1 | tr -dc '0-9')
  libero=$(df --output=avail -BG "$(dirname "$LFS_IMG")" | tail -n1 | tr -dc '0-9')
  [ "$libero" -gt "$serve" ] || muori "Spazio insufficiente per la copia: servono ${serve}GB, liberi ${libero}GB"
  titolo "Copia di sicurezza del disco virtuale"
  local era_montato=0; montato && era_montato=1
  cmd_smonta
  info "Copio in $copia (${serve}GB, puo' volerci qualche minuto)..."
  cp --sparse=always "$LFS_IMG" "$copia"
  ok "Copia fatta: $copia"
  info "Per tornare a questa copia: smonta, poi sostituisci $LFS_IMG con la copia."
  if [ "$era_montato" -eq 1 ]; then cmd_monta; fi
}

# =============================================================================
#  STEP 4 - kernel Linux (cap. 10.3 del libro LFS 13.1-systemd)
#  Il libro configura a mano con "make menuconfig": qui si parte da
#  "make defconfig" (come consiglia il libro) e si impostano in automatico le
#  opzioni dell'elenco qui sotto, poi si CONTROLLA che siano davvero attive.
# =============================================================================
KERNEL_VER="7.1.8"
KERNEL_NOME="vmlinuz-${KERNEL_VER}-lfs-13.1-systemd"

# Formato "NOME=valori":  * = dentro il kernel   M = modulo   spazio = disattivato
# Piu' simboli = va bene uno qualsiasi (si cambia solo se il valore non va bene).
# Per aggiungere opzioni in futuro basta aggiungerle qui e lanciare: sudo ./lfs.sh step4 rifai
OPZIONI_KERNEL=(
  # --- dal libro (chapter10/kernel/systemd.toml): obbligatorie con systemd
  "WERROR= " "PSI=*" "PSI_DEFAULT_DISABLED= " "IKHEADERS= " "CGROUPS=*" "MEMCG=*"
  "EXPERT= " "RELOCATABLE=*" "RANDOMIZE_BASE=*" "STACKPROTECTOR=*" "STACKPROTECTOR_STRONG=*"
  "UEVENT_HELPER= " "DEVTMPFS=*" "DEVTMPFS_MOUNT=*" "SYSFB_SIMPLEFB=*" "DRM=*" "DRM_PANIC=*"
  "DRM_PANIC_SCREEN=kmsg" "DRM_FBDEV_EMULATION=*" "DRM_SIMPLEDRM=*" "FRAMEBUFFER_CONSOLE=*"
  "NET=*" "INET=*" "IPV6=*" "FW_LOADER_USER_HELPER= " "DMIID=*" "INOTIFY_USER=*" "TMPFS=*"
  "TMPFS_POSIX_ACL=*" "CGROUP_SCHED=* " "LEGACY_TIOCSTI= " "RT_GROUP_SCHED= " "TTY=*"
  # --- dal libro (x2apic.toml): per i sistemi a 64 bit
  "X86_X2APIC=*" "PCI=*" "PCI_MSI=*" "IOMMU_SUPPORT=*" "IRQ_REMAP=*"
  # --- dal libro (nvme.toml): dischi NVMe
  "BLK_DEV_NVME=*"
  # --- dal libro (uefi.toml): avvio con UEFI (il disco virtuale ha anche la partizione UEFI)
  "BLOCK=*" "EFI=*" "EFI_STUB=*" "PARTITION_ADVANCED=* " "EFI_PARTITION=*" "VFAT_FS=*M"
  "EFIVAR_FS=*M" "NLS=*" "NLS_CODEPAGE_437=*M" "NLS_ISO8859_1=*M"
  # --- AGGIUNTE NOSTRE: LFS non usa initramfs, quindi disco e file system devono
  #     stare DENTRO il kernel (PC veri: SATA/NVMe; macchine virtuali: virtio)
  "EXT4_FS=*" "ATA=*" "SATA_AHCI=*" "BLK_DEV_SD=*" "VIRTIO_PCI=*" "VIRTIO_BLK=*" "SCSI_VIRTIO=*"
  # --- AGGIUNTE NOSTRE: tastiera/mouse USB, rete e schermo nelle macchine virtuali
  #     (QEMU/virt-manager, VirtualBox, VMware)
  "USB_HID=*M" "HID_GENERIC=*M" "VIRTIO_NET=*M" "DRM_VIRTIO_GPU=*M"
  "DRM_VMWGFX=M*" "DRM_VBOXVIDEO=M*" "VIRT_DRIVERS=*" "VBOXGUEST=M*"
  # --- AGGIUNTE NOSTRE (Fase 4): audio. Il lettore "generico" delle schede HD Audio
  #     (quella delle macchine virtuali e molte dei PC) e le cuffie/casse USB
  "SND_HDA_GENERIC=*" "SND_USB_AUDIO=*M"
  # --- AGGIUNTE NOSTRE (Fase 6): sicurezza. Firewall (iptables del libro BLFS, con il
  #     Guardiano della rete che chiede prima di lasciar uscire un programma), VPN
  #     WireGuard (con le regole che usa wg-quick), cassaforte cifrata (ext4), Yama
  "NETFILTER=*" "NETFILTER_ADVANCED=*" "NETFILTER_XTABLES=*" "NETFILTER_XTABLES_LEGACY=*"
  "NF_CONNTRACK=*" "NF_CONNTRACK_MARK=*" "NETFILTER_NETLINK_QUEUE=*"
  "NETFILTER_XT_MATCH_CONNTRACK=*" "NETFILTER_XT_MATCH_OWNER=*" "NETFILTER_XT_TARGET_NFQUEUE=*"
  "NETFILTER_XT_MATCH_COMMENT=*" "NETFILTER_XT_MATCH_ADDRTYPE=*" "NETFILTER_XT_MARK=*"
  "NETFILTER_XT_CONNMARK=*" "IP_NF_IPTABLES=*" "IP_NF_IPTABLES_LEGACY=*" "IP_NF_FILTER=*"
  "IP_NF_TARGET_REJECT=*" "IP_NF_RAW=*" "IP_NF_MANGLE=*" "IP6_NF_IPTABLES=*"
  "IP6_NF_IPTABLES_LEGACY=*" "IP6_NF_FILTER=*" "IP6_NF_TARGET_REJECT=*" "IP6_NF_RAW=*"
  "IP6_NF_MANGLE=*" "IP_ADVANCED_ROUTER=*" "IP_MULTIPLE_TABLES=*" "IPV6_MULTIPLE_TABLES=*"
  "WIREGUARD=*M" "FS_ENCRYPTION=*" "SECURITY_YAMA=*"
  # --- dal libro BLFS (bubblewrap.toml): i recinti (programmi Windows) usano gli spazi utente
  "NAMESPACES=*" "USER_NS=*"
  # --- AGGIUNTE NOSTRE (Fase 7): modalita' fantasma, i collegamenti girati dentro Tor (NAT)
  "NF_NAT=*" "IP_NF_NAT=*" "NETFILTER_XT_NAT=*" "NETFILTER_XT_TARGET_REDIRECT=*"
)

valore_config() { # NOME -> "*", "M", " " oppure il testo (per le opzioni di testo)
  local r; r=$(grep -E "^CONFIG_$1=" .config | head -n1 | cut -d= -f2- || true)
  case "$r" in
    y) echo '*' ;;  m) echo 'M' ;;  '') echo ' ' ;;
    \"*\") r=${r#\"}; echo "${r%\"}" ;;
    *) echo "$r" ;;
  esac
}
e_simboli() { [[ $1 =~ ^[*M\ ]+$ ]]; }
opzione_ok() { # NOME VALORI
  local v; v=$(valore_config "$1")
  if e_simboli "$2"; then [[ "$2" == *"$v"* ]]; else [ "$v" = "$2" ]; fi
}
applica_opzione() { # NOME VALORI
  if ! e_simboli "$2"; then scripts/config --file .config --set-str "$1" "$2"; return 0; fi
  if [ "${#2}" -gt 1 ] && opzione_ok "$1" "$2"; then return 0; fi
  case "${2:0:1}" in
    '*') scripts/config --file .config --enable  "$1" ;;
    M)   scripts/config --file .config --module  "$1" ;;
    ' ') scripts/config --file .config --disable "$1" ;;
  esac
}

configura_kernel() {
  make defconfig
  local giro voce
  local -a sbagliate=()
  for giro in 1 2 3; do        # piu' giri: alcune opzioni compaiono solo dopo altre
    for voce in "${OPZIONI_KERNEL[@]}"; do applica_opzione "${voce%%=*}" "${voce#*=}"; done
    make olddefconfig
    sbagliate=()
    for voce in "${OPZIONI_KERNEL[@]}"; do
      opzione_ok "${voce%%=*}" "${voce#*=}" || \
        sbagliate+=("${voce%%=*} (serve '${voce#*=}', c'e' '$(valore_config "${voce%%=*}")')")
    done
    [ "${#sbagliate[@]}" -eq 0 ] && break
  done
  if [ "${#sbagliate[@]}" -gt 0 ]; then
    errore "Queste opzioni del kernel non si riescono ad attivare:"
    printf '      %s\n' "${sbagliate[@]}"
    return 1
  fi
  ok "Kernel configurato: tutte le ${#OPZIONI_KERNEL[@]} opzioni richieste sono attive"
}

c10_kernel() {
make mrproper
# MODIFICA: configurazione automatica (defconfig + elenco OPZIONI_KERNEL + controllo) invece di "make menuconfig"
configura_kernel
make
make modules_install
# MODIFICA: "cp -v" invece di "cp -iv": ricompilando, il kernel nuovo sostituisce il vecchio senza domande
cp -v arch/x86/boot/bzImage /boot/$KERNEL_NOME
cp -v System.map /boot/System.map-$KERNEL_VER
cp -v .config /boot/config-$KERNEL_VER
# MODIFICA: la documentazione del kernel non viene copiata (decine di MB, si trova online: sistema piu' leggero)
}

LISTA_STEP4=(
  "kernel Linux $KERNEL_VER (configurazione, compilazione, installazione)|linux-$KERNEL_VER.tar.xz|c10_kernel"
)

_step4_chroot() {
  set +h; umask 022
  [ "${MIA_CHROOT:-}" = 1 ] && [ -d /sources ] || muori "Questa parte gira solo dentro il nuovo sistema (chroot)"
  mkdir -p "$STATO_DIR"/{fatto,log}
  cd /sources
  esegui_lista 4 "${LISTA_STEP4[@]}"
}

cmd_step4() {
  serve_root step4
  titolo "Step 4 - Kernel Linux $KERNEL_VER"
  [ "$(uname -m)" = x86_64 ] || muori "Questo script funziona solo su PC x86_64 (Intel/AMD a 64 bit)"
  assicura_montato
  [ "$(quanti_fatti "${LISTA_STEP3[@]}")" -eq "${#LISTA_STEP3[@]}" ] || muori "Finisci prima lo step 3 ('sudo $0 step3')"
  [ -f "$LFS/sources/linux-$KERNEL_VER.tar.xz" ] || muori "Manca il sorgente linux-$KERNEL_VER.tar.xz: rilancia 'sudo $0 sorgenti'"
  if [ "${2:-}" = rifai ]; then
    rm -f "$(segno_di "${LISTA_STEP4[0]}")"
    info "Ricompilo il kernel da capo (opzione 'rifai')"
  fi
  monta_vfs
  mkdir -p "$STATO_DIR"/{fatto,log}
  install -m 755 "$0" "$STATO_DIR/lfs.sh"
  info "Ci vogliono da 10 minuti a un'ora, dipende dal PC. Lascia il terminale aperto."
  local esito=0
  entra_chroot /bin/bash /sources/.mia-distro/lfs.sh _step4_chroot || esito=$?
  smonta_vfs
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "STEP 4 COMPLETATO"
  info "Kernel installato in $LFS/boot:"
  ls -lh "$LFS/boot" 2>/dev/null | sed -n '2,$p' | sed 's/^/      /' || true
  info "Prossimo: step 5 (GRUB, cioe' rendere il disco avviabile)."
}

# =============================================================================
#  Parti comuni per gli step 5 e 6 (girano dentro il nuovo sistema)
# =============================================================================
CONF_DIR="$(dirname "$LFS_IMG")"

pulisci_nome() { # testo -> nome distro accettabile
  local n; n=$(printf '%s' "$1" | tr -cd 'A-Za-z0-9 ._-' | sed 's/^ *//; s/ *$//' | cut -c1-40)
  echo "${n:-MiaDistro}"
}
nome_pc_da() { # nome distro -> nome del computer (solo minuscole, numeri, trattini)
  local h; h=$(printf '%s' "$1" | tr 'A-Z' 'a-z' | tr ' ._' '---' | tr -cd 'a-z0-9-' | sed 's/^-*//; s/-*$//' | cut -c1-63)
  echo "${h:-mia-distro}"
}
nome_distro() { # nome scelto (variabile NOME, poi file salvato, poi "MiaDistro")
  if [ -n "${NOME:-}" ]; then pulisci_nome "$NOME"
  elif [ -f "$CONF_DIR/nome-distro" ]; then pulisci_nome "$(cat "$CONF_DIR/nome-distro")"
  else echo "MiaDistro"; fi
}
salva_nome() { # ricorda il nome per gli step successivi
  local n; n=$(nome_distro)            # prima si legge, poi si scrive (stesso file!)
  mkdir -p "$CONF_DIR"
  echo "$n" > "$CONF_DIR/nome-distro"
}

lancia_in_chroot() { # numero_step  VARIABILE=valore...  (monta, entra, esegue la lista, smonta)
  local n=$1; shift
  monta_vfs
  mkdir -p "$STATO_DIR"/{fatto,log,test}
  install -m 755 "$0" "$STATO_DIR/lfs.sh"
  local esito=0
  entra_chroot "$@" /bin/bash /sources/.mia-distro/lfs.sh _step_chroot "$n" || esito=$?
  smonta_vfs
  return "$esito"
}

_step_chroot() { # numero_step  (dentro il nuovo sistema)
  set +h; umask 022
  [ "${MIA_CHROOT:-}" = 1 ] && [ -d /sources ] || muori "Questa parte gira solo dentro il nuovo sistema (chroot)"
  mkdir -p "$STATO_DIR"/{fatto,log}
  cd /sources
  local -n lista="LISTA_STEP$1"
  esegui_lista "$1" "${lista[@]}"
}

# =============================================================================
#  STEP 5 - rendere il disco avviabile (cap. 10.2 fstab, 10.4 GRUB, cap. 11)
#  Il disco virtuale ha: p1 avvio BIOS, p2 avvio UEFI (FAT), p3 sistema (ext4).
#  Si installa GRUB per tutti e due i modi di avvio, come suggerisce il libro
#  "se non sai quale firmware userai o sposterai il disco su un altro PC".
# =============================================================================
c10_fstab() {
# MODIFICA: partizioni indicate con PARTUUID (consiglio del libro): il nome del disco
# cambia tra PC e macchine virtuali (sda, vda, nvme0n1...). Niente swap. "nofail" sulla
# partizione UEFI: se mancasse, il sistema parte lo stesso.
mkdir -p /boot/efi
cat > /etc/fstab << EOF
# Begin /etc/fstab

# file system                                 mount-point  type  options                                               dump  fsck
#                                                                                                                            order

PARTUUID=$ROOT_PARTUUID  /            ext4  defaults                                              1     1
PARTUUID=$ESP_PARTUUID  /boot/efi    vfat  rw,relatime,codepage=437,iocharset=iso8859-1,nofail   0     2

# End /etc/fstab
EOF
cat /etc/fstab
}

installa_grub() { # descrizione  argomenti-di-grub-install...
  local cosa=$1; shift
  if grub-install "$@"; then ok "GRUB per $cosa installato"; return 0; fi
  echo "Primo tentativo fallito: riprovo indicando il disco a GRUB (device.map)"
  echo "(hd0) $MIA_DISCO" > /boot/grub/device.map
  local r=0
  grub-install "$@" || r=$?
  rm -f /boot/grub/device.map
  if [ "$r" -eq 0 ]; then ok "GRUB per $cosa installato (secondo tentativo)"; return 0; fi
  errore "GRUB per $cosa non si installa"
  return 1
}

c10_grub() {
[ -b "$MIA_DISCO" ] || { errore "Non vedo il disco $MIA_DISCO dentro il nuovo sistema"; return 1; }
mountpoint -q /boot/efi || { errore "La partizione UEFI non e' montata in /boot/efi"; return 1; }
mkdir -p /boot/grub
local bios=0 uefi=0
installa_grub "BIOS" --target=i386-pc "$MIA_DISCO" && bios=1 || true
installa_grub "UEFI" --target=x86_64-efi --removable && uefi=1 || true
[ $((bios + uefi)) -gt 0 ] || { errore "GRUB non si e' installato in nessun modo: mandami questo registro"; return 1; }
[ "$bios" -eq 1 ] || echo "ATTENZIONE: il disco partira' solo con UEFI"
[ "$uefi" -eq 1 ] || echo "ATTENZIONE: il disco partira' solo con BIOS"
# MODIFICA: la partizione si cerca per UUID (consiglio del libro) invece di (hd0,2);
# in piu' una voce "emergenza" per riparare il sistema se qualcosa non va.
cat > /boot/grub/grub.cfg << EOF
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod part_gpt
insmod ext2

search --set=root --fs-uuid $ROOT_FSUUID
set gfxpayload=1024x768x32

menuentry "$NOME_DISTRO (Linux $KERNEL_VER)" {
        linux   /boot/$KERNEL_NOME root=PARTUUID=$ROOT_PARTUUID ro
}

menuentry "$NOME_DISTRO - modalita' di emergenza" {
        linux   /boot/$KERNEL_NOME root=PARTUUID=$ROOT_PARTUUID ro systemd.unit=emergency.target
}
EOF
cat /boot/grub/grub.cfg
}

c11_rilascio() {
# MODIFICA: il nome scelto da te al posto di "Linux From Scratch" / "<your name here>"
echo 13.1-systemd > /etc/lfs-release
cat > /etc/lsb-release << EOF
DISTRIB_ID="$NOME_DISTRO"
DISTRIB_RELEASE="13.1-systemd"
DISTRIB_CODENAME="$NOME_PC"
DISTRIB_DESCRIPTION="$NOME_DISTRO (basata su Linux From Scratch 13.1)"
EOF
cat > /etc/os-release << EOF
NAME="$NOME_DISTRO"
VERSION="13.1-systemd"
ID=lfs
PRETTY_NAME="$NOME_DISTRO (Linux From Scratch 13.1-systemd)"
VERSION_CODENAME="$NOME_PC"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
RELEASE_TYPE="stable"
EOF
}

LISTA_STEP5=(
  "tabella dei dischi (/etc/fstab)|-|c10_fstab"
  "GRUB (avvio con BIOS e con UEFI)|-|c10_grub"
  "nome e versione della distro|-|c11_rilascio"
)

cmd_step5() {
  serve_root step5
  titolo "Step 5 - Rendere il disco avviabile (GRUB)"
  assicura_montato
  [ -f "$LFS/boot/$KERNEL_NOME" ] || muori "Non trovo il kernel in $LFS/boot: finisci prima lo step 4 ('sudo $0 step4')"
  [ -x "$LFS/usr/sbin/grub-install" ] || muori "GRUB non c'e' nel nuovo sistema: finisci prima lo step 3"
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP5[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio lo step 5 da capo (opzione 'rifai')"
  fi
  local dev; dev=$(loop_dev)
  [ -n "$dev" ] || muori "Non trovo il disco virtuale collegato"
  local root_partuuid esp_partuuid root_fsuuid nome
  root_partuuid=$(blkid -c /dev/null -s PARTUUID -o value "${dev}p3")
  esp_partuuid=$(blkid -c /dev/null -s PARTUUID -o value "${dev}p2")
  root_fsuuid=$(blkid -c /dev/null -s UUID -o value "${dev}p3")
  [ -n "$root_partuuid" ] && [ -n "$esp_partuuid" ] && [ -n "$root_fsuuid" ] || muori "Non riesco a leggere gli identificativi delle partizioni"
  salva_nome; nome=$(nome_distro)
  ok "Distro: $nome  (computer: $(nome_pc_da "$nome"))"
  mkdir -p "$LFS/boot/efi"
  mountpoint -q "$LFS/boot/efi" || mount "${dev}p2" "$LFS/boot/efi"
  local esito=0
  lancia_in_chroot 5 MIA_DISCO="$dev" ROOT_PARTUUID="$root_partuuid" ESP_PARTUUID="$esp_partuuid" \
    ROOT_FSUUID="$root_fsuuid" NOME_DISTRO="$nome" NOME_PC="$(nome_pc_da "$nome")" || esito=$?
  umount "$LFS/boot/efi" 2>/dev/null || true
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "STEP 5 COMPLETATO"
  info "Il disco virtuale ora si puo' avviare (BIOS e UEFI)."
  info "Prossimo: step 6 (configurazione: rete, tastiera italiana, lingua)."
}

# =============================================================================
#  STEP 6 - configurazione del sistema con systemd (cap. 9 del libro)
# =============================================================================
c9_rete() {
# MODIFICA: rete automatica (DHCP) su qualsiasi scheda via cavo (Type=ether)
# invece di un nome di scheda fisso: funziona su PC diversi e in macchina virtuale
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/10-eth-dhcp.network << "EOF"
[Match]
Type=ether

[Network]
DHCP=ipv4

[DHCPv4]
UseDomains=true
EOF
echo "$NOME_PC" > /etc/hostname
cat > /etc/hosts << EOF
# Begin /etc/hosts

127.0.0.1 localhost.localdomain localhost
127.0.1.1 $NOME_PC.localdomain $NOME_PC
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF
}

c9_orologio() {
# Il libro crea /etc/adjtime solo se l'orologio del PC e' in ora locale (tipico con
# Windows sullo stesso PC). Predefinito: UTC (macchine virtuali, solo Linux).
if [ "${OROLOGIO:-utc}" = locale ]; then
cat > /etc/adjtime << "EOF"
0.0 0 0.0
0
LOCAL
EOF
echo "Orologio del PC in ora locale"
else
rm -f /etc/adjtime
echo "Orologio del PC in UTC"
fi
}

c9_console() {
# MODIFICA: tastiera italiana al posto dell'esempio tedesco del libro
cat > /etc/vconsole.conf << "EOF"
KEYMAP=it
FONT=Lat2-Terminus16
EOF
}

c9_lingua() {
# MODIFICA: italiano (it_IT.UTF-8, installato nello step 3)
cat > /etc/locale.conf << "EOF"
LANG=it_IT.UTF-8
EOF
cat > /etc/profile << "EOF"
# Begin /etc/profile

for i in $(locale); do
  unset ${i%=*}
done

if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  source /etc/locale.conf

  for i in $(locale); do
    key=${i%=*}
    if [[ -v $key ]]; then
      export $key
    fi
  done
fi

# End /etc/profile
EOF
}

c9_inputrc() {
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8-bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# uncomment for history search mode with up/down
# "\e[A": history-search-backward
# "\e[B": history-search-forward

# End /etc/inputrc
EOF
}

c9_shells() {
cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF
}

LISTA_STEP6=(
  "rete e nome del computer|-|c9_rete"
  "orologio|-|c9_orologio"
  "tastiera italiana e carattere della console|-|c9_console"
  "lingua italiana|-|c9_lingua"
  "tasti della riga di comando (/etc/inputrc)|-|c9_inputrc"
  "elenco delle shell (/etc/shells)|-|c9_shells"
)

cmd_step6() {
  serve_root step6
  titolo "Step 6 - Configurazione (rete, tastiera, lingua)"
  assicura_montato
  [ -x "$LFS/usr/lib/systemd/systemd" ] || muori "systemd non c'e' nel nuovo sistema: finisci prima lo step 3"
  case "${OROLOGIO:-utc}" in utc|locale) ;; *) muori "OROLOGIO puo' essere: utc oppure locale" ;; esac
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP6[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio lo step 6 da capo (opzione 'rifai')"
  fi
  salva_nome; local nome; nome=$(nome_distro)
  ok "Distro: $nome  (computer: $(nome_pc_da "$nome"))"
  local esito=0
  lancia_in_chroot 6 NOME_DISTRO="$nome" NOME_PC="$(nome_pc_da "$nome")" OROLOGIO="${OROLOGIO:-utc}" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "STEP 6 COMPLETATO"
  info "La tua distro e' pronta per accendersi:  sudo $0 avvia"
}

# =============================================================================
#  ACCENDERE IL SISTEMA: macchina virtuale QEMU, o file per VirtualBox/VMware
# =============================================================================
installa_qemu() {
  command -v qemu-system-x86_64 >/dev/null 2>&1 && command -v qemu-img >/dev/null 2>&1 && return 0
  info "Installo QEMU (il programma per le macchine virtuali)..."
  if command -v dnf >/dev/null 2>&1; then dnf install -y qemu-system-x86 qemu-img edk2-ovmf || true
  elif command -v apt-get >/dev/null 2>&1; then apt-get install -y qemu-system-x86 qemu-utils ovmf || true; fi
  command -v qemu-system-x86_64 >/dev/null 2>&1 || muori "Non riesco a installare QEMU: installalo a mano (Fedora: sudo dnf install qemu-system-x86)"
}

firmware_uefi() { # stampa "codice|variabili|formato" del firmware UEFI per QEMU, se c'e'
  local c v
  for c in /usr/share/edk2/ovmf/OVMF_CODE.fd /usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2 \
           /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/x64/OVMF_CODE.4m.fd; do
    v=${c/CODE/VARS}
    if [ -f "$c" ] && [ -f "$v" ]; then
      case "$c" in *.qcow2) echo "$c|$v|qcow2" ;; *) echo "$c|$v|raw" ;; esac
      return 0
    fi
  done
  return 1
}

cmd_avvia() { # [bios|uefi]
  serve_root avvia
  titolo "Accendo $(nome_distro) in una macchina virtuale"
  [ -f "$LFS_IMG" ] || muori "Non trovo il disco virtuale $LFS_IMG"
  assicura_montato
  [ -f "$LFS/boot/grub/grub.cfg" ] || muori "Il disco non e' ancora avviabile: finisci gli step fino al 5"
  cmd_smonta >/dev/null                  # mai accendere un disco ancora montato
  installa_qemu
  local modo=${2:-bios} utente=${SUDO_USER:-root}
  local uid; uid=$(id -u "$utente")
  [ "$utente" = root ] || chown "$utente": "$LFS_IMG"
  local acc=(-machine q35,accel=tcg -cpu max)
  if [ -e /dev/kvm ] && sudo -u "$utente" test -w /dev/kvm 2>/dev/null; then acc=(-machine q35,accel=kvm -cpu host); fi
  local ram=${RAM:-4096} cpu; cpu=$(( $(nproc) / 2 )); [ "$cpu" -ge 2 ] || cpu=2
  local fw=()
  if [ "$modo" = uefi ]; then
    local f c v fmt; f=$(firmware_uefi) || muori "Manca il firmware UEFI per QEMU (Fedora: sudo dnf install edk2-ovmf)"
    IFS='|' read -r c v fmt <<<"$f"
    local mie_var="$CONF_DIR/uefi-variabili.$fmt"
    [ -f "$mie_var" ] || cp "$v" "$mie_var"
    [ "$utente" = root ] || chown "$utente": "$mie_var"
    fw=(-drive "if=pflash,format=$fmt,readonly=on,file=$c" -drive "if=pflash,format=$fmt,file=$mie_var")
  fi
  info "Avvio con $modo, ${ram} MB di RAM, $cpu processori, schermo 1920x1080. Chiudi la finestra per spegnere."
  info "Col mouse sopra la finestra i tasti (anche Windows) vanno alla distro. Schermo intero: Ctrl+Alt+F."
  if [ -f "$CONF_DIR/utente" ]; then
    info "Entra con l'utente '$(cat "$CONF_DIR/utente")' per la grafica (oppure root per la riga di comando)."
  else
    info "Accedi con utente: root  e la password che hai scelto."
  fi
  # scheda audio della macchina virtuale: il suono va al tuo PC (PipeWire o PulseAudio)
  local audio=() drv
  if ! qemu-system-x86_64 -audiodev help 2>/dev/null | grep -qw -e pipewire -e pa; then
    command -v dnf >/dev/null 2>&1 && dnf install -y qemu-audio-pipewire qemu-audio-pa >/dev/null 2>&1 || true
  fi
  for drv in pipewire pa alsa; do
    if qemu-system-x86_64 -audiodev help 2>/dev/null | grep -qw "$drv"; then
      audio=(-audiodev "$drv,id=suono" -device intel-hda -device hda-duplex,audiodev=suono); break
    fi
  done
  [ "${#audio[@]}" -gt 0 ] || avviso "QEMU non ha un'uscita audio: la distro partira' senza suono"
  local amb=(DISPLAY="${DISPLAY:-:0}")
  [ -n "${XAUTHORITY:-}" ] && amb+=(XAUTHORITY="$XAUTHORITY")
  if [ -d "/run/user/$uid" ]; then
    amb+=(XDG_RUNTIME_DIR="/run/user/$uid")
    [ -S "/run/user/$uid/wayland-0" ] && amb+=(WAYLAND_DISPLAY=wayland-0)
  fi
  # accelerazione 3D (Fase 10, desktop Vetro): la scheda video "virtio-vga-gl" usa la
  # scheda grafica del tuo PC. Senza, la distro usa il desktop classico. GL=no per
  # spegnerla. Se QEMU non riesce ad aprire la finestra con il 3D, riparte senza.
  local video_semplice=(-vga none -device virtio-vga,xres=1920,yres=1080
                        -display gtk,zoom-to-fit=on,grab-on-hover=on)
  local video=("${video_semplice[@]}") con_3d=0
  if [ "${GL:-si}" != no ]; then
    if ! qemu-system-x86_64 -device help 2>/dev/null | grep -q '"virtio-vga-gl"'; then
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y qemu-device-display-virtio-vga-gl qemu-device-display-virtio-gpu-gl \
                       qemu-ui-opengl virglrenderer >/dev/null 2>&1 || true
      fi
    fi
    if qemu-system-x86_64 -device help 2>/dev/null | grep -q '"virtio-vga-gl"'; then
      video=(-vga none -device virtio-vga-gl,xres=1920,yres=1080
             -display gtk,gl=on,zoom-to-fit=on,grab-on-hover=on)
      con_3d=1
      info "Accelerazione 3D accesa (desktop Vetro con animazioni)."
    else
      avviso "QEMU non ha l'accelerazione 3D: la distro usera' il desktop classico"
    fi
  fi
  local t0=$SECONDS esito=0
  sudo -u "$utente" env "${amb[@]}" qemu-system-x86_64 -name "$(nome_distro)" \
    "${acc[@]}" -m "$ram" -smp "$cpu" "${fw[@]}" \
    -drive "file=$LFS_IMG,format=raw,if=virtio" \
    -nic user,model=virtio-net-pci "${video[@]}" \
    -device qemu-xhci -device usb-tablet "${audio[@]}" || esito=$?
  if [ "$esito" -ne 0 ] && [ "$con_3d" -eq 1 ] && [ $(( SECONDS - t0 )) -lt 20 ]; then
    avviso "QEMU non e' partito con l'accelerazione 3D: riprovo senza (desktop classico)"
    sudo -u "$utente" env "${amb[@]}" qemu-system-x86_64 -name "$(nome_distro)" \
      "${acc[@]}" -m "$ram" -smp "$cpu" "${fw[@]}" \
      -drive "file=$LFS_IMG,format=raw,if=virtio" \
      -nic user,model=virtio-net-pci "${video_semplice[@]}" \
      -device qemu-xhci -device usb-tablet "${audio[@]}"
  fi
}

cmd_esporta() { # virtualbox|vmware
  serve_root esporta
  local tipo=${2:-virtualbox} fmt est
  case "$tipo" in
    virtualbox) fmt=vdi;  est=vdi ;;
    vmware)     fmt=vmdk; est=vmdk ;;
    *) muori "Uso: sudo $0 esporta virtualbox   oppure   sudo $0 esporta vmware" ;;
  esac
  [ -f "$LFS_IMG" ] || muori "Non trovo il disco virtuale $LFS_IMG"
  cmd_smonta >/dev/null
  installa_qemu
  local out="${LFS_IMG%.img}.$est"
  titolo "Converto il disco per $tipo"
  qemu-img convert -p -O "$fmt" "$LFS_IMG" "$out"
  [ -z "${SUDO_USER:-}" ] || chown "$SUDO_USER": "$out"
  ok "Fatto: $out"
  info "Crea una macchina virtuale 'Linux 64 bit' e usa questo file come disco."
  info "Il disco parte sia con BIOS che con EFI."
}

# =============================================================================
#  FASE 2 - interfaccia grafica leggera: Sway (Wayland)
#  Pacchetti e comandi dal libro BLFS 13.1 (versione systemd) dove ci sono
#  (tag r13.1). Ogni differenza dal libro e' segnata con "# MODIFICA:".
#  Sway, swaybg, il terminale foot (con fcft, tllist, utf8proc), il menu bemenu
#  e scdoc NON sono in BLFS: comandi scritti per questa distro ("# NON IN BLFS").
#  Nei comandi BLFS i "&&" a fine riga sono tolti: e' lo stesso, ma lo script si
#  ferma subito al primo errore.
#  Scelte per restare leggeri:
#   - niente X11 e niente Mesa: Sway disegna via software (pixman). Niente 3D,
#     ma pochissima RAM e funziona ovunque (anche in macchina virtuale).
#   - niente Linux-PAM: la grafica usa il servizio seatd per schermo e tastiera.
# =============================================================================
FONTI_FASE2=(
  # file | indirizzo | controllo (md5 dal libro BLFS 13.1; sha256 da Void Linux; md5 calcolati sui file ufficiali)
  "scdoc-1.11.4.tar.gz|https://git.sr.ht/~sircmpwn/scdoc/archive/1.11.4.tar.gz|sha256:e1a9c2000f855123a1a50c8f897073e0ee95fc41787431efe3864c2f1c2e7092"
  "libxml2-2.15.3.tar.xz|https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz|md5:b7b0123654f86ebf630a5cbedaafdece"
  "wayland-1.26.0.tar.xz|https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.26.0/downloads/wayland-1.26.0.tar.xz|md5:64c593ccf6820635765a952ec5f34fbb"
  "wayland-protocols-1.49.tar.xz|https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.49/downloads/wayland-protocols-1.49.tar.xz|md5:5685f769a227f2d4143d983ad07edaba"
  "libpng-1.6.58.tar.xz|https://downloads.sourceforge.net/libpng/libpng-1.6.58.tar.xz|md5:c6c372a9d7754c66e0b77a8d34987a3b"
  "pixman-0.46.4.tar.gz|https://www.cairographics.org/releases/pixman-0.46.4.tar.gz|md5:c08173c8e1d2cc79428d931c13ffda59"
  "freetype-2.14.3.tar.xz|https://downloads.sourceforge.net/freetype/freetype-2.14.3.tar.xz|md5:5e78e6fdce5a61d3075e4c25e9852f84"
  "fontconfig-2.18.3.tar.xz|https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.18.3/fontconfig-2.18.3.tar.xz|md5:ce819e229ca6fb7d1be47a192d6681a3"
  "dejavu-fonts-ttf-2.37.tar.bz2|https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2|md5:d0efec10b9f110a32e9b8f796e21782c"
  "fribidi-1.0.16.tar.xz|https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz|md5:333ad150991097a627755b752b87f9ff"
  "glib-2.88.3.tar.xz|https://download.gnome.org/sources/glib/2.88/glib-2.88.3.tar.xz|md5:b61c04cfbf55b0d24fbe64e4ac9e9d56"
  "harfbuzz-14.3.1.tar.xz|https://github.com/harfbuzz/harfbuzz/releases/download/14.3.1/harfbuzz-14.3.1.tar.xz|md5:4baccda978c92e5f27702ed8b3ceefa7"
  "cairo-1.18.4.tar.xz|https://www.cairographics.org/releases/cairo-1.18.4.tar.xz|md5:db575fb41bbda127e0147e401f36f8ac"
  "pango-1.58.2.tar.xz|https://download.gnome.org/sources/pango/1.58/pango-1.58.2.tar.xz|md5:7b5640fd9adfa24554a88b2b9a6cd3f3"
  "libdrm-2.4.134.tar.xz|https://dri.freedesktop.org/libdrm/libdrm-2.4.134.tar.xz|md5:0e70607bb5c2f7ecbc411e6a2fab8b22"
  "xkeyboard-config-2.48.tar.xz|https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.48.tar.xz|md5:575106aff79b589abe4aff6c4bff4782"
  "libxkbcommon-1.13.2.tar.gz|https://github.com/lfs-book/libxkbcommon/archive/v1.13.2/libxkbcommon-1.13.2.tar.gz|md5:07f838f575d62c267cfc53eaf5ee739b"
  "libxkbcommon-1.13.2-upstream_fix-1.patch|https://www.linuxfromscratch.org/patches/blfs/13.1/libxkbcommon-1.13.2-upstream_fix-1.patch|-"
  "mtdev-1.1.7.tar.bz2|https://bitmath.org/code/mtdev/mtdev-1.1.7.tar.bz2|md5:483ed7fdf7c1e7b7375c05a62848cce7"
  "libevdev-1.13.6.tar.xz|https://www.freedesktop.org/software/libevdev/libevdev-1.13.6.tar.xz|md5:4202ff132e3efe95fe9ca2c4f8f119f7"
  "libinput-1.31.3.tar.gz|https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.31.3/libinput-1.31.3.tar.gz|md5:022aa3838b0cf8b932c0e4a4dbeac150"
  "hwdata-0.410.tar.gz|https://github.com/vcrhonek/hwdata/archive/v0.410/hwdata-0.410.tar.gz|md5:07f1de937ff5b830280f6157221164eb"
  "libdisplay-info-0.4.0.tar.xz|https://gitlab.freedesktop.org/emersion/libdisplay-info/-/releases/0.4.0/downloads/libdisplay-info-0.4.0.tar.xz|md5:af9f07493bd5ff560a98b95ea4c5c129"
  "seatd-0.9.3.tar.gz|https://github.com/kennylevinsen/seatd/archive/0.9.3/seatd-0.9.3.tar.gz|md5:c1cc200188d31214b88af015b1f19f7b"
  "wlroots-0.20.2.tar.bz2|https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.20.2/wlroots-0.20.2.tar.bz2|md5:03634ea5be3d116490630c955355610c"
  "cmake-4.4.2.tar.gz|https://cmake.org/files/v4.4/cmake-4.4.2.tar.gz|md5:6911f0379d901db23619413f092b99ef"
  "json-c-0.19.tar.gz|https://s3.amazonaws.com/json-c_releases/releases/json-c-0.19.tar.gz|md5:5678f1373ba51e0041b574c0411c696b"
  "utf8proc-2.12.0.tar.gz|https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v2.12.0.tar.gz|sha256:f564011d38b2888d583d510b08e69ffa15aa117155db1b9b49ef1dfe1fa25111"
  "sway-1.12.tar.gz|https://github.com/swaywm/sway/releases/download/1.12/sway-1.12.tar.gz|md5:2202e71db6e261ed66414ea85533c435"
  "swaybg-1.2.2.tar.gz|https://github.com/swaywm/swaybg/releases/download/v1.2.2/swaybg-1.2.2.tar.gz|md5:ac79822e449597d8d87aba36c6006de7"
  "tllist-1.1.0.tar.gz|https://codeberg.org/dnkl/tllist/archive/1.1.0.tar.gz|sha256:0e7b7094a02550dd80b7243bcffc3671550b0f1d8ba625e4dff52517827d5d23"
  "fcft-3.3.3.tar.gz|https://codeberg.org/dnkl/fcft/archive/3.3.3.tar.gz|sha256:b0c0f4a599f43723736c8565b8b84337c4195077f07f1bb8bb3252bb13a2306a"
  "foot-1.28.0.tar.gz|https://codeberg.org/dnkl/foot/archive/1.28.0.tar.gz|sha256:4296be402b5684d049534598e69db92b918f92beac9dab76b585207045f0b037"
  "bemenu-0.6.23.tar.gz|https://github.com/Cloudef/bemenu/releases/download/0.6.23/bemenu-0.6.23.tar.gz|md5:bbb8a0bd003afaa9a238d0063ca33547"
)

controlla_somma() { # file controllo  (md5:..., sha256:..., sha512:... oppure "-" = basta che non sia vuoto)
  case "$2" in
    md5:*)    [ "$(md5sum "$1" | cut -d' ' -f1)" = "${2#md5:}" ] ;;
    sha256:*) [ "$(sha256sum "$1" | cut -d' ' -f1)" = "${2#sha256:}" ] ;;
    sha512:*) [ "$(sha512sum "$1" | cut -d' ' -f1)" = "${2#sha512:}" ] ;;
    -)        [ -s "$1" ] ;;
    *)        return 1 ;;
  esac
}

scarica_fonti() { # voci "file|indirizzo|controllo"...
  local voce f url ctrl n=0 tot=$# falliti=()
  for voce in "$@"; do
    n=$((n + 1)); IFS='|' read -r f url ctrl <<<"$voce"
    if [ -f "$LFS/sources/$f" ] && controlla_somma "$LFS/sources/$f" "$ctrl"; then
      info "[$n/$tot] $f  (gia' scaricato)"; continue
    fi
    info "[$n/$tot] $f"
    if scarica "$url" "$LFS/sources/$f" && controlla_somma "$LFS/sources/$f" "$ctrl"; then continue; fi
    rm -f "$LFS/sources/$f" "$LFS/sources/$f.part"; falliti+=("$f")
  done
  [ "${#falliti[@]}" -eq 0 ] || muori "Non sono riuscito a scaricare (o il file e' rovinato): ${falliti[*]} - riprova tra un po'"
  ok "Tutti i $tot file ci sono e sono integri"
}

ambiente_xorg() { # BLFS, pagina "Xorg-7": variabili usate da alcuni pacchetti grafici
export XORG_PREFIX="/usr"
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc \
    --localstatedir=/var --disable-static"
}

f2_scdoc() {
# NON IN BLFS: programmino per generare i manuali (lo usano seatd, sway, foot, bemenu)
make PREFIX=/usr
make PREFIX=/usr install
}

f2_libxml2() {
sed -i "/'git'/,+3d" meson.build
mkdir build
cd    build
# MODIFICA: -D icu=disabled (ICU e' "consigliato" ma pesante, a Sway non serve)
meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D history=enabled  \
      -D icu=disabled
ninja
ninja install
sed "s/--static/--shared/" -i /usr/bin/xml2-config
}

f2_wayland() {
mkdir build
cd    build
meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D documentation=false
ninja
ninja install
}

f2_wayland_protocols() {
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release
ninja
ninja install
}

f2_libpng() {
# (saltata la patch facoltativa per le immagini APNG)
./configure --prefix=/usr --disable-static
make
make install
install -vDm644 README libpng-manual.txt -t /usr/share/doc/libpng-1.6.58
}

f2_pixman() {
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2_freetype2() {
# (saltata la documentazione facoltativa)
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
    -i include/freetype/config/ftoption.h
./configure --prefix=/usr            \
            --disable-static         \
            --enable-freetype-config \
            --with-harfbuzz=dynamic
make
make install
}

f2_fontconfig() {
./configure --prefix=/usr        \
            --sysconfdir=/etc    \
            --localstatedir=/var \
            --disable-docs       \
            --docdir=/usr/share/doc/fontconfig-2.18.3
make
make install
}

f2_dejavu() {
# BLFS, pagina "TTF and OTF fonts": i caratteri DejaVu (servono a terminale e menu)
install -v -d -m755 /usr/share/fonts/dejavu
install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu
fc-cache -v /usr/share/fonts/dejavu
}

f2_fribidi() {
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2_glib2() {
# (saltata la patch facoltativa per i messaggi di avviso)
if [ -e /usr/include/glib-2.0 ]; then
    rm -rf /usr/include/glib-2.0.old
    mv -vf /usr/include/glib-2.0{,.old}
fi
mkdir build
cd    build
# MODIFICA: -D man-pages=disabled (servirebbe docutils) e niente GObject Introspection
# (il libro la compila subito dopo: serve solo ai programmi GNOME)
meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -D introspection=disabled \
      -D glib_debug=disabled    \
      -D man-pages=disabled     \
      -D sysprof=disabled
ninja
ninja install
}

f2_harfbuzz() {
mkdir build
cd    build
# MODIFICA: -D graphite2=disabled (graphite2 non installato: serve solo per alcune scritture rare)
meson setup ..             \
      --prefix=/usr        \
      --buildtype=release  \
      -D graphite2=disabled
ninja
ninja install
}

f2_cairo() {
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2_pango() {
mkdir build
cd    build
# MODIFICA: -D introspection=disabled (niente GObject Introspection, vedi GLib)
meson setup --prefix=/usr            \
            --buildtype=release      \
            --wrap-mode=nofallback   \
            -D introspection=disabled \
            ..
ninja
ninja install
}

f2_libdrm() {
ambiente_xorg
mkdir build
cd    build
meson setup --prefix=$XORG_PREFIX \
            --buildtype=release   \
            -D udev=true          \
            -D valgrind=disabled  \
            ..
ninja
ninja install
}

f2_xkeyboard_config() {
ambiente_xorg
mkdir build
cd    build
meson setup --prefix=$XORG_PREFIX --buildtype=release ..
ninja
if [ -d $XORG_PREFIX/share/X11/xkb ]; then
  rm -rf $XORG_PREFIX/share/X11/xkb
  rm -f  $XORG_PREFIX/share/man/man7/xkeyboard-config.7
  rm -f  $XORG_PREFIX/share/pkgconfig/xkeyboard-config.pc
fi
ninja install
}

f2_libxkbcommon() {
patch -Np1 -i ../libxkbcommon-1.13.2-upstream_fix-1.patch
mkdir build
cd    build
# MODIFICA: -D enable-x11=false (X11 non e' installato)
meson setup ..             \
      --prefix=/usr        \
      --buildtype=release  \
      -D enable-docs=false \
      -D enable-x11=false
ninja
ninja install
}

f2_mtdev() {
./configure --prefix=/usr --disable-static
make
make install
}

f2_libevdev() {
ambiente_xorg
mkdir build
cd    build
meson setup ..                  \
      --prefix=$XORG_PREFIX     \
      --buildtype=release       \
      -D documentation=disabled \
      -D tests=disabled
ninja
ninja install
}

f2_libinput() {
ambiente_xorg
mkdir build
cd    build
meson setup ..              \
      --prefix=$XORG_PREFIX \
      --buildtype=release   \
      -D debug-gui=false    \
      -D tests=false        \
      -D libwacom=false     \
      -D udev-dir=/usr/lib/udev
ninja
ninja install
}

f2_hwdata() {
./configure --prefix=/usr --disable-blacklist
make install
}

f2_libdisplay_info() {
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2_seatd() {
mkdir build
cd    build
# MODIFICA: tenuti il servizio seatd e il suo collegamento (il libro li toglie perche'
# usa le sessioni di systemd-logind, che senza Linux-PAM non ci sono)
meson setup --prefix=/usr             \
            --buildtype=release       \
            ..
ninja
ninja install
# NON IN BLFS: servizio di sistema che avvia seatd all'accensione
# (chi e' nel gruppo "video" puo' usare schermo, tastiera e mouse per la grafica)
cat > /usr/lib/systemd/system/seatd.service << "EOF"
[Unit]
Description=Seat management daemon
Documentation=man:seatd(1)

[Service]
Type=simple
ExecStart=/usr/bin/seatd -g video
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF
systemctl enable seatd
}

f2_wlroots() {
mkdir build
cd    build
meson setup --prefix=/usr          \
            --buildtype=release    \
            --wrap-mode=nofallback \
            ..
ninja
ninja install
}

f2_cmake() {
sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake
# MODIFICA: senza --system-libs (usa le sue librerie interne: curl, libarchive, libuv...
# non sono installate) e con --parallel per compilare piu' in fretta
./bootstrap --prefix=/usr        \
            --mandir=/share/man  \
            --no-system-jsoncpp  \
            --no-system-cppdap   \
            --no-system-librhash \
            --parallel=$(nproc)  \
            --docdir=/share/doc/cmake-4.4.2
make
make install
}

f2_json_c() {
mkdir build
cd    build
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -D BUILD_STATIC_LIBS=OFF     \
      ..
make
make install
}

f2_utf8proc() {
# NON IN BLFS: libreria Unicode (emoji e caratteri composti nel terminale foot)
cmake -B build -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release -D BUILD_SHARED_LIBS=ON
cmake --build build
cmake --install build
}

f2_sway() {
# NON IN BLFS: Sway 1.12 (richiede wlroots 0.20, quella del libro)
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false -D gdk-pixbuf=disabled ..
ninja
ninja install
}

f2_swaybg() {
# NON IN BLFS: lo sfondo del desktop
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false -D gdk-pixbuf=disabled ..
ninja
ninja install
}

f2_tllist() {
# NON IN BLFS: piccola libreria usata da fcft e foot
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2_fcft() {
# NON IN BLFS: caricamento dei caratteri per il terminale foot
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false ..
ninja
ninja install
}

f2_foot() {
# NON IN BLFS: foot, il terminale leggero (e' quello predefinito di Sway)
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false ..
ninja
ninja install
}

f2_bemenu() {
# NON IN BLFS: il menu per avviare i programmi (tasto Super+D)
make PREFIX=/usr clients curses wayland
make PREFIX=/usr install
}

f2_configura() {
# NON IN BLFS: utente normale, avvio automatico della grafica, configurazione di Sway
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
if id "$MIA_UTENTE" >/dev/null 2>&1; then
  usermod -aG video,input,audio,wheel "$MIA_UTENTE"
else
  useradd -m -G video,input,audio,wheel -s /bin/bash "$MIA_UTENTE"
fi
local casa; casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
cat > "$casa/.bash_profile" << "EOF"
# Creato da lfs.sh (Fase 2): entrando dal primo terminale parte la grafica (Sway).
# Dagli altri terminali (Ctrl+Alt+F2...) resti nella riga di comando.
# Questa grafica disegna via software (pixman): va detto a wlroots, altrimenti
# se trova una scheda video cerca il disegno 3D (non installato) e si ferma.
export WLR_RENDERER=pixman
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="/tmp/$(id -u)-runtime-dir"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi
if [ "$(tty)" = /dev/tty1 ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    export LANG=it_IT.UTF-8
    # nelle macchine virtuali il puntatore del mouse "hardware" a volte non si vede
    if systemd-detect-virt -q; then export WLR_NO_HARDWARE_CURSORS=1; fi
    if ! dbus-run-session sway > "$HOME/.sway.log" 2>&1; then
        echo "Sway si e' chiuso con un errore. Il registro e' in: $HOME/.sway.log"
        echo "Per riprovare scrivi:  sway"
    fi
fi
EOF
mkdir -p "$casa/.config/sway"
# configurazione di Sway: quella di serie, con il menu bemenu e la tastiera italiana
sed -e 's/^set \$menu .*/set $menu bemenu-run/' /etc/sway/config > "$casa/.config/sway/config"
cat >> "$casa/.config/sway/config" << "EOF"

# --- aggiunte della tua distro (lfs.sh) ---
# tastiera italiana
input type:keyboard {
    xkb_layout it
}
EOF
grep -q '^set \$menu bemenu-run' "$casa/.config/sway/config" || { echo "Non trovo la riga del menu nella configurazione di Sway"; return 1; }
chown -R "$MIA_UTENTE:" "$casa"
fc-cache -f
echo "Utente $MIA_UTENTE pronto: entrando dal primo terminale parte Sway"
}

LISTA_STEP7=(
  "scdoc (manuali)|scdoc-1.11.4.tar.gz|f2_scdoc"
  "libxml2|libxml2-2.15.3.tar.xz|f2_libxml2"
  "Wayland|wayland-1.26.0.tar.xz|f2_wayland"
  "Wayland-Protocols|wayland-protocols-1.49.tar.xz|f2_wayland_protocols"
  "libpng|libpng-1.6.58.tar.xz|f2_libpng"
  "Pixman|pixman-0.46.4.tar.gz|f2_pixman"
  "FreeType|freetype-2.14.3.tar.xz|f2_freetype2"
  "Fontconfig|fontconfig-2.18.3.tar.xz|f2_fontconfig"
  "caratteri DejaVu|dejavu-fonts-ttf-2.37.tar.bz2|f2_dejavu"
  "FriBidi|fribidi-1.0.16.tar.xz|f2_fribidi"
  "GLib|glib-2.88.3.tar.xz|f2_glib2"
  "HarfBuzz|harfbuzz-14.3.1.tar.xz|f2_harfbuzz"
  "Cairo|cairo-1.18.4.tar.xz|f2_cairo"
  "Pango|pango-1.58.2.tar.xz|f2_pango"
  "libdrm|libdrm-2.4.134.tar.xz|f2_libdrm"
  "XKeyboardConfig|xkeyboard-config-2.48.tar.xz|f2_xkeyboard_config"
  "libxkbcommon|libxkbcommon-1.13.2.tar.gz|f2_libxkbcommon"
  "mtdev|mtdev-1.1.7.tar.bz2|f2_mtdev"
  "libevdev|libevdev-1.13.6.tar.xz|f2_libevdev"
  "libinput|libinput-1.31.3.tar.gz|f2_libinput"
  "hwdata|hwdata-0.410.tar.gz|f2_hwdata"
  "libdisplay-info|libdisplay-info-0.4.0.tar.xz|f2_libdisplay_info"
  "seatd|seatd-0.9.3.tar.gz|f2_seatd"
  "wlroots|wlroots-0.20.2.tar.bz2|f2_wlroots"
  "CMake|cmake-4.4.2.tar.gz|f2_cmake"
  "json-c|json-c-0.19.tar.gz|f2_json_c"
  "utf8proc|utf8proc-2.12.0.tar.gz|f2_utf8proc"
  "Sway|sway-1.12.tar.gz|f2_sway"
  "swaybg (sfondo)|swaybg-1.2.2.tar.gz|f2_swaybg"
  "tllist|tllist-1.1.0.tar.gz|f2_tllist"
  "fcft|fcft-3.3.3.tar.gz|f2_fcft"
  "foot (terminale)|foot-1.28.0.tar.gz|f2_foot"
  "bemenu (menu dei programmi)|bemenu-0.6.23.tar.gz|f2_bemenu"
  "utente e configurazione della grafica|-|f2_configura"
)

valido_utente() { [[ $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && [ "$1" != root ]; }

chiedi_utente() { # nome e password dell'utente normale (per la grafica)
  [ -n "${UTENTE:-}" ] || UTENTE=$(cat "$CONF_DIR/utente" 2>/dev/null || true)
  if [ -z "${UTENTE:-}" ] && [ -t 0 ]; then
    local def=${SUDO_USER:-utente}; valido_utente "$def" || def=utente
    while true; do
      read -r -p "  Nome del tuo utente per la grafica (minuscole) [$def]: " UTENTE || true
      UTENTE=${UTENTE:-$def}
      valido_utente "$UTENTE" && break
      avviso "Nome non valido: solo lettere minuscole, numeri, - e _ (e non 'root'). Riprova"
    done
  fi
  UTENTE=${UTENTE:-utente}
  valido_utente "$UTENTE" || muori "Nome utente non valido '$UTENTE': solo lettere minuscole, numeri, - e _ (e non 'root')"
  mkdir -p "$CONF_DIR"; echo "$UTENTE" > "$CONF_DIR/utente"
  ok "Utente per la grafica: $UTENTE"
  if montato && [ -e "$STATO_DIR/fatto/password-utente-$UTENTE" ]; then return 0; fi
  [ -z "${PASSWORD_UTENTE:-}" ] || return 0
  [ -t 0 ] || { avviso "Nessun terminale: la password di $UTENTE la imposterai dopo (entra come root e scrivi: passwd $UTENTE)"; return 0; }
  local p1 p2
  while true; do
    read -r -s -p "  Scegli la password per $UTENTE: " p1; echo
    read -r -s -p "  Riscrivila: " p2; echo
    if [ -z "$p1" ]; then avviso "La password non puo' essere vuota"
    elif [ "$p1" != "$p2" ]; then avviso "Le due password sono diverse, riprova"
    else break; fi
  done
  PASSWORD_UTENTE=$p1
  ok "Password ricevuta"
}

imposta_password_utente() {
  [ -e "$STATO_DIR/fatto/password-utente-$UTENTE" ] && return 0
  [ -n "${PASSWORD_UTENTE:-}" ] || { avviso "Password di $UTENTE non impostata: entra come root e scrivi  passwd $UTENTE"; return 0; }
  monta_vfs
  if printf '%s:%s\n' "$UTENTE" "$PASSWORD_UTENTE" | entra_chroot /usr/sbin/chpasswd; then
    touch "$STATO_DIR/fatto/password-utente-$UTENTE"; ok "Password di $UTENTE impostata"
  else
    avviso "Non sono riuscito a impostare la password di $UTENTE: entra come root e scrivi  passwd $UTENTE"
  fi
  smonta_vfs
}

cmd_fase2() {
  serve_root fase2
  titolo "Fase 2 - Interfaccia grafica leggera (Sway)"
  assicura_montato
  [ "$(quanti_fatti "${LISTA_STEP6[@]}")" -eq "${#LISTA_STEP6[@]}" ] || muori "Finisci prima la Fase 1 ('sudo $0 tutto')"
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP7[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 2 da capo (opzione 'rifai')"
  fi
  chiedi_utente
  titolo "Scarico i sorgenti della Fase 2"
  scarica_fonti "${FONTI_FASE2[@]}"
  info "Ci vuole circa un'ora (dipende dal PC). Lascia il terminale aperto."
  local esito=0
  lancia_in_chroot 7 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase2 MIA_ETICHETTA="Fase 2" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  imposta_password_utente
  titolo "FASE 2 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia) ed entra con l'utente '$UTENTE': parte Sway."
  info "Tasti principali (Super = tasto Windows):"
  info "   Super+Invio  terminale       Super+D  menu dei programmi    Super+Shift+Q  chiudi finestra"
  info "   Super+1..9   cambia desktop  Super+Shift+E  esci dalla grafica"
  info "La configurazione da personalizzare e':  /home/$UTENTE/.config/sway/config"
}

# =============================================================================
#  FASE 2b - PROGRAMMI: browser (Firefox), file (Thunar), editor (Mousepad e
#  nano), certificati per i siti sicuri (https), curl e wget, barra di stato.
#  Pacchetti e comandi dal libro BLFS 13.1 (versione systemd) dove ci sono
#  (tag r13.1). Ogni differenza dal libro e' segnata con "# MODIFICA:", le
#  parti che il libro non ha con "# NON IN BLFS".
#  Scelte per restare leggeri:
#   - niente GObject Introspection, Vala e manuali (servono solo a chi sviluppa);
#   - Mesa minima: disegno 3D via software (softpipe) e schede video virtuali,
#     senza LLVM (enorme). Serve alle librerie dei programmi, Sway non la usa;
#   - icone "AdwaitaLegacy" (immagini PNG): quelle nuove sono SVG e per leggerle
#     servirebbe librsvg, che si compila con Rust (pesante);
#   - Firefox e' quello ufficiale di Mozilla, gia' compilato: compilarlo da zero
#     richiede ore e piu' di 16 GB di RAM. Si aggiorna da solo.
# =============================================================================
FONTI_FASE2B=(
  # file | indirizzo | controllo (md5 dal libro BLFS 13.1; sha512 da Gentoo Linux)
  "libtasn1-4.21.0.tar.gz|https://ftpmirror.gnu.org/libtasn1/libtasn1-4.21.0.tar.gz|md5:2ee1d9f3aa66f1e308c46a283aa9a8c2"
  "p11-kit-0.26.5.tar.xz|https://github.com/p11-glue/p11-kit/releases/download/0.26.5/p11-kit-0.26.5.tar.xz|md5:308306e889850bff08fae74ae7897a21"
  "make-ca-1.16.1.tar.gz|https://github.com/lfs-book/make-ca/archive/v1.16.1/make-ca-1.16.1.tar.gz|md5:bf9cea2d24fc5344d4951b49f275c595"
  "curl-8.21.0.tar.xz|https://curl.se/download/curl-8.21.0.tar.xz|md5:230131079987135cbe1eadb77a04af57"
  "wget-1.25.0.tar.gz|https://ftpmirror.gnu.org/wget/wget-1.25.0.tar.gz|md5:c70ba58b36f944e8ba1d655ace552881"
  "util-macros-1.20.2.tar.xz|https://www.x.org/pub/individual/util/util-macros-1.20.2.tar.xz|md5:5f683a1966834b0a6ae07b3680bcb863"
  "xorgproto-2025.1.tar.xz|https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2025.1.tar.xz|md5:15534fa6fb13a6a70afe7561c1424f3c"
  "libXau-1.0.12.tar.xz|https://www.x.org/pub/individual/lib/libXau-1.0.12.tar.xz|md5:4c9f81acf00b62e5de56a912691bd737"
  "libXdmcp-1.1.5.tar.xz|https://www.x.org/pub/individual/lib/libXdmcp-1.1.5.tar.xz|md5:ce0af51de211e4c99a111e64ae1df290"
  "xcb-proto-1.17.0.tar.xz|https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-1.17.0.tar.xz|md5:c415553d2ee1a8cea43c3234a079b53f"
  "libxcb-1.17.0.tar.xz|https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz|md5:96565523e9f9b701fcb35d31f1d4086e"
  "cairo-1.18.4.tar.xz|https://www.cairographics.org/releases/cairo-1.18.4.tar.xz|md5:db575fb41bbda127e0147e401f36f8ac"
  "mako-1.4.1.tar.gz|https://files.pythonhosted.org/packages/source/M/Mako/mako-1.4.1.tar.gz|md5:9c09a897c23a34df7ba614ec2d7229e1"
  "pyyaml-6.0.3.tar.gz|https://files.pythonhosted.org/packages/source/P/PyYAML/pyyaml-6.0.3.tar.gz|md5:dbc6f815cd75160ccf12e470be1c8d6e"
  "mesa-26.1.7.tar.xz|https://mesa.freedesktop.org/archive/mesa-26.1.7.tar.xz|md5:1a3ea044abc823e2db8c6041e5adcc4f"
  "libepoxy-1.5.10.tar.xz|https://download.gnome.org/sources/libepoxy/1.5/libepoxy-1.5.10.tar.xz|md5:10c635557904aed5239a4885a7c4efb7"
  "gsettings-desktop-schemas-50.1.tar.xz|https://download.gnome.org/sources/gsettings-desktop-schemas/50/gsettings-desktop-schemas-50.1.tar.xz|md5:b3851a1d2dd684f7ea1a1d032e2a7dfb"
  "at-spi2-core-2.60.6.tar.xz|https://download.gnome.org/sources/at-spi2-core/2.60/at-spi2-core-2.60.6.tar.xz|md5:1082626c9a82694b7900f8283b20dfac"
  "shared-mime-info-2.5.1.tar.gz|https://gitlab.freedesktop.org/xdg/shared-mime-info/-/archive/2.5.1/shared-mime-info-2.5.1.tar.gz|md5:5f8baa7bac254ea9e65782f754a2880b"
  "gdk-pixbuf-2.44.7.tar.xz|https://download.gnome.org/sources/gdk-pixbuf/2.44/gdk-pixbuf-2.44.7.tar.xz|md5:2a12da2133476b7b36fbfcadd7133315"
  "hicolor-icon-theme-0.18.tar.xz|https://icon-theme.freedesktop.org/releases/hicolor-icon-theme-0.18.tar.xz|md5:ef14f3af03bcde9ed134aad626bdbaad"
  "gtk-3.24.52.tar.xz|https://download.gnome.org/sources/gtk/3.24/gtk-3.24.52.tar.xz|md5:4dfad1e56bf8ad25dfab58add17e7146"
  "adwaita-icon-theme-legacy-46.2.tar.xz|https://download.gnome.org/sources/adwaita-icon-theme-legacy/46/adwaita-icon-theme-legacy-46.2.tar.xz|sha512:01e4711e353d44914ed69a5d815046260c360f6da5586e419f54b33e9661abbb90bc8b675a505107e713d5b872d0d464491589498f40bad00f03183ddd81e791"
  "alsa-lib-1.2.16.1.tar.bz2|https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.16.1.tar.bz2|md5:c14c9f94f78f76924c13668954997a33"
  "alsa-ucm-conf-1.2.16.1.tar.bz2|https://www.alsa-project.org/files/pub/lib/alsa-ucm-conf-1.2.16.1.tar.bz2|sha512:df25a29afc3b87347fa89f3fe60ebda68068acdaf68e081b58455ebee319c21e82af4076ba1f10781ba620a9e8efa6e65db27c5989d63a429d44a715dbd1d460"
  "libxfce4util-4.20.1.tar.bz2|https://archive.xfce.org/src/xfce/libxfce4util/4.20/libxfce4util-4.20.1.tar.bz2|md5:8e30b7735333f74d80c379e15d9da145"
  "xfconf-4.20.0.tar.bz2|https://archive.xfce.org/src/xfce/xfconf/4.20/xfconf-4.20.0.tar.bz2|md5:ca596ff0a9be7fa655bb09cb05458644"
  "libxfce4ui-4.20.2.tar.bz2|https://archive.xfce.org/src/xfce/libxfce4ui/4.20/libxfce4ui-4.20.2.tar.bz2|md5:ce54074a9ed7964b4a3274e8ac74d949"
  "exo-4.20.0.tar.bz2|https://archive.xfce.org/src/xfce/exo/4.20/exo-4.20.0.tar.bz2|md5:f059ec3d8686d4b322c42d19ebec0366"
  "thunar-4.20.9.tar.bz2|https://archive.xfce.org/src/xfce/thunar/4.20/thunar-4.20.9.tar.bz2|md5:7d6daadb0c241ebfaed2684950a67f74"
  "gtksourceview-4.8.4.tar.xz|https://download.gnome.org/sources/gtksourceview/4.8/gtksourceview-4.8.4.tar.xz|md5:2bf056caaae27654ec3a5930dd5597d3"
  "mousepad-0.7.0.tar.xz|https://archive.xfce.org/src/apps/mousepad/0.7/mousepad-0.7.0.tar.xz|md5:96c09736fd02da599ffedf215313328f"
  "nano-9.2.tar.xz|https://www.nano-editor.org/dist/v9/nano-9.2.tar.xz|md5:9bb0f37945afa964d16bffd9e4da3106"
  "fuzzel-1.15.0.tar.gz|https://codeberg.org/dnkl/fuzzel/archive/1.15.0.tar.gz|sha256:95b6c022fc1f1c7ab586d47c1594417cc311bf41ea8f5f8b5641478da7b5cf3b"
)

# Le 32 librerie X: l'elenco con gli md5 e' quello del libro, scritto una volta sola
# dentro f2b_xorg_lib (qui sotto). Si scaricano sul tuo PC nella cartella sources/xlib.
scarica_elenco() { # nome-elenco cartella indirizzo-base quanti  (elenco = heredoc del libro nello script)
  local righe md5 f voci=()
  righe=$(sed -n "/^cat > $1 << \"EOF\"\$/,/^EOF\$/p" "${BASH_SOURCE[0]}" | grep -E '^[0-9a-f]{32}  [A-Za-z0-9._-]+$' || true)
  [ "$(printf '%s\n' "$righe" | grep -c . || true)" -eq "$4" ] || muori "Non trovo l'elenco $1 dentro lo script"
  while read -r md5 f; do
    voci+=("$2/$f|$3$f|md5:$md5")
  done <<<"$righe"
  mkdir -p "$LFS/sources/$2"
  scarica_fonti "${voci[@]}"
}

scarica_xlib() { scarica_elenco lib-7.md5 xlib https://www.x.org/pub/individual/lib/ 32; }

# certdata.txt: l'elenco ufficiale di Mozilla delle autorita' che garantiscono i siti
# sicuri (https). Il libro lo fa scaricare a make-ca dentro il nuovo sistema; qui lo
# scarica il tuo PC (sempre da Mozilla, in https) e make-ca lo usa dal file.
certdata_valido() { [ -s "$1" ] && [ "$(grep -c '^CKA_CLASS CK_OBJECT_CLASS CKO_CERTIFICATE' "$1" || true)" -gt 50 ]; }

scarica_certificati() {
  local f="$LFS/sources/certdata.txt" u
  if certdata_valido "$f"; then info "certdata.txt  (gia' scaricato)"; return 0; fi
  for u in https://hg-edge.mozilla.org/projects/nss/raw-file/tip/lib/ckfw/builtins/certdata.txt \
           https://raw.githubusercontent.com/nss-dev/nss/HEAD/lib/ckfw/builtins/certdata.txt; do
    info "certdata.txt (certificati dei siti sicuri, da Mozilla)"
    if scarica "$u" "$f" && certdata_valido "$f"; then ok "Certificati scaricati"; return 0; fi
    rm -f "$f" "$f.part"
  done
  muori "Non riesco a scaricare i certificati (certdata.txt): riprova tra un po'"
}

# Firefox: l'ultima versione ufficiale, in italiano, dal sito di Mozilla. Il controllo
# SHA-512 usa l'elenco pubblicato da Mozilla per quella versione (SHA512SUMS).
FIREFOX_RISERVA=159.0     # si usa solo se il sito di Mozilla non dice qual e' l'ultima

scarica_firefox() {
  local d="$LFS/sources" ver base atteso
  if [ -s "$d/firefox.tar.xz" ] && [ -s "$d/firefox.sha512" ] \
     && [ "$(sha512sum "$d/firefox.tar.xz" | cut -d' ' -f1)" = "$(cut -d' ' -f1 "$d/firefox.sha512")" ]; then
    info "Firefox $(cut -d' ' -f2 "$d/firefox.sha512")  (gia' scaricato)"; return 0
  fi
  ver=$(curl -fsSL --retry 3 --connect-timeout 20 https://product-details.mozilla.org/1.0/firefox_versions.json </dev/null \
        | sed -n 's/.*"LATEST_FIREFOX_VERSION": *"\([0-9][0-9.]*\)".*/\1/p' | head -n1 || true)
  if [ -z "$ver" ]; then
    avviso "Non riesco a sapere qual e' l'ultima versione di Firefox: uso la $FIREFOX_RISERVA (poi si aggiorna da solo)"
    ver=$FIREFOX_RISERVA
  fi
  base="https://archive.mozilla.org/pub/firefox/releases/$ver"
  info "Firefox $ver in italiano (circa 90 MB)"
  scarica "$base/SHA512SUMS" "$d/firefox-SHA512SUMS" || muori "Non riesco a scaricare i controlli di Firefox: riprova tra un po'"
  atteso=$(awk -v f="linux-x86_64/it/firefox-$ver.tar.xz" '$2 == f { print $1 }' "$d/firefox-SHA512SUMS")
  [ -n "$atteso" ] || muori "Nell'elenco di Mozilla non c'e' Firefox $ver per Linux in italiano"
  scarica "$base/linux-x86_64/it/firefox-$ver.tar.xz" "$d/firefox.tar.xz" || muori "Download di Firefox non riuscito: riprova tra un po'"
  if [ "$(sha512sum "$d/firefox.tar.xz" | cut -d' ' -f1)" != "$atteso" ]; then
    rm -f "$d/firefox.tar.xz"; muori "Il file di Firefox e' rovinato (controllo SHA-512 fallito): riprova"
  fi
  echo "$atteso $ver" > "$d/firefox.sha512"
  rm -f "$d/firefox-SHA512SUMS"
  ok "Firefox $ver scaricato e controllato (SHA-512 pubblicato da Mozilla)"
}

f2b_libtasn1() {
./configure --prefix=/usr --disable-static
make
make install
}

f2b_p11_kit() {
sed '20,$ d' -i trust/trust-extract-compat

cat >> trust/trust-extract-compat << "EOF"
# Copy existing anchor modifications to /etc/ssl/local
/usr/libexec/make-ca/copy-trust-modifications

# Update trust stores
/usr/sbin/make-ca -r
EOF
mkdir p11-build
cd    p11-build

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D trust_paths=/etc/pki/anchors
ninja
ninja install
ln -sfv /usr/libexec/p11-kit/trust-extract-compat \
        /usr/bin/update-ca-certificates
ln -sfv ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
}

f2b_make_ca() {
sed '/mktemp/s/-t //' -i make-ca
make install
install -vdm755 /etc/ssl/local
# MODIFICA: "-C /sources/certdata.txt" al posto di "-g": il file dei certificati l'ha
# gia' scaricato lo script sul tuo PC (qui dentro non c'e' la rete)
/usr/sbin/make-ca -C /sources/certdata.txt
systemctl enable update-pki.timer
mkdir -pv /etc/profile.d
cat > /etc/profile.d/pythoncerts.sh << "EOF"
# Begin /etc/profile.d/pythoncerts.sh

export _PIP_STANDALONE_CERT=/etc/pki/tls/certs/ca-bundle.crt

# End /etc/profile.d/pythoncerts.sh
EOF
}

f2b_curl() {
# MODIFICA: --without-libpsl (libpsl non installata: serve a controllare i cookie
# dei domini, curl funziona lo stesso)
./configure --prefix=/usr    \
            --disable-static \
            --with-openssl   \
            --without-libpsl \
            --with-ca-path=/etc/ssl/certs
make
make install

rm -rf docs/examples/.deps

find docs \( -name Makefile\* -o  \
             -name \*.1       -o  \
             -name \*.3       -o  \
             -name CMakeLists.txt \) -delete

cp -v -R docs -T /usr/share/doc/curl-8.21.0
}

f2b_wget() {
NEW_LINE='#if !defined OPENSSL_NO_SSL3_METHOD '
NEW_LINE+='&& OPENSSL_VERSION_NUMBER < 0x40000000L'

sed -i "/SSL3/c $NEW_LINE" src/openssl.c

unset NEW_LINE
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl
make
make install
}

f2b_util_macros() {
ambiente_xorg
./configure $XORG_CONFIG
make install
}

f2b_xorgproto() {
ambiente_xorg
mkdir build
cd    build

meson setup --prefix=$XORG_PREFIX ..
ninja
ninja install
mv -v $XORG_PREFIX/share/doc/xorgproto{,-2025.1}
}

f2b_libXau() {
ambiente_xorg
./configure $XORG_CONFIG
make
make install
}

f2b_libXdmcp() {
ambiente_xorg
./configure $XORG_CONFIG --docdir='${datadir}'/doc/libXdmcp-1.1.5
make
make install
}

f2b_xcb_proto() {
ambiente_xorg
PYTHON=python3 ./configure $XORG_CONFIG
make install
}

f2b_libxcb() {
ambiente_xorg
./configure $XORG_CONFIG      \
            --without-doxygen \
            --docdir='${datadir}'/doc/libxcb-1.17.0
LC_ALL=en_US.UTF-8 make
make install
chown -Rv root:root $XORG_PREFIX/share/doc/libxcb-1.17.0
}

f2b_xorg_lib() {
# BLFS, pagina "Xorg Libraries": 32 librerie X (servono a GTK3, Mesa e Firefox)
ambiente_xorg
cat > lib-7.md5 << "EOF"
6ad67d4858814ac24e618b8072900664  xtrans-1.6.0.tar.xz
b617a053d2003cc81309f4e13d01379c  libX11-1.8.13.tar.xz
ea8149187a26e9df6dbd94a60b3d8da0  libXext-1.3.7.tar.xz
c5cc0942ed39c49b8fcd47a427bd4305  libFS-1.0.10.tar.xz
d1ffde0a07709654b20bada3f9abdd16  libICE-1.1.2.tar.xz
3aeeea05091db1c69e6f768e0950a431  libSM-1.2.6.tar.xz
ec09c90a1cfd2c0630321d366a5e7203  libXScrnSaver-1.2.5.tar.xz
9acd189c68750b5028cf120e53c68009  libXt-1.3.1.tar.xz
1ef8065f0284e76c2238770365012ab2  libXmu-1.3.1.tar.xz
cdc7a83243dba674b1ea3c365a1deab1  libXpm-3.5.19.tar.xz
2a9793533224f92ddad256492265dd82  libXaw-1.0.16.tar.xz
baa39ada682dd524491a165bb0dfc708  libXfixes-6.0.2.tar.xz
132816d5efccb883bbc2bf45eb905770  libXcomposite-0.4.7.tar.xz
4c54dce455d96e3bdee90823b0869f89  libXrender-0.9.12.tar.xz
5ce55e952ec2d84d9817169d5fdb7865  libXcursor-1.2.3.tar.xz
72bb73f2a07f81784ad69a39d7df1da2  libXdamage-1.1.7.tar.xz
3cba344d6b351cf308114865afa0d91e  libfontenc-1.1.9.tar.xz
134b3f673f6ecd3e67c0e892dd1a89e8  libXfont2-2.0.9.tar.xz
d378be0fcbd1f689f9a132e0d642bc4b  libXft-2.3.9.tar.xz
2b1cde310bc361464df43276fb969adf  libXi-1.8.3.tar.xz
5f3f5754a40730d1518233a60ba5c48e  libXinerama-1.1.6.tar.xz
b550dfa388292a821aecdd52acecc94c  libXrandr-1.5.5.tar.xz
5014282a08b54ec0edfa73c5cf9ae2c1  libXres-1.2.3.tar.xz
b62dc44d8e63a67bb10230d54c44dcb7  libXtst-1.2.5.tar.xz
8a26503185afcb1bbd2c65e43f775a67  libXv-1.0.13.tar.xz
de4227c5722a8f5ca5748f3ef524aeee  libXvMC-1.0.15.tar.xz
543164f1239fbe92cc0a9128d8da88e9  libXxf86dga-1.1.7.tar.xz
bea9e3707fae6c3275769e771006fa0f  libXxf86vm-1.1.7.tar.xz
0c11ea502b531e59563a9aa7979146fc  libpciaccess-0.19.tar.xz
fa0faa5b6a8e726186c535d73712ccea  libxkbfile-1.2.0.tar.xz
9805be7e18f858bed9938542ed2905dc  libxshmfence-1.3.3.tar.xz
53b72ce969745f8d3e41175d6549ce0b  libXpresent-1.0.2.tar.xz
EOF
# MODIFICA: i file li ha gia' scaricati e controllati lo script sul tuo PC, nella
# cartella xlib (al posto di "mkdir lib; cd lib; wget ..."). Qui si ricontrollano.
cd xlib
md5sum -c ../lib-7.md5
as_root()
{
  if   [ $EUID = 0 ];        then $*
  elif [ -x /usr/bin/sudo ]; then sudo $*
  else                            su -c \\"$*\\"
  fi
}

export -f as_root
# (il libro apre una shell "bash -e" che si ferma al primo errore: qui lo fa gia' lo script)
for package in $(grep -v '^#' ../lib-7.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.?z*}
  echo "Building $packagedir"

  tar -xf $package
  pushd $packagedir
  docdir="--docdir=$XORG_PREFIX/share/doc/$packagedir"

  do_build() { make; }
  do_test() { make check; }
  do_install() { as_root make install; }

  case $packagedir in
    libXfont2-[0-9]* )
      ./configure $XORG_CONFIG $docdir --disable-devel-docs
    ;;

    libXt-[0-9]* )
      ./configure $XORG_CONFIG $docdir \
                  --with-appdefaultdir=/etc/X11/app-defaults
    ;;

    libXpm-[0-9]* )
      ./configure $XORG_CONFIG $docdir --disable-open-zfile
    ;;

    libpciaccess* | libxkbfile* )
      meson setup --prefix=$XORG_PREFIX --buildtype=release build
      do_build()  { ninja -C build; }
      do_test() { ninja -C build test; }
      do_install() { as_root ninja -C build install; }
    ;;

    * )
      ./configure $XORG_CONFIG $docdir
    ;;
  esac

  do_build
  #do_test |& tee ../$packagedir-test.log
  do_install
  unset do_build do_test do_install

  popd
  rm -rf $packagedir
  as_root /sbin/ldconfig
done
}

f2b_cairo() {
# Cairo di nuovo (era nella Fase 2): adesso ci sono le librerie X e la ricompilazione
# aggiunge il disegno per X11, che serve a GTK3 e a Firefox
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2b_mako() {
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD
pip3 install --no-index --find-links dist --no-user Mako
}

f2b_pyyaml() {
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD
pip3 install --no-index --find-links dist --no-user PyYAML
}

f2b_mesa() {
ambiente_xorg
mkdir build
cd    build

# MODIFICA: solo i driver "softpipe" (disegno 3D col processore), "virgl" (QEMU) e
# "svga" (VMware): gli altri richiedono LLVM, enorme. Niente Vulkan (servirebbero
# glslang e vulkan-loader) e niente "-D video-codecs=all" (serve solo con libva e
# VDPAU, non installati; il libro stesso consiglia di toglierlo se distribuisci la distro)
meson setup ..                 \
      --prefix=$XORG_PREFIX    \
      --buildtype=release      \
      -D platforms=x11,wayland \
      -D gallium-drivers=softpipe,virgl,svga \
      -D vulkan-drivers=""     \
      -D llvm=disabled         \
      -D valgrind=disabled     \
      -D libunwind=disabled

ninja
ninja install
}

f2b_libepoxy() {
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2b_gsettings_desktop_schemas() {
sed -i -r 's:"(/system):"/org/gnome\1:g' schemas/*.in

mkdir build
cd    build

# MODIFICA: -D introspection=false (niente GObject Introspection, vedi GLib nella Fase 2)
meson setup --prefix=/usr --buildtype=release -D introspection=false ..
ninja
ninja install
}

f2b_at_spi2_core() {
mkdir build
cd    build

# MODIFICA: -D introspection=disabled
meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -D gtk2_atk_adaptor=false \
      -D introspection=disabled
ninja
ninja install
}

f2b_shared_mime_info() {
mkdir build
cd    build

meson setup --prefix=/usr         \
            --buildtype=release   \
            -D update-mimedb=true \
            -D build-tests=false  \
            -D build-spec=false   \
            ..
ninja
ninja install
}

f2b_gdk_pixbuf() {
mkdir build
cd    build

# MODIFICA: -D png=enabled (il libro legge le immagini con glycin, che si compila con
# Rust: qui si usa il lettore PNG interno, serve per le icone), -D man=false (servirebbe
# docutils) e -D introspection=disabled
meson setup ..                \
      --prefix=/usr           \
      --buildtype=release     \
      -D png=enabled          \
      -D gif=disabled         \
      -D jpeg=disabled        \
      -D tiff=disabled        \
      -D thumbnailer=disabled \
      -D man=false            \
      -D introspection=disabled \
      --wrap-mode=nofallback  \
      $(pkgconf glycin-2 || echo -D glycin=disabled)
ninja
ninja install
gdk-pixbuf-query-loaders --update-cache
}

f2b_hicolor() {
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2b_gtk3() {
mkdir build
cd    build

# MODIFICA: -D man=false (servirebbero docbook-xsl e libxslt) e -D introspection=false
meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D man=false        \
      -D introspection=false \
      -D broadway_backend=true
ninja
ninja install
gtk-query-immodules-3.0 --update-cache
}

f2b_adwaita_legacy() {
# NON IN BLFS: le icone a colori del tema Adwaita in formato PNG (cartelle, file,
# pulsanti). GTK3 le legge senza librsvg. Si compila come gli altri pacchetti meson.
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2b_alsa_lib() {
# ALSA: la libreria del suono di Linux (Firefox la richiede)
./configure
make
make install
tar -C /usr/share/alsa --strip-components=1 -xf ../alsa-ucm-conf-1.2.16.1.tar.bz2
}

f2b_libxfce4util() {
./configure --prefix=/usr
make
make install
}

f2b_xfconf() {
./configure --prefix=/usr
make
make install
}

f2b_libxfce4ui() {
./configure --prefix=/usr --sysconfdir=/etc
make
make install
}

f2b_exo() {
./configure --prefix=/usr --sysconfdir=/etc
make
make install
}

f2b_thunar() {
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/thunar-4.20.9
make
make install
}

f2b_gtksourceview4() {
mkdir build
cd    build

# MODIFICA: -D gir=false -D vapi=false (servirebbero GObject Introspection e Vala)
meson setup --prefix=/usr --buildtype=release -D gir=false -D vapi=false ..
ninja
ninja install
}

f2b_mousepad() {
mkdir build
cd    build

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release

ninja
ninja install
}

f2b_nano() {
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --enable-utf8     \
            --docdir=/usr/share/doc/nano-9.2
make
make install
install -v -m644 doc/{nano.html,sample.nanorc} /usr/share/doc/nano-9.2
}

f2b_firefox() {
# NON IN BLFS: Firefox ufficiale di Mozilla (gia' compilato, in italiano).
# Va in /opt/firefox e appartiene al tuo utente: cosi' Firefox si aggiorna da solo
# (gli aggiornamenti arrivano da Mozilla firmati, e Firefox controlla la firma).
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
[ -x ./firefox ] || { echo "L'archivio di Firefox non contiene il programma"; return 1; }
rm -rf /opt/firefox
mkdir -p /opt
cp -a . /opt/firefox
chown -R "$MIA_UTENTE:" /opt/firefox
ln -sfv /opt/firefox/firefox /usr/bin/firefox
install -vdm755 /usr/share/applications
cat > /usr/share/applications/firefox.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Firefox
GenericName=Browser web
Comment=Navigare in Internet
Exec=firefox %u
Icon=/opt/firefox/browser/chrome/icons/default/default128.png
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;application/xhtml+xml;application/pdf;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
StartupWMClass=firefox
EOF
# controllo: ci sono tutte le librerie di sistema che servono a Firefox?
local f manca
manca=$(for f in /opt/firefox/libxul.so /opt/firefox/libmozgtk.so /opt/firefox/firefox-bin; do
          [ -e "$f" ] && LD_LIBRARY_PATH=/opt/firefox ldd "$f" 2>&1
        done | grep 'not found' | sort -u || true)
if [ -n "$manca" ]; then
  echo "A Firefox mancano queste librerie:"
  echo "$manca"
  return 1
fi
echo "[OK] Firefox: ci sono tutte le librerie che gli servono"
}

f2b_configura() {
# NON IN BLFS: impostazioni per usare i nuovi programmi dentro Sway
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa conf
casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
conf="$casa/.config/sway/config"
[ -f "$conf" ] || { echo "Non trovo la configurazione di Sway ($conf): rifai la Fase 2"; return 1; }

# aspetto dei programmi GTK per tutti gli utenti (come nell'esempio del libro BLFS,
# pagina GTK3, ma con le icone installate qui e senza tema del puntatore)
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << "EOF"
[Settings]
gtk-theme-name = Adwaita
gtk-icon-theme-name = AdwaitaLegacy
gtk-font-name = DejaVu Sans 11
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintslight
gtk-xft-rgba = rgb
EOF

# programmi predefiniti per aprire cartelle, testi, pagine web e immagini
mkdir -p /etc/xdg
cat > /etc/xdg/mimeapps.list << "EOF"
[Default Applications]
inode/directory=thunar.desktop
text/plain=org.xfce.mousepad.desktop
text/html=firefox.desktop
application/xhtml+xml=firefox.desktop
application/pdf=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
image/png=firefox.desktop
image/jpeg=firefox.desktop
image/gif=firefox.desktop
image/svg+xml=firefox.desktop
EOF

# barra di stato di Sway: rete, memoria usata, carico del processore, batteria, ora.
# Legge solo file del sistema ogni 5 secondi: consuma pochissimo.
mkdir -p /usr/local/bin
cat > /usr/local/bin/barra-stato << "EOF"
#!/bin/bash
# Barra di stato di Sway (creata da lfs.sh). Per cambiarla: modifica questo file.
while :; do
    rete="rete: no"
    for d in /sys/class/net/*; do
        [ "${d##*/}" = lo ] && continue
        stato=; read -r stato < "$d/operstate" 2>/dev/null
        if [ "$stato" = up ]; then rete="rete: si"; break; fi
    done
    tot=0; libera=0
    while read -r k v _; do
        case $k in MemTotal:) tot=$v ;; MemAvailable:) libera=$v ;; esac
    done < /proc/meminfo
    read -r carico _ < /proc/loadavg
    bat=
    for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/capacity" ] || continue
        read -r c < "$b/capacity"; bat=" | batteria: $c%"
    done
    printf '%s | RAM: %d/%d MB | carico: %s%s | %s\n' "$rete" $(( (tot - libera) / 1024 )) \
        $(( tot / 1024 )) "$carico" "$bat" "$(date '+%a %d/%m %H:%M')"
    sleep 5
done
EOF
chmod 755 /usr/local/bin/barra-stato
if grep -q '^[[:space:]]*status_command while date' "$conf"; then
  sed -i 's|^\([[:space:]]*\)status_command while date.*|\1status_command /usr/local/bin/barra-stato|' "$conf"
elif ! grep -q 'status_command /usr/local/bin/barra-stato' "$conf"; then
  echo "Nota: nella configurazione di Sway la barra era gia' cambiata da te, la lascio com'e'"
fi

# tasti per i programmi ($mod e' il tasto scelto in alto nella configurazione:
# Super/Windows, oppure Alt se l'hai cambiato)
if ! grep -q 'aggiunte della Fase 2b' "$conf"; then
cat >> "$conf" << "EOF"

# --- aggiunte della Fase 2b (lfs.sh) ---
# I = internet (Firefox), C = cartelle (Thunar), N = note (Mousepad)
bindsym $mod+i exec firefox
bindsym $mod+c exec thunar
bindsym $mod+n exec mousepad
EOF
fi
chown "$MIA_UTENTE:" "$conf"

# indici che i programmi grafici leggono all'avvio (impostazioni, icone, tipi di file)
glib-compile-schemas /usr/share/glib-2.0/schemas
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
gtk-update-icon-cache -qtf /usr/share/icons/AdwaitaLegacy
update-mime-database /usr/share/mime
gdk-pixbuf-query-loaders --update-cache
echo "[OK] Programmi pronti: Firefox, Thunar, Mousepad, nano, curl, wget"
}

f2b_fuzzel() {
# NON IN BLFS: fuzzel, la schermata con tutte le app (icone e ricerca). E' dello
# stesso autore del terminale foot e usa le stesse librerie (gia' installate).
# Le icone SVG le legge da solo (nanosvg, incluso nel pacchetto): niente librsvg.
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false \
            -D enable-cairo=enabled -D png-backend=libpng -D svg-backend=nanosvg ..
ninja
ninja install
}

f2b_menu_app() {
# NON IN BLFS: tasto Windows = schermata con tutte le app; schermo 1920x1080
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa conf f
casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
conf="$casa/.config/sway/config"
[ -f "$conf" ] || { echo "Non trovo la configurazione di Sway ($conf): rifai la Fase 2"; return 1; }

# aspetto del menu, uguale per tutti gli utenti
mkdir -p /etc/xdg/fuzzel
cat > /etc/xdg/fuzzel/fuzzel.ini << "EOF"
# Menu delle app (fuzzel), creato da lfs.sh.
# Per cambiarlo solo per te: copialo in ~/.config/fuzzel/fuzzel.ini e modifica quello.
[main]
font=DejaVu Sans:size=13
prompt="Cerca: "
terminal=foot
lines=14
width=45
layer=overlay

[colors]
background=323232f2
text=ffffffff
match=8fc7ffff
selection=285577ff
selection-text=ffffffff
selection-match=bfe1ffff
border=4c7899ff

[border]
width=2
radius=10
EOF

# nel menu solo le app vere: si nascondono le voci tecniche (prove di GTK,
# impostazioni, servizi). Le copie in /usr/local hanno la precedenza sugli originali.
mkdir -p /usr/local/share/applications
for f in footclient.desktop foot-server.desktop gtk3-demo.desktop \
         gtk3-widget-factory.desktop gtk3-icon-browser.desktop xfce4-about.desktop \
         thunar-bulk-rename.desktop thunar-settings.desktop org.xfce.mousepad-settings.desktop; do
  [ -f "/usr/share/applications/$f" ] || continue
  sed '/^\[Desktop Entry\]/a NoDisplay=true' "/usr/share/applications/$f" > "/usr/local/share/applications/$f"
done

# tasto+D apre lo stesso menu (al posto della riga di bemenu)
sed -i 's/^set \$menu bemenu-run$/set $menu fuzzel/' "$conf"

if ! grep -q 'menu delle app e schermo (lfs.sh)' "$conf"; then
cat >> "$conf" << "EOF"

# --- menu delle app e schermo (lfs.sh) ---
# tasto Windows da solo (premi e rilascia): apre o chiude la schermata con tutte le app
bindsym --release Mod4+Super_L exec pkill -x fuzzel || fuzzel
bindsym --release Mod4+Super_R exec pkill -x fuzzel || fuzzel
bindsym --release Super_L exec pkill -x fuzzel || fuzzel
# schermo della macchina virtuale: 1920x1080, come un monitor normale
output Virtual-1 mode 1920x1080
EOF
fi
chown "$MIA_UTENTE:" "$conf"
echo "[OK] Tasto Windows: schermata con tutte le app. Schermo della macchina virtuale: 1920x1080"
}

LISTA_STEP8=(
  "libtasn1|libtasn1-4.21.0.tar.gz|f2b_libtasn1"
  "p11-kit|p11-kit-0.26.5.tar.xz|f2b_p11_kit"
  "make-ca (certificati dei siti sicuri)|make-ca-1.16.1.tar.gz|f2b_make_ca"
  "cURL|curl-8.21.0.tar.xz|f2b_curl"
  "Wget|wget-1.25.0.tar.gz|f2b_wget"
  "util-macros|util-macros-1.20.2.tar.xz|f2b_util_macros"
  "xorgproto|xorgproto-2025.1.tar.xz|f2b_xorgproto"
  "libXau|libXau-1.0.12.tar.xz|f2b_libXau"
  "libXdmcp|libXdmcp-1.1.5.tar.xz|f2b_libXdmcp"
  "xcb-proto|xcb-proto-1.17.0.tar.xz|f2b_xcb_proto"
  "libxcb|libxcb-1.17.0.tar.xz|f2b_libxcb"
  "librerie X (32 pacchetti)|-|f2b_xorg_lib"
  "Cairo (con X11)|cairo-1.18.4.tar.xz|f2b_cairo"
  "Mako|mako-1.4.1.tar.gz|f2b_mako"
  "PyYAML|pyyaml-6.0.3.tar.gz|f2b_pyyaml"
  "Mesa (minima)|mesa-26.1.7.tar.xz|f2b_mesa"
  "libepoxy|libepoxy-1.5.10.tar.xz|f2b_libepoxy"
  "gsettings-desktop-schemas|gsettings-desktop-schemas-50.1.tar.xz|f2b_gsettings_desktop_schemas"
  "at-spi2-core|at-spi2-core-2.60.6.tar.xz|f2b_at_spi2_core"
  "shared-mime-info|shared-mime-info-2.5.1.tar.gz|f2b_shared_mime_info"
  "gdk-pixbuf|gdk-pixbuf-2.44.7.tar.xz|f2b_gdk_pixbuf"
  "hicolor-icon-theme|hicolor-icon-theme-0.18.tar.xz|f2b_hicolor"
  "GTK3|gtk-3.24.52.tar.xz|f2b_gtk3"
  "icone AdwaitaLegacy|adwaita-icon-theme-legacy-46.2.tar.xz|f2b_adwaita_legacy"
  "alsa-lib (suono)|alsa-lib-1.2.16.1.tar.bz2|f2b_alsa_lib"
  "libxfce4util|libxfce4util-4.20.1.tar.bz2|f2b_libxfce4util"
  "Xfconf|xfconf-4.20.0.tar.bz2|f2b_xfconf"
  "libxfce4ui|libxfce4ui-4.20.2.tar.bz2|f2b_libxfce4ui"
  "Exo|exo-4.20.0.tar.bz2|f2b_exo"
  "Thunar (file)|thunar-4.20.9.tar.bz2|f2b_thunar"
  "GtkSourceView 4|gtksourceview-4.8.4.tar.xz|f2b_gtksourceview4"
  "Mousepad (editor)|mousepad-0.7.0.tar.xz|f2b_mousepad"
  "nano (editor nel terminale)|nano-9.2.tar.xz|f2b_nano"
  "Firefox (browser)|firefox.tar.xz|f2b_firefox"
  "configurazione dei programmi|-|f2b_configura"
  "fuzzel (schermata delle app)|fuzzel-1.15.0.tar.gz|f2b_fuzzel"
  "tasto Windows e risoluzione|-|f2b_menu_app"
)

cmd_fase2b() {
  serve_root fase2b
  titolo "Fase 2b - Programmi: browser, file, editor"
  assicura_montato
  [ "$(quanti_fatti "${LISTA_STEP7[@]}")" -eq "${#LISTA_STEP7[@]}" ] || muori "Finisci prima la Fase 2 ('sudo $0 fase2')"
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP8[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 2b da capo (opzione 'rifai')"
  fi
  chiedi_utente
  titolo "Scarico i sorgenti della Fase 2b"
  scarica_fonti "${FONTI_FASE2B[@]}"
  info "Librerie X (32 file):"
  scarica_xlib
  scarica_certificati
  scarica_firefox
  info "Ci vuole circa un'ora o poco piu' (dipende dal PC). Lascia il terminale aperto."
  local esito=0
  lancia_in_chroot 8 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase2b MIA_ETICHETTA="Fase 2b" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 2b COMPLETATA"
  info "Accendi la distro (sudo $0 avvia) ed entra con '$UTENTE'. Nuovi tasti"
  info "(tasto = Super/Windows, oppure Alt se l'hai cambiato):"
  info "   tasto+I  Firefox (internet)    tasto+C  Thunar (cartelle)    tasto+N  Mousepad (note)"
  info "   tasto Windows da solo (o tasto+D): schermata con tutte le app"
  info "Nel terminale: 'nano file.txt' per modificare un file, 'curl' e 'wget' per scaricare."
  info "Se Sway era gia' acceso: premi tasto+Shift+C per ricaricare la configurazione."
}

# =============================================================================
#  FASE 2c - DESKTOP: finestre con i pulsanti (riduci, ingrandisci, chiudi X),
#  barra delle applicazioni in basso (menu, programmi aperti, orologio,
#  spegnimento), caratteri e colori come GNOME, sfondo, sudo.
#  Pacchetti e comandi dal libro BLFS 13.1 (versione systemd) dove ci sono
#  (tag r13.1). Ogni differenza dal libro e' segnata con "# MODIFICA:", le
#  parti che il libro non ha con "# NON IN BLFS".
#  Scelte:
#   - labwc al posto di Sway: finestre "normali" (si spostano e si sovrappongono,
#     con i pulsanti in alto), leggerissimo e funziona col disegno via software.
#     Sway resta installato: dalla riga di comando si avvia con "sway".
#   - la barra in basso e' il pannello di Xfce (usa le librerie gia' installate
#     per Thunar e Mousepad); su Wayland gli serve gtk-layer-shell.
#   - caratteri Adwaita Sans e Adwaita Mono: gli stessi di GNOME.
# =============================================================================
FONTI_FASE2C=(
  # file | indirizzo | controllo (md5 dal libro BLFS 13.1; sha256 da Void Linux)
  "gtk-layer-shell-0.10.1.tar.gz|https://github.com/wmww/gtk-layer-shell/archive/refs/tags/v0.10.1.tar.gz|sha256:88c3a3e0a5300532f3d368d5df64838a87f1fb85273f22d41df0a6b8d0ec59c6"
  "libwnck-43.3.tar.xz|https://download.gnome.org/sources/libwnck/43/libwnck-43.3.tar.xz|md5:61938ba1c41f38c9c12033aca5706598"
  "libxfce4windowing-4.20.7.tar.bz2|https://archive.xfce.org/src/xfce/libxfce4windowing/4.20/libxfce4windowing-4.20.7.tar.bz2|md5:7f409dec4961e9340a29b273029453d2"
  "garcon-4.20.0.tar.bz2|https://archive.xfce.org/src/xfce/garcon/4.20/garcon-4.20.0.tar.bz2|md5:fe17e9cb15a62013e0086183a446e89e"
  "xfce4-panel-4.20.8.tar.bz2|https://archive.xfce.org/src/xfce/xfce4-panel/4.20/xfce4-panel-4.20.8.tar.bz2|md5:c4c7919a07c2c48cffea7a608ea86803"
  "labwc-0.20.2.tar.gz|https://github.com/labwc/labwc/archive/refs/tags/0.20.2.tar.gz|sha256:fae023b6fe022f7057556707a17cdb2d98e0138c5dffaedaa1dade975699f9e8"
  "adwaita-fonts-48.2.tar.xz|https://download.gnome.org/sources/adwaita-fonts/48/adwaita-fonts-48.2.tar.xz|sha256:156f7e92f2f82e527fc73c309dbb237c0a4a5c3a95bc5ee94a5efb6947c553e0"
  "sudo-1.9.17p2.tar.gz|https://www.sudo.ws/dist/sudo-1.9.17p2.tar.gz|md5:dcbf46f739ae06b076e1a11cbb271a10"
  # sha512 da Alpine Linux
  "wlr-randr-v0.5.0.tar.gz|https://gitlab.freedesktop.org/emersion/wlr-randr/-/archive/v0.5.0/wlr-randr-v0.5.0.tar.gz|sha512:83c6980c4ba917bdaa55f618b4ecdf713639d302b9ab7a7dfdfbefb6e394051cad5589d9aedd8a4576d81edcd7e981be0495ea59a88db70839e2dad58fe310ff"
)

f2c_gtk_layer_shell() {
# NON IN BLFS: permette al pannello di stare fisso in basso sullo schermo (Wayland)
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D introspection=false -D vapi=false ..
ninja
ninja install
}

f2c_libwnck() {
mkdir build
cd    build

# MODIFICA: -D introspection=disabled (niente GObject Introspection, vedi GLib nella Fase 2)
meson setup --prefix=/usr --buildtype=release -D introspection=disabled ..
ninja
ninja install
}

f2c_libxfce4windowing() {
# (il libro chiede anche xfce4-dev-tools, ma serve solo il programmino
#  xdt-gen-visibility, che e' gia' dentro l'archivio: cosi' non serve libxslt)
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --enable-x11      \
            --disable-debug
make
make install
}

f2c_garcon() {
./configure --prefix=/usr --sysconfdir=/etc
make
make install
}

f2c_xfce4_panel() {
./configure --prefix=/usr --sysconfdir=/etc
make
make install
}

f2c_labwc() {
# NON IN BLFS: labwc, il gestore delle finestre (in stile Openbox): titolo e pulsanti
# su ogni finestra, menu col tasto destro sul desktop, Alt+Tab con le anteprime.
# Senza X11 (xwayland), senza librsvg (svg) e senza icone nei titoli (icon).
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false \
            -D xwayland=disabled -D svg=disabled -D icon=disabled ..
ninja
ninja install
}

f2c_adwaita_fonts() {
# NON IN BLFS: i caratteri di GNOME (Adwaita Sans per i testi, Adwaita Mono per il terminale)
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
fc-cache -f /usr/share/fonts/Adwaita
}

f2c_sudo() {
sed -e 's/\([->.a-zA-Z_]*\)->length/ASN1_STRING_length(\1)/' \
    -i lib/iolog/hostcheck.c
./configure --prefix=/usr         \
            --libexecdir=/usr/lib \
            --with-secure-path    \
            --with-env-editor     \
            --docdir=/usr/share/doc/sudo-1.9.17p2 \
            --with-passprompt="[sudo] password for %p: "
make
make install
# (saltata la parte per Linux-PAM: qui non e' installato, sudo usa le password normali)
cat > /etc/sudoers.d/00-sudo << "EOF"
Defaults secure_path="/usr/sbin:/usr/bin"
%wheel ALL=(ALL) ALL
EOF
}

f2c_configura() {
# NON IN BLFS: il desktop pronto all'uso
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa; casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
[ -d "$casa" ] || { echo "Non trovo la cartella di $MIA_UTENTE"; return 1; }

# --- sfondo: sfumatura blu creata qui (PNG 1920x1080, solo Python) ---
mkdir -p /usr/share/backgrounds
python3 - /usr/share/backgrounds/sfondo-desktop.png << "EOF"
import math, struct, sys, zlib
L, A = 1920, 1080
def colore(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
alto_sx, basso_dx = colore("#1c4f8e"), colore("#0a1730")
luci = [(0.80, 0.18, 0.55, colore("#62a0ea"), 0.55),
        (0.10, 0.95, 0.60, colore("#613583"), 0.45)]
righe = bytearray()
for y in range(A):
    righe.append(0)
    fy = y / (A - 1)
    for x in range(L):
        fx = x / (L - 1)
        t = fx * 0.55 + fy * 0.45
        r = alto_sx[0] + (basso_dx[0] - alto_sx[0]) * t
        g = alto_sx[1] + (basso_dx[1] - alto_sx[1]) * t
        b = alto_sx[2] + (basso_dx[2] - alto_sx[2]) * t
        for cx, cy, rag, (lr, lg, lb), forza in luci:
            dx = (fx - cx) * L / A
            dy = fy - cy
            d2 = (dx * dx + dy * dy) / (rag * rag)
            if d2 < 4.0:
                k = forza * math.exp(-2.0 * d2)
                r += (lr - r) * k
                g += (lg - g) * k
                b += (lb - b) * k
        s = ((x * 7 + y * 13) & 3) * 0.25 - 0.375
        righe += bytes((min(255, max(0, int(r + s + 0.5))),
                        min(255, max(0, int(g + s + 0.5))),
                        min(255, max(0, int(b + s + 0.5)))))
def blocco(tipo, dati):
    return struct.pack(">I", len(dati)) + tipo + dati + struct.pack(">I", zlib.crc32(tipo + dati) & 0xffffffff)
with open(sys.argv[1], "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n")
    f.write(blocco(b"IHDR", struct.pack(">IIBBBBB", L, A, 8, 2, 0, 0, 0)))
    f.write(blocco(b"IDAT", zlib.compress(bytes(righe), 9)))
    f.write(blocco(b"IEND", b""))
EOF

# --- caratteri: Adwaita Sans e Adwaita Mono al posto di DejaVu, ovunque ---
cat > /etc/fonts/local.conf << "EOF"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- Creato da lfs.sh: caratteri preferiti (gli stessi di GNOME) -->
<fontconfig>
  <alias><family>sans-serif</family><prefer><family>Adwaita Sans</family></prefer></alias>
  <alias><family>monospace</family><prefer><family>Adwaita Mono</family></prefer></alias>
</fontconfig>
EOF
cat > /etc/gtk-3.0/settings.ini << "EOF"
[Settings]
gtk-theme-name = Adwaita
gtk-icon-theme-name = AdwaitaLegacy
gtk-font-name = Adwaita Sans 11
gtk-decoration-layout = :minimize,maximize,close
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintslight
gtk-xft-rgba = rgb
EOF
sed -i 's/^font=DejaVu Sans:size=13$/font=Adwaita Sans:size=13/' /etc/xdg/fuzzel/fuzzel.ini
mkdir -p /etc/xdg/foot
cat > /etc/xdg/foot/foot.ini << "EOF"
# Terminale foot (creato da lfs.sh). Per cambiarlo solo per te: ~/.config/foot/foot.ini
[main]
font=Adwaita Mono:size=11
pad=10x10
EOF

# --- spegnere, riavviare, uscire: un piccolo menu (si usa fuzzel) ---
cat > /etc/sudoers.d/10-spegnimento << "EOF"
# Creato da lfs.sh: chi e' nel gruppo wheel puo' spegnere e riavviare senza password
%wheel ALL=(root) NOPASSWD: /usr/bin/systemctl poweroff, /usr/bin/systemctl reboot
EOF
chmod 440 /etc/sudoers.d/00-sudo /etc/sudoers.d/10-spegnimento
visudo -c
mkdir -p /usr/local/bin
cat > /usr/local/bin/menu-spegnimento << "EOF"
#!/bin/bash
# Menu per spegnere, riavviare o uscire dal desktop (creato da lfs.sh)
scelta=$(printf '%s\n' "Spegni il computer" "Riavvia il computer" "Esci dalla sessione" \
         | fuzzel --dmenu --prompt "Cosa vuoi fare? " --lines 3 --width 32) || exit 0
case "$scelta" in
    Spegni*)  sudo -n /usr/bin/systemctl poweroff ;;
    Riavvia*) sudo -n /usr/bin/systemctl reboot ;;
    Esci*)    labwc --exit ;;
esac
EOF
chmod 755 /usr/local/bin/menu-spegnimento
cat > /usr/share/applications/spegnimento.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Spegni o riavvia
Comment=Spegni, riavvia o esci dalla sessione
Exec=/usr/local/bin/menu-spegnimento
Icon=system-shutdown
Terminal=false
Categories=System;
EOF

# --- labwc: finestre, tasti, menu col tasto destro, avvio di sfondo e barra ---
mkdir -p /etc/xdg/labwc
cat > /etc/xdg/labwc/rc.xml << "EOF"
<?xml version="1.0"?>
<!-- Desktop (labwc), creato da lfs.sh. Per cambiarlo solo per te copia questo
     file in ~/.config/labwc/rc.xml e modifica quello. -->
<labwc_config>
  <core>
    <decoration>server</decoration>
  </core>
  <placement>
    <policy>center</policy>
  </placement>
  <theme>
    <titlebar>
      <layout>:iconify,max,close</layout>
      <showTitle>yes</showTitle>
    </titlebar>
    <cornerRadius>10</cornerRadius>
    <dropShadows>yes</dropShadows>
    <font>
      <name>Adwaita Sans</name>
      <size>11</size>
    </font>
    <font place="ActiveWindow">
      <name>Adwaita Sans</name>
      <size>11</size>
      <weight>bold</weight>
    </font>
    <font place="InactiveWindow">
      <name>Adwaita Sans</name>
      <size>11</size>
      <weight>bold</weight>
    </font>
  </theme>
  <windowSwitcher preview="yes" outlines="yes">
    <osd show="yes" style="thumbnail" />
  </windowSwitcher>
  <keyboard>
    <default />
    <!-- tasto Windows da solo: schermata con tutte le app (di nuovo: la chiude) -->
    <keybind key="Super_L" onRelease="yes">
      <action name="Execute" command="sh -c 'pkill -x fuzzel || fuzzel'" />
    </keybind>
    <keybind key="W-Return">
      <action name="Execute" command="foot" />
    </keybind>
    <keybind key="C-A-t">
      <action name="Execute" command="foot" />
    </keybind>
    <keybind key="W-e">
      <action name="Execute" command="thunar" />
    </keybind>
  </keyboard>
  <mouse>
    <default />
  </mouse>
</labwc_config>
EOF
cat > /etc/xdg/labwc/menu.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<!-- Menu che si apre col tasto destro sul desktop (creato da lfs.sh) -->
<openbox_menu>
<menu id="root-menu">
  <item label="Tutte le app">
    <action name="Execute" command="fuzzel" />
  </item>
  <separator />
  <item label="Firefox">
    <action name="Execute" command="firefox" />
  </item>
  <item label="File">
    <action name="Execute" command="thunar" />
  </item>
  <item label="Terminale">
    <action name="Execute" command="foot" />
  </item>
  <item label="Editor di testo">
    <action name="Execute" command="mousepad" />
  </item>
  <separator />
  <item label="Spegni, riavvia o esci...">
    <action name="Execute" command="/usr/local/bin/menu-spegnimento" />
  </item>
</menu>
</openbox_menu>
EOF
cat > /etc/xdg/labwc/autostart << "EOF"
# Programmi che partono insieme al desktop (creato da lfs.sh)
swaybg -i /usr/share/backgrounds/sfondo-desktop.png -m fill >/dev/null 2>&1 &
xfce4-panel >/dev/null 2>&1 &
EOF
cat > /etc/xdg/labwc/environment << "EOF"
# Tastiera italiana e puntatore del mouse (creato da lfs.sh)
XKB_DEFAULT_LAYOUT=it
XCURSOR_SIZE=24
EOF
cat > /etc/xdg/labwc/themerc-override << "EOF"
# Colori e forme delle finestre in stile GNOME (creato da lfs.sh)
border.width: 1
window.titlebar.padding.width: 6
window.titlebar.padding.height: 6
window.active.border.color: #c0bfbc
window.inactive.border.color: #deddda
window.active.title.bg.color: #ebebed
window.inactive.title.bg.color: #fafafb
window.active.label.text.color: #1e1e1e
window.inactive.label.text.color: #8f8f8f
window.label.text.justify: center
window.button.width: 26
window.button.height: 26
window.button.spacing: 6
window.button.hover.bg.color: #00000018
window.button.hover.bg.corner-radius: 13
window.active.button.unpressed.image.color: #1e1e1e
window.inactive.button.unpressed.image.color: #8f8f8f
window.active.shadow.size: 30
window.inactive.shadow.size: 18
window.active.shadow.color: #00000050
window.inactive.shadow.color: #00000030
menu.border.width: 1
menu.border.color: #c0bfbc
menu.items.bg.color: #ffffff
menu.items.text.color: #1e1e1e
menu.items.active.bg.color: #3584e4
menu.items.active.text.color: #ffffff
menu.items.padding.x: 12
menu.items.padding.y: 6
menu.separator.color: #deddda
osd.bg.color: #ffffff
osd.border.color: #c0bfbc
osd.label.text.color: #1e1e1e
osd.window-switcher.style-thumbnail.item.active.border.color: #3584e4
osd.window-switcher.style-thumbnail.item.active.bg.color: #3584e420
snapping.overlay.region.bg.color: #3584e440
snapping.overlay.edge.bg.color: #3584e440
EOF

# --- barra in basso (pannello di Xfce): menu, programmi preferiti, finestre
#     aperte, orologio, spegnimento. E' la configurazione di partenza per tutti:
#     ognuno puo' cambiarla (tasto destro sulla barra -> Pannello -> Preferenze).
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="true"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=8;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="44"/>
      <property name="icon-size" type="uint" value="24"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
        <value type="int" value="8"/>
        <value type="int" value="9"/>
        <value type="int" value="10"/>
        <value type="int" value="11"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-title" type="string" value="Applicazioni"/>
      <property name="button-icon" type="string" value="start-here"/>
      <property name="show-button-title" type="bool" value="true"/>
    </property>
    <property name="plugin-2" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="/usr/share/applications/firefox.desktop"/>
      </property>
    </property>
    <property name="plugin-4" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="/usr/share/applications/thunar.desktop"/>
      </property>
    </property>
    <property name="plugin-5" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="/usr/share/applications/foot.desktop"/>
      </property>
    </property>
    <property name="plugin-6" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-7" type="string" value="tasklist">
      <property name="grouping" type="bool" value="false"/>
      <property name="flat-buttons" type="bool" value="true"/>
      <property name="show-handle" type="bool" value="false"/>
      <property name="include-all-workspaces" type="bool" value="true"/>
    </property>
    <property name="plugin-8" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-9" type="string" value="clock">
      <property name="digital-layout" type="uint" value="1"/>
      <property name="digital-time-format" type="string" value="%H:%M"/>
      <property name="digital-date-format" type="string" value="%a %d %b"/>
      <property name="digital-time-font" type="string" value="Adwaita Sans Bold 11"/>
      <property name="digital-date-font" type="string" value="Adwaita Sans 9"/>
    </property>
    <property name="plugin-10" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-11" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="/usr/share/applications/spegnimento.desktop"/>
      </property>
    </property>
  </property>
</channel>
EOF

# --- all'accesso dal primo terminale parte il nuovo desktop (labwc) ---
cat > "$casa/.bash_profile" << "EOF"
# Creato da lfs.sh (Fase 2c): entrando dal primo terminale parte il desktop
# (labwc con la barra in basso). Dagli altri terminali (Ctrl+Alt+F2...) resti
# nella riga di comando. La vecchia grafica si avvia scrivendo:  sway
# La grafica disegna via software (pixman): va detto a wlroots.
export PATH="/usr/local/bin:$PATH"
export WLR_RENDERER=pixman
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="/tmp/$(id -u)-runtime-dir"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi
if [ "$(tty)" = /dev/tty1 ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    export LANG=it_IT.UTF-8
    # nelle macchine virtuali il puntatore del mouse "hardware" a volte non si vede
    if systemd-detect-virt -q; then export WLR_NO_HARDWARE_CURSORS=1; fi
    if dbus-run-session labwc > "$HOME/.labwc.log" 2>&1; then
        exit    # hai scelto "Esci dalla sessione": torna la schermata di accesso
    fi
    echo "Il desktop si e' chiuso con un errore. Il registro e' in: $HOME/.labwc.log"
    echo "Per riprovare scrivi:  labwc      (oppure la vecchia grafica:  sway)"
fi
EOF
chown "$MIA_UTENTE:" "$casa/.bash_profile"

fc-cache -f
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
echo "[OK] Desktop pronto: finestre con i pulsanti, barra in basso, sfondo, caratteri di GNOME"
}

f2c_wlr_randr() {
# NON IN BLFS: wlr-randr, cambia risoluzione e grandezza dello schermo
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f2c_schermo() {
# NON IN BLFS: il comando "schermo" e la risoluzione giusta a ogni accesso.
# In QEMU la distro riceve come risoluzione la grandezza della finestra: se la
# finestra era piccola quando sei entrato, a schermo intero tutto sembra enorme.
# Per questo nella macchina virtuale si mette sempre 1920x1080.
mkdir -p /usr/local/bin
cat > /usr/local/bin/schermo << "EOF"
#!/bin/bash
# Risoluzione e grandezza dello schermo (creato da lfs.sh). Uso:
#   schermo                   mostra lo schermo e le risoluzioni possibili
#   schermo 1920x1080         cambia la risoluzione (e la ricorda ai prossimi accessi)
#   schermo 1920x1080 1.25    anche la grandezza: 1 = normale, 1.25 = tutto piu' grande
#   schermo modi              solo l'elenco delle risoluzioni (per le Impostazioni)
#   schermo attuale           risoluzione e grandezza di adesso
# Dalle finestre: menu Applicazioni -> Impostazioni -> Schermo
conf="${XDG_CONFIG_HOME:-$HOME/.config}/schermo.conf"
info=$(wlr-randr 2>/dev/null)
# il primo schermo acceso (qualsiasi nome: Virtual-1, HDMI-A-1, eDP-1...)
uscita=$(printf '%s\n' "$info" | awk '/^[^ ]/ { nome = $1 } /^  Enabled: yes/ && nome { print nome; exit }')
[ -n "$uscita" ] || uscita=$(printf '%s\n' "$info" | awk '/^[^ ]/ { print $1; exit }')
[ -n "$uscita" ] || { echo "Nessuno schermo trovato: il comando funziona solo dentro il desktop"; exit 1; }

blocco() { # le righe di wlr-randr dello schermo scelto
  printf '%s\n' "$info" | awk -v u="$uscita" '/^[^ ]/ { dentro = ($1 == u) } dentro'
}
modi() { # risoluzioni possibili, dalla piu' grande, senza doppioni
  blocco | sed -n 's/^ *\([0-9][0-9]*\)x\([0-9][0-9]*\) px.*/\1 \2/p' \
    | sort -k1,1nr -k2,2nr | uniq | awk '{ print $1 "x" $2 }'
}
attuale() {
  local m s
  m=$(blocco | sed -n 's/^ *\([0-9]*x[0-9]*\) px.*current.*/\1/p' | head -n1)
  s=$(blocco | sed -n 's/^  Scale: \([0-9.]*\).*/\1/p' | head -n1)
  echo "${m:-?} ${s:-1}"
}
applica() { # risoluzione grandezza
  if modi | grep -qx "$1"; then
    wlr-randr --output "$uscita" --mode "$1" --scale "$2" 2>/dev/null && return 0
  fi
  # risoluzione non nell'elenco: si prova a crearla (va nelle macchine virtuali e in molti schermi)
  wlr-randr --output "$uscita" --custom-mode "$1" --scale "$2" 2>/dev/null
}
salva() {
  mkdir -p "$(dirname "$conf")"
  printf 'RISOLUZIONE=%s\nSCALA=%s\n' "$1" "$2" > "$conf"
}

case "${1:-}" in
  "")
    printf '%s\n' "$info" ;;
  modi)
    modi ;;
  attuale)
    attuale ;;
  --avvio)
    ris=$(sed -n 's/^RISOLUZIONE=\([0-9]*x[0-9]*\)$/\1/p' "$conf" 2>/dev/null)
    sca=$(sed -n 's/^SCALA=\([0-9.]*\)$/\1/p' "$conf" 2>/dev/null)
    # nessuna scelta salvata: nelle macchine virtuali 1920x1080 (la finestra di QEMU
    # all'inizio puo' far partire lo schermo piccolo, per esempio 800x600)
    if [ -z "$ris" ] && { systemd-detect-virt -q 2>/dev/null || [[ $uscita == Virtual-* ]]; }; then
      ris=1920x1080
    fi
    if [ -n "$ris" ]; then applica "$ris" "${sca:-1}"; fi ;;
  [0-9]*x[0-9]*)
    sca=${2:-1}
    [[ $1 =~ ^[0-9]+x[0-9]+$ ]] || { echo "La risoluzione si scrive cosi': 1920x1080"; exit 1; }
    [[ $sca =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "La grandezza deve essere un numero, es. 1 oppure 1.25"; exit 1; }
    if ! applica "$1" "$sca"; then
      echo "Lo schermo non accetta $1 (scegline una da: schermo modi)"; exit 2
    fi
    [ "${3:-}" = --non-salvare ] || salva "$1" "$sca"
    echo "Fatto: $1, grandezza $sca" ;;
  *)
    echo "Uso: schermo [LARGHEZZAxALTEZZA [GRANDEZZA]]    esempio: schermo 1920x1080 1.25"
    exit 1 ;;
esac
EOF
chmod 755 /usr/local/bin/schermo
# all'accesso, prima di sfondo e barra
grep -q 'schermo --avvio' /etc/xdg/labwc/autostart \
  || sed -i '1a /usr/local/bin/schermo --avvio >/dev/null 2>&1' /etc/xdg/labwc/autostart
grep -q 'schermo --avvio' /etc/xdg/labwc/autostart || { echo "Non riesco a modificare l'avvio del desktop"; return 1; }
echo "[OK] Schermo: 1920x1080 nella macchina virtuale; per cambiarlo: Impostazioni -> Schermo"
}

f2c_impostazioni() {
# NON IN BLFS: le Impostazioni (menu Applicazioni -> Impostazioni, o tasto destro sul
# desktop): una finestra con tutte le regolazioni, e "Schermo" per risoluzione e grandezza.
# Usa le finestre di yad se c'e' (Fase 6), altrimenti i menu di fuzzel. Se qualcosa non
# va, il motivo compare a video ed e' scritto in ~/.cache/impostazioni.log
f2c_schermo                      # il comando "schermo" aggiornato (ogni nome di schermo)
mkdir -p /usr/local/bin
cat > /usr/local/bin/impostazioni-schermo << "EOF"
#!/bin/bash
# Impostazioni dello schermo (creato da lfs.sh): risoluzione e grandezza di testi e
# finestre. Dopo il cambio chiede "Va bene cosi'?": se non rispondi entro 15 secondi
# torna come prima (utile se lo schermo diventa illeggibile).
# Se qualcosa non va, il motivo e' scritto in ~/.cache/impostazioni.log
registro="${XDG_CACHE_HOME:-$HOME/.cache}/impostazioni.log"
mkdir -p "$(dirname "$registro")" 2>/dev/null && exec 2>>"$registro"
echo "--- $(date '+%F %T') impostazioni-schermo" >&2
export PATH="/usr/local/bin:/usr/bin:$PATH"     # anche se aperto da un menu con un PATH corto
TITOLO="Schermo"
ICONA=preferences-desktop-display
COMUNI="2560x1440 1920x1200 1920x1080 1680x1050 1600x900 1440x900 1366x768 1280x1024 1280x800 1280x720 1024x768"
GRANDEZZE="100%|1
125%|1.25
150%|1.5
175%|1.75
200%|2"
usa_yad=0
command -v yad >/dev/null && usa_yad=1

# un messaggio a video: con yad, altrimenti con una notifica, altrimenti con fuzzel
messaggio() { # icona testo
  echo "MESSAGGIO: $2" >&2
  if [ "$usa_yad" = 1 ]; then
    yad --title "$TITOLO" --window-icon "$ICONA" --image "$1" --center --fixed --width 460 \
        --text "$2" --button "OK:0"
    case $? in 0|252) return 0 ;; esac
  fi
  local semplice; semplice=$(printf '%s' "$2" | sed 's/<[^>]*>//g' | tr '\n' ' ')
  notify-send -i "$1" "$TITOLO" "$semplice" 2>/dev/null && return 0
  printf 'OK\n' | fuzzel --dmenu --prompt "$semplice  " --lines 1 --width 60 >/dev/null 2>&1
}

[ -n "${WAYLAND_DISPLAY:-}" ] \
  || { messaggio dialog-error "<b>Lo schermo si regola solo dal desktop.</b>"; exit 1; }
command -v wlr-randr >/dev/null || { messaggio dialog-error "<b>Manca il programma wlr-randr.</b>
Rifai il desktop dal tuo PC:  sudo bash lfs.sh fase2c"; exit 1; }
command -v schermo >/dev/null || { messaggio dialog-error "<b>Manca il comando schermo.</b>
Rifai il desktop dal tuo PC:  sudo bash lfs.sh fase2c"; exit 1; }

if ! attuale=$(schermo attuale 2>&1); then
  messaggio dialog-error "<b>Non trovo lo schermo.</b>
$(printf '%s' "$attuale" | sed 's/&/\&amp;/g; s/</\&lt;/g')"
  exit 1
fi
read -r ora sca_ora <<<"$attuale"
[ -n "$ora" ] || { messaggio dialog-error "<b>Non trovo lo schermo.</b>"; exit 1; }
[[ $sca_ora =~ ^[0-9]+(\.[0-9]+)?$ ]] || sca_ora=1
sca_ora=$(awk -v s="$sca_ora" 'BEGIN { printf "%g", s }')     # 1.000000 -> 1, 1.250000 -> 1.25
echo "ora: $ora grandezza $sca_ora" >&2
# elenco: quelle dello schermo, poi quelle comuni (in una macchina virtuale vanno tutte)
elenco=$( { schermo modi 2>/dev/null; for r in $COMUNI; do echo "$r"; done; } | grep -E '^[0-9]+x[0-9]+$' \
          | awk '!visto[$0]++' | sort -t x -k1,1nr -k2,2nr)
percento=$(awk -v s="$sca_ora" 'BEGIN { printf "%d%%", s * 100 + 0.5 }')
# la scelta di adesso viene segnata con ^ (cosi' yad la mostra gia' scelta)
segna() { awk -v x="$1" '{ print ($0 == x ? "^" $0 : $0) }' | paste -sd '!'; }

scegli_yad() { # stampa "risoluzione|grandezza|"; 0 = Applica, 2/252 = Annulla, altro = yad non va
  yad --title "$TITOLO" --window-icon "$ICONA" --image "$ICONA" \
      --center --fixed --width 460 --form --separator '|' \
      --text "<span size='x-large' weight='bold'>Schermo</span>
Ora: <b>$ora</b>, grandezza <b>$percento</b>" \
      --field "Risoluzione:CB" "$(printf '%s\n' "$elenco" | segna "$ora")" \
      --field "Grandezza di testi e finestre:CB" "$(printf '%s\n' "$GRANDEZZE" | cut -d'|' -f1 | segna "$percento")" \
      --button "Annulla:2" --button "Applica:0"
}
scegli_fuzzel() {
  local r g
  r=$(printf '%s\n' "$elenco" | fuzzel --dmenu --prompt "Risoluzione (ora $ora): " --lines 12 --width 34) || return 2
  g=$(printf '%s\n' "$GRANDEZZE" | cut -d'|' -f1 | fuzzel --dmenu --prompt "Grandezza (ora $percento): " --lines 5 --width 34) || return 2
  echo "$r|$g"
}
chiedi_conferma() {
  if [ "$usa_yad" = 1 ]; then
    yad --title "$TITOLO" --window-icon "$ICONA" --image dialog-question --center --fixed --width 460 \
        --text "<span size='large' weight='bold'>Va bene così?</span>
Se non rispondi, fra 15 secondi torna come prima." \
        --timeout 15 --timeout-indicator bottom --button "Torna come prima:2" --button "Tieni:0"
  else
    [ "$(printf 'Tieni\nTorna come prima\n' | timeout 15 fuzzel --dmenu --prompt 'Va bene cosi? ' --lines 2 --width 34)" = Tieni ]
  fi
}

esito=1
if [ "$usa_yad" = 1 ]; then
  scelta=$(scegli_yad); esito=$?
  case $esito in
    0) ;;
    2|252) exit 0 ;;
    *) echo "yad non si e' aperto (codice $esito): uso i menu di fuzzel" >&2; usa_yad=0 ;;
  esac
fi
if [ "$usa_yad" = 0 ]; then
  scelta=$(scegli_fuzzel) || exit 0
fi
ris=$(cut -d'|' -f1 <<<"$scelta")
gra=$(cut -d'|' -f2 <<<"$scelta")
sca=$(printf '%s\n' "$GRANDEZZE" | awk -F'|' -v g="$gra" '$1 == g { print $2 }')
echo "scelta: $ris $gra" >&2
[[ $ris =~ ^[0-9]+x[0-9]+$ ]] && [ -n "$sca" ] || exit 0
[ "$ris" = "$ora" ] && [ "$sca" = "$sca_ora" ] && exit 0

if ! msg=$(schermo "$ris" "$sca" --non-salvare 2>&1); then
  echo "$msg" >&2
  messaggio dialog-error "<b>Lo schermo non accetta $ris.</b>
Scegline un'altra."
  exit 1
fi
if chiedi_conferma; then
  schermo "$ris" "$sca" >/dev/null 2>&1          # la ricorda anche per i prossimi accessi
  notify-send -i "$ICONA" "Schermo" "$ris, grandezza $gra" 2>/dev/null
else
  schermo "$ora" "$sca_ora" --non-salvare >/dev/null 2>&1
fi
exit 0
EOF
cat > /usr/local/bin/impostazioni << "EOF"
#!/bin/bash
# Impostazioni (creato da lfs.sh): tutte le regolazioni del sistema in un elenco, come le
# Preferenze di Sistema di macOS o le Impostazioni di Windows (icona + nome, una riga per
# voce). Si vedono solo quelle installate (alcune arrivano con le fasi successive).
# Se qualcosa non va, il motivo e' scritto in ~/.cache/impostazioni.log
registro="${XDG_CACHE_HOME:-$HOME/.cache}/impostazioni.log"
mkdir -p "$(dirname "$registro")" 2>/dev/null && exec 2>>"$registro"
echo "--- $(date '+%F %T') impostazioni" >&2
export PATH="/usr/local/bin:/usr/bin:$PATH"
# in quest'ordine (nome del file .desktop, senza ".desktop")
VOCI="impostazioni-schermo impostazioni-aspetto vpn fantasma guardiano-regole cassaforte
      wine-impostazioni wine-programmi cups xfce4-taskmanager"
cartella="${XDG_RUNTIME_DIR:-/tmp}/impostazioni-$(id -u)"
rm -rf "$cartella"; mkdir -p "$cartella" || exit 1
n=10
for v in $VOCI; do
  for d in "/usr/share/applications/$v.desktop" "/usr/share/applications/org.xfce.$v.desktop" \
           /usr/share/applications/*-"$v".desktop; do
    if [ -f "$d" ]; then
      ln -sf "$d" "$cartella/$n-$(basename "$d")"      # il numero davanti tiene l'ordine
      n=$((n + 1))
      break
    fi
  done
done

avvia() { # file .desktop: esegue il suo comando (senza %f, %u...)
  local cmd
  cmd=$(sed -n 's/^Exec=//p' "$1" | head -n1 | sed 's/ *%[a-zA-Z]//g')
  [ -n "$cmd" ] || return 1
  echo "avvio: $cmd" >&2
  setsid sh -c "$cmd" >/dev/null 2>&1 < /dev/null &
}

if command -v yad >/dev/null; then
  elenco=""
  for d in "$cartella"/*.desktop; do
    [ -f "$d" ] || continue
    nome=$(sed -n 's/^Name=//p' "$d" | head -n1)
    icona=$(sed -n 's/^Icon=//p' "$d" | head -n1)
    [ -n "$icona" ] || icona=preferences-system
    [ -n "$nome" ] || continue
    elenco+="$icona"$'\n'"$nome"$'\n'
  done
  scelta=$(printf '%s' "$elenco" | yad --title "Impostazioni" --window-icon preferences-system \
      --list --no-headers --column "Icona:IMG" --column "Nome:TEXT" \
      --width 420 --height 480 --center \
      --text "<span size='x-large' weight='bold'>Impostazioni</span>" \
      --button "Chiudi:2" --button "Apri:0" --separator '|')
  esito=$?
  case $esito in
    0)
      nome=$(cut -d'|' -f2 <<<"$scelta")
      for d in "$cartella"/*.desktop; do
        if [ "$(sed -n 's/^Name=//p' "$d" | head -n1)" = "$nome" ]; then
          avvia "$d"; break
        fi
      done
      exit 0 ;;
    2|252) exit 0 ;;
  esac
  echo "yad non si e' aperto (codice $esito): uso il menu di fuzzel" >&2
fi
# senza yad (o se yad non parte): un elenco semplice
nome=$(for d in "$cartella"/*.desktop; do sed -n 's/^Name=//p' "$d" | head -n1; done \
       | fuzzel --dmenu --prompt "Impostazioni: " --lines 10 --width 36) || exit 0
for d in "$cartella"/*.desktop; do
  if [ "$(sed -n 's/^Name=//p' "$d" | head -n1)" = "$nome" ]; then
    avvia "$d"
    exit 0
  fi
done
EOF
chmod 755 /usr/local/bin/impostazioni-schermo /usr/local/bin/impostazioni
bash -n /usr/local/bin/impostazioni-schermo
bash -n /usr/local/bin/impostazioni
cat > /usr/share/applications/impostazioni.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Impostazioni
Comment=Schermo, VPN, modalita' fantasma, rete, programmi Windows e altro
Exec=/usr/local/bin/impostazioni
Icon=preferences-system
Terminal=false
Categories=Settings;System;
EOF
cat > /usr/share/applications/impostazioni-schermo.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Schermo
Comment=Risoluzione e grandezza di testi e finestre
Exec=/usr/local/bin/impostazioni-schermo
Icon=preferences-desktop-display
Terminal=false
Categories=Settings;HardwareSettings;
Keywords=risoluzione;monitor;display;grandezza;
EOF
if ! grep -q 'impostazioni' /etc/xdg/labwc/menu.xml; then
  sed -i 's|^  <item label="Spegni, riavvia o esci...">|  <item label="Impostazioni">\n    <action name="Execute" command="/usr/local/bin/impostazioni" />\n  </item>\n  <item label="Spegni, riavvia o esci...">|' \
      /etc/xdg/labwc/menu.xml
fi
grep -q 'impostazioni' /etc/xdg/labwc/menu.xml || { echo "Non riesco a mettere le Impostazioni nel menu"; return 1; }
if command -v update-desktop-database >/dev/null; then update-desktop-database /usr/share/applications; fi
echo "[OK] Impostazioni pronte (menu Applicazioni -> Impostazioni -> Schermo)"
}

LISTA_STEP9=(
  "gtk-layer-shell|gtk-layer-shell-0.10.1.tar.gz|f2c_gtk_layer_shell"
  "libwnck|libwnck-43.3.tar.xz|f2c_libwnck"
  "libxfce4windowing|libxfce4windowing-4.20.7.tar.bz2|f2c_libxfce4windowing"
  "Garcon (menu delle app)|garcon-4.20.0.tar.bz2|f2c_garcon"
  "pannello Xfce (barra in basso)|xfce4-panel-4.20.8.tar.bz2|f2c_xfce4_panel"
  "labwc (finestre)|labwc-0.20.2.tar.gz|f2c_labwc"
  "caratteri Adwaita|adwaita-fonts-48.2.tar.xz|f2c_adwaita_fonts"
  "Sudo|sudo-1.9.17p2.tar.gz|f2c_sudo"
  "configurazione del desktop|-|f2c_configura"
  "wlr-randr (risoluzione)|wlr-randr-v0.5.0.tar.gz|f2c_wlr_randr"
  "risoluzione dello schermo|-|f2c_schermo"
  "impostazioni (schermo e altro)|-|f2c_impostazioni"
)

cmd_fase2c() {
  serve_root fase2c
  titolo "Fase 2c - Desktop: finestre con i pulsanti e barra in basso"
  assicura_montato
  if [ "$(quanti_fatti "${LISTA_STEP8[@]}")" -ne "${#LISTA_STEP8[@]}" ]; then
    info "Prima finisco la Fase 2b (programmi), poi passo al desktop."
    cmd_fase2b
    titolo "Fase 2c - Desktop: finestre con i pulsanti e barra in basso"
  fi
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP9[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 2c da capo (opzione 'rifai')"
  fi
  chiedi_utente
  titolo "Scarico i sorgenti della Fase 2c"
  scarica_fonti "${FONTI_FASE2C[@]}"
  info "Ci vogliono circa 15-30 minuti (dipende dal PC). Lascia il terminale aperto."
  local esito=0
  lancia_in_chroot 9 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase2c MIA_ETICHETTA="Fase 2c" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 2c COMPLETATA"
  info "Accendi la distro (sudo $0 avvia) ed entra con '$UTENTE': parte il nuovo desktop."
  info "   Barra in basso: Applicazioni, Firefox, File, Terminale, finestre aperte, ora, spegnimento"
  info "   Ogni finestra ha in alto i pulsanti  _  (riduci)  []  (ingrandisci)  X  (chiudi)"
  info "   Tasto Windows: tutte le app     Alt+Tab: cambia finestra     Alt+F4: chiudi"
  info "   Windows+E: file     Ctrl+Alt+T: terminale     tasto destro sul desktop: menu"
}

# =============================================================================
#  FASE 3 - PROGRAMMI WINDOWS (.exe) con Wine 11.0
#  Wine non e' nel libro BLFS 13.1: comandi scritti per questa distro, sulla
#  base delle istruzioni ufficiali di Wine ("# NON IN BLFS"). GnuTLS (connessioni
#  sicure dei programmi Windows) e le sue librerie vengono dal libro BLFS.
#  Scelte:
#   - Wine "WoW64": funzionano sia i programmi Windows a 64 bit sia quelli a
#     32 bit (quasi tutti gli installatori), senza installare librerie Linux
#     a 32 bit. Serve un compilatore per Windows: si usa llvm-mingw, gia'
#     pronto (LLVM 21, coetaneo di Wine 11.0), solo durante la compilazione.
#   - le finestre dei programmi Windows si aprono direttamente nel desktop
#     (Wayland), senza X11.
#   - Wine Mono (.NET) e Wine Gecko (pagine HTML) gia' installati: niente
#     download e domande al primo avvio.
# =============================================================================
FONTI_FASE3=(
  # file | indirizzo | controllo (md5 dal libro BLFS 13.1; sha512 da Gentoo Linux;
  #                               sha256 calcolato sul file ufficiale di llvm-mingw)
  "nettle-4.0.tar.gz|https://ftpmirror.gnu.org/nettle/nettle-4.0.tar.gz|md5:144401453f9f35e53938bcacfc59800e"
  "libunistring-1.4.2.tar.xz|https://ftpmirror.gnu.org/libunistring/libunistring-1.4.2.tar.xz|md5:e033195d90d0803063f3fecc77148124"
  "gnutls-3.8.13.tar.xz|https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz|md5:a97671c1839340c6b43c23ccb3237180"
  "llvm-mingw-20251216-ucrt-ubuntu-22.04-x86_64.tar.xz|https://github.com/mstorsjo/llvm-mingw/releases/download/20251216/llvm-mingw-20251216-ucrt-ubuntu-22.04-x86_64.tar.xz|sha256:db561734a05eb4a0695d5e901aadd6c1cda74bba4c9e102b677f81c6fd59849a"
  "wine-11.0.tar.xz|https://dl.winehq.org/wine/source/11.0/wine-11.0.tar.xz|sha512:a2c3db14f8cf0d19927466805c8f17c68ee7e93d1196d1162dd2279af497c21ec611a63f7a9de59953bbdfdb44c87d7bf55373c6533224a5d54e434c29428d1b"
  "wine-mono-10.4.1-x86.tar.xz|https://dl.winehq.org/wine/wine-mono/10.4.1/wine-mono-10.4.1-x86.tar.xz|sha512:9274a1f167e76535c521ba47335fd596ba6413d4e8e9301502eea4f2646f077e172efb326278147700ebcb2d0d351a568ab142221793821ee3174bcb68e77099"
  "wine-gecko-2.47.4-x86.tar.xz|https://dl.winehq.org/wine/wine-gecko/2.47.4/wine-gecko-2.47.4-x86.tar.xz|sha512:1279456eca4439e9adc3c97678fabeca42cc89f683246805ca14f85fc104bf4ba970fb6490f4ebd0938fc8e0a0ca372b000fdd5165f900070eeee30a1aeec117"
  "wine-gecko-2.47.4-x86_64.tar.xz|https://dl.winehq.org/wine/wine-gecko/2.47.4/wine-gecko-2.47.4-x86_64.tar.xz|sha512:1defbbc1fb5029bf43872a4e1c49995b61e0f106b1fcc4c99159bf4788226981b9ba8a25a2296d3a9312dbfa7e27b469ca27c0867afb218990d45f68705dbfbe"
)

f3_nettle() {
./configure --prefix=/usr --disable-static
make
make install
chmod   -v   755 /usr/lib/lib{hogweed,nettle}.so
install -v -m755 -d /usr/share/doc/nettle-4.0
install -v -m644 nettle.{html,pdf} /usr/share/doc/nettle-4.0
}

f3_libunistring() {
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/libunistring-1.4.2
make
make install
}

f3_gnutls() {
./configure --prefix=/usr \
            --docdir=/usr/share/doc/gnutls-3.8.13 \
            --with-default-trust-store-pkcs11="pkcs11:"
make
make install
}

f3_wine() {
# NON IN BLFS: Wine 11.0, per avviare i programmi Windows (.exe e .msi).
# Il compilatore per la parte "Windows" di Wine (llvm-mingw) si usa solo qui:
# si estrae, si compila e alla fine si cancella.
rm -rf /opt/llvm-mingw
mkdir -p /opt/llvm-mingw
tar -C /opt/llvm-mingw --strip-components=1 -xf /sources/llvm-mingw-20251216-ucrt-ubuntu-22.04-x86_64.tar.xz
export PATH=/opt/llvm-mingw/bin:$PATH
mkdir build
cd    build
../configure --prefix=/usr                \
             --enable-archs=i386,x86_64   \
             --with-mingw=llvm-mingw      \
             --disable-tests              \
             --with-wayland               \
             --with-freetype              \
             --with-fontconfig            \
             --with-gnutls                \
             --with-alsa                  \
             --with-dbus                  \
             --with-udev                  \
             --with-opengl
make
make install
rm -rf /opt/llvm-mingw
# Wine Mono (programmi .NET) e Wine Gecko (pagine HTML dentro i programmi):
# messi dove Wine li cerca, cosi' non li scarica a ogni nuovo utente
install -vdm755 /usr/share/wine/mono /usr/share/wine/gecko
tar -C /usr/share/wine/mono  -xf /sources/wine-mono-10.4.1-x86.tar.xz
tar -C /usr/share/wine/gecko -xf /sources/wine-gecko-2.47.4-x86.tar.xz
tar -C /usr/share/wine/gecko -xf /sources/wine-gecko-2.47.4-x86_64.tar.xz
[ -d /usr/share/wine/mono/wine-mono-10.4.1 ] && [ -d /usr/share/wine/gecko/wine-gecko-2.47.4-x86 ] \
  || { echo "Mono o Gecko non sono nella cartella giusta"; return 1; }
[ -d /usr/lib/wine/i386-windows ] || { echo "Manca la parte a 32 bit di Wine"; return 1; }
echo "[OK] $(/usr/bin/wine --version): programmi Windows a 64 e a 32 bit"
}

f3_configura() {
# NON IN BLFS: i file .exe e .msi si aprono con Wine (doppio clic in Thunar)
# e nel menu ci sono le voci per gestire i programmi Windows
local t
for t in application/x-ms-dos-executable application/vnd.microsoft.portable-executable \
         application/x-msdownload application/x-msi application/x-ms-shortcut application/x-bat; do
  grep -q "^$t=" /etc/xdg/mimeapps.list || sed -i "/^\[Default Applications\]/a $t=wine.desktop" /etc/xdg/mimeapps.list
done
grep -q '^\[Added Associations\]' /etc/xdg/mimeapps.list || cat >> /etc/xdg/mimeapps.list << "EOF"

[Added Associations]
application/x-ms-dos-executable=wine.desktop;
application/vnd.microsoft.portable-executable=wine.desktop;
application/x-msdownload=wine.desktop;
application/x-msi=wine.desktop;
EOF
cat > /usr/share/applications/wine-impostazioni.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Impostazioni di Wine
Comment=Versione di Windows, dischi, aspetto e suono dei programmi Windows
Exec=winecfg
Icon=applications-system
Terminal=false
Categories=System;
EOF
cat > /usr/share/applications/wine-programmi.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Programmi Windows installati
Comment=Vedi e disinstalla i programmi Windows
Exec=wine uninstaller
Icon=applications-system
Terminal=false
Categories=System;
EOF
cat > /usr/share/applications/wine-esplora.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Esplora risorse (Windows)
Comment=Il disco C: dei programmi Windows
Exec=wine explorer
Icon=system-file-manager
Terminal=false
Categories=System;
EOF
update-mime-database /usr/share/mime
echo "[OK] Doppio clic su un file .exe o .msi: si apre con Wine"
}

LISTA_STEP10=(
  "Nettle|nettle-4.0.tar.gz|f3_nettle"
  "libunistring|libunistring-1.4.2.tar.xz|f3_libunistring"
  "GnuTLS (connessioni sicure)|gnutls-3.8.13.tar.xz|f3_gnutls"
  "Wine (programmi Windows)|wine-11.0.tar.xz|f3_wine"
  "configurazione di Wine|-|f3_configura"
)

cmd_fase3() {
  serve_root fase3
  titolo "Fase 3 - Programmi Windows (.exe) con Wine"
  assicura_montato
  if [ "$(quanti_fatti "${LISTA_STEP9[@]}")" -ne "${#LISTA_STEP9[@]}" ]; then
    info "Prima finisco il desktop (Fase 2c), poi passo a Wine."
    cmd_fase2c
    titolo "Fase 3 - Programmi Windows (.exe) con Wine"
  fi
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP10[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 3 da capo (opzione 'rifai')"
  fi
  titolo "Scarico i sorgenti della Fase 3 (circa 320 MB)"
  scarica_fonti "${FONTI_FASE3[@]}"
  info "Wine e' grande: ci vuole da mezz'ora a un paio d'ore (dipende dal PC)."
  info "Lascia il terminale aperto. Se si ferma, rilancia: riparte da dove era."
  local esito=0
  lancia_in_chroot 10 MIA_COMANDO=fase3 MIA_ETICHETTA="Fase 3" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 3 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia). Per usare un programma Windows:"
  info "   doppio clic sul file .exe (o .msi) in Thunar: si apre con Wine."
  info "   La prima volta Wine prepara il suo 'disco C:' (circa un minuto)."
  info "   I programmi installati compaiono nel menu Applicazioni e col tasto Windows."
  info "Nel menu trovi anche: Impostazioni di Wine, Programmi Windows installati."
}

# =============================================================================
#  FASE 4 - USO QUOTIDIANO: audio, programmi X11 (piu' compatibili, anche con
#  Wine), foto, video e musica, archivi (zip, 7z, rar), schermate, notifiche,
#  volume nella barra. Il kernel viene ricompilato con la scheda audio.
#  Pacchetti e comandi dal libro BLFS 13.1 (versione systemd) dove ci sono
#  (tag r13.1). Ogni differenza dal libro e' segnata con "# MODIFICA:", le
#  parti che il libro non ha con "# NON IN BLFS".
#  Scelte:
#   - audio con PipeWire (come Fedora): i programmi "PulseAudio" (Firefox) e
#     "ALSA" (Wine) passano tutti da PipeWire. Si avvia insieme al desktop.
#   - Xwayland: i programmi fatti per X11 si aprono nel desktop Wayland.
#     Wine usa cosi' il suo driver piu' collaudato (X11).
#   - FFmpeg senza codificatori esterni (servono solo per creare video):
#     legge da solo quasi tutti i formati audio e video.
# =============================================================================
FONTI_FASE4=(
  # file | indirizzo | controllo (md5 dal libro BLFS 13.1; sha256 da Void Linux)
  "libsndfile-1.2.2.tar.xz|https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz|md5:04e2e6f726da7c5dc87f8cf72f250d04"
  "pulseaudio-17.0.tar.xz|https://www.freedesktop.org/software/pulseaudio/releases/pulseaudio-17.0.tar.xz|md5:c4a3596a26ff4b9dcd0c394dd1d4f8ee"
  "Class-Inspector-1.36.tar.gz|https://cpan.metacpan.org/authors/id/P/PL/PLICEASE/Class-Inspector-1.36.tar.gz|md5:084c3aeec023639d21ecbaf7d4460b21"
  "File-ShareDir-Install-0.14.tar.gz|https://cpan.metacpan.org/authors/id/E/ET/ETHER/File-ShareDir-Install-0.14.tar.gz|md5:bac4d924f3d863b00648ab56ec0dcbdc"
  "File-ShareDir-1.118.tar.gz|https://cpan.metacpan.org/authors/id/R/RE/REHSACK/File-ShareDir-1.118.tar.gz|md5:0084f730f4e3d4d89703d92b3ea82f54"
  "XML-Parser-2.59.tar.gz|https://www.cpan.org/authors/id/T/TO/TODDR/XML-Parser-2.59.tar.gz|md5:f483e6b8541d60a84e4bf50803e476bc"
  "intltool-0.51.0.tar.gz|https://launchpad.net/intltool/trunk/0.51.0/+download/intltool-0.51.0.tar.gz|md5:12e517cac2b57a0121cda351570f1e63"
  "font-util-1.4.2.tar.xz|https://www.x.org/pub/individual/font/font-util-1.4.2.tar.xz|md5:42ea8cc91549e43e9251ccbd664e7864"
  "lua-5.4.8.tar.gz|https://www.lua.org/ftp/lua-5.4.8.tar.gz|md5:81cf5265b8634967d8a7480d238168ce"
  "lua-5.4.8-shared_library-1.patch|https://www.linuxfromscratch.org/patches/blfs/13.1/lua-5.4.8-shared_library-1.patch|-"
  "pipewire-1.6.8.tar.bz2|https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/1.6.8/pipewire-1.6.8.tar.bz2|md5:9ae75812a76951c93210a26272c90ef3"
  "wireplumber-0.5.15.tar.bz2|https://gitlab.freedesktop.org/pipewire/wireplumber/-/archive/0.5.15/wireplumber-0.5.15.tar.bz2|md5:dba978afa67ba317d99ef03285ad4733"
  "alsa-utils-1.2.16.tar.bz2|https://www.alsa-project.org/files/pub/utils/alsa-utils-1.2.16.tar.bz2|md5:570a1627d47b70ad683ef9f2429ddfca"
  "libxcvt-0.1.3.tar.xz|https://www.x.org/pub/individual/lib/libxcvt-0.1.3.tar.xz|md5:7fb9c51d33a680f724f34da41768b1d0"
  "xcb-util-0.4.1.tar.xz|https://xcb.freedesktop.org/dist/xcb-util-0.4.1.tar.xz|md5:34d749eab0fd0ffd519ac64798d79847"
  "xkbcomp-1.5.0.tar.xz|https://www.x.org/pub/individual/app/xkbcomp-1.5.0.tar.xz|md5:b8128ff6816897bd385ca437cd2886ee"
  "xwayland-24.1.13.tar.xz|https://www.x.org/pub/individual/xserver/xwayland-24.1.13.tar.xz|md5:f84a91c4d3aee2b18b1864fe2bbe78c3"
  "wlroots-0.20.2.tar.bz2|https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.20.2/wlroots-0.20.2.tar.bz2|md5:03634ea5be3d116490630c955355610c"
  "labwc-0.20.2.tar.gz|https://github.com/labwc/labwc/archive/refs/tags/0.20.2.tar.gz|sha256:fae023b6fe022f7057556707a17cdb2d98e0138c5dffaedaa1dade975699f9e8"
  "nasm-3.02.tar.xz|https://www.nasm.us/pub/nasm/releasebuilds/3.02/nasm-3.02.tar.xz|md5:31ba022fff8de3065b5bc5ad5559188c"
  "libjpeg-turbo-3.2.0.tar.gz|https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0.tar.gz|md5:a80f9f1c735b57d3cdd66daed1ba6bb4"
  "gdk-pixbuf-2.44.7.tar.xz|https://download.gnome.org/sources/gdk-pixbuf/2.44/gdk-pixbuf-2.44.7.tar.xz|md5:2a12da2133476b7b36fbfcadd7133315"
  "libexif-0.6.26.tar.bz2|https://github.com/libexif/libexif/releases/download/v0.6.26/libexif-0.6.26.tar.bz2|md5:d659a750d1be6330105de54eb3bf627a"
  "ristretto-0.14.0.tar.xz|https://archive.xfce.org/src/apps/ristretto/0.14/ristretto-0.14.0.tar.xz|md5:63b94c3e3fab28c4533697f36ee6caa2"
  "tumbler-4.20.2.tar.bz2|https://archive.xfce.org/src/xfce/tumbler/4.20/tumbler-4.20.2.tar.bz2|md5:544cd05cf6ec8d16c8c812529d09b34b"
  "dav1d-1.5.4.tar.gz|https://code.videolan.org/videolan/dav1d/-/archive/1.5.4/dav1d-1.5.4.tar.gz|md5:af9b8fdb97f436a76b73425ed16b6239"
  "libass-0.17.5.tar.xz|https://github.com/libass/libass/releases/download/0.17.5/libass-0.17.5.tar.xz|md5:d9aeb9dac0ca97acbaae96c35af4013b"
  "ffmpeg-9.0.1.tar.xz|https://ffmpeg.org/releases/ffmpeg-9.0.1.tar.xz|md5:3ed2aab5ce5d18a3c5e0d22d8ca3fadb"
  "glad-2.0.8.tar.gz|https://github.com/Dav1dde/glad/archive/v2.0.8/glad-2.0.8.tar.gz|md5:028c39d581e6b53e53871f1dc21cf442"
  "Vulkan-Headers-vulkan-sdk-1.4.357.0.tar.gz|https://github.com/KhronosGroup/Vulkan-Headers/archive/vulkan-sdk-1.4.357.0/Vulkan-Headers-vulkan-sdk-1.4.357.0.tar.gz|md5:64a23bb12e95a2017004d72569132929"
  "libplacebo-7.360.1.tar.gz|https://github.com/haasn/libplacebo/archive/v7.360.1/libplacebo-7.360.1.tar.gz|md5:e0fa1b52f8d7b7ba51373e9a639ca966"
  "luajit-20260213.tar.xz|https://anduin.linuxfromscratch.org/BLFS/luajit/luajit-20260213.tar.xz|md5:6459b2696188b74edf950926cb3bacd1"
  "mpv-0.41.0.tar.gz|https://github.com/mpv-player/mpv/archive/v0.41.0/mpv-0.41.0.tar.gz|md5:fa40a0fedeaf0a77127e238a39b9d4c4"
  "7zip-26.02.tar.gz|https://github.com/ip7z/7zip/archive/26.02/7zip-26.02.tar.gz|md5:29f692dc18d150acbbd31a86e3ffe610"
  "zip30.tar.gz|https://downloads.sourceforge.net/infozip/zip30.tar.gz|md5:7b74551e63f8ee6aab6fbc86676c0d37"
  "xarchiver-0.5.4.27.tar.gz|https://github.com/ib/xarchiver/archive/0.5.4.27/xarchiver-0.5.4.27.tar.gz|md5:8a6fb3ab5c0161e3fa05ec6a1faf2c12"
  "thunar-archive-plugin-0.6.0.tar.xz|https://archive.xfce.org/src/thunar-plugins/thunar-archive-plugin/0.6/thunar-archive-plugin-0.6.0.tar.xz|sha256:692708cd047c7a552f2f85fe2ee32f19c7d5be5bf695d0288e8cadf50289db06"
  "libnotify-0.8.8.tar.xz|https://download.gnome.org/sources/libnotify/0.8/libnotify-0.8.8.tar.xz|md5:35bef24dc1e9a336394556d09345e078"
  "mako-1.11.0.tar.gz|https://github.com/emersion/mako/archive/v1.11.0.tar.gz|sha256:72d11d3fca20a3dfbca0107ff875eace479751be0cf2ddd1dd5bafa131ac7282"
  "grim-v1.5.0.tar.gz|https://gitlab.freedesktop.org/emersion/grim/-/archive/v1.5.0/grim-v1.5.0.tar.gz|sha256:9e72a98f7621b1f5741b405b8dbd447acf7d300ddb12667ec526db1ce6154eaa"
  "slurp-1.5.0.tar.gz|https://github.com/emersion/slurp/archive/v1.5.0.tar.gz|sha256:0fa880d4a93e1c795e3b5929fbea47546df0955bea34fc2f7ffeb1751678f663"
  "wl-clipboard-2.3.0.tar.gz|https://github.com/bugaevc/wl-clipboard/archive/v2.3.0.tar.gz|sha256:b4dc560973f0cd74e02f817ffa2fd44ba645a4f1ea94b7b9614dacc9f895f402"
  "desktop-file-utils-0.28.tar.xz|https://www.freedesktop.org/software/desktop-file-utils/releases/desktop-file-utils-0.28.tar.xz|md5:dec5d7265c802db1fde3980356931b7b"
  "xfce4-pulseaudio-plugin-0.5.1.tar.xz|https://archive.xfce.org/src/panel-plugins/xfce4-pulseaudio-plugin/0.5/xfce4-pulseaudio-plugin-0.5.1.tar.xz|md5:186a097794ced3612713c2098ec0b51c"
)

f4_libsndfile() {
sed -i '/typedef enum/,/bool ;/d' src/ALAC/alac_{en,de}coder.c
./configure --prefix=/usr    \
            --docdir=/usr/share/doc/libsndfile-1.2.2
make
make install
}

f4_perl_modulo() {
# BLFS, moduli Perl (Class::Inspector, File::ShareDir::Install, File::ShareDir,
# XML::Parser): istruzioni standard. LFS 13.1 non ha piu' XML::Parser, che serve a
# Intltool (e quindi a xarchiver e alla calcolatrice) e ai manuali di PulseAudio.
perl Makefile.PL
make
make install
}

f4_intltool() {
# BLFS, pagina "intltool" (tolto da LFS 13.1): traduzioni dei programmi piu' vecchi
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make install
install -v -m644 -D doc/I18N-HOWTO -t /usr/share/doc/intltool-0.51.0
}

f4_pulseaudio() {
# (si usa solo la parte per i programmi, libpulse: il servizio audio e' PipeWire)
# MODIFICA: -D man=false (i manuali non servono: cosi' non dipende da XML::Parser)
mkdir build
cd    build

meson setup --prefix=/usr       \
            --buildtype=release \
            -D database=gdbm    \
            -D doxygen=false    \
            -D bluez5=disabled  \
            -D tests=false      \
            -D man=false        \
            ..
ninja
ninja install
rm /usr/share/dbus-1/system.d/pulseaudio-system.conf
}

f4_lua() {
cat > lua.pc << "EOF"
V=5.4
R=5.4.8

prefix=/usr
INSTALL_BIN=${prefix}/bin
INSTALL_INC=${prefix}/include
INSTALL_LIB=${prefix}/lib
INSTALL_MAN=${prefix}/share/man/man1
INSTALL_LMOD=${prefix}/share/lua/${V}
INSTALL_CMOD=${prefix}/lib/lua/${V}
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: Lua
Description: An Extensible Extension Language
Version: ${R}
Requires:
Libs: -L${libdir} -llua -lm -ldl
Cflags: -I${includedir}
EOF
patch -Np1 -i ../lua-5.4.8-shared_library-1.patch
make linux
make INSTALL_TOP=/usr                \
     INSTALL_DATA="cp -d"            \
     INSTALL_MAN=/usr/share/man/man1 \
     TO_LIB="liblua.so liblua.so.5.4 liblua.so.5.4.8" \
     install

mkdir -pv                      /usr/share/doc/lua-5.4.8
cp -v doc/*.{html,css,gif,png} /usr/share/doc/lua-5.4.8

install -v -m644 -D lua.pc /usr/lib/pkgconfig/lua.pc
}

f4_pipewire() {
mkdir build
cd    build

meson setup ..                 \
      --prefix=/usr            \
      --buildtype=release      \
      -D session-managers="[]"
ninja
ninja install
}

f4_wireplumber() {
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release -D system-lua=true ..
ninja
ninja install
mv -v /usr/share/doc/wireplumber{,-0.5.15}
rm -vf /etc/xdg/autostart/pulseaudio.desktop
rm -vf /etc/xdg/Xwayland-session.d/00-pulseaudio-x11
sed -e '$a autospawn = no' -i /etc/pulse/client.conf
# MODIFICA: niente "systemctl enable --global ...": senza Linux-PAM non c'e' la
# sessione systemd dell'utente. PipeWire e WirePlumber partono col desktop (autostart).
}

f4_alsa_utils() {
./configure --disable-alsaconf \
            --disable-bat      \
            --disable-xmlto    \
            --with-curses=ncursesw
make
make install
# MODIFICA: niente "alsactl -L store": qui dentro la scheda audio non si vede
# (lo stato si salva da solo al primo spegnimento)
}

f4_libxcvt() {
ambiente_xorg
mkdir build
cd    build

meson setup --prefix=$XORG_PREFIX --buildtype=release ..
ninja
ninja install
}

f4_xcb_util() {
ambiente_xorg
./configure $XORG_CONFIG
make
make install
}

f4_xcb_utilities() {
# BLFS, pagina "XCB Utilities" (serve xcb-util-wm a Xwayland, wlroots e labwc)
ambiente_xorg
cat > xcb-utils.md5 << "EOF"
a67bfac2eff696170259ef1f5ce1b611  xcb-util-image-0.4.1.tar.xz
fbdc05f86f72f287ed71b162f1a9725a  xcb-util-keysyms-0.4.1.tar.xz
193b890e2a89a53c31e2ece3afcbd55f  xcb-util-renderutil-0.3.10.tar.xz
581b3a092e3c0c1b4de6416d90b969c3  xcb-util-wm-0.4.2.tar.xz
e85bccd1993992be07232f8b80a814c8  xcb-util-cursor-0.1.6.tar.xz
322cf9df283625223933ffcecb4a1cca  xcb-util-errors-1.0.1.tar.xz
EOF
# MODIFICA: i file li ha gia' scaricati e controllati lo script sul tuo PC, nella
# cartella xcb-utils (al posto di "wget ..."). Qui si ricontrollano.
cd    xcb-utils
md5sum -c ../xcb-utils.md5
as_root()
{
  if   [ $EUID = 0 ];        then $*
  elif [ -x /usr/bin/sudo ]; then sudo $*
  else                            su -c \\"$*\\"
  fi
}

export -f as_root
# (il libro apre una shell "bash -e" che si ferma al primo errore: qui lo fa gia' lo script)
for package in $(grep -v '^#' ../xcb-utils.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.?z*}
  tar -xf $package
  pushd $packagedir
     ./configure $XORG_CONFIG
     make
     as_root make install
  popd
  rm -rf $packagedir
done
}

f4_xkbcomp() {
# BLFS, pagina "Xorg Applications": solo xkbcomp (Xwayland lo usa per la tastiera)
ambiente_xorg
./configure $XORG_CONFIG
make
make install
}

f4_font_util() {
# BLFS, pagina "Xorg Fonts": solo font-util (Xwayland la chiede per sapere dove
# sono i caratteri X11)
ambiente_xorg
./configure $XORG_CONFIG
make
make install
}

f4_xwayland() {
ambiente_xorg
sed -i '/install_man/,$d' meson.build

mkdir build
cd    build

# MODIFICA: -D secure-rpc=false (servirebbe libtirpc: e' per vecchi sistemi di rete)
meson setup ..              \
      --prefix=$XORG_PREFIX \
      --buildtype=release   \
      -D secure-rpc=false   \
      -D xkb_output_dir=/var/lib/xkb
ninja
ninja install
}

f4_wlroots() {
# wlroots di nuovo (era nella Fase 2): adesso c'e' Xwayland e si aggiunge il supporto
mkdir build
cd    build
meson setup --prefix=/usr          \
            --buildtype=release    \
            --wrap-mode=nofallback \
            ..
ninja
ninja install
}

f4_labwc() {
# NON IN BLFS: labwc di nuovo (era nella Fase 2c), adesso con i programmi X11 (xwayland)
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false \
            -D xwayland=enabled -D svg=disabled -D icon=disabled ..
ninja
ninja install
}

f4_nasm() {
./configure --prefix=/usr
make
make install
}

f4_libjpeg_turbo() {
mkdir build
cd    build

cmake -D CMAKE_INSTALL_PREFIX=/usr        \
      -D CMAKE_BUILD_TYPE=RELEASE         \
      -D ENABLE_STATIC=FALSE              \
      -D CMAKE_INSTALL_DEFAULT_LIBDIR=lib \
      -D CMAKE_SKIP_INSTALL_RPATH=ON      \
      -D CMAKE_INSTALL_DOCDIR=/usr/share/doc/libjpeg-turbo-3.2.0 \
      ..
make
make install
}

f4_gdk_pixbuf() {
# gdk-pixbuf di nuovo (era nella Fase 2b), adesso legge anche le foto JPEG
mkdir build
cd    build

# MODIFICA: -D png=enabled, -D gif=enabled e -D jpeg=enabled (il libro legge le immagini
# con glycin, che si compila con Rust), -D man=false (servirebbe docutils),
# -D introspection=disabled
meson setup ..                \
      --prefix=/usr           \
      --buildtype=release     \
      -D png=enabled          \
      -D gif=enabled          \
      -D jpeg=enabled         \
      -D tiff=disabled        \
      -D thumbnailer=disabled \
      -D man=false            \
      -D introspection=disabled \
      --wrap-mode=nofallback  \
      $(pkgconf glycin-2 || echo -D glycin=disabled)
ninja
ninja install
gdk-pixbuf-query-loaders --update-cache
}

f4_libexif() {
./configure --prefix=/usr    \
            --disable-static \
            --with-doc-dir=/usr/share/doc/libexif-0.6.26
make
make install
}

f4_ristretto() {
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f4_tumbler() {
./configure --prefix=/usr --sysconfdir=/etc
make
make install
}

f4_dav1d() {
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
ninja
ninja install
}

f4_libass() {
./configure --prefix=/usr --disable-static
make
make install
}

f4_ffmpeg() {
# (saltata la patch facoltativa per Chromium)
# MODIFICA: senza le librerie esterne per creare video e audio (aom, fdk-aac, lame,
# opus, vorbis, vpx, x264, x265, svt-av1) e senza --enable-nonfree: per guardare e
# ascoltare bastano i decodificatori interni di FFmpeg (piu' dav1d per l'AV1)
./configure --prefix=/usr        \
            --enable-gpl         \
            --enable-version3    \
            --disable-static     \
            --enable-shared      \
            --disable-debug      \
            --enable-libass      \
            --enable-libfreetype \
            --enable-openssl     \
            --enable-libdav1d    \
            --ignore-tests=enhanced-flv-av1,enhanced-flv-multitrack \
            --docdir=/usr/share/doc/ffmpeg-9.0.1

make

gcc tools/qt-faststart.c -o tools/qt-faststart
make install

install -v -m755    tools/qt-faststart /usr/bin
install -v -m755 -d           /usr/share/doc/ffmpeg-9.0.1
install -v -m644    doc/*.txt /usr/share/doc/ffmpeg-9.0.1
}

f4_glad() {
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD
pip3 install --no-index --find-links dist --no-user glad2
}

f4_vulkan_headers() {
# BLFS, pagina "Vulkan-Headers": solo i file .h di Vulkan. libplacebo li vuole anche
# quando non usa Vulkan (senza, si ferma su "vulkan/vulkan.h: No such file")
mkdir build
cd    build
cmake -D CMAKE_INSTALL_PREFIX=/usr -G Ninja ..
ninja
ninja install
}

f4_libplacebo() {
# MODIFICA: -D tests=false (i programmi di prova non si usano; con FFmpeg gia'
# installato se ne compilano di piu', e uno puo' fermare tutto)
mkdir build
cd    build

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D tests=false      \
      -D demos=false
ninja
ninja install
}

f4_luajit() {
make PREFIX=/usr amalg
make PREFIX=/usr install
rm -v /usr/lib/libluajit-5.1.a
}

f4_mpv() {
mkdir build
cd    build

meson setup --prefix=/usr       \
            --buildtype=release \
            -D x11=enabled      \
            ..
ninja
ninja install
}

f4_7zip() {
sed -i 's/-Werror //g' CPP/7zip/7zip_gcc.mak
(for i in Bundles/{Alone,Alone7z,Format7zF,SFXCon} UI/Console; do
    make -C CPP/7zip/$i -f ../../cmpl_gcc.mak || exit
done)
install -vDm755 CPP/7zip/Bundles/Alone{/b/g/7za,7z/b/g/7zr} \
                CPP/7zip/Bundles/Format7zF/b/g/7z.so        \
                CPP/7zip/UI/Console/b/g/7z                  \
                -t /usr/lib/7zip/

install -vm755 CPP/7zip/Bundles/SFXCon/b/g/7zCon \
               /usr/lib/7zip/7zCon.sfx

(for i in 7z 7za 7zr; do
    cat > /usr/bin/$i << EOF || exit
#!/bin/sh
exec /usr/lib/7zip/$i "\$@"
EOF
    chmod 755 /usr/bin/$i || exit
done)

cp -rv DOC -T /usr/share/doc/7zip-26.02
}

f4_zip() {
make -f unix/Makefile generic CC="gcc -std=gnu89"
make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
}

f4_xarchiver() {
# MODIFICA: --disable-doc (per la guida servirebbe xsltproc, cioe' libxslt, che qui non c'e')
sed '/TOGGLE.*prefer_unzip/s/TRUE/FALSE/' -i src/pref_dialog.c
./configure  --prefix=/usr               \
             --libexecdir=/usr/lib/xfce4 \
             --docdir=/usr/share/doc/xarchiver-0.5.4.27 \
             --disable-doc
make
make install
}

f4_thunar_archive_plugin() {
# NON IN BLFS: "Estrai qui" e "Crea archivio" col tasto destro in Thunar (usa xarchiver).
# La cartella dei programmini deve essere la stessa di xarchiver (/usr/lib/xfce4).
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D libexecdir=lib/xfce4 ..
ninja
ninja install
}

f4_libnotify() {
mkdir build
cd    build

# MODIFICA: -D introspection=disabled (niente GObject Introspection, vedi GLib nella Fase 2)
#           -D tests=false (servono per i test, e vogliono gtk4 che qui non c'e')
meson setup --prefix=/usr       \
            --buildtype=release \
            -D gtk_doc=false    \
            -D man=false        \
            -D tests=false      \
            -D introspection=disabled \
            ..
ninja
ninja install
if [ -e /usr/share/doc/libnotify ]; then
  rm -rf /usr/share/doc/libnotify-0.8.8
  mv -v  /usr/share/doc/libnotify{,-0.8.8}
fi
}

f4_mako() {
# NON IN BLFS: mako, i fumetti delle notifiche (in alto a destra)
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false \
            -D sd-bus-provider=libsystemd -D icons=enabled ..
ninja
ninja install
}

f4_grim() {
# NON IN BLFS: grim, fotografa lo schermo
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false -D jpeg=enabled ..
ninja
ninja install
}

f4_slurp() {
# NON IN BLFS: slurp, per scegliere col mouse la parte di schermo da fotografare
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false ..
ninja
ninja install
}

f4_wl_clipboard() {
# NON IN BLFS: wl-copy e wl-paste, copia e incolla dalla riga di comando
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release \
            -D zshcompletiondir=no -D fishcompletiondir=no ..
ninja
ninja install
}

f4_desktop_file_utils() {
rm -fv /usr/bin/desktop-file-edit
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
install -vdm755 /usr/share/applications
update-desktop-database /usr/share/applications
}

f4_xfce4_pulseaudio_plugin() {
mkdir build
cd    build

meson setup  --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f4_configura() {
# NON IN BLFS: tutto pronto all'uso
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa t
casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
[ -d "$casa" ] || { echo "Non trovo la cartella di $MIA_UTENTE"; return 1; }
mkdir -p /usr/local/bin

# --- audio: i programmi ALSA (come Wine) passano da PipeWire ---
[ -f /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf ] || { echo "Manca la configurazione ALSA di PipeWire"; return 1; }
mkdir -p /etc/alsa/conf.d
ln -sfv /usr/share/alsa/alsa.conf.d/50-pipewire.conf         /etc/alsa/conf.d/50-pipewire.conf
ln -sfv /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/99-pipewire-default.conf
# senza la sessione di systemd-logind WirePlumber non deve aspettare "il posto attivo"
mkdir -p /etc/wireplumber/wireplumber.conf.d
cat > /etc/wireplumber/wireplumber.conf.d/80-senza-logind.conf << "EOF"
# Creato da lfs.sh: qui non c'e' systemd-logind, le schede audio si usano sempre
wireplumber.profiles = {
  main = {
    support.logind = disabled
  }
}
EOF
cat > /usr/local/bin/avvia-audio << "EOF"
#!/bin/bash
# Audio del desktop (creato da lfs.sh): PipeWire, WirePlumber e la parte "PulseAudio".
# Prima chiude quelli rimasti da una sessione precedente.
for p in wireplumber pipewire-pulse pipewire; do pkill -u "$(id -u)" -x "$p"; done
sleep 0.5
pipewire &
sleep 1
wireplumber &
pipewire-pulse &
wait
EOF
chmod 755 /usr/local/bin/avvia-audio

# --- schermate: tasto Stamp (tutto lo schermo) e Shift+Stamp (scegli una parte) ---
cat > /usr/local/bin/schermata << "EOF"
#!/bin/bash
# Fotografia dello schermo (creato da lfs.sh). Uso: schermata [area]
# Salva in ~/Immagini e copia l'immagine: si incolla con Ctrl+V.
cartella="$HOME/Immagini"
mkdir -p "$cartella"
file="$cartella/Schermata_$(date +%Y-%m-%d_%H-%M-%S).png"
if [ "${1:-}" = area ]; then
    zona=$(slurp) || exit 0
    grim -g "$zona" "$file" || exit 1
else
    grim "$file" || exit 1
fi
wl-copy --type image/png < "$file"
notify-send -i "$file" "Schermata salvata" "In Immagini. E' anche copiata: incollala con Ctrl+V"
EOF
chmod 755 /usr/local/bin/schermata

# --- xdg-open (aprire link e file dai programmi) con il programma giusto ---
cat > /usr/local/bin/xdg-open << "EOF"
#!/bin/sh
# Creato da lfs.sh: apre file e indirizzi con il programma predefinito
exec gio open "$@"
EOF
chmod 755 /usr/local/bin/xdg-open

# --- tasti e avvio del desktop ---
if ! grep -q 'schermata' /etc/xdg/labwc/rc.xml; then
  sed -i 's|^  </keyboard>|    <keybind key="Print">\n      <action name="Execute" command="/usr/local/bin/schermata" />\n    </keybind>\n    <keybind key="S-Print">\n      <action name="Execute" command="/usr/local/bin/schermata area" />\n    </keybind>\n  </keyboard>|' /etc/xdg/labwc/rc.xml
fi
grep -q 'schermata area' /etc/xdg/labwc/rc.xml || { echo "Non riesco ad aggiungere il tasto Stamp"; return 1; }
if ! grep -q 'avvia-audio' /etc/xdg/labwc/autostart; then
  sed -i '/^swaybg /i /usr/local/bin/avvia-audio >/dev/null 2>\&1 \&\nmako --font "Adwaita Sans 11" --background-color "#303030f0" --text-color "#ffffff" --border-size 0 --border-radius 10 --padding 12 --default-timeout 6000 >/dev/null 2>\&1 \&' /etc/xdg/labwc/autostart
fi
grep -q 'avvia-audio' /etc/xdg/labwc/autostart && grep -q '^mako ' /etc/xdg/labwc/autostart \
  || { echo "Non riesco a modificare l'avvio del desktop"; return 1; }

# --- programmi predefiniti: foto, video, musica, archivi ---
sed -i -e 's|^\(image/[a-z+-]*\)=firefox.desktop$|\1=org.xfce.ristretto.desktop|' /etc/xdg/mimeapps.list
for t in image/webp image/bmp image/tiff \
         video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg video/ogg \
         audio/mpeg audio/mp4 audio/ogg audio/flac audio/x-wav audio/x-vorbis+ogg audio/aac audio/x-m4a audio/opus \
         application/zip application/x-7z-compressed application/vnd.rar application/x-rar application/x-tar \
         application/x-compressed-tar application/x-xz-compressed-tar application/x-bzip2-compressed-tar application/gzip; do
  case $t in
    image/*) app=org.xfce.ristretto.desktop ;;
    video/*|audio/*) app=mpv.desktop ;;
    *) app=xarchiver.desktop ;;
  esac
  grep -q "^$t=" /etc/xdg/mimeapps.list || sed -i "/^\[Default Applications\]/a $t=$app" /etc/xdg/mimeapps.list
done
update-desktop-database /usr/share/applications
update-mime-database /usr/share/mime

# --- barra in basso: si aggiunge il volume (prima dell'orologio) ---
if ! grep -q 'value="pulseaudio"' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml; then
sed -i -e 's|^        <value type="int" value="8"/>$|        <value type="int" value="8"/>\n        <value type="int" value="12"/>\n        <value type="int" value="13"/>|' \
       -e 's|^    <property name="plugin-9" type="string" value="clock">$|    <property name="plugin-12" type="string" value="pulseaudio">\n      <property name="mixer-command" type="string" value="foot -e alsamixer"/>\n    </property>\n    <property name="plugin-13" type="string" value="separator">\n      <property name="style" type="uint" value="0"/>\n    </property>\n    <property name="plugin-9" type="string" value="clock">|' \
       /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
[ "$(grep -c 'pulseaudio\|value="12"\|value="13"' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml)" -ge 3 ] \
  || { echo "Non riesco ad aggiungere il volume alla barra"; return 1; }
# la barra dell'utente riparte dalla nuova configurazione (con il volume)
rm -rf "$casa/.config/xfce4/panel" "$casa/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
fi

# --- i comandi in /usr/local/bin (schermo, schermata...) si trovano anche nel terminale ---
grep -q '/usr/local/bin' "$casa/.bash_profile" \
  || sed -i '1a export PATH="/usr/local/bin:$PATH"' "$casa/.bash_profile"

# --- cartelle personali in italiano ---
for t in Documenti Immagini Musica Video Scaricati; do
  mkdir -p "$casa/$t"; chown "$MIA_UTENTE:" "$casa/$t"
done
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
glib-compile-schemas /usr/share/glib-2.0/schemas
echo "[OK] Audio, foto, video, musica, archivi, schermate e notifiche pronti"
}

LISTA_STEP11=(
  "libsndfile|libsndfile-1.2.2.tar.xz|f4_libsndfile"
  "Perl: Class::Inspector|Class-Inspector-1.36.tar.gz|f4_perl_modulo"
  "Perl: File::ShareDir::Install|File-ShareDir-Install-0.14.tar.gz|f4_perl_modulo"
  "Perl: File::ShareDir|File-ShareDir-1.118.tar.gz|f4_perl_modulo"
  "Perl: XML::Parser|XML-Parser-2.59.tar.gz|f4_perl_modulo"
  "Intltool (traduzioni)|intltool-0.51.0.tar.gz|f4_intltool"
  "PulseAudio (libreria)|pulseaudio-17.0.tar.xz|f4_pulseaudio"
  "Lua|lua-5.4.8.tar.gz|f4_lua"
  "PipeWire (audio)|pipewire-1.6.8.tar.bz2|f4_pipewire"
  "WirePlumber|wireplumber-0.5.15.tar.bz2|f4_wireplumber"
  "alsa-utils|alsa-utils-1.2.16.tar.bz2|f4_alsa_utils"
  "libxcvt|libxcvt-0.1.3.tar.xz|f4_libxcvt"
  "xcb-util|xcb-util-0.4.1.tar.xz|f4_xcb_util"
  "XCB Utilities (6 pacchetti)|-|f4_xcb_utilities"
  "font-util|font-util-1.4.2.tar.xz|f4_font_util"
  "xkbcomp|xkbcomp-1.5.0.tar.xz|f4_xkbcomp"
  "Xwayland (programmi X11)|xwayland-24.1.13.tar.xz|f4_xwayland"
  "wlroots (con Xwayland)|wlroots-0.20.2.tar.bz2|f4_wlroots"
  "labwc (con Xwayland)|labwc-0.20.2.tar.gz|f4_labwc"
  "NASM|nasm-3.02.tar.xz|f4_nasm"
  "libjpeg-turbo|libjpeg-turbo-3.2.0.tar.gz|f4_libjpeg_turbo"
  "gdk-pixbuf (con JPEG)|gdk-pixbuf-2.44.7.tar.xz|f4_gdk_pixbuf"
  "libexif|libexif-0.6.26.tar.bz2|f4_libexif"
  "Ristretto (foto)|ristretto-0.14.0.tar.xz|f4_ristretto"
  "Tumbler (anteprime)|tumbler-4.20.2.tar.bz2|f4_tumbler"
  "dav1d|dav1d-1.5.4.tar.gz|f4_dav1d"
  "libass|libass-0.17.5.tar.xz|f4_libass"
  "FFmpeg|ffmpeg-9.0.1.tar.xz|f4_ffmpeg"
  "Glad|glad-2.0.8.tar.gz|f4_glad"
  "Vulkan-Headers|Vulkan-Headers-vulkan-sdk-1.4.357.0.tar.gz|f4_vulkan_headers"
  "libplacebo|libplacebo-7.360.1.tar.gz|f4_libplacebo"
  "LuaJIT|luajit-20260213.tar.xz|f4_luajit"
  "mpv (video e musica)|mpv-0.41.0.tar.gz|f4_mpv"
  "7zip|7zip-26.02.tar.gz|f4_7zip"
  "Zip|zip30.tar.gz|f4_zip"
  "xarchiver (archivi)|xarchiver-0.5.4.27.tar.gz|f4_xarchiver"
  "thunar-archive-plugin|thunar-archive-plugin-0.6.0.tar.xz|f4_thunar_archive_plugin"
  "libnotify|libnotify-0.8.8.tar.xz|f4_libnotify"
  "mako (notifiche)|mako-1.11.0.tar.gz|f4_mako"
  "grim (schermate)|grim-v1.5.0.tar.gz|f4_grim"
  "slurp|slurp-1.5.0.tar.gz|f4_slurp"
  "wl-clipboard|wl-clipboard-2.3.0.tar.gz|f4_wl_clipboard"
  "desktop-file-utils|desktop-file-utils-0.28.tar.xz|f4_desktop_file_utils"
  "volume nella barra|xfce4-pulseaudio-plugin-0.5.1.tar.xz|f4_xfce4_pulseaudio_plugin"
  "configurazione per l'uso quotidiano|-|f4_configura"
)

cmd_fase4() {
  serve_root fase4
  titolo "Fase 4 - Uso quotidiano: audio, foto, video, archivi, schermate"
  assicura_montato
  # anche i passaggi aggiunti dopo alle fasi precedenti (es. la risoluzione dello
  # schermo nella Fase 2c): la Fase 3 controlla la 2c, che controlla la 2b
  if [ "$(quanti_fatti "${LISTA_STEP9[@]}")" -ne "${#LISTA_STEP9[@]}" ] \
     || [ "$(quanti_fatti "${LISTA_STEP10[@]}")" -ne "${#LISTA_STEP10[@]}" ]; then
    info "Prima finisco le fasi precedenti (fino a Wine), poi passo all'uso quotidiano."
    cmd_fase3
    titolo "Fase 4 - Uso quotidiano: audio, foto, video, archivi, schermate"
  fi
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP11[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 4 da capo (opzione 'rifai')"
  fi
  # il kernel deve conoscere la scheda audio (anche quella della macchina virtuale)
  if ! grep -q '^CONFIG_SND_HDA_GENERIC=y' "$LFS/boot/config-$KERNEL_VER" 2>/dev/null; then
    info "Ricompilo il kernel con il supporto per le schede audio (una volta sola)."
    cmd_step4 step4 rifai
    titolo "Fase 4 - Uso quotidiano: audio, foto, video, archivi, schermate"
  fi
  chiedi_utente
  titolo "Scarico i sorgenti della Fase 4 (circa 120 MB)"
  scarica_fonti "${FONTI_FASE4[@]}"
  info "Utilita' XCB (6 file):"
  scarica_elenco xcb-utils.md5 xcb-utils https://xorg.freedesktop.org/archive/individual/lib/ 6
  info "Ci vuole circa un'ora (dipende dal PC). Lascia il terminale aperto."
  local esito=0
  lancia_in_chroot 11 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase4 MIA_ETICHETTA="Fase 4" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 4 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia). Novita':"
  info "   Audio: volume nella barra in basso (e con i tasti del volume)"
  info "   Foto: doppio clic su un'immagine (Ristretto). Video e musica: mpv"
  info "   Archivi zip, 7z, rar: doppio clic, oppure tasto destro -> Estrai qui"
  info "   Tasto Stamp: fotografa lo schermo (Shift+Stamp: scegli una parte)"
  info "   Programmi per X11 e Wine piu' compatibili (Xwayland)"
  info "   Spotify: vai su open.spotify.com in Firefox e accetta i 'contenuti DRM'"
}

# =============================================================================
#  FASE 5 - USO QUOTIDIANO (seconda parte): ufficio (LibreOffice), posta
#  (Thunderbird), blocco dello schermo, gestione attivita', calcolatrice,
#  immagini WebP, caratteri compatibili con Windows, stampa (CUPS).
#  Pacchetti e comandi dal libro BLFS 13.1 (versione systemd) dove ci sono
#  (tag r13.1). Ogni differenza dal libro e' segnata con "# MODIFICA:", le
#  parti che il libro non ha con "# NON IN BLFS".
#  Scelte:
#   - LibreOffice e Thunderbird sono quelli ufficiali, gia' compilati (compilarli
#     da zero richiede molte ore). Si scaricano le ultime versioni, in italiano.
#   - il blocco dello schermo (swaylock) controlla la password senza Linux-PAM:
#     per leggerla deve partire con i permessi di root (come spiega il suo README).
# =============================================================================
FONTI_FASE5=(
  # file | indirizzo | controllo (md5 dal libro BLFS 13.1; sha256 da Void Linux o
  #                               calcolato sui file ufficiali)
  "libwebp-1.6.0.tar.gz|https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz|md5:cceb6447180f961473b181c9ef38b630"
  "webp-pixbuf-loader-0.2.7.tar.gz|https://github.com/aruiz/webp-pixbuf-loader/archive/refs/tags/0.2.7.tar.gz|sha256:61ce5e8e036043f9d0e78c1596a621788e879c52aedf72ab5e78a8c44849411a"
  "swaylock-1.8.6.tar.gz|https://github.com/swaywm/swaylock/releases/download/v1.8.6/swaylock-1.8.6.tar.gz|sha256:a15154348fef852fdb224112d137c393c826478b777f63479beb15e8d3812eaf"
  "swayidle-1.9.0.tar.gz|https://github.com/swaywm/swayidle/releases/download/v1.9.0/swayidle-1.9.0.tar.gz|sha256:6c1b769038b60250c88e47380cbb021cfa57a65f872bf4d6c340b5e3057096ac"
  "xfce4-taskmanager-1.6.0.tar.xz|https://archive.xfce.org/src/apps/xfce4-taskmanager/1.6/xfce4-taskmanager-1.6.0.tar.xz|sha256:29bdc7840ab8b9025f6c0e456a83a31090d1c9fd9e26b359baa4a4010cfb0b90"
  "galculator-2.1.4.tar.gz|https://github.com/galculator/galculator/archive/v2.1.4.tar.gz|sha256:dcbdb48ddf8a3f68b9aa5902f880f174fd269de2b7410988148d05871012e142"
  "liberation-fonts-ttf-2.1.5.tar.gz|https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-2.1.5.tar.gz|sha256:7191c669bf38899f73a2094ed00f7b800553364f90e2637010a69c0e268f25d0"
  "cups-2.4.19-source.tar.gz|https://github.com/OpenPrinting/cups/releases/download/v2.4.19/cups-2.4.19-source.tar.gz|md5:06b7a3921812988cdb3198ff74ae381d"
)

# Thunderbird: l'ultima versione ufficiale, in italiano, dal sito di Mozilla (come Firefox).
THUNDERBIRD_RISERVA=145.0   # si usa solo se il sito di Mozilla non dice qual e' l'ultima

scarica_thunderbird() {
  local d="$LFS/sources" ver base riga atteso nome
  if [ -s "$d/thunderbird.tar.xz" ] && [ -s "$d/thunderbird.sha512" ] \
     && [ "$(sha512sum "$d/thunderbird.tar.xz" | cut -d' ' -f1)" = "$(cut -d' ' -f1 "$d/thunderbird.sha512")" ]; then
    info "Thunderbird $(cut -d' ' -f2 "$d/thunderbird.sha512")  (gia' scaricato)"; return 0
  fi
  ver=$(curl -fsSL --retry 3 --connect-timeout 20 https://product-details.mozilla.org/1.0/thunderbird_versions.json </dev/null \
        | sed -n 's/.*"LATEST_THUNDERBIRD_VERSION": *"\([0-9][0-9.]*\)".*/\1/p' | head -n1 || true)
  if [ -z "$ver" ]; then
    avviso "Non riesco a sapere qual e' l'ultima versione di Thunderbird: uso la $THUNDERBIRD_RISERVA (poi si aggiorna da solo)"
    ver=$THUNDERBIRD_RISERVA
  fi
  base="https://archive.mozilla.org/pub/thunderbird/releases/$ver"
  info "Thunderbird $ver in italiano (circa 80 MB)"
  scarica "$base/SHA512SUMS" "$d/thunderbird-SHA512SUMS" || muori "Non riesco a scaricare i controlli di Thunderbird: riprova tra un po'"
  # l'archivio puo' essere .tar.xz (versioni nuove) o .tar.bz2 (vecchie): si guarda l'elenco
  riga=$(grep -E "  linux-x86_64/it/thunderbird-$ver\.tar\.(xz|bz2)\$" "$d/thunderbird-SHA512SUMS" | head -n1 || true)
  [ -n "$riga" ] || muori "Nell'elenco di Mozilla non c'e' Thunderbird $ver per Linux in italiano"
  atteso=${riga%%  *}; nome=${riga##*/}
  scarica "$base/linux-x86_64/it/$nome" "$d/thunderbird.tar.xz" || muori "Download di Thunderbird non riuscito: riprova tra un po'"
  if [ "$(sha512sum "$d/thunderbird.tar.xz" | cut -d' ' -f1)" != "$atteso" ]; then
    rm -f "$d/thunderbird.tar.xz"; muori "Il file di Thunderbird e' rovinato (controllo SHA-512 fallito): riprova"
  fi
  echo "$atteso $ver" > "$d/thunderbird.sha512"
  rm -f "$d/thunderbird-SHA512SUMS"
  ok "Thunderbird $ver scaricato e controllato (SHA-512 pubblicato da Mozilla)"
}

# LibreOffice: l'ultima versione ufficiale (pacchetti .deb, che dentro il nuovo sistema
# si aprono con "ar" e "tar") e la lingua italiana. Il controllo SHA-256 e' quello
# pubblicato dal sito di LibreOffice accanto a ogni file.
scarica_libreoffice() {
  local d="$LFS/sources" base ver f dest atteso ok_tutti=1
  if [ -s "$d/libreoffice.sha256" ]; then
    while read -r atteso dest; do
      [ -s "$d/$dest" ] && [ "$(sha256sum "$d/$dest" | cut -d' ' -f1)" = "$atteso" ] || ok_tutti=0
    done < <(sed -n '2,$p' "$d/libreoffice.sha256")
    if [ "$ok_tutti" = 1 ]; then info "LibreOffice $(head -n1 "$d/libreoffice.sha256")  (gia' scaricato)"; return 0; fi
  fi
  base=https://download.documentfoundation.org/libreoffice/stable
  ver=$(curl -fsSL --retry 3 --connect-timeout 20 "$base/" </dev/null \
        | grep -o 'href="[0-9][0-9.]*/"' | grep -o '[0-9][0-9.]*[0-9]' | sort -V | tail -n1 || true)
  [ -n "$ver" ] || muori "Non riesco a sapere qual e' l'ultima versione di LibreOffice: riprova tra un po'"
  info "LibreOffice $ver in italiano (circa 250 MB)"
  printf '%s\n' "$ver" > "$d/libreoffice.sha256.nuovo"
  for f in "LibreOffice_${ver}_Linux_x86-64_deb.tar.gz|libreoffice.tar.gz" \
           "LibreOffice_${ver}_Linux_x86-64_deb_langpack_it.tar.gz|libreoffice-it.tar.gz"; do
    dest=${f#*|}; f=${f%|*}
    atteso=$(curl -fsSL --retry 3 --connect-timeout 20 "$base/$ver/deb/x86_64/$f.sha256" </dev/null \
             | grep -o '^[0-9a-f]\{64\}' | head -n1 || true)
    [ -n "$atteso" ] || muori "Non riesco a scaricare il controllo di $f: riprova tra un po'"
    scarica "$base/$ver/deb/x86_64/$f" "$d/$dest" || muori "Download di $f non riuscito: riprova tra un po'"
    if [ "$(sha256sum "$d/$dest" | cut -d' ' -f1)" != "$atteso" ]; then
      rm -f "$d/$dest"; muori "Il file $f e' rovinato (controllo SHA-256 fallito): riprova"
    fi
    printf '%s %s\n' "$atteso" "$dest" >> "$d/libreoffice.sha256.nuovo"
  done
  mv -f "$d/libreoffice.sha256.nuovo" "$d/libreoffice.sha256"
  ok "LibreOffice $ver scaricato e controllato (SHA-256 pubblicato da LibreOffice)"
}

f5_libwebp() {
./configure --prefix=/usr           \
            --enable-libwebpmux     \
            --enable-libwebpdemux   \
            --enable-libwebpdecoder \
            --enable-libwebpextras  \
            --enable-swap-16bit-csp \
            --disable-static
make
make install
}

f5_webp_pixbuf_loader() {
# BLFS (pagina archiviata "webp-pixbuf-loader"): le immagini WebP nei programmi GTK
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
gdk-pixbuf-query-loaders --update-cache
}

f5_swaylock() {
# NON IN BLFS: swaylock, il blocco dello schermo (Windows+L e dopo 10 minuti fermo).
# Senza Linux-PAM legge la password da /etc/shadow: per questo parte con i permessi
# di root (setuid), come spiega il README di swaylock; li abbandona subito dopo.
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false \
            -D pam=disabled -D gdk-pixbuf=enabled \
            -D zsh-completions=false -D fish-completions=false ..
ninja
ninja install
chmod -v 4755 /usr/bin/swaylock
}

f5_swayidle() {
# NON IN BLFS: swayidle, avvia il blocco dello schermo quando non usi il PC
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release -D werror=false \
            -D logind=disabled -D zsh-completions=false -D fish-completions=false ..
ninja
ninja install
}

f5_xfce4_taskmanager() {
# NON IN BLFS: Gestione attivita' (Ctrl+Shift+Esc): programmi aperti, processore, memoria
mkdir build
cd    build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f5_galculator() {
# NON IN BLFS: Calcolatrice (normale e scientifica). Programma vecchio: si compila
# con le regole del C di prima (gnu17) e con -fcommon, come fanno Void e Gentoo.
export CFLAGS="${CFLAGS:--O2} -std=gnu17 -fcommon"
./autogen.sh --prefix=/usr --enable-gtk3
make
make install
}

f5_liberation_fonts() {
# BLFS, pagina "TTF and OTF fonts": caratteri Liberation, con le stesse misure di
# Arial, Times New Roman e Courier New (i documenti di Windows restano uguali)
install -v -d -m755 /usr/share/fonts/liberation
install -v -m644 *.ttf /usr/share/fonts/liberation
fc-cache -v /usr/share/fonts/liberation
}

f5_cups() {
# MODIFICA: l'utente lp e il gruppo lpadmin si creano solo se non ci sono gia'
# (cosi' si puo' rilanciare)
id lp >/dev/null 2>&1 || useradd -c "Print Service User" -d /var/spool/cups -g lp -s /bin/false -u 9 lp
getent group lpadmin >/dev/null || groupadd -g 19 lpadmin
sed -i 's#@CUPS_HTMLVIEW@#firefox#' desktop/cups.desktop.in
sed -i '/& ipp->prev)/s/prev/& \&\& ipp->prev->next == *attr/' cups/ipp.c
./configure --libdir=/usr/lib            \
            --with-rundir=/run/cups      \
            --with-system-groups=lpadmin \
            --with-docdir=/usr/share/cups/doc-2.4.19
make
make install
ln -svnf ../cups/doc-2.4.19 /usr/share/doc/cups-2.4.19
echo "ServerName /run/cups/cups.sock" > /etc/cups/client.conf
# (saltata la parte per Linux-PAM: qui non e' installato)
systemctl enable cups
}

f5_libreoffice() {
# NON IN BLFS: LibreOffice ufficiale (Writer, Calc, Impress...), in italiano.
# I pacchetti .deb si aprono con "ar" (dentro c'e' un normale archivio tar).
local tmp=/sources/libreoffice-tmp deb dir f
rm -rf "$tmp" /opt/libreoffice*
mkdir -p "$tmp"
tar -C "$tmp" -xf /sources/libreoffice.tar.gz
tar -C "$tmp" -xf /sources/libreoffice-it.tar.gz
for deb in "$tmp"/*/DEBS/*.deb; do
  rm -rf "$tmp/x"; mkdir "$tmp/x"
  (cd "$tmp/x" && ar x "$deb" && tar -C / -xf data.tar.*)
done
rm -rf "$tmp"
dir=$(ls -d /opt/libreoffice*/program 2>/dev/null | head -n1)
[ -n "$dir" ] && [ -x "$dir/soffice" ] || { echo "LibreOffice non si e' installato in /opt"; return 1; }
ln -sfv "$dir/soffice" /usr/bin/libreoffice
# le voci del menu avviano "libreofficeNN.N": il comando deve esistere
ln -sfv "$dir/soffice" "/usr/bin/$(basename "$(dirname "$dir")")"
# le voci del menu (Writer, Calc, Impress...): se il pacchetto "menus" non le ha messe
if ! ls /usr/share/applications/libreoffice*-writer.desktop >/dev/null 2>&1; then
  for f in "$dir"/../share/xdg/*.desktop; do
    ln -sfv "$(realpath "$f")" "/usr/share/applications/libreoffice-$(basename "$f")"
  done
fi
# controllo: ci sono tutte le librerie di sistema che servono?
local manca
manca=$(for f in "$dir/soffice.bin" "$dir/libvcllo.so" "$dir/libvclplug_gtk3lo.so"; do
          [ -e "$f" ] && LD_LIBRARY_PATH="$dir" ldd "$f" 2>&1
        done | grep 'not found' | sort -u || true)
if [ -n "$manca" ]; then
  echo "A LibreOffice mancano queste librerie:"
  echo "$manca"
  return 1
fi
echo "[OK] LibreOffice: ci sono tutte le librerie che gli servono"
}

f5_thunderbird() {
# NON IN BLFS: Thunderbird ufficiale di Mozilla (posta elettronica), come Firefox:
# in /opt e del tuo utente, cosi' si aggiorna da solo.
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
[ -x ./thunderbird ] || { echo "L'archivio di Thunderbird non contiene il programma"; return 1; }
rm -rf /opt/thunderbird
mkdir -p /opt
cp -a . /opt/thunderbird
chown -R "$MIA_UTENTE:" /opt/thunderbird
ln -sfv /opt/thunderbird/thunderbird /usr/bin/thunderbird
cat > /usr/share/applications/thunderbird.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Thunderbird
GenericName=Posta elettronica
Comment=Leggere e scrivere email
Exec=thunderbird %u
Icon=/opt/thunderbird/chrome/icons/default/default128.png
Terminal=false
Categories=Network;Email;
MimeType=x-scheme-handler/mailto;message/rfc822;
StartupNotify=true
StartupWMClass=thunderbird
EOF
local f manca
manca=$(for f in /opt/thunderbird/libxul.so /opt/thunderbird/thunderbird-bin; do
          [ -e "$f" ] && LD_LIBRARY_PATH=/opt/thunderbird ldd "$f" 2>&1
        done | grep 'not found' | sort -u || true)
if [ -n "$manca" ]; then
  echo "A Thunderbird mancano queste librerie:"
  echo "$manca"
  return 1
fi
echo "[OK] Thunderbird: ci sono tutte le librerie che gli servono"
}

f5_configura() {
# NON IN BLFS: tasti, blocco automatico, programmi predefiniti
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local t app w c i
usermod -aG lpadmin "$MIA_UTENTE"
mkdir -p /usr/local/bin

# --- blocco dello schermo: con lo sfondo del desktop ---
cat > /usr/local/bin/blocca-schermo << "EOF"
#!/bin/bash
# Blocca lo schermo (creato da lfs.sh): per sbloccare scrivi la tua password e premi Invio
pgrep -x swaylock >/dev/null && exit 0
exec swaylock -f -i /usr/share/backgrounds/sfondo-desktop.png -s fill \
     --indicator-radius 90 --indicator-thickness 8 \
     --inside-color 00000088 --ring-color 3584e4ff --key-hl-color 99c1f1ff \
     --line-color 00000000 --separator-color 00000000 --text-color ffffffff
EOF
chmod 755 /usr/local/bin/blocca-schermo

# --- menu di spegnimento: anche "Blocca lo schermo" ---
cat > /usr/local/bin/menu-spegnimento << "EOF"
#!/bin/bash
# Menu per bloccare, spegnere, riavviare o uscire dal desktop (creato da lfs.sh)
scelta=$(printf '%s\n' "Blocca lo schermo" "Spegni il computer" "Riavvia il computer" "Esci dalla sessione" \
         | fuzzel --dmenu --prompt "Cosa vuoi fare? " --lines 4 --width 32) || exit 0
case "$scelta" in
    Blocca*)  /usr/local/bin/blocca-schermo ;;
    Spegni*)  sudo -n /usr/bin/systemctl poweroff ;;
    Riavvia*) sudo -n /usr/bin/systemctl reboot ;;
    Esci*)    labwc --exit ;;
esac
EOF
chmod 755 /usr/local/bin/menu-spegnimento

# --- tasti: Windows+L blocca, Ctrl+Shift+Esc gestione attivita' ---
if ! grep -q 'blocca-schermo' /etc/xdg/labwc/rc.xml; then
  sed -i 's|^  </keyboard>|    <keybind key="W-l">\n      <action name="Execute" command="/usr/local/bin/blocca-schermo" />\n    </keybind>\n    <keybind key="C-S-Escape">\n      <action name="Execute" command="xfce4-taskmanager" />\n    </keybind>\n  </keyboard>|' /etc/xdg/labwc/rc.xml
fi
grep -q 'blocca-schermo' /etc/xdg/labwc/rc.xml || { echo "Non riesco ad aggiungere i tasti"; return 1; }

# --- blocco automatico dopo 10 minuti senza usare il PC ---
if ! grep -q '^swayidle ' /etc/xdg/labwc/autostart; then
  echo "swayidle -w timeout 600 /usr/local/bin/blocca-schermo >/dev/null 2>&1 &" >> /etc/xdg/labwc/autostart
fi

# --- menu col tasto destro sul desktop: anche ufficio e posta ---
if ! grep -q 'libreoffice' /etc/xdg/labwc/menu.xml; then
  sed -i 's|^  <item label="Editor di testo">|  <item label="Documenti (LibreOffice)">\n    <action name="Execute" command="libreoffice" />\n  </item>\n  <item label="Posta (Thunderbird)">\n    <action name="Execute" command="thunderbird" />\n  </item>\n  <item label="Editor di testo">|' /etc/xdg/labwc/menu.xml
fi

# --- programmi predefiniti: documenti, fogli, presentazioni, posta, WebP ---
w=$(basename "$(ls /usr/share/applications/libreoffice*-writer.desktop | head -n1)")
c=$(basename "$(ls /usr/share/applications/libreoffice*-calc.desktop | head -n1)")
i=$(basename "$(ls /usr/share/applications/libreoffice*-impress.desktop | head -n1)")
for t in "application/vnd.openxmlformats-officedocument.wordprocessingml.document|$w" \
         "application/msword|$w" "application/vnd.oasis.opendocument.text|$w" "application/rtf|$w" \
         "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet|$c" \
         "application/vnd.ms-excel|$c" "application/vnd.oasis.opendocument.spreadsheet|$c" "text/csv|$c" \
         "application/vnd.openxmlformats-officedocument.presentationml.presentation|$i" \
         "application/vnd.ms-powerpoint|$i" "application/vnd.oasis.opendocument.presentation|$i" \
         "x-scheme-handler/mailto|thunderbird.desktop" "message/rfc822|thunderbird.desktop" \
         "image/webp|org.xfce.ristretto.desktop"; do
  app=${t#*|}; t=${t%|*}
  if grep -q "^$t=" /etc/xdg/mimeapps.list; then
    sed -i "s|^$t=.*|$t=$app|" /etc/xdg/mimeapps.list
  else
    sed -i "/^\[Default Applications\]/a $t=$app" /etc/xdg/mimeapps.list
  fi
done
update-desktop-database /usr/share/applications
update-mime-database /usr/share/mime
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
fc-cache -f
echo "[OK] Ufficio, posta, blocco schermo, gestione attivita', calcolatrice e stampa pronti"
}

LISTA_STEP12=(
  "libwebp|libwebp-1.6.0.tar.gz|f5_libwebp"
  "immagini WebP nei programmi|webp-pixbuf-loader-0.2.7.tar.gz|f5_webp_pixbuf_loader"
  "swaylock (blocco schermo)|swaylock-1.8.6.tar.gz|f5_swaylock"
  "swayidle (blocco automatico)|swayidle-1.9.0.tar.gz|f5_swayidle"
  "Gestione attivita'|xfce4-taskmanager-1.6.0.tar.xz|f5_xfce4_taskmanager"
  "Calcolatrice|galculator-2.1.4.tar.gz|f5_galculator"
  "caratteri Liberation|liberation-fonts-ttf-2.1.5.tar.gz|f5_liberation_fonts"
  "CUPS (stampa)|cups-2.4.19-source.tar.gz|f5_cups"
  "LibreOffice (ufficio)|-|f5_libreoffice"
  "Thunderbird (posta)|thunderbird.tar.xz|f5_thunderbird"
  "configurazione (seconda parte)|-|f5_configura"
)

cmd_fase5() {
  serve_root fase5
  titolo "Fase 5 - Uso quotidiano (2): ufficio, posta, blocco schermo, calcolatrice"
  assicura_montato
  if [ "$(quanti_fatti "${LISTA_STEP11[@]}")" -ne "${#LISTA_STEP11[@]}" ]; then
    info "Prima finisco la Fase 4 (audio, foto, video...), poi passo alla seconda parte."
    cmd_fase4
    titolo "Fase 5 - Uso quotidiano (2): ufficio, posta, blocco schermo, calcolatrice"
  fi
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP12[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 5 da capo (opzione 'rifai')"
  fi
  chiedi_utente
  titolo "Scarico i sorgenti della Fase 5 (circa 350 MB)"
  scarica_fonti "${FONTI_FASE5[@]}"
  scarica_libreoffice
  scarica_thunderbird
  info "Ci vogliono circa 20-30 minuti (dipende dal PC). Lascia il terminale aperto."
  local esito=0
  lancia_in_chroot 12 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase5 MIA_ETICHETTA="Fase 5" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 5 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia). Novita' nel menu Applicazioni:"
  info "   LibreOffice (documenti Word, fogli Excel, presentazioni), Thunderbird (posta),"
  info "   Calcolatrice, Gestione attivita' (anche con Ctrl+Shift+Esc)"
  info "   Windows+L: blocca lo schermo (si blocca da solo dopo 10 minuti fermo)"
  info "   Stampanti: in Firefox vai su  localhost:631"
}

# =============================================================================
#  FASE 6 - SICUREZZA
#   - firewall: da internet nessuno puo' collegarsi al computer
#   - Guardiano della rete: la prima volta che un programma vuole usare internet
#     compare la domanda "Blocca / Permetti" (niente esce senza il tuo permesso)
#   - Tor Browser come browser predefinito (i siti non vedono il tuo indirizzo IP)
#   - VPN WireGuard: al primo accesso chiede se hai un abbonamento; se no propone
#     Mullvad; se non la vuoi, si continua senza
#   - Cassaforte: una cartella cifrata che si apre con una password
#   - Recinto per i programmi Windows: vedono solo il loro disco C: e la cartella
#     ~/Windows, non il resto dei tuoi file (bubblewrap, dal libro BLFS)
#   - DNS cifrato (Quad9), indirizzi IPv6 temporanei, impostazioni del kernel piu'
#     prudenti
#  iptables e bubblewrap dal libro BLFS 13.1 (tag r13.1): ogni differenza e' segnata con
#  "# MODIFICA:", le parti che il libro non ha con "# NON IN BLFS".
#  Scelte:
#   - il Guardiano e' scritto in Python (gia' nel sistema) e parla col kernel
#     direttamente (NFQUEUE): niente librerie in piu'. Se il Guardiano non gira,
#     i programmi dell'utente restano senza internet (mai "aperto per sbaglio").
#   - la cassaforte usa la cifratura di ext4 (fscrypt v2, AES-256): niente
#     programmi in piu', ma il disco deve avere l'opzione "encrypt" (la attiva
#     questa fase, sul PC, con il disco smontato).
#   - Tor Browser e' quello ufficiale: la firma degli sviluppatori di Tor si
#     controlla con gpg sul tuo PC prima di usarlo.
# =============================================================================
FONTI_FASE6=(
  # file | indirizzo | controllo (md5 dal libro BLFS 13.1; sha256 da Void Linux)
  "iptables-1.8.13.tar.xz|https://www.netfilter.org/projects/iptables/files/iptables-1.8.13.tar.xz|md5:81b5edf500e2672bfbc744581ff7dc3e"
  "wireguard-tools-1.0.20260223.tar.xz|https://git.zx2c4.com/wireguard-tools/snapshot/wireguard-tools-1.0.20260223.tar.xz|sha256:af459827b80bfd31b83b08077f4b5843acb7d18ad9a33a2ef532d3090f291fbf"
  "yad-14.2.tar.xz|https://github.com/v1cont/yad/releases/download/v14.2/yad-14.2.tar.xz|sha256:5cab399af8d9a10b76d477f848180d00addba38f4f1272a05b153a393bba3038"
  "bubblewrap-0.11.2.tar.xz|https://github.com/containers/bubblewrap/releases/download/v0.11.2/bubblewrap-0.11.2.tar.xz|md5:6376255e2e505100e01b20c2dafa7faf"
)

# Tor Browser: l'ultima versione ufficiale. Il file e' firmato dagli sviluppatori di
# Tor; la loro chiave ha questa impronta (pubblicata su support.torproject.org).
TOR_CHIAVE=EF6E286DDA85EA2A4BA7DE684E2C6E8793298290

scarica_tor_browser() {
  local d="$LFS/sources" dati url firma ver g esito
  if [ -s "$d/tor-browser.tar.xz" ] && [ -s "$d/tor-browser.sha256" ] \
     && [ "$(sha256sum "$d/tor-browser.tar.xz" | cut -d' ' -f1)" = "$(cut -d' ' -f1 "$d/tor-browser.sha256")" ]; then
    info "Tor Browser $(cut -d' ' -f2 "$d/tor-browser.sha256")  (gia' scaricato e controllato)"; return 0
  fi
  command -v gpg >/dev/null 2>&1 \
    || muori "Per controllare la firma di Tor Browser serve gpg sul tuo PC (Fedora: sudo dnf install gnupg2)"
  dati=$(curl -fsSL --retry 3 --connect-timeout 20 \
         https://aus1.torproject.org/torbrowser/update_3/release/download-linux-x86_64.json </dev/null || true)
  url=$(printf '%s' "$dati" | grep -o '"binary" *: *"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' || true)
  firma=$(printf '%s' "$dati" | grep -o '"sig" *: *"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' || true)
  ver=$(printf '%s' "$dati" | grep -o '"version" *: *"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' || true)
  case "$url" in
    https://dist.torproject.org/torbrowser/*/tor-browser-linux-x86_64-*.tar.xz) ;;
    *) muori "Non riesco a sapere qual e' l'ultima versione di Tor Browser: riprova tra un po'" ;;
  esac
  [ "$firma" = "$url.asc" ] || muori "Il sito di Tor non indica la firma di Tor Browser: riprova tra un po'"
  info "Tor Browser $ver (circa 110 MB)"
  scarica "$url" "$d/tor-browser.tar.xz" || muori "Download di Tor Browser non riuscito: riprova tra un po'"
  scarica "$firma" "$d/tor-browser.tar.xz.asc" || muori "Download della firma di Tor Browser non riuscito: riprova"
  # la chiave degli sviluppatori: dal sito di Tor (WKD), altrimenti da keys.openpgp.org.
  # In tutti e due i casi conta solo l'impronta, controllata qui sotto.
  g=$(mktemp -d); chmod 700 "$g"
  if ! gpg --homedir "$g" --batch --quiet --auto-key-locate clear,nodefault,wkd \
           --locate-external-keys torbrowser@torproject.org >/dev/null 2>&1; then
    curl -fsSL --retry 3 --connect-timeout 20 "https://keys.openpgp.org/vks/v1/by-fingerprint/$TOR_CHIAVE" </dev/null \
      | gpg --homedir "$g" --batch --quiet --import >/dev/null 2>&1 || true
  fi
  esito=$(gpg --homedir "$g" --batch --status-fd 1 --verify "$d/tor-browser.tar.xz.asc" "$d/tor-browser.tar.xz" 2>/dev/null || true)
  gpgconf --homedir "$g" --kill all >/dev/null 2>&1 || true
  rm -rf "$g" "$d/tor-browser.tar.xz.asc"
  if ! printf '%s\n' "$esito" | grep -Eq "^\[GNUPG:\] VALIDSIG ($TOR_CHIAVE .*|.* $TOR_CHIAVE)\$"; then
    rm -f "$d/tor-browser.tar.xz"
    muori "La firma di Tor Browser NON e' valida (file rovinato o non originale): riprova tra un po'"
  fi
  echo "$(sha256sum "$d/tor-browser.tar.xz" | cut -d' ' -f1) $ver" > "$d/tor-browser.sha256"
  ok "Tor Browser $ver scaricato e controllato (firma degli sviluppatori di Tor)"
}

f6_iptables() {
./configure --prefix=/usr      \
            --disable-nftables \
            --enable-libipq
make
make install
# MODIFICA: niente script di esempio /etc/systemd/scripts/iptables e niente unita' del
# pacchetto blfs-systemd-units: il firewall di questa distro lo crea f6_guardiano
# (firewall-avvia e firewall.service, partendo dall'esempio "Personal Firewall" del libro)
}

f6_wireguard_tools() {
# NON IN BLFS: gli strumenti della VPN WireGuard (wg e wg-quick). WireGuard stesso e'
# dentro il kernel (opzione WIREGUARD, aggiunta all'elenco OPZIONI_KERNEL)
make -C src RUNSTATEDIR=/run
make -C src RUNSTATEDIR=/run WITH_BASHCOMPLETION=yes WITH_WGQUICK=yes WITH_SYSTEMDUNITS=yes install
install -vdm700 /etc/wireguard
command -v resolvconf >/dev/null || { echo "Manca resolvconf (di systemd): serve a wg-quick per i DNS"; return 1; }
}

f6_yad() {
# NON IN BLFS: yad, le finestre di dialogo usate dal Guardiano, dalla cassaforte e dalla VPN
./configure --prefix=/usr          \
            --enable-standalone    \
            --disable-html         \
            --disable-spell        \
            --disable-sourceview
make
make install
}

f6_tor_browser() {
# NON IN BLFS: Tor Browser ufficiale (la firma e' stata controllata sul tuo PC quando e'
# stato scaricato). Va in /opt/tor-browser e appartiene al tuo utente: cosi' si
# aggiorna da solo (anche gli aggiornamenti sono firmati dagli sviluppatori di Tor).
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
[ -x ./Browser/start-tor-browser ] || { echo "L'archivio di Tor Browser non contiene il programma"; return 1; }
rm -rf /opt/tor-browser
mkdir -p /opt
cp -a . /opt/tor-browser
chown -R "$MIA_UTENTE:" /opt/tor-browser
cat > /usr/local/bin/tor-browser << "EOF"
#!/bin/sh
# Tor Browser (creato da lfs.sh): i siti non vedono il tuo indirizzo IP.
# In modalita' fantasma usa il Tor del sistema (niente "Tor dentro Tor").
# L'utente fantasma ha una sua copia in memoria (sparisce allo spegnimento).
TB=/opt/tor-browser
if [ "$(id -un)" = fantasma ]; then
  TB="$HOME/.tor-browser"
  if [ ! -x "$TB/Browser/start-tor-browser" ]; then
    notify-send -a "Tor Browser" -i fantasma "Tor Browser" "Lo preparo (qualche secondo)..." 2>/dev/null
    rm -rf "$TB"
    cp -a /usr/local/lib/fantasma/tor-browser "$TB" || exit 1
  fi
fi
if [ -e /etc/fantasma/attivo ]; then
  TOR_PROVIDER=none TOR_SOCKS_HOST=127.0.0.1 TOR_SOCKS_PORT=9150
  export TOR_PROVIDER TOR_SOCKS_HOST TOR_SOCKS_PORT
fi
exec "$TB/Browser/start-tor-browser" --detach "$@"
EOF
chmod 755 /usr/local/bin/tor-browser
local icona=/opt/tor-browser/Browser/browser/chrome/icons/default/default128.png manca
[ -f "$icona" ] || icona=web-browser
install -vdm755 /usr/share/applications
cat > /usr/share/applications/tor-browser.desktop << EOF
[Desktop Entry]
Type=Application
Name=Tor Browser
GenericName=Browser anonimo
Comment=Navigare in Internet senza far vedere il tuo indirizzo IP
Exec=/usr/local/bin/tor-browser %u
Icon=$icona
Terminal=false
Categories=Network;WebBrowser;Security;
MimeType=text/html;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
StartupWMClass=Tor Browser
EOF
# controllo: ci sono tutte le librerie di sistema che servono a Tor Browser?
manca=$(for f in /opt/tor-browser/Browser/libxul.so /opt/tor-browser/Browser/firefox.real \
                 /opt/tor-browser/Browser/TorBrowser/Tor/tor; do
          [ -e "$f" ] && LD_LIBRARY_PATH=/opt/tor-browser/Browser:/opt/tor-browser/Browser/TorBrowser/Tor ldd "$f" 2>&1
        done | grep 'not found' | sort -u || true)
if [ -n "$manca" ]; then
  echo "Mancano queste librerie per Tor Browser:"; echo "$manca"; return 1
fi
echo "[OK] Tor Browser installato in /opt/tor-browser"
}

f6_guardiano() {
# NON IN BLFS: firewall e Guardiano della rete.
#   firewall-avvia      le regole (iptables e ip6tables), all'accensione (firewall.service)
#   guardiano-rete      il servizio (root) che ferma il primo collegamento di ogni programma
#   guardiano-avvisi    la finestra con la domanda, sul desktop dell'utente
#   guardiano-regole    l'elenco dei programmi permessi/bloccati (menu: Regole della rete)
mkdir -p /usr/local/sbin /usr/local/bin /etc/guardiano-rete
cat > /usr/local/sbin/firewall-avvia << "EOF"
#!/bin/bash
# Firewall (creato da lfs.sh, partendo dall'esempio "Personal Firewall" del libro BLFS)
#  - in ENTRATA passano solo le risposte a cio' che hai chiesto tu (piu' DHCP e IPv6 di base):
#    nessuno da fuori puo' collegarsi al tuo computer
#  - in USCITA i programmi del tuo utente passano dal Guardiano della rete, che ti chiede
#    il permesso; i servizi del sistema (rete, orologio, DNS) escono normalmente
#  - catena VPN: con la VPN sempre accesa i tuoi programmi escono SOLO dalla VPN
#  - MODALITA' FANTASMA (se accesa): TUTTO esce solo da Tor. I collegamenti dei programmi
#    vengono girati dentro Tor, i nomi dei siti li risolve Tor, il resto (UDP, IPv6,
#    rete locale, orologio) e' bloccato. Esce direttamente solo Tor stesso.
set -e
UTENTI=1000-59999
SEMPRE=/etc/wireguard/sempre-accesa
FANTASMA=/etc/fantasma/attivo

regole() { # 4 oppure 6
  echo '*filter'
  echo ':INPUT DROP [0:0]'
  echo ':FORWARD DROP [0:0]'
  echo ':OUTPUT ACCEPT [0:0]'
  echo ':VPN - [0:0]'
  echo '-A INPUT -i lo -j ACCEPT'
  echo '-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'
  if [ "$1" = 4 ]; then
    echo '-A INPUT -p udp --sport 67 --dport 68 -j ACCEPT'
  else
    echo '-A INPUT -p ipv6-icmp -j ACCEPT'
    echo '-A INPUT -s fe80::/10 -p udp --dport 546 -j ACCEPT'
  fi
  echo '-A OUTPUT -o lo -j ACCEPT'
  echo '-A OUTPUT -j VPN'
  echo '-A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'
  echo "-A OUTPUT -m owner --uid-owner $UTENTI -j NFQUEUE --queue-num 0"
  if [ -e "$SEMPRE" ]; then
    echo "-A VPN -m owner --uid-owner $UTENTI ! -o vpn -j REJECT"
  fi
  echo 'COMMIT'
}

regole_fantasma() { # 4 oppure 6: esce solo Tor
  echo '*filter'
  echo ':INPUT DROP [0:0]'
  echo ':FORWARD DROP [0:0]'
  echo ':OUTPUT DROP [0:0]'
  echo ':VPN - [0:0]'
  echo '-A INPUT -i lo -j ACCEPT'
  echo '-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'
  [ "$1" = 4 ] && echo '-A INPUT -p udp --sport 67 --dport 68 -j ACCEPT'
  # pacchetti "fuori posto" (es. dopo un collegamento chiuso): mai fuori da Tor
  echo '-A OUTPUT -m conntrack --ctstate INVALID -j DROP'
  echo '-A OUTPUT -o lo -j ACCEPT'
  if [ "$1" = 4 ]; then
    # i collegamenti girati dentro Tor: qui la scheda risulta ancora quella di uscita
    # (il kernel decide "-o" prima del giro), per questo si guarda la destinazione
    echo '-A OUTPUT -d 127.0.0.1/32 -p tcp --dport 9040 -j ACCEPT'
    echo '-A OUTPUT -d 127.0.0.1/32 -p udp --dport 9053 -j ACCEPT'
    echo '-A OUTPUT -m owner --uid-owner tor -j ACCEPT'
    echo '-A OUTPUT -p udp --dport 67 -m owner --uid-owner systemd-network -j ACCEPT'
  fi
  # pacchetti del kernel senza programma (la VPN WireGuard, se accesa, porta Tor dentro la VPN)
  echo '-A OUTPUT -m owner ! --socket-exists -j ACCEPT'
  echo '-A OUTPUT -j REJECT'
  echo 'COMMIT'
}

nat_fantasma() { # i collegamenti TCP e i nomi dei siti vanno dentro Tor
  echo '*nat'
  echo ':PREROUTING ACCEPT [0:0]'
  echo ':INPUT ACCEPT [0:0]'
  echo ':OUTPUT ACCEPT [0:0]'
  echo ':POSTROUTING ACCEPT [0:0]'
  echo '-A OUTPUT -m owner --uid-owner tor -j RETURN'
  echo '-A OUTPUT -o lo -j RETURN'
  echo '-A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 9053'
  echo '-A OUTPUT -p tcp --syn -j REDIRECT --to-ports 9040'
  echo 'COMMIT'
}

applica() {
  if [ -e "$FANTASMA" ]; then
    nat_fantasma | iptables-restore
    regole_fantasma 4 | iptables-restore
    regole_fantasma 6 | ip6tables-restore
    # il Guardiano chiede anche in modalita' fantasma (prima che il collegamento entri in Tor)
    iptables -t mangle -F OUTPUT
    iptables -t mangle -A OUTPUT ! -o lo -m owner --uid-owner "$UTENTI" -m conntrack --ctstate NEW \
             -p tcp --syn -j NFQUEUE --queue-num 0
    iptables -t mangle -A OUTPUT ! -o lo -m owner --uid-owner "$UTENTI" -m conntrack --ctstate NEW \
             -p udp --dport 53 -j NFQUEUE --queue-num 0
  else
    regole 4 | iptables-restore
    regole 6 | ip6tables-restore
    iptables -t nat -F OUTPUT 2>/dev/null || true
    iptables -t mangle -F OUTPUT 2>/dev/null || true
  fi
}

case "${1:-avvia}" in
  avvia)
    applica ;;
  prova)
    regole 4 | iptables-restore --test
    regole 6 | ip6tables-restore --test
    if [ -e "$FANTASMA" ]; then
      nat_fantasma | iptables-restore --test
      regole_fantasma 4 | iptables-restore --test
      regole_fantasma 6 | ip6tables-restore --test
    fi
    echo "Regole del firewall corrette" ;;
  mostra)
    if [ -e "$FANTASMA" ]; then nat_fantasma; regole_fantasma "${2:-4}"; else regole "${2:-4}"; fi ;;
esac
EOF
cat > /usr/local/sbin/guardiano-rete << "EOF"
#!/usr/bin/python3 -I
# Guardiano della rete (creato da lfs.sh).
# Prima che un programma del tuo utente si colleghi a internet per la prima volta,
# il collegamento viene fermato e nel desktop compare la domanda: Permetti o Blocca.
# Le risposte "sempre" restano in /etc/guardiano-rete/regole.
# Gira come root (servizio guardiano-rete); le finestre le mostra "guardiano-avvisi".
import errno, json, os, socket, struct, sys, threading, time

CODA = int(os.environ.get("GUARDIANO_CODA", "0"))
CARTELLA = os.environ.get("GUARDIANO_CARTELLA", "/etc/guardiano-rete")
REGOLE = os.path.join(CARTELLA, "regole")
PRESA = os.environ.get("GUARDIANO_PRESA", "/run/guardiano-rete.sock")
GRUPPO = os.environ.get("GUARDIANO_GRUPPO", "wheel")
# i soli due programmi che possono rispondere (devono partire con "python3 -I")
AMMESSI = os.environ.get("GUARDIANO_AMMESSI",
                         "/usr/local/bin/guardiano-avvisi:/usr/local/bin/guardiano-regole").split(":")
ATTESA = 60            # secondi per rispondere, poi il collegamento resta bloccato
PAUSA = 600            # dopo "Blocca per ora" (o nessuna risposta) non richiede per 10 minuti

# --- netlink / NFQUEUE (linux/netfilter/nfnetlink_queue.h) ---
NETLINK_NETFILTER = 12
NFNL_SUBSYS_QUEUE = 3
MSG_PACKET, MSG_VERDICT, MSG_CONFIG = 0, 1, 2
CFG_CMD, CFG_PARAMS, CFG_MASK, CFG_FLAGS = 1, 2, 4, 5
CMD_BIND = 1
COPY_PACKET = 2
A_PACKET_HDR, A_VERDICT_HDR, A_PAYLOAD, A_UID = 1, 2, 10, 16
F_UID_GID = 0x08
NLM_F_REQUEST, NLM_F_ACK = 0x1, 0x4
NLMSG_ERROR = 2
NF_DROP, NF_ACCEPT = 0, 1

def attr(tipo, dati):
    lun = 4 + len(dati)
    return struct.pack("=HH", lun, tipo) + dati + b"\0" * ((4 - lun % 4) % 4)

class Coda:
    def __init__(self, numero):
        self.numero = numero
        self.s = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, NETLINK_NETFILTER)
        self.s.bind((0, 0))
        self.s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 << 20)
        self.seq = 0
        self.blocco = threading.Lock()
        self._invia(MSG_CONFIG, socket.AF_UNSPEC, attr(CFG_CMD, struct.pack("!BBH", CMD_BIND, 0, 0)), NLM_F_ACK)
        self._invia(MSG_CONFIG, socket.AF_UNSPEC,
                    attr(CFG_PARAMS, struct.pack("!IB", 512, COPY_PACKET))
                    + attr(CFG_FLAGS, struct.pack("!I", F_UID_GID))
                    + attr(CFG_MASK, struct.pack("!I", F_UID_GID)), NLM_F_ACK)

    def _invia(self, msg, famiglia, attributi, flag=0):
        with self.blocco:
            self.seq += 1
            corpo = struct.pack("!BBH", famiglia, 0, self.numero) + attributi
            testa = struct.pack("=IHHII", 16 + len(corpo), (NFNL_SUBSYS_QUEUE << 8) | msg,
                                NLM_F_REQUEST | flag, self.seq, 0)
            self.s.send(testa + corpo)

    def verdetto(self, ident, sentenza):
        self._invia(MSG_VERDICT, socket.AF_UNSPEC, attr(A_VERDICT_HDR, struct.pack("!II", sentenza, ident)))

    def pacchetti(self):
        """Restituisce i pacchetti in arrivo: (id, famiglia, payload, uid)."""
        while True:
            try:
                dati = self.s.recv(1 << 20)
            except OSError as e:
                if e.errno == errno.ENOBUFS:        # troppi pacchetti insieme: si va avanti
                    continue
                raise
            pos = 0
            while pos + 16 <= len(dati):
                lun, tipo, _, _, _ = struct.unpack_from("=IHHII", dati, pos)
                if lun < 16:
                    break
                if tipo == NLMSG_ERROR:
                    err = struct.unpack_from("=i", dati, pos + 16)[0]
                    if err != 0:
                        print("Errore dal kernel (netlink):", os.strerror(-err), flush=True)
                elif tipo == (NFNL_SUBSYS_QUEUE << 8) | MSG_PACKET:
                    famiglia = dati[pos + 16]
                    p = pos + 20
                    ident, payload, uid = None, b"", None
                    while p + 4 <= pos + lun:
                        alun, atipo = struct.unpack_from("=HH", dati, p)
                        if alun < 4:
                            break
                        valore = dati[p + 4:p + alun]
                        atipo &= 0x3fff
                        if atipo == A_PACKET_HDR:
                            ident = struct.unpack_from("!I", valore)[0]
                        elif atipo == A_PAYLOAD:
                            payload = bytes(valore)
                        elif atipo == A_UID:
                            uid = struct.unpack_from("!I", valore)[0]
                        p += (alun + 3) & ~3
                    if ident is not None:
                        yield ident, famiglia, payload, uid
                pos += (lun + 3) & ~3

# --- chi sta parlando: dal pacchetto al programma ---
def leggi_pacchetto(famiglia, b):
    """-> (protocollo, porta_locale, indirizzo_remoto, porta_remota) oppure None"""
    try:
        if famiglia == socket.AF_INET:
            ihl = (b[0] & 0x0F) * 4
            proto, remoto, l4 = b[9], socket.inet_ntop(socket.AF_INET, b[16:20]), b[ihl:]
        elif famiglia == socket.AF_INET6:
            proto, remoto, l4 = b[6], socket.inet_ntop(socket.AF_INET6, b[24:40]), b[40:]
        else:
            return None
        if proto not in (6, 17) or len(l4) < 4:
            return None
        sport, dport = struct.unpack("!HH", l4[:4])
        return ("tcp" if proto == 6 else "udp"), sport, remoto, dport
    except (IndexError, ValueError, struct.error):
        return None

def inode_presa(proto, famiglia, porta_locale, porta_remota):
    file = [f"/proc/net/{proto}6"] if famiglia == socket.AF_INET6 else [f"/proc/net/{proto}", f"/proc/net/{proto}6"]
    di_riserva = None
    for f in file:
        try:
            righe = open(f).read().splitlines()[1:]
        except OSError:
            continue
        for r in righe:
            c = r.split()
            if len(c) < 10:
                continue
            if int(c[1].rsplit(":", 1)[1], 16) != porta_locale:
                continue
            inode = int(c[9])
            if inode == 0:
                continue
            if int(c[2].rsplit(":", 1)[1], 16) == porta_remota:
                return inode
            di_riserva = di_riserva or inode
    return di_riserva

def processo_della_presa(inode):
    cerca = f"socket:[{inode}]"
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            for fd in os.listdir(f"/proc/{pid}/fd"):
                try:
                    if os.readlink(f"/proc/{pid}/fd/{fd}") == cerca:
                        return int(pid)
                except OSError:
                    pass
        except OSError:
            pass
    return None

INTERPRETI = ("python", "python3", "bash", "sh", "perl", "ruby", "node", "java", "lua", "luajit")
WINE = ("wine", "wine64", "wine-preloader", "wine64-preloader")

def manomesso(pid):
    """Un programma "permesso" fatto partire con codice infilato dentro (LD_PRELOAD...)
    o controllato da un altro programma non vale come quello vero: si chiede di nuovo."""
    try:
        ambiente = open(f"/proc/{pid}/environ", "rb").read().split(b"\0")
        controllato = [r for r in open(f"/proc/{pid}/status") if r.startswith("TracerPid:")]
    except OSError:
        return ""
    if any(v.startswith((b"LD_PRELOAD=", b"LD_AUDIT=")) and len(v.split(b"=", 1)[1]) > 0 for v in ambiente):
        return " [con codice aggiunto: LD_PRELOAD]"
    if controllato and controllato[0].split()[1] != "0":
        return " [controllato da un altro programma]"
    return ""

def descrivi_processo(pid):
    """-> (chiave della regola, nome da mostrare, percorso del programma)"""
    d = descrivi_processo_base(pid)
    if d is None:
        return None
    extra = manomesso(pid)
    return (d[0] + extra, d[1] + extra, d[2]) if extra else d

def descrivi_processo_base(pid):
    try:
        exe = os.readlink(f"/proc/{pid}/exe")
    except OSError:
        return None
    if exe.endswith(" (deleted)"):
        exe = exe[:-10]
    try:
        argomenti = [a for a in open(f"/proc/{pid}/cmdline", "rb").read().decode(errors="replace").split("\0") if a]
    except OSError:
        argomenti = []
    base = os.path.basename(exe)
    if base in WINE or "/wine/" in exe:
        prog = argomenti[0] if argomenti else exe
        return "wine:" + prog, prog.replace("\\", "/").rsplit("/", 1)[-1] + " (Windows)", prog
    nome_base = base.rstrip("0123456789.")
    if nome_base in INTERPRETI:
        script = next((a for a in argomenti[1:] if not a.startswith("-")), "")
        if script:
            return exe + " " + script, os.path.basename(script), exe + " " + script
    return exe, base, exe

# --- regole ---
class Regole:
    def __init__(self):
        self.sempre = {}            # chiave -> "permetti" / "blocca"
        self.ora = {}               # chiave -> ("permetti", None) fino al riavvio, ("blocca", scadenza)
        try:
            for r in open(REGOLE):
                r = r.rstrip("\n")
                if "\t" in r and not r.startswith("#"):
                    scelta, chiave = r.split("\t", 1)
                    if scelta in ("permetti", "blocca"):
                        self.sempre[chiave] = scelta
        except OSError:
            pass

    def decisione(self, chiave):
        if chiave in self.ora:
            scelta, scadenza = self.ora[chiave]
            if scadenza is None or time.time() < scadenza:
                return scelta
            del self.ora[chiave]
        return self.sempre.get(chiave)

    def salva(self):
        os.makedirs(CARTELLA, exist_ok=True)
        tmp = REGOLE + ".nuovo"
        with open(tmp, "w") as f:
            f.write("# Regole del Guardiano della rete: permetti/blocca <TAB> programma\n")
            for chiave in sorted(self.sempre):
                f.write(f"{self.sempre[chiave]}\t{chiave}\n")
        os.chmod(tmp, 0o644)
        os.replace(tmp, REGOLE)

# --- il guardiano ---
class Guardiano:
    def __init__(self, coda):
        self.coda = coda
        self.regole = Regole()
        self.blocco = threading.RLock()
        self.attesa = {}            # chiave -> {"id": n, "pacchetti": [...], "da": tempo}
        self.domande = 0
        self.avvisi = None          # connessione con guardiano-avvisi (o None)

    def scrivi(self, conn, oggetto):
        try:
            conn.sendall((json.dumps(oggetto) + "\n").encode())
            return True
        except OSError:
            return False

    def pacchetto(self, ident, famiglia, payload, uid):
        info = leggi_pacchetto(famiglia, payload)
        if info is None:
            self.coda.verdetto(ident, NF_ACCEPT)        # ICMP e altro: non sono programmi da controllare
            return
        proto, plocale, remoto, premota = info
        descr = None
        inode = inode_presa(proto, famiglia, plocale, premota)
        if inode:
            pid = processo_della_presa(inode)
            if pid:
                descr = descrivi_processo(pid)
        if descr is None:
            descr = (f"sconosciuto:uid {uid}", f"programma sconosciuto (utente {uid})", "?")
        chiave, nome, percorso = descr
        with self.blocco:
            d = self.regole.decisione(chiave)
            if d:
                self.coda.verdetto(ident, NF_ACCEPT if d == "permetti" else NF_DROP)
                return
            if chiave in self.attesa:
                self.attesa[chiave]["pacchetti"].append(ident)
                return
            if self.avvisi is None:
                self.coda.verdetto(ident, NF_DROP)      # nessuno puo' rispondere: bloccato
                return
            self.domande += 1
            self.attesa[chiave] = {"id": self.domande, "pacchetti": [ident], "da": time.time()}
            domanda = {"domanda": self.domande, "chiave": chiave, "nome": nome, "programma": percorso,
                       "indirizzo": remoto, "porta": premota, "protocollo": proto}
            if not self.scrivi(self.avvisi, domanda):
                self.chiudi_avvisi()

    def rispondi(self, numero, scelta):
        with self.blocco:
            chiave = next((k for k, v in self.attesa.items() if v["id"] == numero), None)
            if chiave is None:
                return
            v = self.attesa.pop(chiave)
            permetti = scelta in ("permetti_sempre", "permetti_ora")
            if scelta == "permetti_sempre":
                self.regole.sempre[chiave] = "permetti"; self.regole.salva()
            elif scelta == "blocca_sempre":
                self.regole.sempre[chiave] = "blocca"; self.regole.salva()
            elif scelta == "permetti_ora":
                self.regole.ora[chiave] = ("permetti", None)
            else:                                   # "blocca_ora" o nessuna risposta
                self.regole.ora[chiave] = ("blocca", time.time() + PAUSA)
            for ident in v["pacchetti"]:
                self.coda.verdetto(ident, NF_ACCEPT if permetti else NF_DROP)

    def scadenze(self):
        while True:
            time.sleep(1)
            with self.blocco:
                for chiave in [k for k, v in self.attesa.items() if time.time() - v["da"] > ATTESA + 5]:
                    for ident in self.attesa.pop(chiave)["pacchetti"]:
                        self.coda.verdetto(ident, NF_DROP)
                    self.regole.ora[chiave] = ("blocca", time.time() + PAUSA)

    def chiudi_avvisi(self):
        with self.blocco:
            if self.avvisi is not None:
                try:
                    self.avvisi.close()
                except OSError:
                    pass
            self.avvisi = None
            for v in self.attesa.values():          # nessuno risponde piu': bloccati
                for ident in v["pacchetti"]:
                    self.coda.verdetto(ident, NF_DROP)
            self.attesa.clear()

    def autentico(self, conn):
        """Solo i veri guardiano-avvisi e guardiano-regole (la presa e' gia' riservata al
        gruppo wheel): python3 di sistema in modo isolato (-I, niente moduli dell'utente),
        senza librerie infilate (LD_PRELOAD...) e senza un altro programma che lo controlla."""
        if os.environ.get("GUARDIANO_PROVA"):
            return True
        pid, uid, gid = struct.unpack("3i", conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
        try:
            argomenti = open(f"/proc/{pid}/cmdline", "rb").read().split(b"\0")
            exe = os.readlink(f"/proc/{pid}/exe")
            ambiente = open(f"/proc/{pid}/environ", "rb").read().split(b"\0")
            controllato = [r for r in open(f"/proc/{pid}/status") if r.startswith("TracerPid:")]
        except OSError:
            return False
        if os.path.dirname(exe) not in ("/usr/bin", "/usr/local/bin") \
                or not os.path.basename(exe).startswith("python3"):
            return False
        if len(argomenti) < 3 or argomenti[1] != b"-I" \
                or argomenti[2].decode(errors="replace") not in AMMESSI:
            return False
        if any(v.startswith((b"LD_PRELOAD=", b"LD_LIBRARY_PATH=", b"LD_AUDIT=")) for v in ambiente):
            return False
        return bool(controllato) and controllato[0].split()[1] == "0"

    def servi(self, conn):
        if not self.autentico(conn):
            conn.close(); return
        e_avvisi = False
        resto = b""
        try:
            while True:
                dati = conn.recv(65536)
                if not dati:
                    break
                resto += dati
                while b"\n" in resto:
                    riga, resto = resto.split(b"\n", 1)
                    try:
                        m = json.loads(riga)
                    except ValueError:
                        continue
                    if m.get("ciao") == "avvisi":
                        with self.blocco:
                            if self.avvisi is not None:
                                self.chiudi_avvisi()
                            self.avvisi = conn; e_avvisi = True
                    elif "risposta" in m:
                        self.rispondi(int(m["risposta"]), str(m.get("scelta")))
                    elif m.get("comando") == "regole":
                        with self.blocco:
                            elenco = sorted(self.regole.sempre.items())
                        self.scrivi(conn, {"regole": elenco})
                    elif m.get("comando") == "elimina":
                        with self.blocco:
                            self.regole.sempre.pop(str(m.get("chiave")), None)
                            self.regole.ora.pop(str(m.get("chiave")), None)
                            self.regole.salva()
                        self.scrivi(conn, {"fatto": True})
        except OSError:
            pass
        finally:
            if e_avvisi:
                with self.blocco:
                    if self.avvisi is conn:
                        self.chiudi_avvisi()
            else:
                conn.close()

    def ascolta(self):
        try:
            os.unlink(PRESA)
        except FileNotFoundError:
            pass
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.bind(PRESA)
        try:
            import grp
            os.chown(PRESA, 0, grp.getgrnam(GRUPPO).gr_gid)
        except (KeyError, PermissionError):
            pass
        os.chmod(PRESA, 0o660)
        s.listen(5)
        while True:
            conn, _ = s.accept()
            threading.Thread(target=self.servi, args=(conn,), daemon=True).start()

def main():
    coda = Coda(CODA)
    g = Guardiano(coda)
    threading.Thread(target=g.ascolta, daemon=True).start()
    threading.Thread(target=g.scadenze, daemon=True).start()
    print(f"Guardiano della rete attivo (coda {CODA}, {len(g.regole.sempre)} regole)", flush=True)
    for ident, famiglia, payload, uid in coda.pacchetti():
        try:
            g.pacchetto(ident, famiglia, payload, uid)
        except Exception as e:          # mai lasciare un pacchetto senza risposta
            print("Errore:", e, flush=True)
            coda.verdetto(ident, NF_DROP)

if __name__ == "__main__":
    main()
EOF
cat > /usr/local/bin/guardiano-avvisi << "EOF"
#!/usr/bin/python3 -I
# Guardiano della rete - le domande sul desktop (creato da lfs.sh).
# Parte da solo all'accesso. Quando un programma vuole collegarsi a internet per
# la prima volta, mostra la finestra: Blocca / Permetti. Se non rispondi entro un
# minuto, il collegamento resta bloccato (e la domanda torna tra 10 minuti).
import ctypes, fcntl, json, os, socket, subprocess, sys, threading, time

PRESA = os.environ.get("GUARDIANO_PRESA", "/run/guardiano-rete.sock")
ATTESA = 60
COMANDO_FINESTRA = os.environ.get("GUARDIANO_FINESTRA", "yad")    # per le prove

SERVIZI = {80: "pagine web", 443: "pagine web sicure", 53: "nomi dei siti (DNS)",
           853: "nomi dei siti (DNS cifrato)", 993: "posta in arrivo", 995: "posta in arrivo",
           143: "posta in arrivo", 110: "posta in arrivo", 465: "invio posta", 587: "invio posta",
           25: "invio posta", 22: "SSH", 123: "orologio (NTP)", 9001: "rete Tor", 51820: "VPN"}

def non_ispezionabile():
    """Gli altri programmi dell'utente non possono leggere o cambiare questa memoria."""
    try:
        ctypes.CDLL(None, use_errno=True).prctl(4, 0, 0, 0, 0)      # PR_SET_DUMPABLE = 0
    except (OSError, AttributeError):
        pass

def un_solo_avvio():
    cartella = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/guardiano-{os.getuid()}"
    os.makedirs(cartella, mode=0o700, exist_ok=True)
    f = open(os.path.join(cartella, "guardiano-avvisi.lock"), "w")
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)                     # e' gia' attivo
    return f

def sicuro(t):
    return str(t).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def nome_del_sito(indirizzo, fuori):
    try:
        fuori.append(socket.gethostbyaddr(indirizzo)[0])
    except (OSError, UnicodeError):
        pass

def notifica(testo):
    try:
        subprocess.Popen(["notify-send", "-a", "Guardiano della rete", "-i", "security-low",
                          "Guardiano della rete", testo], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass

def chiedi(d, conn, blocco):
    sito = []
    t = threading.Thread(target=nome_del_sito, args=(d.get("indirizzo", ""), sito), daemon=True)
    t.start(); t.join(1.5)
    porta = d.get("porta", 0)
    servizio = SERVIZI.get(porta)
    destinazione = sicuro(d.get("indirizzo", "?")) + (f"  ({sicuro(sito[0])})" if sito else "")
    testo = (f"<b><big>{sicuro(d.get('nome', '?'))}</big></b> vuole collegarsi a internet.\n\n"
             f"Programma:  {sicuro(d.get('programma', '?'))}\n"
             f"Verso:  {destinazione}\n"
             f"Porta:  {porta} {sicuro(d.get('protocollo', '')).upper()}"
             + (f" ({servizio})" if servizio else "") +
             "\n\nLo lasci collegare?")
    comando = [COMANDO_FINESTRA, "--title", "Guardiano della rete", "--window-icon", "security-high",
               "--image", "security-medium", "--text", testo,
               "--button", "Blocca sempre:3", "--button", "Blocca:1",
               "--button", "Permetti fino al riavvio:2", "--button", "Permetti sempre:0",
               "--timeout", str(ATTESA), "--timeout-indicator", "bottom",
               "--center", "--on-top", "--fixed", "--width", "560"]
    try:
        r = subprocess.run(comando, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
    except OSError:
        r = 1
    scelta = {0: "permetti_sempre", 2: "permetti_ora", 3: "blocca_sempre"}.get(r, "blocca_ora")
    try:
        with blocco:
            conn.sendall((json.dumps({"risposta": d["domanda"], "scelta": scelta}) + "\n").encode())
    except (OSError, KeyError):
        pass

def principale():
    non_ispezionabile()
    blocco_avvio = un_solo_avvio()
    avvisato = False
    time.sleep(2)                       # le notifiche partono insieme al desktop
    while True:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.connect(PRESA)
            s.sendall(b'{"ciao": "avvisi"}\n')
        except OSError:
            s.close()
            if not avvisato:
                notifica("Il guardiano non e' attivo: per sicurezza i programmi non possono "
                         "collegarsi a internet. Riavvia il computer.")
                avvisato = True
            time.sleep(5)
            continue
        avvisato = False
        blocco = threading.Lock()
        try:
            for riga in s.makefile("rb"):
                try:
                    d = json.loads(riga)
                except ValueError:
                    continue
                if "domanda" in d:
                    threading.Thread(target=chiedi, args=(d, s, blocco), daemon=True).start()
        except OSError:
            pass
        s.close()
        time.sleep(1)

if __name__ == "__main__":
    principale()
EOF
cat > /usr/local/bin/guardiano-regole << "EOF"
#!/usr/bin/python3 -I
# Regole della rete (creato da lfs.sh): i programmi che hai permesso o bloccato
# "per sempre". Eliminando una regola, la prossima volta il guardiano chiede di nuovo.
import json, os, socket, subprocess, sys

PRESA = os.environ.get("GUARDIANO_PRESA", "/run/guardiano-rete.sock")
TITOLO = "Regole della rete"
SEP = "\x1e"

def parla(messaggio):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(PRESA)
    s.sendall((json.dumps(messaggio) + "\n").encode())
    risposta = s.makefile("rb").readline()
    s.close()
    return json.loads(risposta)

def finestra(*argomenti):
    return subprocess.run(["yad", "--title", TITOLO, "--window-icon", "security-high", "--center"] + list(argomenti),
                          stdout=subprocess.PIPE, text=True)

def nome_leggibile(chiave):
    if chiave.startswith("wine:"):
        return chiave[5:] + "  (Windows)"
    if chiave.startswith("sconosciuto:"):
        return "programma sconosciuto"
    return chiave

def principale():
    while True:
        try:
            regole = parla({"comando": "regole"})["regole"]
        except (OSError, ValueError, KeyError):
            finestra("--image", "dialog-error", "--text", "Il guardiano della rete non risponde.",
                     "--button", "OK:0", "--fixed", "--width", "380")
            sys.exit(1)
        if not regole:
            finestra("--image", "security-high", "--fixed", "--width", "420", "--button", "OK:0",
                     "--text", "<b>Nessuna regola salvata.</b>\n\nQuando un programma vuole collegarsi "
                               "a internet, ti viene chiesto se permetterlo.")
            return
        righe = []
        for chiave, scelta in regole:
            righe += ["Permesso" if scelta == "permetti" else "Bloccato", nome_leggibile(chiave), chiave]
        r = finestra("--list", "--width", "760", "--height", "420", "--image", "security-high",
                     "--text", "Programmi che hai permesso o bloccato per sempre.\n"
                               "Scegline uno e premi <b>Elimina</b>: la prossima volta ti verra' chiesto di nuovo.",
                     "--column", "Scelta", "--column", "Programma", "--column", "chiave:HD",
                     "--print-column", "3", "--separator", SEP,
                     "--button", "Chiudi:1", "--button", "Elimina la regola:0", *righe)
        if r.returncode != 0:
            return
        chiave = r.stdout.rstrip("\n").rstrip(SEP)
        if chiave:
            try:
                parla({"comando": "elimina", "chiave": chiave})
            except (OSError, ValueError):
                pass

if __name__ == "__main__":
    principale()
EOF
chmod 755 /usr/local/sbin/firewall-avvia /usr/local/sbin/guardiano-rete \
          /usr/local/bin/guardiano-avvisi /usr/local/bin/guardiano-regole
cat > /etc/systemd/system/firewall.service << "EOF"
[Unit]
Description=Firewall (lfs.sh): niente collegamenti da fuori, uscite controllate dal Guardiano
DefaultDependencies=no
After=local-fs.target systemd-sysctl.service
Before=network-pre.target shutdown.target
Wants=network-pre.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/firewall-avvia

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/guardiano-rete.service << "EOF"
[Unit]
Description=Guardiano della rete (chiede prima di lasciar uscire un programma)
After=firewall.service
Wants=firewall.service

[Service]
ExecStart=/usr/local/sbin/guardiano-rete
Restart=always
RestartSec=1
NoNewPrivileges=yes
ProtectSystem=full
ReadWritePaths=/etc/guardiano-rete
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
cat > /usr/share/applications/guardiano-regole.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Regole della rete
Comment=I programmi a cui hai permesso o bloccato internet
Exec=/usr/local/bin/guardiano-regole
Icon=security-high
Terminal=false
Categories=System;Security;
EOF
# Tor Browser e' il browser scelto per questo sistema: il suo collegamento alla rete Tor
# e' gia' permesso (gli altri programmi chiedono la prima volta)
[ -f /etc/guardiano-rete/regole ] \
  || echo "# Regole del Guardiano della rete: permetti/blocca <TAB> programma" > /etc/guardiano-rete/regole
for t in /opt/tor-browser/Browser/TorBrowser/Tor/tor \
         /opt/tor-browser/Browser/TorBrowser/Tor/PluggableTransports/lyrebird \
         /opt/tor-browser/Browser/TorBrowser/Tor/PluggableTransports/conjure-client; do
  grep -qF "$(printf 'permetti\t%s' "$t")" /etc/guardiano-rete/regole \
    || printf 'permetti\t%s\n' "$t" >> /etc/guardiano-rete/regole
done
chmod 644 /etc/guardiano-rete/regole
# controlli: gli script si leggono senza errori
bash -n /usr/local/sbin/firewall-avvia
for t in /usr/local/sbin/guardiano-rete /usr/local/bin/guardiano-avvisi /usr/local/bin/guardiano-regole; do
  python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$t"
done
systemctl enable firewall.service guardiano-rete.service
echo "[OK] Firewall e Guardiano della rete pronti (partono all'accensione)"
}

f6_cassaforte() {
# NON IN BLFS: la cassaforte, una cartella cifrata (~/Cassaforte) che si apre con una password
mkdir -p /usr/local/bin
cat > /usr/local/bin/cassaforte << "EOF"
#!/usr/bin/python3 -I
# Cassaforte (creata da lfs.sh): una cartella cifrata che si apre con una password.
# Usa la cifratura del file system ext4 (fscrypt, criteri versione 2, AES-256):
# quando e' chiusa, i file e i loro nomi sul disco sono illeggibili.
#   cassaforte            apre o chiude (con le finestre)
#   cassaforte crea|apri|chiudi|stato
# Per le prove senza finestre: CASSAFORTE_PASSWORD=... e CASSAFORTE_CARTELLA=...
import array, fcntl, hashlib, json, os, re, struct, subprocess, sys, urllib.parse

CASA = os.path.expanduser("~")
CARTELLA = os.environ.get("CASSAFORTE_CARTELLA", os.path.join(CASA, "Cassaforte"))
CONFIG = os.path.join(CASA, ".config", "cassaforte.json")
TITOLO = "Cassaforte"

# --- linux/fscrypt.h ---
FS_IOC_SET_ENCRYPTION_POLICY = 0x800C6613
FS_IOC_GET_ENCRYPTION_POLICY_EX = 0xC0096616
FS_IOC_ADD_ENCRYPTION_KEY = 0xC0506617
FS_IOC_REMOVE_ENCRYPTION_KEY = 0xC0406618
FS_IOC_GET_ENCRYPTION_KEY_STATUS = 0xC080661A
SPEC_IDENTIFICATORE = 2
STATO_ASSENTE, STATO_PRESENTE, STATO_RIMOSSA_IN_PARTE = 1, 2, 3
FILE_IN_USO = 0x1

def specifica(ident):
    return struct.pack("=II32s", SPEC_IDENTIFICATORE, 0, ident)

def chiave_da_password(password, sale):
    return hashlib.scrypt(password.encode(), salt=sale, n=2 ** 17, r=8, p=1,
                          maxmem=256 * 1024 * 1024, dklen=64)

# Le chiavi si aggiungono e si tolgono attraverso la cartella che CONTIENE la cassaforte:
# tenere aperta la cassaforte stessa la farebbe sembrare "in uso" e non si chiuderebbe.
def fuori(cartella):
    return os.path.dirname(os.path.abspath(cartella))

def aggiungi_chiave(cartella, chiave):
    buf = bytearray(specifica(b"") + struct.pack("=II32x", len(chiave), 0) + chiave)
    fd = os.open(fuori(cartella), os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.ioctl(fd, FS_IOC_ADD_ENCRYPTION_KEY, buf, True)
    finally:
        os.close(fd)
    return bytes(buf[8:24])

def togli_chiave(cartella, ident):
    buf = bytearray(specifica(ident) + bytes(24))
    fd = os.open(fuori(cartella), os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.ioctl(fd, FS_IOC_REMOVE_ENCRYPTION_KEY, buf, True)
    finally:
        os.close(fd)
    return struct.unpack_from("=I", buf, 40)[0]

def stato_chiave(cartella, ident):
    buf = bytearray(specifica(ident) + bytes(88))
    fd = os.open(fuori(cartella), os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.ioctl(fd, FS_IOC_GET_ENCRYPTION_KEY_STATUS, buf, True)
    finally:
        os.close(fd)
    return struct.unpack_from("=I", buf, 64)[0]

def imposta_cifratura(cartella, ident):
    # versione 2, contenuti AES-256-XTS, nomi AES-256-CTS, riempimento dei nomi a 32 byte
    criterio = bytearray(struct.pack("=BBBBB3x16s", 2, 1, 4, 0x03, 0, ident))
    fd = os.open(cartella, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.ioctl(fd, FS_IOC_SET_ENCRYPTION_POLICY, criterio, True)
    finally:
        os.close(fd)

def cifrata_con(cartella):
    """-> identificatore della chiave della cartella, oppure None se non e' cifrata"""
    buf = bytearray(struct.pack("=Q", 24) + bytes(24))
    fd = os.open(cartella, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.ioctl(fd, FS_IOC_GET_ENCRYPTION_POLICY_EX, buf, True)
    except OSError:
        return None
    finally:
        os.close(fd)
    return bytes(buf[16:32]) if buf[8] == 2 else None

# --- finestre (yad) oppure terminale ---
GRAFICA = bool(os.environ.get("WAYLAND_DISPLAY") or os.environ.get("DISPLAY")) \
    and not os.environ.get("CASSAFORTE_PASSWORD")

def avviso(testo, icona="dialog-information"):
    if GRAFICA:
        subprocess.run(["yad", "--title", TITOLO, "--window-icon", "changes-prevent", "--image", icona,
                        "--text", testo, "--button", "OK:0", "--center", "--fixed", "--width", "420"])
    else:
        print(re.sub(r"<[^>]+>", "", testo))

def errore(testo):
    avviso(testo, "dialog-error")
    sys.exit(1)

def domanda(testo, si, no):
    if not GRAFICA:
        return True
    r = subprocess.run(["yad", "--title", TITOLO, "--window-icon", "changes-prevent", "--image", "dialog-question",
                        "--text", testo, "--button", f"{no}:1", "--button", f"{si}:0",
                        "--center", "--fixed", "--width", "420"])
    return r.returncode == 0

def chiedi_password(testo):
    if not GRAFICA:
        p = os.environ.get("CASSAFORTE_PASSWORD")
        if p is None:
            import getpass
            p = getpass.getpass(re.sub(r"<[^>]+>", "", testo) + " ")
        return p
    r = subprocess.run(["yad", "--title", TITOLO, "--window-icon", "changes-prevent", "--image", "dialog-password",
                        "--text", testo, "--entry", "--hide-text", "--button", "Annulla:1", "--button", "OK:0",
                        "--center", "--fixed", "--width", "420"], stdout=subprocess.PIPE, text=True)
    if r.returncode != 0:
        sys.exit(0)
    return r.stdout.rstrip("\n")

def apri_in_thunar():
    if GRAFICA:
        subprocess.Popen(["thunar", CARTELLA], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# --- impostazioni salvate (sale e identificatore: non sono segreti) ---
def leggi_config():
    try:
        c = json.load(open(CONFIG))
        return {"cartella": c["cartella"], "sale": bytes.fromhex(c["sale"]),
                "identificatore": bytes.fromhex(c["identificatore"])}
    except (OSError, ValueError, KeyError):
        return None

def salva_config(sale, ident):
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    tmp = CONFIG + ".nuovo"
    with open(tmp, "w") as f:
        json.dump({"cartella": CARTELLA, "sale": sale.hex(), "identificatore": ident.hex()}, f)
    os.chmod(tmp, 0o600)
    os.replace(tmp, CONFIG)

def stato():
    c = leggi_config()
    if c is None or not os.path.isdir(c["cartella"]):
        return "non creata", c
    try:
        s = stato_chiave(c["cartella"], c["identificatore"])
    except OSError:
        return "chiusa", c
    return {STATO_PRESENTE: "aperta", STATO_RIMOSSA_IN_PARTE: "file aperti"}.get(s, "chiusa"), c

# --- comandi ---
def crea():
    if leggi_config() is not None:
        errore("La cassaforte esiste gia'.")
    if os.path.exists(CARTELLA) and os.listdir(CARTELLA):
        errore(f"La cartella {CARTELLA} esiste gia' e non e' vuota: spostala o rinominala, poi riprova.")
    if not domanda("<b>Crea la cassaforte</b>\n\nSara' la cartella <b>Cassaforte</b> nella tua cartella home. "
                   "Quando e' chiusa, nessuno puo' leggere i file che ci metti, neanche "
                   "togliendo il disco dal computer.\n\n"
                   "<b>Attenzione:</b> se dimentichi la password, i file NON si possono recuperare.",
                   "Crea", "Annulla"):
        return
    while True:
        p1 = chiedi_password("Scegli la password della cassaforte (almeno 8 caratteri):")
        if len(p1) < 8:
            avviso("La password e' troppo corta: usa almeno 8 caratteri.", "dialog-warning")
            if not GRAFICA:
                sys.exit(1)
            continue
        p2 = chiedi_password("Riscrivi la password:")
        if p1 == p2:
            break
        avviso("Le due password sono diverse, riprova.", "dialog-warning")
        if not GRAFICA:
            sys.exit(1)
    os.makedirs(CARTELLA, mode=0o700, exist_ok=True)
    os.chmod(CARTELLA, 0o700)
    sale = os.urandom(16)
    try:
        ident = aggiungi_chiave(CARTELLA, chiave_da_password(p1, sale))
        imposta_cifratura(CARTELLA, ident)
    except OSError as e:
        if e.errno in (95, 25):          # EOPNOTSUPP / ENOTTY: disco senza cifratura
            errore("Il disco non permette la cifratura (manca l'opzione 'encrypt' di ext4).")
        errore(f"Non sono riuscito a creare la cassaforte: {e.strerror}")
    salva_config(sale, ident)
    avviso("<b>Cassaforte creata e aperta.</b>\n\nMetti i file nella cartella <b>Cassaforte</b>. "
           "Quando hai finito chiudila dal menu (<i>Chiudi la cassaforte</i>): "
           "si chiude anche spegnendo il computer.")
    apri_in_thunar()

def apri():
    s, c = stato()
    if s == "non creata":
        return crea()
    if s == "aperta":
        apri_in_thunar(); return
    for tentativo in range(3):
        p = chiedi_password("<b>Apri la cassaforte</b>\n\nScrivi la password:")
        chiave = chiave_da_password(p, c["sale"])
        ident = aggiungi_chiave(c["cartella"], chiave)
        if ident == c["identificatore"]:
            if not GRAFICA:
                print("Cassaforte aperta.")
            apri_in_thunar(); return
        try:
            togli_chiave(c["cartella"], ident)    # chiave sbagliata: si toglie subito
        except OSError:
            pass
        if not GRAFICA:
            errore("Password sbagliata.")
        avviso("Password sbagliata, riprova.", "dialog-warning")
    errore("Password sbagliata.")

def pulisci_tracce(cartella):
    """Toglie le anteprime delle immagini e i 'file recenti' che parlano della cassaforte."""
    sumi = set()
    for radice, cartelle, file in os.walk(cartella):
        for nome in file + cartelle:
            uri = "file://" + urllib.parse.quote(os.path.join(radice, nome), safe="/!$&'()*+,;=:@-._~")
            sumi.add(hashlib.md5(uri.encode()).hexdigest())
    base = os.path.join(CASA, ".cache", "thumbnails")
    for radice, _, file in os.walk(base):
        for f in file:
            if f[:-4] in sumi:
                try:
                    os.unlink(os.path.join(radice, f))
                except OSError:
                    pass
    recenti = os.path.join(CASA, ".local", "share", "recently-used.xbel")
    try:
        testo = open(recenti).read()
        prefisso = re.escape("file://" + urllib.parse.quote(cartella, safe="/!$&'()*+,;=:@-._~") + "/")
        nuovo = re.sub(r'\s*<bookmark href="' + prefisso + r'.*?</bookmark>', "", testo, flags=re.S)
        if nuovo != testo:
            open(recenti, "w").write(nuovo)
    except OSError:
        pass

def chiudi():
    s, c = stato()
    if s == "non creata":
        errore("La cassaforte non c'e' ancora: aprila dal menu per crearla.")
    if s == "chiusa":
        avviso("La cassaforte e' gia' chiusa."); return
    pulisci_tracce(c["cartella"])
    os.sync()
    flag = togli_chiave(c["cartella"], c["identificatore"])
    if flag & FILE_IN_USO or stato_chiave(c["cartella"], c["identificatore"]) == STATO_RIMOSSA_IN_PARTE:
        errore("Alcuni file della cassaforte sono ancora aperti in un programma: chiudi quei programmi "
               "e poi chiudi di nuovo la cassaforte.")
    avviso("<b>Cassaforte chiusa.</b>\n\nI file sono cifrati: per rivederli, apri la cassaforte dal menu.")

def principale():
    comando = sys.argv[1] if len(sys.argv) > 1 else ""
    if comando == "stato":
        print(stato()[0]); return
    if comando == "crea":
        return crea()
    if comando == "apri":
        return apri()
    if comando == "chiudi":
        return chiudi()
    s, _ = stato()
    if s in ("aperta", "file aperti") and GRAFICA:
        r = subprocess.run(["yad", "--title", TITOLO, "--window-icon", "changes-prevent", "--image", "folder-open",
                            "--text", "<b>La cassaforte e' aperta.</b>", "--button", "Chiudila:2",
                            "--button", "Mostra i file:0", "--center", "--fixed", "--width", "380"])
        if r.returncode == 2:
            return chiudi()
        if r.returncode == 0:
            apri_in_thunar()
        return
    return apri()

if __name__ == "__main__":
    principale()
EOF
chmod 755 /usr/local/bin/cassaforte
python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/bin/cassaforte
cat > /usr/share/applications/cassaforte.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Cassaforte
Comment=La cartella cifrata: si apre con la tua password
Exec=/usr/local/bin/cassaforte
Icon=changes-prevent
Terminal=false
Categories=Utility;Security;
EOF
cat > /usr/share/applications/cassaforte-chiudi.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Chiudi la cassaforte
Comment=Cifra di nuovo la cartella Cassaforte
Exec=/usr/local/bin/cassaforte chiudi
Icon=system-lock-screen
Terminal=false
Categories=Utility;Security;
EOF
echo "[OK] Cassaforte pronta (menu Applicazioni -> Cassaforte)"
}

f6_vpn() {
# NON IN BLFS: la VPN WireGuard facile e il benvenuto al primo accesso
#   vpn-aiuto   (root, con sudo senza password solo per questo) importa il file, accende, spegne
#   vpn         la finestra per l'utente (menu: VPN)
#   benvenuto   al primo accesso: hai una VPN? se no ti propone Mullvad
command -v wg-quick >/dev/null || { echo "Manca wg-quick"; return 1; }
mkdir -p /usr/local/sbin /usr/local/bin
install -vdm700 /etc/wireguard
cat > /usr/local/sbin/vpn-aiuto << "EOF"
#!/usr/bin/python3 -I
# Aiutante della VPN (creato da lfs.sh). Gira come root (con sudo, senza password
# per il gruppo wheel) e sa fare solo queste cose:
#   vpn-aiuto importa < file.conf   controlla il file WireGuard e lo salva
#   vpn-aiuto accendi | spegni | stato
#   vpn-aiuto su | giu              (li usa il servizio vpn.service)
# Con la VPN accesa i programmi dell'utente possono uscire SOLO dalla VPN: se la VPN
# cade, restano senza internet invece di mostrare il tuo vero indirizzo IP.
import os, re, subprocess, sys

CARTELLA = os.environ.get("VPN_CARTELLA", "/etc/wireguard")
CONF = os.path.join(CARTELLA, "vpn.conf")
SEMPRE = os.path.join(CARTELLA, "sempre-accesa")
SCHEDA = "vpn"
os.environ["PATH"] = "/usr/bin:/usr/sbin"

# solo queste voci passano: niente PostUp/PreDown (sono comandi che girerebbero come root)
AMMESSE = {
    "Interface": {"privatekey": "PrivateKey", "address": "Address", "dns": "DNS", "mtu": "MTU",
                  "listenport": "ListenPort"},
    "Peer": {"publickey": "PublicKey", "presharedkey": "PresharedKey", "allowedips": "AllowedIPs",
             "endpoint": "Endpoint", "persistentkeepalive": "PersistentKeepalive"},
}
CHIAVE = re.compile(r"[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=")
VALORE = re.compile(r"[A-Za-z0-9+/=.,:\[\]_ -]{1,300}")

def pulisci(testo):
    sezione, righe, peer = None, [], 0
    visto = set()
    for r in testo.splitlines():
        r = r.split("#", 1)[0].strip()
        if not r:
            continue
        m = re.fullmatch(r"\[\s*(\w+)\s*\]", r)
        if m:
            sezione = next((s for s in AMMESSE if s.lower() == m.group(1).lower()), None)
            if sezione is None:
                raise ValueError(f"sezione sconosciuta [{m.group(1)}]")
            if sezione == "Interface" and "Interface" in visto:
                raise ValueError("ci sono due sezioni [Interface]")
            peer += sezione == "Peer"
            visto.add(sezione)
            righe.append(f"\n[{sezione}]")
            continue
        if sezione is None or "=" not in r:
            raise ValueError("il file non e' nel formato WireGuard")
        nome, valore = (x.strip() for x in r.split("=", 1))
        nome = AMMESSE[sezione].get(nome.lower())
        if nome is None:
            continue                                    # PostUp, PreDown, Table...: scartati
        if not VALORE.fullmatch(valore):
            raise ValueError(f"valore non valido per {nome}")
        if nome in ("PrivateKey", "PublicKey", "PresharedKey") and not CHIAVE.fullmatch(valore):
            raise ValueError(f"chiave non valida ({nome})")
        visto.add(nome)
        righe.append(f"{nome} = {valore}")
    for necessario in ("Interface", "PrivateKey", "Address", "Peer", "PublicKey", "Endpoint", "AllowedIPs"):
        if necessario not in visto:
            raise ValueError(f"manca {necessario}: non e' un file WireGuard completo")
    return "# VPN WireGuard (importata da vpn-aiuto)\n" + "\n".join(righe).lstrip("\n") + "\n"

def comando(*c, muto=False):
    try:
        return subprocess.run(c, stdout=subprocess.DEVNULL if muto else None,
                              stderr=subprocess.DEVNULL if muto else None).returncode == 0
    except OSError:
        return False

def accesa():
    return comando("ip", "link", "show", SCHEDA, muto=True)

def blocco_fuori_vpn(attivo):
    """La catena VPN del firewall (vedi firewall-avvia): piena = i programmi dell'utente
    escono solo dalla VPN; vuota = escono normalmente."""
    for prog in ("iptables", "ip6tables"):
        comando(prog, "-N", "VPN", muto=True)
        comando(prog, "-F", "VPN")
        if attivo:
            comando(prog, "-A", "VPN", "-m", "owner", "--uid-owner", "1000-59999",
                    "!", "-o", SCHEDA, "-j", "REJECT")

def su():
    if not os.path.exists(CONF):
        print("La VPN non e' configurata"); return False
    if os.path.exists(SEMPRE):
        blocco_fuori_vpn(True)
    if not accesa() and not comando("wg-quick", "up", SCHEDA):
        return False
    comando("resolvectl", "dnsovertls", SCHEDA, "no", muto=True)   # i DNS della VPN sono dentro la VPN
    return True

def giu():
    if accesa():
        comando("wg-quick", "down", SCHEDA)
    return True

def accendi():
    if not os.path.exists(CONF):
        print("La VPN non e' configurata: prima scegli il file"); return False
    open(SEMPRE, "w").close()
    blocco_fuori_vpn(True)
    comando("systemctl", "enable", "vpn.service", muto=True)
    comando("systemctl", "restart", "vpn.service")
    if accesa():
        return True
    print("La VPN non si accende: la spengo, internet resta senza VPN")
    spegni()
    return False

def spegni():
    try:
        os.unlink(SEMPRE)
    except FileNotFoundError:
        pass
    comando("systemctl", "disable", "--now", "vpn.service", muto=True)
    giu()
    blocco_fuori_vpn(False)
    return True

def importa():
    testo = sys.stdin.read(65536)
    try:
        nuovo = pulisci(testo)
    except (ValueError, UnicodeError) as e:
        print(e); return False
    os.makedirs(CARTELLA, mode=0o700, exist_ok=True)
    tmp = CONF + ".nuovo"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(nuovo)
    os.replace(tmp, CONF)
    if accesa():                          # gia' accesa: riparte con il file nuovo
        giu(); su()
    return True

def stato():
    print("non configurata" if not os.path.exists(CONF) else "accesa" if accesa() else "spenta")
    return True

AZIONI = {"importa": importa, "accendi": accendi, "spegni": spegni, "stato": stato, "su": su, "giu": giu}

if __name__ == "__main__":
    if os.geteuid() != 0:
        sys.exit("Serve root: usa  sudo vpn-aiuto ...")
    if len(sys.argv) != 2 or sys.argv[1] not in AZIONI:
        sys.exit("Uso: vpn-aiuto importa|accendi|spegni|stato|su|giu")
    sys.exit(0 if AZIONI[sys.argv[1]]() else 1)
EOF
cat > /usr/local/bin/vpn << "EOF"
#!/bin/bash
# VPN (creato da lfs.sh): accendi, spegni o configura la VPN WireGuard.
#   vpn             finestra con lo stato e i pulsanti
#   vpn configura   scegli il file .conf della tua VPN e accendila
AIUTO=/usr/local/sbin/vpn-aiuto
finestra() { yad --title "VPN" --window-icon network-vpn --center --fixed --width 480 "$@"; }

accendi() {
  local msg
  if msg=$(sudo -n "$AIUTO" accendi 2>&1); then
    finestra --image network-vpn --button OK:0 --text "<b>VPN accesa.</b>

Ora i siti vedono l'indirizzo IP della VPN, non il tuo.
Resta accesa anche dopo un riavvio. Se la VPN si interrompe, i tuoi programmi
restano senza internet (cosi' il tuo vero indirizzo non si vede mai).

Per spegnerla: menu Applicazioni -> <b>VPN</b>."
  else
    finestra --image dialog-error --button OK:0 --text "<b>La VPN non si accende.</b>

Controlla di essere collegato a internet e che il file della VPN sia ancora valido
(l'abbonamento e' attivo?). Internet funziona normalmente, senza VPN.

<small>$(printf '%s' "$msg" | tail -n 3 | sed 's/&/\&amp;/g; s/</\&lt;/g')</small>"
    return 1
  fi
}

configura() {
  local file msg
  file=$(finestra --file --width 760 --height 520 \
           --text "Scegli il file di configurazione <b>WireGuard</b> della tua VPN (finisce con <b>.conf</b>)." \
           --file-filter "File WireGuard (.conf) | *.conf" --file-filter "Tutti i file | *") || return 1
  [ -f "$file" ] || return 1
  if ! msg=$(sudo -n "$AIUTO" importa < "$file" 2>&1); then
    finestra --image dialog-error --button OK:0 --text "<b>Questo file non va bene.</b>

$(printf '%s' "$msg" | sed 's/&/\&amp;/g; s/</\&lt;/g')

Serve il file di configurazione WireGuard che ti da' la tua VPN."
    return 1
  fi
  accendi
}

if [ "${1:-}" = configura ]; then configura; exit; fi

stato=$(sudo -n "$AIUTO" stato 2>/dev/null) || stato="non configurata"
case "$stato" in
  accesa)
    finestra --image network-vpn --text "<b>La VPN e' accesa.</b>  Il tuo indirizzo IP e' nascosto." \
             --button "Cambia file:2" --button "Spegnila:3" --button "Chiudi:0"
    case $? in
      3) sudo -n "$AIUTO" spegni >/dev/null 2>&1
         finestra --image dialog-warning --button OK:0 \
                  --text "<b>VPN spenta.</b>  Ora i siti vedono il tuo vero indirizzo IP." ;;
      2) configura ;;
    esac ;;
  spenta)
    finestra --image dialog-warning --text "<b>La VPN e' spenta.</b>  I siti vedono il tuo vero indirizzo IP." \
             --button "Cambia file:2" --button "Chiudi:1" --button "Accendila:0"
    case $? in
      0) accendi ;;
      2) configura ;;
    esac ;;
  *)
    finestra --image network-vpn --button "Annulla:1" --button "Scegli il file:0" --text "<b>La VPN non e' ancora configurata.</b>

Ti serve il file di configurazione WireGuard (.conf) della tua VPN.
Con Mullvad: sul sito, nel tuo account, <i>WireGuard configuration</i> -> scarica il file." \
      && configura ;;
esac
EOF
cat > /usr/local/bin/benvenuto << "EOF"
#!/bin/bash
# Benvenuto (creato da lfs.sh): al primo accesso propone la VPN per nascondere l'indirizzo IP.
#   Hai gia' una VPN?  si' -> scegli il file e si accende
#                      no  -> ti consigliamo Mullvad (oppure continui senza VPN)
SEGNO="$HOME/.config/benvenuto-fatto"
[ -e "$SEGNO" ] && exit 0
mkdir -p "$HOME/.config"
sleep 4                                   # il desktop finisce di partire
NOME=$( . /etc/os-release 2>/dev/null; echo "${NAME:-la tua distro}" )
finestra() { yad --title "Benvenuto" --window-icon security-high --center --fixed --width 540 "$@"; }

finestra --image security-high --button "No:1" --button "Si', ce l'ho:0" --text "<big><b>Benvenuto in $NOME!</b></big>

Per nascondere il tuo <b>indirizzo IP</b> (cioe' da dove ti colleghi) puoi usare una <b>VPN</b>.
Per navigare senza farti riconoscere c'e' gia' <b>Tor Browser</b>, il browser predefinito.

Hai gia' un abbonamento a una VPN che usa <b>WireGuard</b>?"
risposta=$?
touch "$SEGNO"
case $risposta in
  0)
    /usr/local/bin/vpn configura ;;
  1)
    finestra --image network-vpn --button "No, continua senza VPN:1" --button "Apri il sito di Mullvad:0" --text "<b>Ti consigliamo Mullvad VPN</b>

  - circa 5 euro al mese, senza contratto
  - non chiede email, nome o numero di telefono
  - non tiene registri di cosa fai su internet
  - funziona con WireGuard, gia' pronto in questo sistema

Vuoi aprire il sito di Mullvad?"
    if [ $? -eq 0 ]; then
      xdg-open "https://mullvad.net/it/account/create" >/dev/null 2>&1 &
      finestra --image dialog-information --button OK:0 --text "<b>Come fare</b>

1. Sul sito crea l'account (ti da' un numero: <b>conservalo</b>) e paga.
2. Nel tuo account apri <i>WireGuard configuration</i>, premi <i>Generate key</i>,
   scegli il Paese e scarica il file <b>.conf</b>.
3. Apri il menu Applicazioni -> <b>VPN</b> e scegli quel file.

Puoi farlo anche piu' tardi: intanto continui senza VPN."
    fi ;;
esac
exit 0
EOF
chmod 755 /usr/local/sbin/vpn-aiuto /usr/local/bin/vpn /usr/local/bin/benvenuto
python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/sbin/vpn-aiuto
bash -n /usr/local/bin/vpn
bash -n /usr/local/bin/benvenuto
cat > /etc/systemd/system/vpn.service << "EOF"
[Unit]
Description=VPN WireGuard (lfs.sh)
After=network-online.target firewall.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/vpn-aiuto su
ExecStop=/usr/local/sbin/vpn-aiuto giu

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/sudoers.d/20-vpn << "EOF"
# Creato da lfs.sh: chi e' nel gruppo wheel accende e spegne la VPN senza password
# (solo questo comando, che accetta solo file WireGuard controllati)
%wheel ALL=(root) NOPASSWD: /usr/local/sbin/vpn-aiuto
EOF
chmod 440 /etc/sudoers.d/20-vpn
visudo -c
cat > /usr/share/applications/vpn.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=VPN
Comment=Nascondi il tuo indirizzo IP: accendi, spegni o configura la VPN
Exec=/usr/local/bin/vpn
Icon=network-vpn
Terminal=false
Categories=Network;Security;
EOF
echo "[OK] VPN pronta (al primo accesso ti chiede se hai un abbonamento)"
}

f6_bubblewrap() {
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
}

f6_recinto_wine() {
# NON IN BLFS: il recinto per i programmi Windows. Il comando "wine" (e winecfg,
# regedit, msiexec...) in /usr/local/bin fa girare Wine dentro bubblewrap: i
# programmi Windows vedono solo il disco C: (~/.wine) e la cartella ~/Windows.
# Il Wine vero resta in /usr/bin (i comandi del sistema usano quello).
[ -x /usr/bin/bwrap ] || { echo "Manca bubblewrap"; return 1; }
[ -x /usr/bin/wine ] || { echo "Manca Wine (Fase 3)"; return 1; }
mkdir -p /usr/local/bin /usr/local/lib/wine-recinto
cat > /usr/local/bin/wine << "EOF"
#!/usr/bin/python3 -I
# Programmi Windows nel recinto (creato da lfs.sh).
# Questo comando prende il posto di "wine" (e di winecfg, regedit, msiexec...): i
# programmi Windows girano in una zona chiusa (bubblewrap) dove vedono SOLO:
#   - il loro disco C: (~/.wine), dove si installano
#   - la cartella ~/Windows, che e' la cartella "utente" di Windows (Documenti,
#     Desktop, Download...): li' metti i file da aprire con un programma Windows
# Il resto della tua cartella home, le chiavette e gli altri programmi per loro non
# esistono. Gli indirizzi web che aprono vanno nel browser normale (solo http/https)
# e i programmi installati compaiono nel menu (dopo un controllo).
# Tutti i programmi Windows stanno nello STESSO recinto (servono a Wine insieme):
#   - "custode": fuori dal recinto, lo accende e porta fuori menu e indirizzi web
#   - "servizio": dentro il recinto, fa partire i comandi wine che arrivano
import fcntl, hashlib, json, os, pwd, re, select, shutil, socket, subprocess, sys, threading, time

VERO_WINE = os.environ.get("RECINTO_WINE", "/usr/bin/wine")
VERO_WINESERVER = os.environ.get("RECINTO_WINESERVER", "/usr/bin/wineserver")
BWRAP = os.environ.get("RECINTO_BWRAP", "/usr/bin/bwrap")
PYTHON = "/usr/bin/python3"
XDG_OPEN_DENTRO = "/usr/local/lib/wine-recinto/xdg-open"
QUESTO = os.path.realpath(sys.argv[0])           # /usr/local/bin/wine (anche se chiamato come winecfg)

UID = os.getuid()
UTENTE = pwd.getpwuid(UID).pw_name
CASA = os.environ.get("HOME") or pwd.getpwuid(UID).pw_dir
PREFISSO = os.path.join(CASA, ".wine")
CARTELLA_UTENTE_WIN = os.path.join(PREFISSO, "drive_c", "users", UTENTE)
SCAMBIO = os.path.join(CASA, "Windows")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/{UID}-runtime-dir"
CARTELLA = os.path.join(RUNTIME, "wine-recinto")
PRESA = os.path.join(CARTELLA, "presa")
BLOCCO = os.path.join(CARTELLA, "avvio.lock")
LINK = os.path.join(CARTELLA, "link")
MENU = os.path.join(CASA, ".local", "share", "wine-recinto")        # dove scrive Wine (dentro)
MENU_VERO = os.path.join(CASA, ".local", "share", "applications", "wine-recinto")
ICONE_VERE = os.path.join(CASA, ".local", "share", "icons")
REGISTRO = os.path.join(CASA, ".cache", "wine-recinto.log")
STRUMENTI = {"msidb", "msiexec", "notepad", "regedit", "regsvr32", "wineboot", "winecfg",
             "wineconsole", "winedbg", "winefile", "winemine", "winepath", "wineserver"}
CARTELLE_WIN = ("Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos", "Templates")
AMBIENTE_PASSA = re.compile(r"(LANG|LANGUAGE|LC_[A-Z]+|WINEDEBUG|WINEDLLOVERRIDES|DISPLAY|TZ)")
ATTESA_VUOTO = 15          # secondi senza programmi Windows, poi il recinto si chiude

def avvisa(testo):
    print("wine (recinto): " + testo, file=sys.stderr)
    try:
        subprocess.Popen(["notify-send", "-a", "Programmi Windows", "-i", "dialog-warning",
                          "Programmi Windows", testo], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass

def dentro(percorso, cartella):
    percorso, cartella = os.path.realpath(percorso), os.path.realpath(cartella)
    return percorso == cartella or percorso.startswith(cartella + os.sep)

# =========================================================================== fuori
def proteggi_cartelle():
    """Le cartelle Documenti, Desktop... di Windows sono cartelle vere nel disco C:,
    non collegamenti alle tue cartelle (Wine all'inizio le collega a quelle della home)."""
    if os.path.isdir(CARTELLA_UTENTE_WIN):
        for d in CARTELLE_WIN:
            p = os.path.join(CARTELLA_UTENTE_WIN, d)
            if os.path.islink(p):
                os.unlink(p)
            os.makedirs(p, exist_ok=True)
        if not os.path.lexists(SCAMBIO):
            os.symlink(CARTELLA_UTENTE_WIN, SCAMBIO)

def sposta_menu_vecchi():
    """Una volta sola: le voci del menu create da Wine prima del recinto passano dal controllo."""
    segno = os.path.join(PREFISSO, ".recinto")
    if os.path.exists(segno):
        return
    vecchio = os.path.join(CASA, ".local", "share", "applications", "wine")
    nuovo = os.path.join(MENU, "applications", "wine")
    if os.path.isdir(vecchio) and not os.path.islink(vecchio):
        os.makedirs(os.path.dirname(nuovo), exist_ok=True)
        if os.path.exists(nuovo):
            shutil.copytree(vecchio, nuovo, dirs_exist_ok=True, symlinks=True)
            shutil.rmtree(vecchio)
        else:
            shutil.move(vecchio, nuovo)
    open(segno, "w").close()

GRANDE = 2 * 1024 ** 3
def dimensione(cartella, limite):
    tot = 0
    for radice, _, file in os.walk(cartella):
        for f in file:
            try:
                tot += os.lstat(os.path.join(radice, f)).st_size
            except OSError:
                pass
            if tot > limite:
                return tot
    return tot

def copia_se_cambiato(sorgente, dest):
    try:
        a, b = os.stat(sorgente), os.stat(dest)
        if a.st_size == b.st_size and int(a.st_mtime) == int(b.st_mtime):
            return
    except OSError:
        pass
    shutil.copy2(sorgente, dest)

def copia_cartella(sorgente, dest):
    """Copia solo i file nuovi o cambiati (rilanciare un programma non ricopia tutto)."""
    for radice, cartelle, file in os.walk(sorgente):
        qui = os.path.join(dest, os.path.relpath(radice, sorgente))
        os.makedirs(qui, exist_ok=True)
        for f in file:
            s = os.path.join(radice, f)
            if os.path.isfile(s) and not os.path.islink(s):
                copia_se_cambiato(s, os.path.join(qui, f))

def porta_dentro(argomenti):
    """I file da aprire (es. ~/Scaricati/setup.exe) vengono copiati nel disco C:
    (cartella Download di Windows): da dentro il recinto la tua home non si vede."""
    scaricati = os.path.join(CARTELLA_UTENTE_WIN, "Downloads")
    comuni = {os.path.realpath(p) for p in [CASA, "/tmp"] + [os.path.join(CASA, n) for n in
              ("Scaricati", "Downloads", "Scrivania", "Desktop", "Documenti", "Documents",
               "Immagini", "Musica", "Video", "Windows")]}
    fuori, cartella_lavoro = [], None
    for a in argomenti:
        # file da portare dentro: percorsi completi (doppio clic) oppure, scritti nel
        # terminale, i soli nomi di programmi Windows (setup.exe, installa.msi...)
        if a.startswith("/") or re.search(r"\.(exe|msi|bat|cmd|com|lnk)$", a, re.I):
            p = os.path.abspath(a)
            if os.path.isfile(p) and not dentro(p, PREFISSO) \
                    and not any(dentro(p, s) for s in ("/usr", "/opt", "/etc")):
                os.makedirs(scaricati, exist_ok=True)
                origine = os.path.dirname(os.path.realpath(p))
                if origine in comuni or dimensione(origine, GRANDE) > GRANDE:
                    dest = os.path.join(scaricati, os.path.basename(p))
                    copia_se_cambiato(p, dest)
                else:                       # programma in una sua cartella: si copia tutta
                    cart = os.path.join(scaricati, os.path.basename(origine))
                    copia_cartella(origine, cart)
                    dest = os.path.join(cart, os.path.basename(p))
                fuori.append(dest)
                cartella_lavoro = cartella_lavoro or os.path.dirname(dest)
                continue
            if os.path.isfile(p) and dentro(p, PREFISSO):
                fuori.append(p)
                cartella_lavoro = cartella_lavoro or os.path.dirname(p)
                continue
        fuori.append(a)
    return fuori, cartella_lavoro

def collega():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(PRESA)
        return s
    except OSError:
        s.close()
        return None

def assicura_recinto():
    """-> presa collegata al servizio nel recinto (lo accende se serve)"""
    os.makedirs(CARTELLA, mode=0o700, exist_ok=True)
    with open(BLOCCO, "a") as blocco:
        fcntl.flock(blocco, fcntl.LOCK_EX)
        s = collega()
        if s:
            return s
        try:
            os.unlink(PRESA)                # rimasta da un recinto chiuso male
        except FileNotFoundError:
            pass
        subprocess.Popen([PYTHON, "-I", QUESTO, "--recinto-custode"], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         close_fds=True)
        fine = time.time() + 20
        while time.time() < fine:
            time.sleep(0.2)
            s = collega()
            if s:
                return s
    try:
        dettagli = open(REGISTRO).read()[-400:].strip()
    except OSError:
        dettagli = ""
    avvisa("Il recinto per i programmi Windows non parte, quindi il programma non viene aperto."
           + (f"\n{dettagli}" if dettagli else ""))
    sys.exit(1)

def richiesta(comando, cartella=None, aspetta=True):
    fds = []
    for n in (0, 1, 2):
        try:
            os.fstat(n); fds.append(n)
        except OSError:
            fds.append(os.open(os.devnull, os.O_RDWR))
    messaggio = {"comando": comando, "cartella": cartella or PREFISSO,
                 "ambiente": {k: v for k, v in os.environ.items() if AMBIENTE_PASSA.fullmatch(k)}}
    for tentativo in (1, 2):
        s = assicura_recinto()
        try:
            socket.send_fds(s, [(json.dumps(messaggio) + "\n").encode()], fds)
            risposta = s.makefile("rb").readline()
        except OSError:
            risposta = b""
        s.close()
        if risposta:
            try:
                return int(json.loads(risposta).get("esito", 1))
            except (ValueError, TypeError):
                return 1
        time.sleep(0.5)                     # il recinto si stava chiudendo: si riprova
    return 1

def cliente(nome, argomenti):
    if os.environ.get("WINEPREFIX") and os.path.realpath(os.environ["WINEPREFIX"]) != os.path.realpath(PREFISSO):
        avvisa(f"Si usa solo il disco Windows protetto ({PREFISSO}), non {os.environ['WINEPREFIX']}.")
        sys.exit(1)
    os.makedirs(PREFISSO, exist_ok=True)
    if not os.path.exists(os.path.join(PREFISSO, "system.reg")):
        avvisa("Preparo il disco C: dei programmi Windows (la prima volta ci vuole circa un minuto)...")
        richiesta(["wine", "wineboot", "-i"])
        richiesta(["wineserver", "-w"])
    proteggi_cartelle()
    sposta_menu_vecchi()
    if nome == "wineserver":
        comando = ["wineserver"] + argomenti
    elif nome in STRUMENTI:
        comando = ["wine", nome] + argomenti
    else:
        comando = ["wine"] + argomenti
    comando[1:], lavoro = porta_dentro(comando[1:])
    try:
        if dentro(os.getcwd(), PREFISSO):
            lavoro = os.getcwd()
    except OSError:
        pass
    sys.exit(richiesta(comando, lavoro))

# --- custode (fuori): menu e indirizzi web che arrivano dal recinto ---
MENU_AMMESSE = {"Type", "Version", "Name", "GenericName", "Comment", "Icon", "StartupNotify",
                "StartupWMClass", "Categories", "NoDisplay", "Keywords", "Terminal"}
EXEC_WINE = re.compile(r'(?:env WINEPREFIX="([^"]*)" )?wine (.+)')
VIETATI = re.compile(r'[`$;&|<>\n\r]')

def sanifica_voce(testo):
    """Voce del menu creata da Wine: si tiene solo se lancia un programma Windows
    (nel recinto). Tutto il resto (comandi Linux, altri programmi) viene scartato."""
    righe, sezione, eseguibile = [], None, None
    for r in testo.splitlines():
        r = r.rstrip("\r")
        if r.startswith("["):
            if sezione is not None:
                break                       # solo la prima sezione ([Desktop Entry])
            if r.strip() != "[Desktop Entry]":
                return None
            sezione = r.strip(); righe.append(sezione); continue
        if sezione is None or "=" not in r or r.startswith("#"):
            continue
        chiave, valore = r.split("=", 1)
        base = chiave.split("[", 1)[0].strip()
        if base == "Exec":
            m = EXEC_WINE.fullmatch(valore.strip())
            if not m or VIETATI.search(m.group(2)):
                return None
            # percorsi Linux negli argomenti: solo dentro il disco C: (cosi' una voce del
            # menu non puo' far copiare nel recinto un tuo file, es. ~/.ssh/...)
            for pezzo in re.split(r'(?<!\\)\s+', m.group(2)):
                if ".." in pezzo:
                    return None
                if "/" in pezzo and not re.fullmatch(r"/[A-Za-z]+", pezzo) \
                        and not pezzo.startswith(os.path.realpath(PREFISSO) + "/"):
                    return None
            if m.group(1) is not None and os.path.realpath(m.group(1)) != os.path.realpath(PREFISSO):
                return None
            eseguibile = f"Exec=/usr/local/bin/wine {m.group(2)}"
            righe.append(eseguibile)
        elif base in MENU_AMMESSE and not VIETATI.search(valore):
            if base == "Type" and valore.strip() != "Application":
                return None
            if base == "Terminal" and valore.strip() != "false":
                continue
            righe.append(f"{chiave}={valore}")
    return "\n".join(righe) + "\n" if eseguibile else None

def importa_menu():
    os.makedirs(os.path.join(MENU, "applications"), exist_ok=True)
    with open(os.path.join(MENU, ".lock"), "a") as blocco:
        fcntl.flock(blocco, fcntl.LOCK_EX)
        nuove = {}
        origine = os.path.join(MENU, "applications", "wine")
        for radice, _, file in os.walk(origine):
            for f in file:
                if not f.endswith(".desktop") or not re.fullmatch(r"[\w .,()+'-]+\.desktop", f):
                    continue
                try:
                    testo = open(os.path.join(radice, f), errors="replace").read(65536)
                except OSError:
                    continue
                buona = sanifica_voce(testo)
                if buona:
                    nome = "wine-" + hashlib.sha1(os.path.relpath(os.path.join(radice, f), origine).encode()).hexdigest()[:12] + ".desktop"
                    nuove[nome] = buona
        os.makedirs(MENU_VERO, exist_ok=True)
        for f in os.listdir(MENU_VERO):
            if f not in nuove:
                os.unlink(os.path.join(MENU_VERO, f))
        for f, testo in nuove.items():
            p = os.path.join(MENU_VERO, f)
            try:
                if open(p).read() == testo:
                    continue
            except OSError:
                pass
            with open(p + ".nuovo", "w") as g:
                g.write(testo)
            os.replace(p + ".nuovo", p)
        # icone: solo immagini PNG piccole, con nomi semplici
        icone = os.path.join(MENU, "icons")
        for radice, _, file in os.walk(icone):
            for f in file:
                sorgente = os.path.join(radice, f)
                rel = os.path.relpath(sorgente, icone)
                if not re.fullmatch(r"hicolor/\d+x\d+/apps/[\w.-]+\.png", rel) or os.path.islink(sorgente):
                    continue
                try:
                    if os.path.getsize(sorgente) > 2 * 1024 ** 2 or open(sorgente, "rb").read(8) != b"\x89PNG\r\n\x1a\n":
                        continue
                    dest = os.path.join(ICONE_VERE, rel)
                    if not os.path.exists(dest) or open(dest, "rb").read() != open(sorgente, "rb").read():
                        os.makedirs(os.path.dirname(dest), exist_ok=True)
                        shutil.copyfile(sorgente, dest)
                except OSError:
                    pass

INDIRIZZO = re.compile(r"https?://[^\s\"'<>`\\]{1,2000}")
aperti = []
def apri_indirizzi():
    try:
        nomi = sorted(os.listdir(LINK))
    except OSError:
        return
    for f in nomi:
        p = os.path.join(LINK, f)
        if not f.endswith(".url"):
            if f.endswith(".tmp") and time.time() - os.lstat(p).st_mtime > 60:
                os.unlink(p)
            continue
        try:
            fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(fd, errors="replace") as g:
                url = g.read(4096).strip()
        except OSError:
            url = ""
        try:
            os.unlink(p)
        except OSError:
            pass
        adesso = time.time()
        aperti[:] = [t for t in aperti if adesso - t < 60]
        if INDIRIZZO.fullmatch(url) and len(aperti) < 5:      # al massimo 5 al minuto
            aperti.append(adesso)
            subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)

def comando_recinto():
    a = [BWRAP, "--unshare-user", "--disable-userns", "--unshare-pid", "--unshare-uts",
         "--unshare-cgroup-try", "--new-session", "--die-with-parent",
         "--ro-bind", "/", "/",                         # il sistema: si vede, non si cambia
         "--dev", "/dev", "--dev-bind-try", "/dev/dri", "/dev/dri",
         "--proc", "/proc",                             # solo i processi del recinto
         "--tmpfs", "/home", "--tmpfs", "/tmp", "--tmpfs", "/var/tmp", "--tmpfs", "/run"]
    # /opt: Firefox e Tor Browser (che tiene li' la cronologia); /mnt, /media: chiavette e dischi
    for p in ("/opt", "/mnt", "/media", "/srv"):
        if os.path.isdir(p):
            a += ["--tmpfs", p]                         # chiavette e altri dischi: nascosti
    a += ["--ro-bind-try", "/run/systemd/resolve", "/run/systemd/resolve",   # nomi dei siti
          "--ro-bind-try", "/run/udev", "/run/udev",
          "--ro-bind-try", "/tmp/.X11-unix", "/tmp/.X11-unix",                # le finestre (X11)
          "--bind", PREFISSO, PREFISSO,
          "--bind", CARTELLA, CARTELLA,
          "--bind", os.path.join(MENU, "applications"), os.path.join(CASA, ".local", "share", "applications"),
          "--bind", os.path.join(MENU, "icons"), os.path.join(CASA, ".local", "share", "icons"),
          "--bind-try", os.path.join(RUNTIME, "pipewire-0"), os.path.join(RUNTIME, "pipewire-0"),
          "--bind-try", os.path.join(RUNTIME, "pulse"), os.path.join(RUNTIME, "pulse"),
          "--setenv", "WINE_RECINTO", "1", "--setenv", "WINEPREFIX", PREFISSO,
          "--setenv", "HOME", CASA, "--setenv", "XDG_RUNTIME_DIR", RUNTIME,
          "--unsetenv", "WAYLAND_DISPLAY", "--unsetenv", "DBUS_SESSION_BUS_ADDRESS",
          "--chdir", PREFISSO,
          PYTHON, "-I", QUESTO, "--recinto-servizio"]
    if os.path.exists("/usr/local/bin/xdg-open") and os.path.exists(XDG_OPEN_DENTRO):
        i = a.index("--setenv")             # gli indirizzi web escono dal recinto solo da qui
        a[i:i] = ["--ro-bind", XDG_OPEN_DENTRO, "/usr/local/bin/xdg-open"]
    return a

def custode():
    for d in (CARTELLA, LINK, os.path.join(MENU, "applications"), os.path.join(MENU, "icons"),
              os.path.dirname(REGISTRO), PREFISSO):
        os.makedirs(d, mode=0o700, exist_ok=True)
    registro = open(REGISTRO, "w")
    registro.write(time.strftime("%Y-%m-%d %H:%M:%S") + " recinto acceso\n"); registro.flush()
    p = subprocess.Popen(comando_recinto(), stdin=subprocess.DEVNULL, stdout=registro, stderr=registro)
    while p.poll() is None:
        try:
            importa_menu(); apri_indirizzi()
        except Exception as e:                  # il custode non deve mai fermarsi per questo
            registro.write(f"custode: {e}\n"); registro.flush()
        try:
            p.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass
    importa_menu()
    registro.write(time.strftime("%Y-%m-%d %H:%M:%S") + f" recinto chiuso ({p.returncode})\n")

# ========================================================================== dentro
class Servizio:
    def __init__(self):
        self.blocco = threading.Lock()
        self.attivi = 0
        self.ultimo = time.time()

    def esegui(self, conn):
        fds = []
        try:
            dati, fds, _, _ = socket.recv_fds(conn, 1 << 20, 3)
            while not dati.endswith(b"\n"):
                altro = conn.recv(1 << 20)
                if not altro:
                    return
                dati += altro
            m = json.loads(dati)
            comando = [str(x) for x in m["comando"]]
            programma = {"wine": VERO_WINE, "wineserver": VERO_WINESERVER}.get(comando[0])
            if programma is None or len(fds) != 3:
                conn.sendall(b'{"esito": 1}\n'); return
            ambiente = dict(os.environ)
            ambiente.update({k: str(v) for k, v in m.get("ambiente", {}).items() if AMBIENTE_PASSA.fullmatch(k)})
            cartella = m.get("cartella") if os.path.isdir(str(m.get("cartella"))) else PREFISSO
            with self.blocco:
                self.attivi += 1; self.ultimo = time.time()
            try:
                p = subprocess.Popen([programma] + comando[1:], stdin=fds[0], stdout=fds[1], stderr=fds[2],
                                     cwd=cartella, env=ambiente)
                for fd in fds:
                    os.close(fd)
                fds = []
                esito = p.wait()
            except OSError:
                esito = 127
            finally:
                with self.blocco:
                    self.attivi -= 1; self.ultimo = time.time()
            conn.sendall((json.dumps({"esito": esito}) + "\n").encode())
        except (OSError, ValueError, KeyError, IndexError, TypeError):
            pass
        finally:
            for fd in fds:
                os.close(fd)
            conn.close()

    def altri_processi(self):
        """Programmi Windows ancora accesi nel recinto (tutti tranne il recinto stesso)."""
        io = os.getpid()
        return [p for p in os.listdir("/proc") if p.isdigit() and int(p) not in (1, io)
                and os.path.exists(f"/proc/{p}/exe")]

    def principale(self):
        try:
            os.unlink(PRESA)
        except FileNotFoundError:
            pass
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.bind(PRESA); os.chmod(PRESA, 0o600); s.listen(16)
        while True:
            pronti, _, _ = select.select([s], [], [], 5)
            if pronti:
                conn, _ = s.accept()
                with self.blocco:
                    self.ultimo = time.time()
                threading.Thread(target=self.esegui, args=(conn,), daemon=True).start()
                continue
            with self.blocco:
                fermo = self.attivi == 0 and time.time() - self.ultimo > ATTESA_VUOTO
            if fermo and not self.altri_processi():
                with open(BLOCCO, "a") as blocco:
                    fcntl.flock(blocco, fcntl.LOCK_EX)
                    if select.select([s], [], [], 0)[0] or self.altri_processi():
                        continue                    # e' arrivato qualcuno proprio adesso
                    os.unlink(PRESA)
                    os._exit(0)

def principale():
    nome = os.path.basename(sys.argv[0])
    argomenti = sys.argv[1:]
    if os.environ.get("WINE_RECINTO") == "1":          # gia' dentro il recinto: Wine vero
        if nome == "wineserver":
            os.execv(VERO_WINESERVER, [VERO_WINESERVER] + argomenti)
        os.execv(VERO_WINE, [VERO_WINE] + ([nome] if nome in STRUMENTI else []) + argomenti)
    if argomenti[:1] == ["--recinto-servizio"]:
        sys.exit("solo dentro il recinto")
    if argomenti[:1] == ["--recinto-custode"]:
        return custode()
    return cliente(nome, argomenti)

if __name__ == "__main__":
    if sys.argv[1:2] == ["--recinto-servizio"] and os.environ.get("WINE_RECINTO") == "1":
        Servizio().principale()
    else:
        principale()
EOF
cat > /usr/local/lib/wine-recinto/xdg-open << "EOF"
#!/bin/sh
# Dentro il recinto dei programmi Windows (creato da lfs.sh): un indirizzo web
# (solo http/https) viene passato fuori e si apre nel browser. Nient'altro esce.
cartella="${XDG_RUNTIME_DIR:-/tmp}/wine-recinto/link"
case "$1" in
  http://*|https://*) ;;
  *) echo "Dal recinto si aprono solo indirizzi web (http/https)" >&2; exit 1 ;;
esac
f=$(mktemp "$cartella/XXXXXXXX.tmp") || exit 1
printf '%s\n' "$1" > "$f" && mv "$f" "${f%.tmp}.url"
EOF
chmod 755 /usr/local/bin/wine /usr/local/lib/wine-recinto/xdg-open
python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/bin/wine
sh -n /usr/local/lib/wine-recinto/xdg-open
local t
for t in msidb msiexec notepad regedit regsvr32 wineboot winecfg wineconsole winedbg \
         winefile winemine winepath wineserver; do
  if [ -e "/usr/bin/$t" ]; then ln -sfv wine "/usr/local/bin/$t"; fi
done
# doppio clic su un .exe e voci del menu di Wine: sempre nel recinto
for t in /usr/share/applications/wine.desktop /usr/share/applications/wine-*.desktop; do
  [ -f "$t" ] || continue
  sed -i -e 's|^Exec=wine |Exec=/usr/local/bin/wine |' \
         -e 's|^Exec=winecfg$|Exec=/usr/local/bin/wine winecfg|' "$t"
done
if grep -h '^Exec=' /usr/share/applications/wine.desktop /usr/share/applications/wine-*.desktop 2>/dev/null \
     | grep -v '^Exec=/usr/local/bin/wine '; then
  echo "Una voce di Wine nel menu non passa dal recinto"; return 1
fi
echo "[OK] Recinto per i programmi Windows pronto (vedono solo il disco C: e ~/Windows)"
}

f6_configura() {
# NON IN BLFS: Tor Browser predefinito, avvio del desktop, DNS cifrato, rete e kernel prudenti
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa t
casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
[ -d "$casa" ] || { echo "Non trovo la cartella di $MIA_UTENTE"; return 1; }
id -nG "$MIA_UTENTE" | grep -qw wheel || usermod -aG wheel "$MIA_UTENTE"

# --- impostazioni del kernel piu' prudenti (parte di quelle dell'esempio del libro BLFS) ---
cat > /etc/sysctl.d/90-sicurezza.conf << "EOF"
# Creato da lfs.sh (Fase 6)
# indirizzi del kernel e messaggi del kernel solo per root
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
# un programma puo' "spiare" (ptrace) solo i programmi che ha avviato lui
kernel.yama.ptrace_scope = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.kexec_load_disabled = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0
# rete (come nell'esempio del libro): niente pacchetti con il percorso deciso da
# altri, niente "redirect", protezione dai SYN flood, controllo degli indirizzi falsi
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
# MODIFICA: controllo "largo" (2) invece di "stretto" (1): con la VPN il traffico
# torna da un'altra scheda e il controllo stretto potrebbe scartarlo
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
# IPv6: indirizzi temporanei, che cambiano (non rivelano la scheda di rete)
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
EOF

# --- DNS cifrato (DNS-over-TLS) con Quad9: chi controlla la rete non vede i siti che visiti ---
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/10-dns-cifrato.conf << "EOF"
# Creato da lfs.sh (Fase 6): nomi dei siti chiesti a Quad9 (Svizzera, non registra
# chi chiede) in modo cifrato. Se in qualche rete (hotel, ufficio) i siti non si
# aprono, si puo' cambiare DNSOverTLS=yes in DNSOverTLS=opportunistic.
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net
FallbackDNS=
DNSOverTLS=yes
Domains=~.
LLMNR=no
MulticastDNS=no
EOF
# i programmi chiedono i nomi dei siti a systemd-resolved (che poi usa il DNS cifrato)
[ -L /etc/resolv.conf ] || ln -sfv ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
# la rete via cavo: niente DNS del router (si usa quello cifrato), il nome del
# computer non viene mandato al router, IPv6 con indirizzi temporanei
for t in /etc/systemd/network/*.network; do
  [ -f "$t" ] || continue
  mkdir -p "$t.d"
  cat > "$t.d/20-privacy.conf" << "EOF"
# Creato da lfs.sh (Fase 6)
[Network]
IPv6PrivacyExtensions=yes

[DHCPv4]
UseDNS=no
SendHostname=no

[IPv6AcceptRA]
UseDNS=no
EOF
done

# --- Tor Browser al posto di Firefox; Firefox resta per i siti che non vanno con Tor ---
[ -f /usr/share/applications/tor-browser.desktop ] || { echo "Manca Tor Browser"; return 1; }
for t in text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https; do
  if grep -q "^$t=" /etc/xdg/mimeapps.list; then
    sed -i "s|^$t=.*|$t=tor-browser.desktop|" /etc/xdg/mimeapps.list
  else
    sed -i "/^\[Default Applications\]/a $t=tor-browser.desktop" /etc/xdg/mimeapps.list
  fi
done
if [ -f /usr/share/applications/firefox.desktop ]; then
  sed -i -e 's/^Name=Firefox$/Name=Firefox (non anonimo)/' \
         -e 's/^Comment=.*/Comment=Per i siti che non funzionano con Tor (Spotify, banca...): mostra il tuo indirizzo IP/' \
         /usr/share/applications/firefox.desktop
fi
if ! grep -q 'tor-browser' /etc/xdg/labwc/menu.xml; then
  sed -i -e 's|^  <item label="Firefox">|  <item label="Tor Browser (anonimo)">\n    <action name="Execute" command="/usr/local/bin/tor-browser" />\n  </item>\n  <item label="Firefox (non anonimo)">|' \
         -e 's|^  <item label="Terminale">|  <item label="Cassaforte">\n    <action name="Execute" command="/usr/local/bin/cassaforte" />\n  </item>\n  <item label="Terminale">|' \
         /etc/xdg/labwc/menu.xml
fi
grep -q 'tor-browser' /etc/xdg/labwc/menu.xml || { echo "Non riesco a mettere Tor Browser nel menu"; return 1; }
if grep -q '/usr/share/applications/firefox.desktop' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml; then
  sed -i 's|/usr/share/applications/firefox.desktop|/usr/share/applications/tor-browser.desktop|' \
      /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
  # la barra dell'utente riparte dalla nuova configurazione (con Tor Browser)
  rm -rf "$casa/.config/xfce4/panel" "$casa/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
fi

# --- all'accesso: le domande del Guardiano e (solo la prima volta) il benvenuto ---
if ! grep -q 'guardiano-avvisi' /etc/xdg/labwc/autostart; then
  sed -i '/^swaybg /i /usr/local/bin/guardiano-avvisi >/dev/null 2>\&1 \&' /etc/xdg/labwc/autostart
fi
grep -q 'benvenuto' /etc/xdg/labwc/autostart \
  || echo "/usr/local/bin/benvenuto >/dev/null 2>&1 &" >> /etc/xdg/labwc/autostart
grep -q '^/usr/local/bin/guardiano-avvisi ' /etc/xdg/labwc/autostart \
  || { echo "Non riesco a modificare l'avvio del desktop"; return 1; }

update-desktop-database /usr/share/applications
echo "[OK] Sicurezza pronta: firewall, Guardiano, Tor Browser, VPN, cassaforte, DNS cifrato"
}

LISTA_STEP13=(
  "iptables (firewall)|iptables-1.8.13.tar.xz|f6_iptables"
  "wireguard-tools (VPN)|wireguard-tools-1.0.20260223.tar.xz|f6_wireguard_tools"
  "yad (finestre di dialogo)|yad-14.2.tar.xz|f6_yad"
  "Tor Browser|tor-browser.tar.xz|f6_tor_browser"
  "firewall e Guardiano della rete|-|f6_guardiano"
  "Cassaforte (cartella cifrata)|-|f6_cassaforte"
  "VPN e benvenuto|-|f6_vpn"
  "bubblewrap (recinto)|bubblewrap-0.11.2.tar.xz|f6_bubblewrap"
  "recinto per i programmi Windows|-|f6_recinto_wine"
  "configurazione della sicurezza|-|f6_configura"
)

kernel_ha_sicurezza() { # il kernel installato ha firewall, VPN e cifratura?
  local c="$LFS/boot/config-$KERNEL_VER" o
  for o in NETFILTER_XT_TARGET_NFQUEUE NETFILTER_XT_MATCH_OWNER IP_NF_IPTABLES_LEGACY \
           NETFILTER_XT_CONNMARK WIREGUARD FS_ENCRYPTION SECURITY_YAMA USER_NS \
           IP_NF_NAT NETFILTER_XT_TARGET_REDIRECT; do
    grep -Eq "^CONFIG_$o=[ym]" "$c" 2>/dev/null || return 1
  done
}

attiva_cifratura_disco() { # opzione "encrypt" di ext4 sul disco della distro (per la cassaforte)
  local dev caratteristiche
  dev=$(findmnt -n -o SOURCE --mountpoint "$LFS" 2>/dev/null || true)
  [ -b "$dev" ] || muori "Non trovo il disco della distro montato su $LFS"
  caratteristiche=$(dumpe2fs -h "$dev" 2>/dev/null | grep '^Filesystem features:' || true)
  if [[ " $caratteristiche " == *" encrypt "* ]]; then return 0; fi
  info "Attivo la cifratura sul disco della distro (serve alla cassaforte)"
  sync
  umount "$LFS" || muori "Non riesco a smontare $LFS (un terminale o un programma e' dentro?): chiudilo e rilancia"
  if ! tune2fs -O encrypt "$dev" >/dev/null; then
    mount "$dev" "$LFS"
    muori "Non riesco ad attivare la cifratura sul disco della distro"
  fi
  mount "$dev" "$LFS"
  ok "Cifratura attiva sul disco della distro"
}

cmd_fase6() {
  serve_root fase6
  titolo "Fase 6 - Sicurezza: firewall, Guardiano della rete, Tor Browser, VPN, cassaforte"
  assicura_montato
  if [ "$(quanti_fatti "${LISTA_STEP12[@]}")" -ne "${#LISTA_STEP12[@]}" ]; then
    info "Prima finisco la Fase 5 (ufficio, posta...), poi passo alla sicurezza."
    cmd_fase5
    titolo "Fase 6 - Sicurezza: firewall, Guardiano della rete, Tor Browser, VPN, cassaforte"
  fi
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP13[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 6 da capo (opzione 'rifai')"
  fi
  # il kernel deve avere il firewall, WireGuard e la cifratura dei file
  if ! kernel_ha_sicurezza; then
    info "Ricompilo il kernel con firewall, VPN WireGuard, cifratura e recinti (una volta sola)."
    cmd_step4 step4 rifai
    titolo "Fase 6 - Sicurezza: firewall, Guardiano della rete, Tor Browser, VPN, cassaforte"
  fi
  attiva_cifratura_disco
  chiedi_utente
  titolo "Scarico i sorgenti della Fase 6 (circa 120 MB)"
  scarica_fonti "${FONTI_FASE6[@]}"
  scarica_tor_browser
  info "Ci vogliono circa 5-10 minuti. Lascia il terminale aperto."
  local esito=0
  lancia_in_chroot 13 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase6 MIA_ETICHETTA="Fase 6" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 6 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia). Novita':"
  info "   Primo accesso: ti chiede se hai una VPN (se no, ti propone Mullvad; puoi anche dire no)"
  info "   Tor Browser e' il browser predefinito. Firefox resta: 'Firefox (non anonimo)'"
  info "   La prima volta che un programma usa internet compare la domanda: Blocca o Permetti"
  info "   Menu Applicazioni: Cassaforte (cartella cifrata), VPN, Regole della rete"
  info "   Programmi Windows nel recinto: vedono solo il disco C: e la cartella ~/Windows"
  info "   (per aprire un tuo file con un programma Windows, mettilo prima in ~/Windows)"
  info "   Da internet nessuno puo' collegarsi al tuo computer; DNS cifrato"
}

# =============================================================================
#  FASE 7 - MODALITA' FANTASMA (nascondere il piu' possibile chi sei online)
#   - un pulsante nella barra in basso: accesa, TUTTO quello che fa il computer
#     online passa da Tor (non solo il browser). Quello che non puo' passare da Tor
#     (UDP, IPv6, rete di casa, orologio) e' bloccato: il tuo indirizzo IP non esce mai
#   - Tor nascosto con i "ponti" (bridges): il fornitore di internet non vede nemmeno
#     che usi Tor
#   - scheda di rete con indirizzo (MAC) casuale, nome del computer e identificativo
#     del sistema nascosti, niente IPv6, registro di sistema solo in memoria,
#     webcam e microfono spenti
#   - Tor Browser usa il Tor del sistema; Firefox e Thunderbird avvisano prima di aprirsi
#   - l'utente "fantasma": accedendo con lui la modalita' si accende da sola e tutto
#     quello che fai sta solo in memoria (si cancella allo spegnimento)
#  libevent dal libro BLFS 13.1 (tag r13.1); Tor e il resto non sono nel libro
#  ("# NON IN BLFS"). Ogni differenza dal libro e' segnata con "# MODIFICA:".
#  Scelte:
#   - Tor compilato qui (solo la parte "client", niente relay); i programmi dei ponti
#     (lyrebird) e l'elenco dei ponti predefiniti vengono da Tor Browser, la cui firma
#     e' gia' stata controllata (Fase 6).
#   - niente "porta di controllo" di Tor aperta ai programmi: chi la usa potrebbe
#     far uscire il tuo indirizzo vero.
# =============================================================================
FONTI_FASE7=(
  # file | indirizzo | controllo (md5 dal libro BLFS 13.1; sha512 da Gentoo Linux)
  "libevent-2.1.13-stable.tar.gz|https://github.com/libevent/libevent/releases/download/release-2.1.13-stable/libevent-2.1.13-stable.tar.gz|md5:eaa0bd3472b5d6a52ac6b9e0b7418b03"
  "tor-0.4.9.14.tar.gz|https://archive.torproject.org/tor-package-archive/tor-0.4.9.14.tar.gz|sha512:0832a8c7f7491d97af0a8a75a01143748470c2f077720ba51ece095ae90b235718329b4c7df039e0e82d68ec1195a78a90c745b6767dc34c2425057aceb0a20e"
)

f7_libevent() {
sed -i 's/python/&3/' event_rpcgen.py
./configure --prefix=/usr --disable-static
make
make install
}

f7_tor() {
# NON IN BLFS: Tor, solo la parte "client" (niente relay, niente autorita' di directory),
# con l'utente di sistema "tor" (l'unico che il firewall lascia uscire in modalita' fantasma)
./configure --prefix=/usr                \
            --sysconfdir=/etc            \
            --localstatedir=/var         \
            --disable-asciidoc           \
            --disable-manpage            \
            --disable-html-manual        \
            --disable-module-relay       \
            --disable-module-dirauth     \
            --disable-unittests          \
            --enable-gpl
make
make install
getent group tor >/dev/null || groupadd -r tor
id tor >/dev/null 2>&1 || useradd -r -g tor -d /var/lib/tor -s /bin/false -c "Tor (modalita' fantasma)" tor
install -vdm700 -o tor -g tor /var/lib/tor
echo "[OK] $(/usr/bin/tor --version | head -n1)"
}

f7_ponti() {
# NON IN BLFS: i "ponti" per nascondere che usi Tor e una copia pulita di Tor Browser
# per l'utente fantasma, presi dall'archivio di Tor Browser (firma controllata nella Fase 6)
local base=/usr/local/lib/fantasma pt=/usr/local/lib/fantasma/pt cima sorgente f
[ -s /sources/tor-browser.tar.xz ] || { echo "Manca l'archivio di Tor Browser (Fase 6)"; return 1; }
rm -rf "$base/tor-browser" "$pt" "$base/estratto"
mkdir -p "$base/estratto" "$pt" /etc/fantasma
tar -C "$base/estratto" -xf /sources/tor-browser.tar.xz
cima=$(ls "$base/estratto")
[ -x "$base/estratto/$cima/Browser/start-tor-browser" ] || { echo "L'archivio di Tor Browser e' strano"; return 1; }
mv "$base/estratto/$cima" "$base/tor-browser"
rmdir "$base/estratto"
chown -R root:root "$base/tor-browser"
chmod -R go+rX,go-w "$base/tor-browser"
sorgente="$base/tor-browser/Browser/TorBrowser/Tor/PluggableTransports"
[ -f "$sorgente/pt_config.json" ] || { echo "Tor Browser non contiene l'elenco dei ponti"; return 1; }
for f in "$sorgente"/*; do
  if [ -f "$f" ] && [ -x "$f" ]; then install -vm755 "$f" "$pt/"; fi
done
[ -x "$pt/lyrebird" ] || { echo "Manca lyrebird (il programma dei ponti)"; return 1; }
python3 -I - "$sorgente/pt_config.json" "$pt/" /etc/fantasma << "EOF"
import json, os, sys
c = json.load(open(sys.argv[1]))
pt, uscita = sys.argv[2], sys.argv[3]
trasporti = []
for nome, riga in c["pluggableTransports"].items():
    riga = riga.replace("${pt_path}", pt).replace("${pt_extension}", "")
    programma = riga.split(" exec ", 1)[1].split()[0] if " exec " in riga else ""
    if os.path.isfile(programma):
        trasporti.append(riga)
ponti = []
for tipo in ("obfs4", "snowflake"):
    ponti += [p for p in c.get("bridges", {}).get(tipo, []) if isinstance(p, str)]
if not trasporti or not ponti:
    sys.exit("Non trovo i ponti predefiniti di Tor Browser")
with open(os.path.join(uscita, "trasporti"), "w") as f:
    f.write("# Creato da lfs.sh: i programmi dei ponti (da Tor Browser)\n" + "\n".join(trasporti) + "\n")
with open(os.path.join(uscita, "ponti-predefiniti"), "w") as f:
    f.write("# Creato da lfs.sh: i ponti predefiniti di Tor Browser (obfs4 e snowflake)\n" + "\n".join(ponti) + "\n")
print(f"[OK] {len(ponti)} ponti predefiniti e {len(trasporti)} tipi di ponte, da Tor Browser")
EOF
if [ ! -f /etc/fantasma/ponti ]; then
cat > /etc/fantasma/ponti << "EOF"
# Ponti personali per la modalita' fantasma (facoltativi).
# Chiedili su https://bridges.torproject.org (scegli obfs4) e incollali qui sotto, uno
# per riga. Se qui non c'e' nessun ponte si usano quelli predefiniti di Tor Browser.
# Per usare Tor senza ponti (piu' veloce, ma il fornitore di internet vede che usi Tor)
# crea il file /etc/fantasma/senza-ponti. Dopo una modifica: spegni e riaccendi.
EOF
fi
chmod 644 /etc/fantasma/*
}

f7_fantasma() {
# NON IN BLFS: la modalita' fantasma
#   fantasma-aiuto   (root, con sudo senza password per il gruppo wheel) accende e spegne
#   fantasma         la finestra (pulsante nella barra e menu: Modalita' fantasma)
#   firewall-avvia   aggiornato: in modalita' fantasma esce solo Tor
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa t
casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
[ -d "$casa" ] || { echo "Non trovo la cartella di $MIA_UTENTE"; return 1; }
[ -x /usr/bin/tor ] || { echo "Manca Tor"; return 1; }
mkdir -p /usr/local/sbin /usr/local/bin /usr/local/lib/fantasma /etc/fantasma
cat > /usr/local/sbin/fantasma-aiuto << "EOF"
#!/usr/bin/python3 -I
# Modalita' fantasma (creato da lfs.sh). Gira come root (con sudo) e fa:
#   fantasma-aiuto accendi   tutto internet passa da Tor (anche gli altri programmi),
#                            scheda di rete camuffata, nome del PC nascosto, niente IPv6,
#                            registro di sistema solo in memoria, webcam e microfono spenti
#   fantasma-aiuto spegni    torna tutto normale
#   fantasma-aiuto stato | pronto | attendi | avvio (all'accensione del computer)
# Quando e' accesa resta accesa anche dopo un riavvio, finche' non la spegni.
import glob, os, re, secrets, subprocess, sys, time

CARTELLA = os.environ.get("FANTASMA_CARTELLA", "/etc/fantasma")
STATO = os.path.join(CARTELLA, "attivo")
PONTI_MIEI = os.path.join(CARTELLA, "ponti")                  # ponti personali (facoltativi)
PONTI_PREDEFINITI = os.path.join(CARTELLA, "ponti-predefiniti")
TRASPORTI = os.path.join(CARTELLA, "trasporti")
SENZA_PONTI = os.path.join(CARTELLA, "senza-ponti")
TORRC = "/etc/tor/fantasma.torrc"
LOG_TOR = "/run/tor-fantasma/notice.log"
MACHINE_ID_FINTO = "/run/fantasma/machine-id"
SEGNO = "# Creato da lfs.sh (modalita' fantasma)"
os.environ["PATH"] = "/usr/bin:/usr/sbin"

FILE = {
    # nomi dei siti: chiesti a Tor (porta DNS di Tor), mai alla rete
    "/etc/systemd/resolved.conf.d/99-fantasma.conf":
        f"{SEGNO}\n[Resolve]\nDNS=\nDNS=127.0.0.1:9053\nDNSOverTLS=no\nDNSSEC=no\nDomains=~.\n"
        "LLMNR=no\nMulticastDNS=no\n",
    # registro di sistema solo in memoria
    "/etc/systemd/journald.conf.d/99-fantasma.conf": f"{SEGNO}\n[Journal]\nStorage=volatile\n",
    # niente IPv6 (Tor qui usa solo IPv4: cosi' niente puo' uscire da IPv6)
    "/etc/sysctl.d/99-fantasma.conf":
        f"{SEGNO}\nnet.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\n",
    # webcam e microfono spenti
    "/etc/udev/rules.d/90-fantasma.rules":
        f'{SEGNO}\nSUBSYSTEM=="video4linux", MODE="0000"\nSUBSYSTEM=="sound", KERNEL=="pcmC*D*c", MODE="0000"\n',
}

def comando(*c, muto=True):
    try:
        return subprocess.run(c, stdout=subprocess.DEVNULL if muto else None,
                              stderr=subprocess.DEVNULL if muto else None).returncode == 0
    except OSError:
        return False

def scrivi(percorso, testo, permessi=0o644):
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    with open(percorso + ".nuovo", "w") as f:
        f.write(testo)
    os.chmod(percorso + ".nuovo", permessi)
    os.replace(percorso + ".nuovo", percorso)

def togli_se_nostro(percorso):
    try:
        if open(percorso).read().startswith(SEGNO):
            os.unlink(percorso)
    except OSError:
        pass

def file_rete():
    """Per ogni rete (.network): il router riceve solo l'indirizzo della scheda (camuffato),
    non l'identificativo fisso del computer."""
    return {f"{n}.d/90-fantasma.conf": f"{SEGNO}\n[DHCPv4]\nClientIdentifier=mac\nSendHostname=no\n"
            for n in glob.glob("/etc/systemd/network/*.network")}

def file_link():
    """All'accensione la scheda di rete prende un indirizzo (MAC) casuale."""
    for d in ("/usr/lib/udev/network", "/usr/lib/systemd/network"):
        base = os.path.join(d, "99-default.link")
        if os.path.isfile(base):
            testo = open(base).read()
            if re.search(r"^MACAddressPolicy=", testo, re.M):
                testo = re.sub(r"^MACAddressPolicy=.*$", "MACAddressPolicy=random", testo, flags=re.M)
            else:
                testo = testo.replace("[Link]\n", "[Link]\nMACAddressPolicy=random\n", 1)
            return {base.replace("/usr/lib/", "/etc/", 1): SEGNO + "\n" + testo}
    return {}

def schede():
    return [n for n in sorted(os.listdir("/sys/class/net"))
            if n != "lo" and os.path.exists(f"/sys/class/net/{n}/device")]

def mac_casuale():
    b = bytearray(secrets.token_bytes(6))
    b[0] = (b[0] & 0xFE) | 0x02                       # indirizzo "locale", non di un produttore
    return ":".join(f"{x:02x}" for x in b)

def mac_vero(scheda):
    try:
        uscita = subprocess.run(["ip", "-d", "link", "show", "dev", scheda], capture_output=True, text=True).stdout
    except OSError:
        return None
    m = re.search(r"permaddr ([0-9a-f:]{17})", uscita)
    return m.group(1) if m else None

def cambia_mac(scheda, mac):
    comando("ip", "link", "set", "dev", scheda, "down")
    comando("ip", "link", "set", "dev", scheda, "address", mac)
    comando("ip", "link", "set", "dev", scheda, "up")

def scrivi_torrc():
    righe = [SEGNO, "# Si rigenera a ogni accensione: i ponti personali vanno in " + PONTI_MIEI,
             "DataDirectory /var/lib/tor", "Log notice file " + LOG_TOR,
             "SocksPort 127.0.0.1:9050", "SocksPort 127.0.0.1:9150",
             "TransPort 127.0.0.1:9040 IsolateDestAddr IsolateDestPort",
             "DNSPort 127.0.0.1:9053", "AutomapHostsOnResolve 1", "AutomapHostsSuffixes .onion,.exit",
             "VirtualAddrNetworkIPv4 10.192.0.0/10", "ClientUseIPv6 0", "AvoidDiskWrites 1"]
    def leggi(p):
        try:
            return [r.strip() for r in open(p) if r.strip() and not r.lstrip().startswith("#")]
        except OSError:
            return []
    ponti = [] if os.path.exists(SENZA_PONTI) else (leggi(PONTI_MIEI) or leggi(PONTI_PREDEFINITI))
    ponti = [p[len("Bridge "):] if p.startswith("Bridge ") else p for p in ponti]
    if ponti:
        righe += ["UseBridges 1"] + leggi(TRASPORTI) + ["Bridge " + p for p in ponti]
    scrivi(TORRC, "\n".join(righe) + "\n")

def acceso():
    return os.path.exists(STATO)

def avanzamento():
    try:
        testo = open(LOG_TOR, errors="replace").read()
    except OSError:
        return 0
    numeri = re.findall(r"Bootstrapped (\d+)%", testo)
    return int(numeri[-1]) if numeri else 0

def nascondi_identita():
    comando("hostname", "localhost")
    if not montato("/etc/machine-id"):
        os.makedirs(os.path.dirname(MACHINE_ID_FINTO), exist_ok=True)
        scrivi(MACHINE_ID_FINTO, secrets.token_hex(16) + "\n", 0o444)
        comando("mount", "--bind", MACHINE_ID_FINTO, "/etc/machine-id")

def montato(percorso):
    try:
        return any(r.split()[4] == percorso for r in open("/proc/self/mountinfo"))
    except OSError:
        return False

def accendi():
    os.makedirs(CARTELLA, exist_ok=True)
    scrivi_torrc()
    for p, t in {**FILE, **file_rete(), **file_link()}.items():
        scrivi(p, t)
    open(STATO, "w").close()
    # prima il firewall: da adesso niente esce se non da Tor (anche mentre Tor si collega)
    comando("/usr/local/sbin/firewall-avvia", muto=False)
    comando("sysctl", "-q", "-p", "/etc/sysctl.d/99-fantasma.conf")
    comando("systemctl", "enable", "tor-fantasma.service")
    comando("fuser", "-k", "-n", "tcp", "9150")      # il Tor "privato" di Tor Browser, se aperto
    comando("systemctl", "restart", "tor-fantasma.service")
    comando("systemctl", "restart", "systemd-resolved.service")
    comando("systemctl", "restart", "systemd-journald.service")
    nascondi_identita()
    for s in schede():
        cambia_mac(s, mac_casuale())
    comando("networkctl", "reload")
    for s in schede():
        comando("networkctl", "reconfigure", s)
    comando("udevadm", "control", "--reload")
    comando("udevadm", "trigger", "--subsystem-match=video4linux", "--subsystem-match=sound")
    print("Modalita' fantasma accesa")
    return True

def spegni():
    for p in list(FILE) + list(file_rete()) + list(file_link()):
        togli_se_nostro(p)
    try:
        os.unlink(STATO)
    except FileNotFoundError:
        pass
    comando("/usr/local/sbin/firewall-avvia", muto=False)
    comando("systemctl", "disable", "--now", "tor-fantasma.service")
    for v in ("all", "default") + tuple(schede()):
        comando("sysctl", "-q", "-w", f"net.ipv6.conf.{v}.disable_ipv6=0")
    comando("systemctl", "restart", "systemd-resolved.service")
    comando("systemctl", "restart", "systemd-journald.service")
    if montato("/etc/machine-id"):
        comando("umount", "/etc/machine-id")
    try:
        comando("hostname", open("/etc/hostname").read().strip() or "localhost")
    except OSError:
        pass
    for s in schede():
        vero = mac_vero(s)
        if vero:
            cambia_mac(s, vero)
    comando("networkctl", "reload")
    for s in schede():
        comando("networkctl", "reconfigure", s)
    comando("udevadm", "control", "--reload")
    comando("udevadm", "trigger", "--subsystem-match=video4linux", "--subsystem-match=sound")
    print("Modalita' fantasma spenta")
    return True

def avvio():
    """All'accensione del computer (prima della rete): se la modalita' e' accesa,
    nasconde nome del computer e identificativo (la scheda di rete la camuffa udev)."""
    if acceso():
        nascondi_identita()
    return True

def attendi():
    """Per la finestra di avanzamento (yad --progress): numeri e testo, fino al 100%."""
    if not acceso():
        return False
    fine = time.time() + 180
    ultimo = -1
    while time.time() < fine:
        n = avanzamento()
        if n != ultimo:
            print(f"{n}\n# Collegamento alla rete Tor: {n}%", flush=True)
            ultimo = n
        if n >= 100:
            return True
        time.sleep(1)
    return False

AZIONI = {"accendi": accendi, "spegni": spegni, "avvio": avvio, "attendi": attendi,
          "stato": lambda: print("acceso" if acceso() else "spento") or True,
          "pronto": lambda: acceso() and avanzamento() >= 100}

if __name__ == "__main__":
    if os.geteuid() != 0:
        sys.exit("Serve root: usa  sudo fantasma-aiuto ...")
    if len(sys.argv) != 2 or sys.argv[1] not in AZIONI:
        sys.exit("Uso: fantasma-aiuto accendi|spegni|stato|pronto|attendi|avvio")
    sys.exit(0 if AZIONI[sys.argv[1]]() else 1)
EOF
cat > /usr/local/bin/fantasma << "EOF"
#!/bin/bash
# Modalita' fantasma (creato da lfs.sh): la finestra per accenderla e spegnerla.
# Accesa: tutto quello che fai online passa da Tor, il tuo indirizzo IP non si vede,
# la scheda di rete e il nome del computer sono camuffati, webcam e microfono spenti.
AIUTO=/usr/local/sbin/fantasma-aiuto
finestra() { yad --title "Modalità fantasma" --window-icon fantasma --center --fixed --width 540 "$@"; }
sicuro() { sed 's/&/\&amp;/g; s/</\&lt;/g'; }

sfondo() { setsid /usr/local/bin/sfondo-desktop >/dev/null 2>&1 < /dev/null & }

attendi_tor() {
  sudo -n "$AIUTO" attendi \
    | finestra --progress --image fantasma --auto-close --button "Nascondi:0" \
               --text "<b>Mi collego alla rete Tor...</b>
Di solito ci vuole meno di un minuto. Intanto internet è bloccato:
nessun dato esce senza passare da Tor."
}

accendi() {
  local msg
  if ! msg=$(sudo -n "$AIUTO" accendi 2>&1); then
    finestra --image dialog-error --button OK:0 \
             --text "<b>Non riesco ad accendere la modalità fantasma.</b>

<small>$(printf '%s' "$msg" | tail -n 3 | sicuro)</small>"
    return 1
  fi
  sfondo
  attendi_tor
  if sudo -n "$AIUTO" pronto; then
    notify-send -a "Modalità fantasma" -i fantasma "Modalità fantasma accesa" "Tutto passa da Tor" 2>/dev/null
    finestra --image fantasma --button OK:0 --text "<b>Modalità fantasma accesa.</b>

  - tutto quello che fai online passa da Tor: i siti non vedono il tuo indirizzo IP
  - scheda di rete e nome del computer camuffati
  - webcam e microfono spenti, niente registri sul disco

<b>Chiudi e riapri i programmi già aperti</b> (soprattutto i browser).
Per non farti riconoscere usa <b>Tor Browser</b> e non entrare nei tuoi account.
Resta accesa anche dopo un riavvio, finché non la spegni."
  else
    finestra --image dialog-warning --button OK:0 --text "<b>Tor non si è ancora collegato.</b>

Finché Tor non si collega internet resta bloccato (niente esce senza Tor).
Aspetta un po' e riapri questa finestra, oppure spegni la modalità fantasma."
  fi
}

spegni() {
  finestra --image dialog-warning --button "Annulla:1" --button "Spegni:0" \
           --text "<b>Spegnere la modalità fantasma?</b>

I siti torneranno a vedere il tuo indirizzo IP." || return 0
  sudo -n "$AIUTO" spegni >/dev/null 2>&1
  sfondo
  finestra --image dialog-information --button OK:0 \
           --text "<b>Modalità fantasma spenta.</b>  Chiudi e riapri i programmi già aperti."
}

if [ "$(id -un)" = fantasma ]; then
  finestra --image fantasma --button OK:0 --text "<b>Sei nell'utente fantasma.</b>

Qui la modalità fantasma è sempre accesa e quello che fai sta solo in memoria:
allo spegnimento sparisce tutto. Per tenere un file, salvalo su una chiavetta."
  exit 0
fi

case "$(sudo -n "$AIUTO" stato 2>/dev/null)" in
  acceso)
    if sudo -n "$AIUTO" pronto; then
      finestra --image fantasma --button "Spegni:2" --button "Chiudi:0" \
               --text "<b>La modalità fantasma è accesa.</b>  Tutto passa da Tor."
      [ $? -eq 2 ] && spegni
    else
      attendi_tor
      sudo -n "$AIUTO" pronto || finestra --image dialog-warning --button "Spegni:2" --button "Aspetta:0" \
        --text "<b>Tor non si è ancora collegato</b>: internet resta bloccato finché non si collega."
      [ $? -eq 2 ] && spegni
    fi ;;
  spento)
    finestra --image fantasma --button "Annulla:1" --button "Accendi:0" --text "<b>Modalità fantasma</b>

Accendendola:
  - <b>tutto</b> quello che fai online passa da Tor (non solo il browser):
    nessun sito, né il tuo fornitore di internet, vede cosa fai e da dove
  - Tor è nascosto: il fornitore di internet non vede nemmeno che lo usi
  - scheda di rete e nome del computer camuffati, niente IPv6
  - webcam e microfono spenti, niente registri sul disco

Internet sarà più lento e alcune cose non funzioneranno
(Spotify, molti giochi online, alcune banche)." && accendi ;;
  *)
    finestra --image dialog-error --button OK:0 --text "La modalità fantasma non risponde." ;;
esac
EOF
cat > /usr/local/sbin/firewall-avvia << "EOF"
#!/bin/bash
# Firewall (creato da lfs.sh, partendo dall'esempio "Personal Firewall" del libro BLFS)
#  - in ENTRATA passano solo le risposte a cio' che hai chiesto tu (piu' DHCP e IPv6 di base):
#    nessuno da fuori puo' collegarsi al tuo computer
#  - in USCITA i programmi del tuo utente passano dal Guardiano della rete, che ti chiede
#    il permesso; i servizi del sistema (rete, orologio, DNS) escono normalmente
#  - catena VPN: con la VPN sempre accesa i tuoi programmi escono SOLO dalla VPN
#  - MODALITA' FANTASMA (se accesa): TUTTO esce solo da Tor. I collegamenti dei programmi
#    vengono girati dentro Tor, i nomi dei siti li risolve Tor, il resto (UDP, IPv6,
#    rete locale, orologio) e' bloccato. Esce direttamente solo Tor stesso.
set -e
UTENTI=1000-59999
SEMPRE=/etc/wireguard/sempre-accesa
FANTASMA=/etc/fantasma/attivo

regole() { # 4 oppure 6
  echo '*filter'
  echo ':INPUT DROP [0:0]'
  echo ':FORWARD DROP [0:0]'
  echo ':OUTPUT ACCEPT [0:0]'
  echo ':VPN - [0:0]'
  echo '-A INPUT -i lo -j ACCEPT'
  echo '-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'
  if [ "$1" = 4 ]; then
    echo '-A INPUT -p udp --sport 67 --dport 68 -j ACCEPT'
  else
    echo '-A INPUT -p ipv6-icmp -j ACCEPT'
    echo '-A INPUT -s fe80::/10 -p udp --dport 546 -j ACCEPT'
  fi
  echo '-A OUTPUT -o lo -j ACCEPT'
  echo '-A OUTPUT -j VPN'
  echo '-A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'
  echo "-A OUTPUT -m owner --uid-owner $UTENTI -j NFQUEUE --queue-num 0"
  if [ -e "$SEMPRE" ]; then
    echo "-A VPN -m owner --uid-owner $UTENTI ! -o vpn -j REJECT"
  fi
  echo 'COMMIT'
}

regole_fantasma() { # 4 oppure 6: esce solo Tor
  echo '*filter'
  echo ':INPUT DROP [0:0]'
  echo ':FORWARD DROP [0:0]'
  echo ':OUTPUT DROP [0:0]'
  echo ':VPN - [0:0]'
  echo '-A INPUT -i lo -j ACCEPT'
  echo '-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'
  [ "$1" = 4 ] && echo '-A INPUT -p udp --sport 67 --dport 68 -j ACCEPT'
  # pacchetti "fuori posto" (es. dopo un collegamento chiuso): mai fuori da Tor
  echo '-A OUTPUT -m conntrack --ctstate INVALID -j DROP'
  echo '-A OUTPUT -o lo -j ACCEPT'
  if [ "$1" = 4 ]; then
    # i collegamenti girati dentro Tor: qui la scheda risulta ancora quella di uscita
    # (il kernel decide "-o" prima del giro), per questo si guarda la destinazione
    echo '-A OUTPUT -d 127.0.0.1/32 -p tcp --dport 9040 -j ACCEPT'
    echo '-A OUTPUT -d 127.0.0.1/32 -p udp --dport 9053 -j ACCEPT'
    echo '-A OUTPUT -m owner --uid-owner tor -j ACCEPT'
    echo '-A OUTPUT -p udp --dport 67 -m owner --uid-owner systemd-network -j ACCEPT'
  fi
  # pacchetti del kernel senza programma (la VPN WireGuard, se accesa, porta Tor dentro la VPN)
  echo '-A OUTPUT -m owner ! --socket-exists -j ACCEPT'
  echo '-A OUTPUT -j REJECT'
  echo 'COMMIT'
}

nat_fantasma() { # i collegamenti TCP e i nomi dei siti vanno dentro Tor
  echo '*nat'
  echo ':PREROUTING ACCEPT [0:0]'
  echo ':INPUT ACCEPT [0:0]'
  echo ':OUTPUT ACCEPT [0:0]'
  echo ':POSTROUTING ACCEPT [0:0]'
  echo '-A OUTPUT -m owner --uid-owner tor -j RETURN'
  echo '-A OUTPUT -o lo -j RETURN'
  echo '-A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 9053'
  echo '-A OUTPUT -p tcp --syn -j REDIRECT --to-ports 9040'
  echo 'COMMIT'
}

applica() {
  if [ -e "$FANTASMA" ]; then
    nat_fantasma | iptables-restore
    regole_fantasma 4 | iptables-restore
    regole_fantasma 6 | ip6tables-restore
    # il Guardiano chiede anche in modalita' fantasma (prima che il collegamento entri in Tor)
    iptables -t mangle -F OUTPUT
    iptables -t mangle -A OUTPUT ! -o lo -m owner --uid-owner "$UTENTI" -m conntrack --ctstate NEW \
             -p tcp --syn -j NFQUEUE --queue-num 0
    iptables -t mangle -A OUTPUT ! -o lo -m owner --uid-owner "$UTENTI" -m conntrack --ctstate NEW \
             -p udp --dport 53 -j NFQUEUE --queue-num 0
  else
    regole 4 | iptables-restore
    regole 6 | ip6tables-restore
    iptables -t nat -F OUTPUT 2>/dev/null || true
    iptables -t mangle -F OUTPUT 2>/dev/null || true
  fi
}

case "${1:-avvia}" in
  avvia)
    applica ;;
  prova)
    regole 4 | iptables-restore --test
    regole 6 | ip6tables-restore --test
    if [ -e "$FANTASMA" ]; then
      nat_fantasma | iptables-restore --test
      regole_fantasma 4 | iptables-restore --test
      regole_fantasma 6 | ip6tables-restore --test
    fi
    echo "Regole del firewall corrette" ;;
  mostra)
    if [ -e "$FANTASMA" ]; then nat_fantasma; regole_fantasma "${2:-4}"; else regole "${2:-4}"; fi ;;
esac
EOF
cat > /usr/local/bin/tor-browser << "EOF"
#!/bin/sh
# Tor Browser (creato da lfs.sh): i siti non vedono il tuo indirizzo IP.
# In modalita' fantasma usa il Tor del sistema (niente "Tor dentro Tor").
# L'utente fantasma ha una sua copia in memoria (sparisce allo spegnimento).
TB=/opt/tor-browser
if [ "$(id -un)" = fantasma ]; then
  TB="$HOME/.tor-browser"
  if [ ! -x "$TB/Browser/start-tor-browser" ]; then
    notify-send -a "Tor Browser" -i fantasma "Tor Browser" "Lo preparo (qualche secondo)..." 2>/dev/null
    rm -rf "$TB"
    cp -a /usr/local/lib/fantasma/tor-browser "$TB" || exit 1
  fi
fi
if [ -e /etc/fantasma/attivo ]; then
  TOR_PROVIDER=none TOR_SOCKS_HOST=127.0.0.1 TOR_SOCKS_PORT=9150
  export TOR_PROVIDER TOR_SOCKS_HOST TOR_SOCKS_PORT
fi
exec "$TB/Browser/start-tor-browser" --detach "$@"
EOF
cat > /usr/local/bin/sfondo-desktop << "EOF"
#!/bin/sh
# Sfondo del desktop (creato da lfs.sh). Si sceglie da Impostazioni -> Aspetto (la
# scelta e' in ~/.config/sfondo.conf). In modalita' fantasma diventa quello scuro,
# cosi' si vede subito se e' accesa.
img=$(sed -n 's/^SFONDO=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/sfondo.conf" 2>/dev/null | head -n1)
[ -n "$img" ] && [ -f "$img" ] || img=/usr/share/backgrounds/sfondo-desktop.png
if [ -e /etc/fantasma/attivo ] && [ -f /usr/share/backgrounds/sfondo-fantasma.png ]; then
  img=/usr/share/backgrounds/sfondo-fantasma.png
fi
pkill -u "$(id -u)" -x swaybg
exec swaybg -i "$img" -m fill
EOF
cat > /usr/local/lib/fantasma/avviso-fantasma << "EOF"
#!/bin/sh
# Creato da lfs.sh: in modalita' fantasma, prima di aprire Firefox o Thunderbird avvisa
# che possono farti riconoscere (account, cookie, impronta del programma).
# Si usa come /usr/local/bin/firefox e /usr/local/bin/thunderbird.
nome=$(basename "$0")
vero="/usr/bin/$nome"
if [ -e /etc/fantasma/attivo ]; then
  case "$nome" in
    firefox)
      yad --title "Modalità fantasma" --window-icon fantasma --image dialog-warning --center --fixed --width 500 \
          --text "<b>Sei in modalità fantasma.</b>

Firefox passa da Tor, ma i siti possono riconoscerti lo stesso
(cookie, account, impronta del browser). Per non farti riconoscere
usa <b>Tor Browser</b>." \
          --button "Annulla:1" --button "Apri Tor Browser:2" --button "Apri Firefox lo stesso:0"
      case $? in
        0) ;;
        2) exec /usr/local/bin/tor-browser "$@" ;;
        *) exit 0 ;;
      esac ;;
    *)
      yad --title "Modalità fantasma" --window-icon fantasma --image dialog-warning --center --fixed --width 500 \
          --text "<b>Sei in modalità fantasma.</b>

La posta passa da Tor, ma entrando nel tuo account di posta
chi gestisce la posta sa che sei tu." \
          --button "Annulla:1" --button "Apri lo stesso:0" || exit 0 ;;
  esac
fi
exec "$vero" "$@"
EOF
cat > /usr/local/lib/fantasma/disegna-fantasma << "EOF"
#!/usr/bin/python3 -I
# Disegna lo sfondo scuro e l'icona della modalita' fantasma (PNG, solo Python).
#   disegna-fantasma sfondo FILE.png      1920x1080
#   disegna-fantasma icona FILE.png LATO  icona quadrata (es. 48, 64, 128)
import math, struct, sys, zlib

def png(percorso, larghezza, altezza, pixel, alfa):
    righe = bytearray()
    for y in range(altezza):
        righe.append(0)
        righe += pixel[y]
    def blocco(tipo, dati):
        return struct.pack(">I", len(dati)) + tipo + dati + struct.pack(">I", zlib.crc32(tipo + dati) & 0xffffffff)
    with open(percorso, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(blocco(b"IHDR", struct.pack(">IIBBBBB", larghezza, altezza, 8, 6 if alfa else 2, 0, 0, 0)))
        f.write(blocco(b"IDAT", zlib.compress(bytes(righe), 9)))
        f.write(blocco(b"IEND", b""))

def dentro_fantasma(x, y):
    """Fantasmino in un quadrato 0..1: testa tonda, corpo, bordo in basso ondulato.
    -> 0 fuori, 1 corpo, 2 occhi"""
    cx, testa, raggio = 0.5, 0.38, 0.27
    for ox in (0.41, 0.59):                                   # occhi
        if ((x - ox) / 0.045) ** 2 + ((y - 0.37) / 0.065) ** 2 <= 1:
            return 2
    if ((x - cx) / 0.04) ** 2 + ((y - 0.52) / 0.05) ** 2 <= 1:   # bocca "oh"
        return 2
    if (x - cx) ** 2 + (y - testa) ** 2 <= raggio ** 2:
        return 1
    if testa <= y <= 0.95:                                     # lenzuolo che si allarga in basso
        meta = raggio * (1 + 0.28 * (y - testa) / (0.95 - testa))
        if abs(x - cx) <= meta:
            fondo = 0.86 + 0.05 * math.sin((x - (cx - meta)) / (2 * meta) * 2.5 * 2 * math.pi + 0.6)
            if y <= fondo:
                return 1
    return 0

def sfondo(percorso):
    L, A = 1920, 1080
    alto, basso = (0x24, 0x14, 0x3a), (0x08, 0x06, 0x12)
    lato = 300                                                 # il fantasma, in basso a destra
    gx, gy = L - lato - 140, A - lato - 120
    pixel = []
    for y in range(A):
        riga = bytearray()
        fy = y / (A - 1)
        for x in range(L):
            fx = x / (L - 1)
            t = fx * 0.35 + fy * 0.65
            c = [alto[i] + (basso[i] - alto[i]) * t for i in range(3)]
            d2 = ((fx - 0.22) * L / A) ** 2 + (fy - 0.25) ** 2      # alone viola
            if d2 < 1.0:
                k = 0.35 * math.exp(-4.0 * d2)
                c = [c[i] + ((0x61, 0x35, 0x83)[i] - c[i]) * k for i in range(3)]
            if gx <= x < gx + lato and gy <= y < gy + lato:
                v = dentro_fantasma((x - gx) / lato, (y - gy) / lato)
                if v == 1:
                    c = [c[i] + ((0xc0, 0xb0, 0xe8)[i] - c[i]) * 0.18 for i in range(3)]
            s = ((x * 7 + y * 13) & 3) * 0.25 - 0.375
            riga += bytes(min(255, max(0, int(v + s + 0.5))) for v in c)
        pixel.append(riga)
    png(percorso, L, A, pixel, False)

def icona(percorso, lato):
    campioni = 4                                               # bordi morbidi
    pixel = []
    for y in range(lato):
        riga = bytearray()
        for x in range(lato):
            corpo = occhi = 0
            for sy in range(campioni):
                for sx in range(campioni):
                    v = dentro_fantasma((x + (sx + 0.5) / campioni) / lato, (y + (sy + 0.5) / campioni) / lato)
                    corpo += v == 1
                    occhi += v == 2
            n = campioni * campioni
            a = (corpo + occhi) / n
            if a == 0:
                riga += bytes((0, 0, 0, 0))
                continue
            k = occhi / (corpo + occhi)
            c = [int((0xf0, 0xec, 0xff)[i] * (1 - k) + (0x2a, 0x1a, 0x45)[i] * k) for i in range(3)]
            riga += bytes(c + [int(a * 255)])
        pixel.append(riga)
    png(percorso, lato, lato, pixel, True)

if __name__ == "__main__":
    if sys.argv[1:2] == ["sfondo"]:
        sfondo(sys.argv[2])
    elif sys.argv[1:2] == ["icona"]:
        icona(sys.argv[2], int(sys.argv[3]))
    else:
        sys.exit("Uso: disegna-fantasma sfondo FILE | icona FILE LATO")
EOF
chmod 755 /usr/local/sbin/fantasma-aiuto /usr/local/bin/fantasma /usr/local/sbin/firewall-avvia \
          /usr/local/bin/tor-browser /usr/local/bin/sfondo-desktop \
          /usr/local/lib/fantasma/avviso-fantasma /usr/local/lib/fantasma/disegna-fantasma
for t in /usr/local/sbin/fantasma-aiuto /usr/local/lib/fantasma/disegna-fantasma; do
  python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$t"
done
for t in /usr/local/bin/fantasma /usr/local/sbin/firewall-avvia; do bash -n "$t"; done
for t in /usr/local/bin/tor-browser /usr/local/bin/sfondo-desktop /usr/local/lib/fantasma/avviso-fantasma; do sh -n "$t"; done
# Firefox e Thunderbird: in modalita' fantasma avvisano prima di aprirsi
for t in firefox thunderbird; do
  if [ -e "/usr/bin/$t" ]; then ln -sfv ../lib/fantasma/avviso-fantasma "/usr/local/bin/$t"; fi
done

# --- sfondo scuro e icona del fantasma ---
/usr/local/lib/fantasma/disegna-fantasma sfondo /usr/share/backgrounds/sfondo-fantasma.png
for t in 32 48 64 128 256; do
  install -vdm755 "/usr/share/icons/hicolor/${t}x${t}/apps"
  /usr/local/lib/fantasma/disegna-fantasma icona "/usr/share/icons/hicolor/${t}x${t}/apps/fantasma.png" "$t"
done
gtk-update-icon-cache -qtf /usr/share/icons/hicolor

# --- servizi: Tor (acceso solo in modalita' fantasma) e la parte che agisce all'accensione ---
cat > /etc/systemd/system/tor-fantasma.service << "EOF"
[Unit]
Description=Tor per la modalita' fantasma (lfs.sh)
After=network-online.target firewall.service
Wants=network-online.target

[Service]
User=tor
Group=tor
RuntimeDirectory=tor-fantasma
RuntimeDirectoryMode=0750
ExecStartPre=/usr/bin/tor -f /etc/tor/fantasma.torrc --verify-config --quiet
ExecStart=/usr/bin/tor -f /etc/tor/fantasma.torrc --RunAsDaemon 0
Restart=on-failure
RestartSec=5
NoNewPrivileges=yes
ProtectSystem=strict
ReadWritePaths=/var/lib/tor
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/fantasma-avvio.service << "EOF"
[Unit]
Description=Modalita' fantasma: nome del computer e identificativo nascosti (lfs.sh)
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target systemd-networkd.service dbus.service sysinit.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/fantasma-aiuto avvio

[Install]
WantedBy=sysinit.target
EOF
systemctl enable fantasma-avvio.service

cat > /etc/sudoers.d/30-fantasma << "EOF"
# Creato da lfs.sh: chi e' nel gruppo wheel accende e spegne la modalita' fantasma
# senza password (solo questo comando)
%wheel ALL=(root) NOPASSWD: /usr/local/sbin/fantasma-aiuto
EOF
chmod 440 /etc/sudoers.d/30-fantasma
visudo -c

cat > /usr/share/applications/fantasma.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Modalità fantasma
Comment=Tutto quello che fai online passa da Tor: nessuno vede chi sei
Exec=/usr/local/bin/fantasma
Icon=fantasma
Terminal=false
Categories=Network;Security;
EOF

# --- lo sfondo cambia con la modalita' (si vede subito se e' accesa) ---
sed -i 's|^swaybg -i /usr/share/backgrounds/sfondo-desktop.png -m fill >/dev/null 2>&1 &$|/usr/local/bin/sfondo-desktop >/dev/null 2>\&1 \&|' \
    /etc/xdg/labwc/autostart
grep -q '^/usr/local/bin/sfondo-desktop ' /etc/xdg/labwc/autostart \
  || { echo "Non riesco a cambiare lo sfondo all'avvio del desktop"; return 1; }

# --- pulsante nella barra in basso (prima dell'orologio) ---
if ! grep -q 'fantasma.desktop' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml; then
  sed -i -e 's|^        <value type="int" value="13"/>$|        <value type="int" value="13"/>\n        <value type="int" value="14"/>|' \
         -e 's|^    <property name="plugin-9" type="string" value="clock">$|    <property name="plugin-14" type="string" value="launcher">\n      <property name="items" type="array">\n        <value type="string" value="/usr/share/applications/fantasma.desktop"/>\n      </property>\n    </property>\n    <property name="plugin-9" type="string" value="clock">|' \
         /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
  [ "$(grep -c 'value="14"\|"plugin-14"\|fantasma.desktop' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml)" -ge 3 ] \
    || { echo "Non riesco ad aggiungere il pulsante alla barra"; return 1; }
  rm -rf "$casa/.config/xfce4/panel" "$casa/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
fi
update-desktop-database /usr/share/applications
echo "[OK] Modalita' fantasma pronta (pulsante nella barra in basso)"
}

f7_utente_fantasma() {
# NON IN BLFS: l'utente "fantasma". La sua cartella home e' in memoria (tmpfs): ogni
# accensione riparte pulita e allo spegnimento sparisce tutto. Accedendo con lui la
# modalita' fantasma si accende da sola (e da li' non si puo' spegnere).
local uid gid
id fantasma >/dev/null 2>&1 || useradd -M -d /home/fantasma -s /bin/bash \
    -c "Utente fantasma (tutto in memoria)" -G video,input,audio fantasma
uid=$(id -u fantasma); gid=$(id -g fantasma)
install -vdm755 /home/fantasma
rm -rf /usr/local/share/fantasma/casa
mkdir -p /usr/local/share/fantasma/casa/.config
cat > /usr/local/share/fantasma/casa/.bash_profile << "EOF"
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
EOF
touch /usr/local/share/fantasma/casa/.config/benvenuto-fatto
bash -n /usr/local/share/fantasma/casa/.bash_profile
cat > /etc/systemd/system/home-fantasma.mount << EOF
[Unit]
Description=Casa dell'utente fantasma (in memoria: si cancella allo spegnimento)

[Mount]
What=tmpfs
Where=/home/fantasma
Type=tmpfs
Options=mode=0700,uid=$uid,gid=$gid,size=40%,nosuid,nodev

[Install]
WantedBy=local-fs.target
EOF
cat > /etc/systemd/system/fantasma-casa.service << "EOF"
[Unit]
Description=Prepara la casa (in memoria) dell'utente fantasma
Requires=home-fantasma.mount
After=home-fantasma.mount
Before=systemd-user-sessions.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'cp -a /usr/local/share/fantasma/casa/. /home/fantasma/ && chown -R fantasma: /home/fantasma'

[Install]
WantedBy=multi-user.target
EOF
systemctl enable home-fantasma.mount fantasma-casa.service
cat > /etc/sudoers.d/31-utente-fantasma << "EOF"
# Creato da lfs.sh: l'utente fantasma accende la modalita' fantasma (non la spegne)
fantasma ALL=(root) NOPASSWD: /usr/local/sbin/fantasma-aiuto accendi, /usr/local/sbin/fantasma-aiuto stato, /usr/local/sbin/fantasma-aiuto pronto, /usr/local/sbin/fantasma-aiuto attendi
EOF
chmod 440 /etc/sudoers.d/31-utente-fantasma
visudo -c
echo "[OK] Utente fantasma pronto (si entra con il nome: fantasma)"
}

LISTA_STEP14=(
  "libevent|libevent-2.1.13-stable.tar.gz|f7_libevent"
  "Tor (per tutto il sistema)|tor-0.4.9.14.tar.gz|f7_tor"
  "ponti e Tor Browser per il fantasma|-|f7_ponti"
  "modalita' fantasma|-|f7_fantasma"
  "utente fantasma (tutto in memoria)|-|f7_utente_fantasma"
)

chiedi_password_fantasma() {
  if montato && [ -e "$STATO_DIR/fatto/password-fantasma" ]; then return 0; fi
  [ -z "${PASSWORD_FANTASMA:-}" ] || return 0
  [ -t 0 ] || { avviso "Nessun terminale: la password dell'utente fantasma la imposterai dopo (da root: passwd fantasma)"; return 0; }
  local p1 p2
  info "L'utente 'fantasma' entra nel desktop con la modalita' fantasma accesa e non lascia tracce."
  while true; do
    read -r -s -p "  Scegli la password dell'utente fantasma: " p1; echo
    read -r -s -p "  Riscrivila: " p2; echo
    if [ -z "$p1" ]; then avviso "La password non puo' essere vuota"
    elif [ "$p1" != "$p2" ]; then avviso "Le due password sono diverse, riprova"
    else break; fi
  done
  PASSWORD_FANTASMA=$p1
  ok "Password ricevuta"
}

imposta_password_fantasma() {
  [ -e "$STATO_DIR/fatto/password-fantasma" ] && return 0
  [ -n "${PASSWORD_FANTASMA:-}" ] || { avviso "Password dell'utente fantasma non impostata: entra come root e scrivi  passwd fantasma"; return 0; }
  monta_vfs
  if printf 'fantasma:%s\n' "$PASSWORD_FANTASMA" | entra_chroot /usr/sbin/chpasswd; then
    touch "$STATO_DIR/fatto/password-fantasma"; ok "Password dell'utente fantasma impostata"
  else
    avviso "Non sono riuscito a impostare la password: entra come root e scrivi  passwd fantasma"
  fi
  smonta_vfs
}

completa_fasi_precedenti() { # numero dell'ultima lista da controllare (7 = Fase 2 ... 16 = Fase 9)
  local n c fatti tot
  for n in 7 8 9 10 11 12 13 14 15 16; do
    [ "$n" -le "$1" ] || break
    declare -n lista_n="LISTA_STEP$n"
    fatti=$(quanti_fatti "${lista_n[@]}"); tot=${#lista_n[@]}
    unset -n lista_n
    [ "$fatti" -lt "$tot" ] || continue
    case $n in
      7) c=fase2 ;; 8) c=fase2b ;; 9) c=fase2c ;; 10) c=fase3 ;; 11) c=fase4 ;; 12) c=fase5 ;; 13) c=fase6 ;;
      14) c=fase7 ;; 15) c=fase8 ;; 16) c=fase9 ;;
    esac
    info "La $c ha parti nuove o non finite: le faccio adesso ($fatti/$tot fatte)."
    "cmd_$c" "$c"
  done
}

cmd_fase7() {
  serve_root fase7
  titolo "Fase 7 - Modalita' fantasma: tutto da Tor, niente tracce"
  assicura_montato
  # le fasi precedenti con parti nuove (aggiunte dopo) o non finite si completano prima;
  # poi serve il kernel con il firewall completo (anche la parte NAT)
  # le domande subito, cosi' poi lavora da solo fino alla fine
  chiedi_utente
  chiedi_password_fantasma
  completa_fasi_precedenti 13
  if ! kernel_ha_sicurezza; then
    info "Prima finisco la Fase 6 (sicurezza), poi passo alla modalita' fantasma."
    cmd_fase6 fase6
  fi
  titolo "Fase 7 - Modalita' fantasma: tutto da Tor, niente tracce"
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP14[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 7 da capo (opzione 'rifai')"
  fi
  titolo "Scarico i sorgenti della Fase 7 (circa 12 MB)"
  scarica_fonti "${FONTI_FASE7[@]}"
  scarica_tor_browser
  info "Ci vogliono circa 5-10 minuti. Lascia il terminale aperto."
  local esito=0
  lancia_in_chroot 14 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase7 MIA_ETICHETTA="Fase 7" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  imposta_password_fantasma
  titolo "FASE 7 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia). Novita':"
  info "   Pulsante col fantasma nella barra in basso: accende/spegne la modalita' fantasma"
  info "   (tutto passa da Tor, IP nascosto, scheda di rete camuffata, sfondo scuro)"
  info "   Utente 'fantasma': entra con lui per una sessione che non lascia tracce"
  info "   Ponti personali (facoltativi): /etc/fantasma/ponti"
}

# =============================================================================
#  FASE 8 - ASPETTO ELEGANTE (simile a macOS)
#   - finestre chiare con il titolo al centro e, a sinistra, tre cerchi colorati:
#     rosso chiude, giallo riduce, verde ingrandisce (passandoci sopra compare il segno)
#   - in alto una barra sottile e trasparente: menu Applicazioni, modalita' fantasma,
#     volume, Impostazioni, data e ora, spegnimento
#   - in basso il "dock" con gli angoli tondi: le app preferite e le finestre aperte
#   - tema "Elegante" per i programmi (azzurro, angoli morbidi), sfondo nuovo,
#     ricerca delle app al centro dello schermo, notifiche chiare, blocco schermo
#   - Impostazioni piu' solide: Schermo (risoluzione e grandezza) e Aspetto (sfondo,
#     anche una tua immagine, e finestre chiare o scure). Se qualcosa non si apre,
#     il motivo e' scritto in ~/.cache/impostazioni.log
#  Niente di questo e' nel libro BLFS ("# NON IN BLFS"): sono file di configurazione e
#  immagini disegnate qui con Python. Nessun logo o marchio di altri: il simbolo della
#  distro e i pulsanti sono disegnati da zero.
# =============================================================================

f8_immagini() {
# NON IN BLFS: le immagini dell'aspetto "Elegante" (solo Python, niente da scaricare):
# due sfondi, il simbolo della distro, l'icona "Tutte le app", i pulsanti delle finestre
install -vdm755 /usr/local/lib/elegante /usr/share/backgrounds /usr/share/themes/Elegante/labwc
cat > /usr/local/lib/elegante/disegna-elegante << "EOF"
#!/usr/bin/python3 -I
# Disegna le immagini dell'aspetto "Elegante" (creato da lfs.sh), solo Python:
#   disegna-elegante sfondo FILE.png [chiaro|scuro]   sfondo 1920x1080 a onde morbide
#   disegna-elegante logo FILE.png LATO               il simbolo della distro (menu in alto)
#   disegna-elegante griglia FILE.png LATO            l'icona di "Tutte le app"
#   disegna-elegante pulsanti CARTELLA                i pulsanti tondi colorati delle finestre
#   disegna-elegante icona SIMBOLO FILE.png LATO      icona "squircle" di un'app (Fase 9)
import math, os, struct, sys, zlib

def png(percorso, larghezza, altezza, righe, alfa):
    dati = bytearray()
    for r in righe:
        dati.append(0)
        dati += r
    def blocco(tipo, d):
        return struct.pack(">I", len(d)) + tipo + d + struct.pack(">I", zlib.crc32(tipo + d) & 0xffffffff)
    with open(percorso, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(blocco(b"IHDR", struct.pack(">IIBBBBB", larghezza, altezza, 8, 6 if alfa else 2, 0, 0, 0)))
        f.write(blocco(b"IDAT", zlib.compress(bytes(dati), 9)))
        f.write(blocco(b"IEND", b""))

def colore(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def mescola(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def morbido(x):                       # 0..1 con bordi dolci
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)

# ------------------------------------------------------------------- sfondo
def sfondo(percorso, tono="chiaro"):
    L, A = 1920, 1080
    if tono == "scuro":
        angoli = [colore("#141a3a"), colore("#2a1b4d"), colore("#3d1f3f"), colore("#0d2a3f")]
        onde = [(colore("#5b6cff"), 0.35), (colore("#b45cff"), 0.30), (colore("#ff7a8a"), 0.22)]
    else:
        angoli = [colore("#4f9dff"), colore("#8b6dff"), colore("#ff9a85"), colore("#4cc9f0")]
        onde = [(colore("#ffffff"), 0.42), (colore("#d9c9ff"), 0.55), (colore("#ffe3d3"), 0.55)]
    # tre onde: altezza di base, ampiezza, lunghezza, fase, spessore
    forme = [(0.58, 0.10, 1.25, 0.3, 0.16), (0.70, 0.08, 0.95, 2.1, 0.14), (0.84, 0.06, 1.6, 4.0, 0.12)]
    righe = []
    for y in range(A):
        fy = y / (A - 1)
        riga = bytearray()
        for x in range(L):
            fx = x / (L - 1)
            alto = mescola(angoli[0], angoli[1], fx)
            basso = mescola(angoli[3], angoli[2], fx)
            c = mescola(alto, basso, morbido(fy))
            for (col, forza), (base, amp, lung, fase, spess) in zip(onde, forme):
                centro = base + amp * math.sin(fx * 2 * math.pi / lung + fase) \
                    + 0.025 * math.sin(fx * 9.0 + fase * 2)
                d = (fy - centro) / spess
                if -1.6 < d < 1.0:
                    # sopra l'onda sfuma piano, sotto il bordo e' piu' netto
                    k = forza * (morbido(1 - abs(d) / 1.6) if d < 0 else morbido(1 - d))
                    c = mescola(c, col, k)
            s = ((x * 7 + y * 13) & 3) * 0.25 - 0.375          # niente righe nelle sfumature
            riga += bytes(min(255, max(0, int(v + s + 0.5))) for v in c)
        righe.append(riga)
    png(percorso, L, A, righe, False)

# ------------------------------------------------------------------- dischi
def disegna(lato, funzione, campioni=4):
    """funzione(x, y) con x,y in 0..1 -> (r, g, b, a 0..1) oppure None; bordi morbidi"""
    righe = []
    for y in range(lato):
        riga = bytearray()
        for x in range(lato):
            somma = [0.0, 0.0, 0.0, 0.0]
            for sy in range(campioni):
                for sx in range(campioni):
                    v = funzione((x + (sx + 0.5) / campioni) / lato, (y + (sy + 0.5) / campioni) / lato)
                    if v:
                        r, g, b, a = v
                        somma[0] += r * a; somma[1] += g * a; somma[2] += b * a; somma[3] += a
            n = campioni * campioni
            a = somma[3] / n
            if a <= 0:
                riga += bytes((0, 0, 0, 0))
            else:
                riga += bytes((int(somma[0] / somma[3]), int(somma[1] / somma[3]), int(somma[2] / somma[3]),
                               int(a * 255 + 0.5)))
        righe.append(riga)
    return righe

def logo(percorso, lato):
    """Un cerchio con sfumatura azzurro-viola e un anello bianco (simbolo della distro)."""
    a, b = colore("#2f8bff"), colore("#a55bff")
    def f(x, y):
        d = math.hypot(x - 0.5, y - 0.5)
        if d > 0.46:
            return None
        if 0.20 < d < 0.29 or (0.30 < x < 0.70 and abs(y - 0.5) < 0.04 and d < 0.20):
            return (255, 255, 255, 1.0)
        c = mescola(a, b, morbido((x + y) / 2))
        return (*c, 1.0)
    png(percorso, lato, lato, disegna(lato, f), True)

def griglia(percorso, lato):
    """Icona di "Tutte le app": quadrato arrotondato azzurro con nove puntini bianchi."""
    a, b = colore("#38b6ff"), colore("#6a5cff")
    def f(x, y):
        # quadrato con gli angoli molto arrotondati
        m, r = 0.06, 0.22
        dx = max(abs(x - 0.5) - (0.5 - m - r), 0.0)
        dy = max(abs(y - 0.5) - (0.5 - m - r), 0.0)
        if math.hypot(dx, dy) > r:
            return None
        for cy in (0.31, 0.5, 0.69):
            for cx in (0.31, 0.5, 0.69):
                if math.hypot(x - cx, y - cy) < 0.065:
                    return (255, 255, 255, 1.0)
        return (*mescola(a, b, morbido((x * 0.4 + y * 0.6))), 1.0)
    png(percorso, lato, lato, disegna(lato, f), True)

# --------------------------------------------------------- icone delle app
def _squircle(x, y, m=0.045, r=0.30):
    """Dentro al quadrato con gli angoli molto arrotondati (stile icone macOS)?"""
    dx = max(abs(x - 0.5) - (0.5 - m - r), 0.0)
    dy = max(abs(y - 0.5) - (0.5 - m - r), 0.0)
    return math.hypot(dx, dy) <= r

def _linea(x, y, x1, y1, x2, y2, spessore):
    """Distanza (in unita' dell'icona) dal segmento (x1,y1)-(x2,y2) <= spessore?"""
    dx, dy = x2 - x1, y2 - y1
    l2 = dx * dx + dy * dy
    t = 0 if l2 == 0 else max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / l2))
    px, py = x1 + t * dx, y1 + t * dy
    return math.hypot(x - px, y - py) <= spessore

_SIMBOLI = {}
def _simbolo(nome):
    def _(f): _SIMBOLI[nome] = f; return f
    return _

@_simbolo("globo")                                       # browser: un mondo stilizzato
def _g_globo(x, y):
    d = math.hypot(x - 0.5, y - 0.5)
    if not (0.27 < d < 0.33):
        if abs(x - 0.5) < 0.017 and d < 0.30:
            return True
        if abs(y - 0.5) < 0.017 and d < 0.30:
            return True
        if abs((x - 0.5) * 2.1) < 0.14 and abs(d - 0.0) < 0.30 \
           and abs(math.hypot((x - 0.5) * 2.1, y - 0.5) - 0.30) < 0.017:
            return True
        return False
    return True

@_simbolo("cartella")                                     # gestore file: una cartella
def _g_cartella(x, y):
    corpo = 0.20 < x < 0.80 and 0.40 < y < 0.74
    coperchio = 0.20 < x < 0.44 and 0.32 < y < 0.40
    return corpo or coperchio

@_simbolo("busta")                                         # posta: una busta con la "V"
def _g_busta(x, y):
    bordo = 0.18 < x < 0.82 and 0.32 < y < 0.68
    if not bordo:
        return False
    cornice = x < 0.22 or x > 0.78 or y < 0.36 or y > 0.64
    if cornice:
        return True
    return _linea(x, y, 0.18, 0.32, 0.50, 0.54, 0.028) or _linea(x, y, 0.82, 0.32, 0.50, 0.54, 0.028)

def _pagina(x, y, righe_colore=None):
    """Un foglio verticale con tre righe di "testo"; righe_colore: colore delle righe (altrimenti bianco)."""
    foglio = 0.31 < x < 0.69 and 0.20 < y < 0.80
    if not foglio:
        return None
    for ry in (0.36, 0.48, 0.60):
        if abs(y - ry) < 0.028 and x < 0.62:
            return righe_colore if righe_colore else False
    return True

@_simbolo("documento")                                     # editor di testo: un foglio
def _g_documento(x, y):
    return bool(_pagina(x, y))

@_simbolo("terminale")                                     # terminale: finestra con ">_"
def _g_terminale(x, y):
    cornice = (0.20 < x < 0.80 and 0.26 < y < 0.74) and \
              (x < 0.235 or x > 0.765 or y < 0.295 or y > 0.705)
    if cornice:
        return True
    chevron = _linea(x, y, 0.33, 0.40, 0.44, 0.50, 0.030) or _linea(x, y, 0.33, 0.60, 0.44, 0.50, 0.030)
    cursore = 0.48 < x < 0.60 and 0.565 < y < 0.60
    return chevron or cursore

@_simbolo("ingranaggio")                                   # impostazioni: una ruota dentata
def _g_ingranaggio(x, y):
    dx, dy = x - 0.5, y - 0.5
    d = math.hypot(dx, dy)
    ang = math.atan2(dy, dx)
    dente = 0.025 * (1 + math.cos(ang * 8))
    if 0.14 < d < 0.30 + dente:
        return d > 0.155
    return False

@_simbolo("accensione")                                     # spegnimento: simbolo di accensione
def _g_accensione(x, y):
    dx, dy = x - 0.5, y - 0.5
    d = math.hypot(dx, dy)
    ang = math.degrees(math.atan2(dy, dx))
    anello = 0.24 < d < 0.30 and not (-125 < ang < -55)
    asta = abs(dx) < 0.017 and -0.30 < dy < -0.03
    return anello or asta

def icona_app(percorso, lato, simbolo, c1, c2=None):
    """Icona "squircle" (stile macOS): sfondo a colore pieno (o sfumato c1->c2) col
    simbolo bianco al centro. Disegni originali, non copie di icone esistenti."""
    a = colore(c1); b = colore(c2) if c2 else a
    g = _SIMBOLI[simbolo]
    def f(x, y):
        if not _squircle(x, y):
            return None
        v = g(x, y)
        if v is True:
            return (255, 255, 255, 1.0)
        fondo = mescola(a, b, morbido((x + y) / 2))
        if isinstance(v, str):
            return (*mescola(fondo, colore(v), 0.55), 1.0)
        return (*fondo, 1.0)
    png(percorso, lato, lato, disegna(lato, f), True)

def pulsanti(cartella):
    """Tre dischi colorati (chiudi, riduci, ingrandisci). Passandoci sopra col mouse
    compare il simbolo; nelle finestre non attive sono grigi."""
    os.makedirs(cartella, exist_ok=True)
    lato, r = 40, 0.30
    colori = {"close": ("#ff5f57", "#e0443e"), "iconify": ("#febc2e", "#dea123"), "max": ("#28c840", "#1aab29")}
    def simbolo(tipo, x, y):
        dx, dy = x - 0.5, y - 0.5
        t = 0.035                                            # spessore del segno
        if tipo == "close":
            return (abs(dx - dy) < t * 1.4 or abs(dx + dy) < t * 1.4) and abs(dx) < 0.13 and abs(dy) < 0.13
        if tipo == "iconify":
            return abs(dy) < t and abs(dx) < 0.15
        return (abs(dy) < t and abs(dx) < 0.15) or (abs(dx) < t and abs(dy) < 0.15)
    for tipo, (pieno, bordo) in colori.items():
        for stato in ("active", "inactive", "hover-active", "hover-inactive"):
            inattivo = stato == "inactive"
            col = colore("#d4d4d8") if inattivo else colore(pieno)
            col_bordo = colore("#c0c0c6") if inattivo else colore(bordo)
            con_segno = stato.startswith("hover")
            def f(x, y, col=col, col_bordo=col_bordo, con_segno=con_segno, tipo=tipo):
                d = math.hypot(x - 0.5, y - 0.5)
                if d > r:
                    return None
                if con_segno and simbolo(tipo, x, y):
                    return (90, 30, 25, 0.75) if tipo == "close" else (100, 65, 10, 0.75) if tipo == "iconify" \
                        else (20, 90, 30, 0.75)
                if d > r - 0.03:
                    return (*col_bordo, 1.0)
                return (*col, 1.0)
            nomi = {"active": f"{tipo}-active", "inactive": f"{tipo}-inactive",
                    "hover-active": f"{tipo}_hover-active", "hover-inactive": f"{tipo}_hover-inactive"}
            righe = disegna(lato, f)
            png(os.path.join(cartella, nomi[stato] + ".png"), lato, lato, righe, True)
            if tipo == "max":                                 # finestra gia' ingrandita: stessi pulsanti
                png(os.path.join(cartella, nomi[stato].replace("max", "max_toggled", 1) + ".png"),
                    lato, lato, righe, True)

if __name__ == "__main__":
    cosa = sys.argv[1] if len(sys.argv) > 1 else ""
    if cosa == "sfondo":
        sfondo(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "chiaro")
    elif cosa == "logo":
        logo(sys.argv[2], int(sys.argv[3]))
    elif cosa == "griglia":
        griglia(sys.argv[2], int(sys.argv[3]))
    elif cosa == "pulsanti":
        pulsanti(sys.argv[2])
    elif cosa == "icona":
        icona_app(sys.argv[3], int(sys.argv[4]), sys.argv[2],
                  sys.argv[5], sys.argv[6] if len(sys.argv) > 6 else None)
    else:
        sys.exit("Uso: disegna-elegante sfondo FILE [chiaro|scuro] | logo FILE LATO | griglia FILE LATO"
                 " | pulsanti CARTELLA | icona SIMBOLO FILE LATO COLORE1 [COLORE2]")
EOF
chmod 755 /usr/local/lib/elegante/disegna-elegante
local D=/usr/local/lib/elegante/disegna-elegante t
python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$D"
echo "Disegno gli sfondi (circa un minuto)..."
python3 -I "$D" sfondo /usr/share/backgrounds/elegante-chiaro.png chiaro
python3 -I "$D" sfondo /usr/share/backgrounds/elegante-scuro.png scuro
# lo sfondo blu di prima resta tra le scelte (Impostazioni -> Aspetto)
[ -f /usr/share/backgrounds/sfondo-blu.png ] \
  || cp -v /usr/share/backgrounds/sfondo-desktop.png /usr/share/backgrounds/sfondo-blu.png
cp -v /usr/share/backgrounds/elegante-chiaro.png /usr/share/backgrounds/sfondo-desktop.png
for t in 16 22 24 32 48 64 128 256; do
  install -dm755 "/usr/share/icons/hicolor/${t}x${t}/apps"
  python3 -I "$D" logo "/usr/share/icons/hicolor/${t}x${t}/apps/logo-distro.png" "$t"
  python3 -I "$D" griglia "/usr/share/icons/hicolor/${t}x${t}/apps/tutte-le-app.png" "$t"
done
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
python3 -I "$D" pulsanti /usr/share/themes/Elegante/labwc
[ "$(ls /usr/share/themes/Elegante/labwc/*.png | wc -l)" -ge 16 ] || { echo "Mancano i pulsanti delle finestre"; return 1; }
echo "[OK] Sfondi, simbolo e pulsanti pronti"
}

f8_tema() {
# NON IN BLFS: il tema "Elegante". Per i programmi (GTK): Adwaita con l'azzurro come
# colore principale e angoli morbidi. Per le finestre (labwc): barra del titolo chiara
# e i tre cerchi colorati a sinistra.
install -vdm755 /usr/share/themes/Elegante/gtk-3.0 /usr/share/themes/Elegante/labwc
cat > /usr/share/themes/Elegante/gtk-3.0/elegante.css << "EOF"
/* Tema "Elegante" (creato da lfs.sh): Adwaita con l'azzurro come colore principale,
   angoli piu' morbidi, barra in alto trasparente e dock in basso.
   Lo usano gtk.css (chiaro) e gtk-dark.css (scuro). */

@define-color accento #0a84ff;
@define-color accento_scuro #0060df;
@define-color accento_chiaro #4da3ff;
@define-color theme_selected_bg_color #0a84ff;
@define-color theme_selected_fg_color #ffffff;
@define-color selected_bg_color #0a84ff;
@define-color selected_fg_color #ffffff;

/* ------------------------------------------------------------ selezioni */
selection,
*:selected,
*:selected:focus,
.view:selected,
.view:selected:focus,
iconview:selected,
iconview:selected:focus,
treeview.view:selected,
treeview.view:selected:focus,
row:selected,
flowboxchild:selected,
calendar:selected,
textview text selection,
entry selection,
label selection {
  background-color: @accento;
  color: #ffffff;
}

*:link, link { color: @accento_scuro; }

/* ------------------------------------------------------------ pulsanti */
button {
  border-radius: 8px;
}
button.suggested-action,
button.default:not(.flat) {
  background-image: none;
  background-color: @accento;
  border-color: @accento_scuro;
  color: #ffffff;
  text-shadow: none;
  -gtk-icon-shadow: none;
}
button.suggested-action:hover,
button.default:not(.flat):hover {
  background-image: none;
  background-color: @accento_chiaro;
}
button.suggested-action:active,
button.suggested-action:checked {
  background-image: none;
  background-color: @accento_scuro;
}
button.suggested-action label,
button.default:not(.flat) label {
  color: #ffffff;
}

/* ------------------------------------------------------------ caselle di testo */
entry,
spinbutton:not(.vertical),
combobox button.combo {
  border-radius: 8px;
}
entry:focus,
spinbutton:focus:not(.vertical) {
  border-color: @accento;
  box-shadow: inset 0 0 0 1px @accento;
}

/* ------------------------------------------------------------ caselle e interruttori */
check:checked,
radio:checked,
check:indeterminate,
radio:indeterminate {
  background-image: none;
  background-color: @accento;
  border-color: @accento_scuro;
  color: #ffffff;
}
check {
  border-radius: 5px;
}
switch {
  border-radius: 14px;
}
switch slider {
  border-radius: 14px;
}
switch:checked {
  background-image: none;
  background-color: #34c759;
  border-color: #2aa84a;
}

/* ------------------------------------------------------------ barre di avanzamento e cursori */
progressbar progress,
scale highlight,
levelbar block.filled {
  background-image: none;
  background-color: @accento;
  border-color: @accento_scuro;
}
progressbar trough,
progressbar progress {
  border-radius: 6px;
}
scale slider {
  border-radius: 100%;
}

/* ------------------------------------------------------------ schede */
notebook > header tab:checked {
  box-shadow: inset 0 -3px @accento;
}
notebook > header.top tab:checked { box-shadow: inset 0 -3px @accento; }
notebook > header.bottom tab:checked { box-shadow: inset 0 3px @accento; }
notebook > header.left tab:checked { box-shadow: inset -3px 0 @accento; }
notebook > header.right tab:checked { box-shadow: inset 3px 0 @accento; }

/* ------------------------------------------------------------ menu e suggerimenti */
.csd.popup decoration,
.popup decoration {
  border-radius: 10px;
}
menu,
.menu,
.context-menu {
  border-radius: 10px;
  padding: 5px 0;
}
menu menuitem,
.menu menuitem,
.context-menu menuitem {
  border-radius: 6px;
  margin: 0 5px;
  padding: 5px 10px;
}
menu menuitem:hover,
.menu menuitem:hover,
.context-menu menuitem:hover {
  background-color: @accento;
  color: #ffffff;
}
menu menuitem:hover label,
menu menuitem:hover accelerator,
menu menuitem:hover arrow {
  color: #ffffff;
}
popover,
popover.background {
  border-radius: 12px;
}
popover modelbutton:hover {
  background-color: @accento;
  color: #ffffff;
  border-radius: 6px;
}
tooltip,
tooltip.background {
  border-radius: 8px;
  background-color: rgba(30, 30, 32, 0.92);
  color: #ffffff;
}
tooltip * {
  color: #ffffff;
}

/* ------------------------------------------------------------ pulsanti delle finestre
   (per i programmi che disegnano da soli la barra del titolo): tre cerchi colorati */
headerbar button.titlebutton,
.titlebar button.titlebutton {
  min-width: 14px;
  min-height: 14px;
  padding: 0;
  margin: 0 4px;
  border: none;
  border-radius: 100%;
  background-image: none;
  box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.12);
  color: transparent;
  -gtk-icon-shadow: none;
}
headerbar button.titlebutton image,
.titlebar button.titlebutton image {
  opacity: 0;
}
headerbar button.titlebutton:hover image,
.titlebar button.titlebutton:hover image {
  opacity: 0.6;
  color: #3a1e1e;
}
headerbar button.titlebutton.close,
.titlebar button.titlebutton.close { background-color: #ff5f57; }
headerbar button.titlebutton.minimize,
.titlebar button.titlebutton.minimize { background-color: #febc2e; }
headerbar button.titlebutton.maximize,
.titlebar button.titlebutton.maximize { background-color: #28c840; }
headerbar:backdrop button.titlebutton,
.titlebar:backdrop button.titlebutton {
  background-color: #d4d4d8;
}

/* ------------------------------------------------------------ barra in alto (pannello 1)
   Nota: il pannello impone "background" e "padding" dei suoi pulsanti; per
   colorarli si usa un'ombra interna (box-shadow), che non viene toccata. */
.xfce4-panel.panel-1.background {
  background-color: rgba(250, 250, 252, 0.74);
  color: #1d1d1f;
}
.xfce4-panel.panel-1 button {
  border-color: transparent;
  border-radius: 6px;
  box-shadow: none;
  margin: 2px 1px;
}
.xfce4-panel.panel-1 button:hover {
  box-shadow: inset 0 0 0 40px rgba(0, 0, 0, 0.08);
}
.xfce4-panel.panel-1 button:active,
.xfce4-panel.panel-1 button:checked {
  box-shadow: inset 0 0 0 40px rgba(0, 0, 0, 0.15);
}
.xfce4-panel.panel-1 label {
  color: #1d1d1f;
}

/* ------------------------------------------------------------ dock in basso (pannello 2) */
.xfce4-panel.panel-2.background {
  background-color: rgba(255, 255, 255, 0.52);
  border-radius: 18px 18px 0 0;
}
.xfce4-panel.panel-2 button {
  border-color: transparent;
  border-radius: 12px;
  box-shadow: none;
  margin: 4px 2px;
}
.xfce4-panel.panel-2 button:hover {
  box-shadow: inset 0 0 0 64px rgba(255, 255, 255, 0.5);
}
/* la finestra in primo piano: una lineetta azzurra sotto la sua icona */
.xfce4-panel.panel-2 button:checked {
  box-shadow: inset 0 -3px 0 0 @accento, inset 0 0 0 64px rgba(255, 255, 255, 0.35);
}
EOF
cat > /usr/share/themes/Elegante/gtk-3.0/gtk.css << "EOF"
/* Tema "Elegante" chiaro (creato da lfs.sh): Adwaita + i ritocchi di elegante.css */
@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained.css");
@import url("elegante.css");
EOF
cat > /usr/share/themes/Elegante/gtk-3.0/gtk-dark.css << "EOF"
/* Tema "Elegante" scuro (creato da lfs.sh): Adwaita scuro + i ritocchi di elegante.css */
@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");
@import url("elegante.css");

*:link, link { color: #4da3ff; }
.xfce4-panel.panel-1.background {
  background-color: rgba(30, 30, 34, 0.72);
  color: #f5f5f7;
}
.xfce4-panel.panel-1 label { color: #f5f5f7; }
.xfce4-panel.panel-1 button:hover { box-shadow: inset 0 0 0 40px rgba(255, 255, 255, 0.10); }
.xfce4-panel.panel-2.background { background-color: rgba(40, 40, 46, 0.60); }
.xfce4-panel.panel-2 button:hover { box-shadow: inset 0 0 0 64px rgba(255, 255, 255, 0.12); }
EOF
cat > /usr/share/themes/Elegante/labwc/themerc << "EOF"
# Tema "Elegante" per le finestre (labwc), creato da lfs.sh.
# Barra del titolo chiara, titolo al centro, a sinistra tre cerchi colorati
# (rosso chiude, giallo riduce, verde ingrandisce): le immagini sono qui accanto.
border.width: 1
window.titlebar.padding.width: 10
window.titlebar.padding.height: 5
window.active.border.color: #c9c9cd
window.inactive.border.color: #dcdce0
window.active.title.bg.color: #ececef
window.inactive.title.bg.color: #f6f6f8
window.active.label.text.color: #1d1d1f
window.inactive.label.text.color: #a1a1a6
window.label.text.justify: center
window.button.width: 22
window.button.height: 22
window.button.spacing: 0
window.button.hover.bg.color: #00000000
window.button.hover.bg.corner-radius: 0
window.active.button.unpressed.image.color: #1d1d1f
window.inactive.button.unpressed.image.color: #a1a1a6
window.active.shadow.size: 34
window.inactive.shadow.size: 20
window.active.shadow.color: #00000048
window.inactive.shadow.color: #00000026
menu.border.width: 1
menu.border.color: #d2d2d7
menu.items.bg.color: #f9f9fb
menu.items.text.color: #1d1d1f
menu.items.active.bg.color: #0a84ff
menu.items.active.text.color: #ffffff
menu.items.padding.x: 14
menu.items.padding.y: 6
menu.separator.color: #e3e3e8
menu.title.bg.color: #f9f9fb
menu.title.text.color: #6e6e73
osd.bg.color: #f9f9fbf0
osd.border.color: #d2d2d7
osd.border.width: 1
osd.label.text.color: #1d1d1f
osd.window-switcher.style-thumbnail.item.active.border.color: #0a84ff
osd.window-switcher.style-thumbnail.item.active.bg.color: #0a84ff26
osd.window-switcher.style-classic.item.active.border.color: #0a84ff
osd.window-switcher.style-classic.item.active.bg.color: #0a84ff26
snapping.overlay.region.bg.color: #0a84ff40
snapping.overlay.edge.bg.color: #0a84ff40
EOF
cat > /usr/share/themes/Elegante/index.theme << "EOF"
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=Elegante
Comment=Chiaro, con l'azzurro e i pulsanti tondi colorati (creato da lfs.sh)
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=Elegante
IconTheme=AdwaitaLegacy
EOF

# --- programmi GTK: tema Elegante; nei programmi che disegnano da soli la barra del
#     titolo i pulsanti vanno a sinistra, come nelle altre finestre ---
sed -i -e 's/^gtk-theme-name = .*/gtk-theme-name = Elegante/' \
       -e 's/^gtk-decoration-layout = .*/gtk-decoration-layout = close,minimize,maximize:/' \
       /etc/gtk-3.0/settings.ini
grep -q '^gtk-decoration-layout' /etc/gtk-3.0/settings.ini \
  || sed -i '/^\[Settings\]/a gtk-decoration-layout = close,minimize,maximize:' /etc/gtk-3.0/settings.ini
grep -q '^gtk-theme-name = Elegante' /etc/gtk-3.0/settings.ini \
  && grep -q '^gtk-decoration-layout = close,minimize,maximize:' /etc/gtk-3.0/settings.ini \
  || { echo "Non riesco a cambiare il tema dei programmi"; return 1; }

# --- finestre (labwc): tema Elegante, pulsanti a sinistra, angoli piu' tondi ---
grep -q '<name>Elegante</name>' /etc/xdg/labwc/rc.xml \
  || sed -i 's|^  <theme>$|  <theme>\n    <name>Elegante</name>|' /etc/xdg/labwc/rc.xml
sed -i -e 's|<layout>[^<]*</layout>|<layout>close,iconify,max:</layout>|' \
       -e 's|<cornerRadius>[0-9]*</cornerRadius>|<cornerRadius>12</cornerRadius>|' \
       /etc/xdg/labwc/rc.xml
grep -q '<name>Elegante</name>' /etc/xdg/labwc/rc.xml \
  && grep -q '<layout>close,iconify,max:</layout>' /etc/xdg/labwc/rc.xml \
  || { echo "Non riesco a cambiare il tema delle finestre"; return 1; }
python3 -I -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' /etc/xdg/labwc/rc.xml
# i colori "stile GNOME" di prima coprirebbero quelli del tema: si tolgono
cat > /etc/xdg/labwc/themerc-override << "EOF"
# Creato da lfs.sh. I colori delle finestre sono nel tema "Elegante":
#   /usr/share/themes/Elegante/labwc/themerc
# Qui puoi cambiarne qualcuno per tutti, per esempio:
#   window.active.title.bg.color: #e0e0e4
EOF
echo "[OK] Tema Elegante pronto (programmi e finestre)"
}

f8_barre() {
# NON IN BLFS: la barra in alto e il dock in basso (due pannelli di Xfce). Si mettono
# solo i programmi installati. E' la configurazione di partenza per tutti: ognuno puo'
# cambiarla (tasto destro sulla barra o sul dock -> Pannello -> Preferenze).
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa; casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
[ -d "$casa" ] || { echo "Non trovo la cartella di $MIA_UTENTE"; return 1; }
local A=/usr/share/applications
local xml=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
local ids1=() ids2=() plugins="" id=20 vol=0

# "Tutte le app": la ricerca di fuzzel al centro dello schermo (anche col tasto Windows)
mkdir -p /usr/local/bin
cat > /usr/local/bin/tutte-le-app << "EOF"
#!/bin/sh
# Apre la ricerca delle app, o la chiude se e' gia' aperta (creato da lfs.sh)
pkill -u "$(id -u)" -x fuzzel || exec fuzzel
EOF
chmod 755 /usr/local/bin/tutte-le-app
cat > "$A/tutte-le-app.desktop" << "EOF"
[Desktop Entry]
Type=Application
Name=Tutte le app
Comment=Cerca e apri un programma (anche col tasto Windows)
Exec=/usr/local/bin/tutte-le-app
Icon=tutte-le-app
Terminal=false
NoDisplay=true
EOF

lanciatore() { # id file.desktop
  plugins+="    <property name=\"plugin-$1\" type=\"string\" value=\"launcher\">
      <property name=\"items\" type=\"array\">
        <value type=\"string\" value=\"$2\"/>
      </property>
    </property>
"
}
nel_dock() { # file.desktop (solo se c'e')
  [ -n "${1:-}" ] && [ -f "$1" ] || return 0
  lanciatore "$id" "$1"; ids2+=("$id"); id=$((id + 1))
}
valori() { local i; for i in "$@"; do printf '        <value type="int" value="%s"/>\n' "$i"; done; }

# --- barra in alto: menu | (spazio) | fantasma, volume, impostazioni, ora, spegnimento ---
plugins+='    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-title" type="string" value="Applicazioni"/>
      <property name="button-icon" type="string" value="logo-distro"/>
      <property name="show-button-title" type="bool" value="true"/>
    </property>
    <property name="plugin-2" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
'
ids1=(1 2)
if [ -f "$A/fantasma.desktop" ]; then lanciatore 3 "$A/fantasma.desktop"; ids1+=(3); fi
[ -f /usr/share/xfce4/panel/plugins/pulseaudio.desktop ] && vol=1
grep -q 'value="pulseaudio"' "$xml" 2>/dev/null && vol=1
if [ "$vol" = 1 ]; then
  plugins+='    <property name="plugin-4" type="string" value="pulseaudio">
      <property name="mixer-command" type="string" value="foot -e alsamixer"/>
    </property>
'
  ids1+=(4)
fi
lanciatore 5 "$A/impostazioni.desktop"; ids1+=(5)
plugins+='    <property name="plugin-6" type="string" value="clock">
      <property name="digital-layout" type="uint" value="3"/>
      <property name="digital-time-format" type="string" value="%a %-d %b   %H:%M"/>
      <property name="digital-time-font" type="string" value="Adwaita Sans Medium 10"/>
    </property>
'
ids1+=(6)
lanciatore 7 "$A/spegnimento.desktop"; ids1+=(7)

# --- dock: tutte le app, browser, file, posta, documenti, testo, terminale,
#     impostazioni | finestre aperte ---
nel_dock "$A/tutte-le-app.desktop"
if [ -f "$A/tor-browser.desktop" ]; then nel_dock "$A/tor-browser.desktop"; else nel_dock "$A/firefox.desktop"; fi
nel_dock "$A/thunar.desktop"
nel_dock "$A/thunderbird.desktop"
nel_dock "$(ls "$A"/libreoffice*-writer.desktop 2>/dev/null | head -n1)"
nel_dock "$A/org.xfce.mousepad.desktop"
nel_dock "$A/foot.desktop"
nel_dock "$A/impostazioni.desktop"
plugins+='    <property name="plugin-40" type="string" value="separator">
      <property name="style" type="uint" value="1"/>
    </property>
    <property name="plugin-41" type="string" value="tasklist">
      <property name="show-labels" type="bool" value="false"/>
      <property name="grouping" type="bool" value="true"/>
      <property name="flat-buttons" type="bool" value="true"/>
      <property name="show-handle" type="bool" value="false"/>
      <property name="include-all-workspaces" type="bool" value="true"/>
    </property>
'
ids2+=(40 41)

mkdir -p "$(dirname "$xml")"
cat > "$xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!-- Barra in alto e dock in basso (creato da lfs.sh, Fase 8) -->
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <value type="int" value="2"/>
    <property name="dark-mode" type="bool" value="false"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="30"/>
      <property name="icon-size" type="uint" value="18"/>
      <property name="enable-struts" type="bool" value="true"/>
      <property name="plugin-ids" type="array">
$(valori "${ids1[@]}")
      </property>
    </property>
    <property name="panel-2" type="empty">
      <property name="position" type="string" value="p=10;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="62"/>
      <property name="icon-size" type="uint" value="44"/>
      <property name="enable-struts" type="bool" value="true"/>
      <property name="plugin-ids" type="array">
$(valori "${ids2[@]}")
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
$plugins  </property>
</channel>
EOF
python3 -I -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$xml"
grep -q 'value="tasklist"' "$xml" && grep -q 'value="applicationsmenu"' "$xml" \
  || { echo "Non riesco a preparare la barra e il dock"; return 1; }
# la barra dell'utente riparte dalla nuova configurazione
rm -rf "$casa/.config/xfce4/panel" "$casa/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
echo "[OK] Barra in alto e dock in basso pronti (${#ids2[@]} elementi nel dock)"
}

f8_ritocchi() {
# NON IN BLFS: ricerca delle app (fuzzel) al centro come uno "Spotlight", notifiche
# chiare e arrotondate, sfondo e blocco schermo che seguono la scelta dell'utente
mkdir -p /etc/xdg/fuzzel /usr/local/bin
cat > /etc/xdg/fuzzel/fuzzel.ini << "EOF"
# Ricerca delle app (fuzzel), creata da lfs.sh (Fase 8): al centro dello schermo,
# chiara e arrotondata. Si apre col tasto Windows o con "Tutte le app" nel dock.
# Per cambiarla solo per te: copiala in ~/.config/fuzzel/fuzzel.ini e modifica quella.
[main]
font=Adwaita Sans:size=14
prompt="Cerca   "
icon-theme=AdwaitaLegacy
terminal=foot
lines=8
width=42
horizontal-pad=24
vertical-pad=16
inner-pad=12
layer=overlay

[colors]
background=f6f6f8f0
text=1d1d1fff
match=0a84ffff
selection=0a84ffff
selection-text=ffffffff
selection-match=ffffffff
border=0000002a

[border]
width=1
radius=16
EOF

# --- notifiche (mako): chiare, con gli angoli tondi, sotto la barra in alto ---
grep -q '^mako ' /etc/xdg/labwc/autostart || { echo "Manca mako all'avvio del desktop (Fase 4)"; return 1; }
sed -i 's|^mako .*|mako --font "Adwaita Sans 11" --background-color "#f6f6f8f2" --text-color "#1d1d1f" --border-size 1 --border-color "#0000001f" --border-radius 14 --padding 14 --margin 12 --width 360 --max-icon-size 40 --default-timeout 6000 >/dev/null 2>\&1 \&|' \
    /etc/xdg/labwc/autostart
grep -q '^mako .*f6f6f8f2' /etc/xdg/labwc/autostart || { echo "Non riesco a cambiare le notifiche"; return 1; }

# --- sfondo: quello scelto in Impostazioni -> Aspetto (o quello della modalita' fantasma) ---
cat > /usr/local/bin/sfondo-desktop << "EOF"
#!/bin/sh
# Sfondo del desktop (creato da lfs.sh). Si sceglie da Impostazioni -> Aspetto (la
# scelta e' in ~/.config/sfondo.conf). In modalita' fantasma diventa quello scuro,
# cosi' si vede subito se e' accesa.
img=$(sed -n 's/^SFONDO=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/sfondo.conf" 2>/dev/null | head -n1)
[ -n "$img" ] && [ -f "$img" ] || img=/usr/share/backgrounds/sfondo-desktop.png
if [ -e /etc/fantasma/attivo ] && [ -f /usr/share/backgrounds/sfondo-fantasma.png ]; then
  img=/usr/share/backgrounds/sfondo-fantasma.png
fi
pkill -u "$(id -u)" -x swaybg
exec swaybg -i "$img" -m fill
EOF
chmod 755 /usr/local/bin/sfondo-desktop
sh -n /usr/local/bin/sfondo-desktop
sed -i 's|^swaybg -i /usr/share/backgrounds/sfondo-desktop.png -m fill >/dev/null 2>&1 &$|/usr/local/bin/sfondo-desktop >/dev/null 2>\&1 \&|' \
    /etc/xdg/labwc/autostart
grep -q '^/usr/local/bin/sfondo-desktop ' /etc/xdg/labwc/autostart \
  || { echo "Non riesco a cambiare lo sfondo all'avvio del desktop"; return 1; }

# --- blocco dello schermo: stesso sfondo, cerchio azzurro ---
cat > /usr/local/bin/blocca-schermo << "EOF"
#!/bin/bash
# Blocca lo schermo (creato da lfs.sh): per sbloccare scrivi la tua password e premi Invio.
# Mostra lo stesso sfondo del desktop (Impostazioni -> Aspetto).
pgrep -u "$(id -u)" -x swaylock >/dev/null && exit 0
img=$(sed -n 's/^SFONDO=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/sfondo.conf" 2>/dev/null | head -n1)
[ -n "$img" ] && [ -f "$img" ] || img=/usr/share/backgrounds/sfondo-desktop.png
if [ -e /etc/fantasma/attivo ] && [ -f /usr/share/backgrounds/sfondo-fantasma.png ]; then
  img=/usr/share/backgrounds/sfondo-fantasma.png
fi
exec swaylock -f -i "$img" -s fill \
     --font "Adwaita Sans" --indicator-radius 80 --indicator-thickness 6 \
     --inside-color ffffff33 --inside-clear-color ffffff33 --inside-ver-color 0a84ff55 \
     --inside-wrong-color ff5f5755 --ring-color ffffffcc --ring-clear-color febc2eff \
     --ring-ver-color 0a84ffff --ring-wrong-color ff5f57ff --key-hl-color 0a84ffff \
     --bs-hl-color ff5f57ff --line-color 00000000 --line-clear-color 00000000 \
     --line-ver-color 00000000 --line-wrong-color 00000000 --separator-color 00000000 \
     --text-color ffffffff --text-clear-color ffffffff --text-ver-color ffffffff \
     --text-wrong-color ffffffff
EOF
chmod 755 /usr/local/bin/blocca-schermo
bash -n /usr/local/bin/blocca-schermo

# --- menu col tasto destro sul desktop: "Cambia sfondo..." ---
if ! grep -q 'impostazioni-aspetto' /etc/xdg/labwc/menu.xml; then
  sed -i 's|^  <item label="Impostazioni">|  <item label="Cambia sfondo...">\n    <action name="Execute" command="/usr/local/bin/impostazioni-aspetto" />\n  </item>\n  <item label="Impostazioni">|' \
      /etc/xdg/labwc/menu.xml
fi
grep -q 'impostazioni-aspetto' /etc/xdg/labwc/menu.xml || { echo "Non riesco a cambiare il menu del desktop"; return 1; }
python3 -I -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' /etc/xdg/labwc/menu.xml
echo "[OK] Ricerca, notifiche, sfondo e blocco schermo nel nuovo stile"
}

f8_impostazioni() {
# NON IN BLFS: Impostazioni nuove. Ogni finestra scrive cosa non va in
# ~/.cache/impostazioni.log e lo dice anche a video (prima a volte non si apriva e
# basta). Se yad non parte, si usano i menu di fuzzel.
mkdir -p /usr/local/bin
cat > /usr/local/bin/impostazioni << "EOF"
#!/bin/bash
# Impostazioni (creato da lfs.sh): tutte le regolazioni del sistema in un elenco, come le
# Preferenze di Sistema di macOS o le Impostazioni di Windows (icona + nome, una riga per
# voce). Si vedono solo quelle installate (alcune arrivano con le fasi successive).
# Se qualcosa non va, il motivo e' scritto in ~/.cache/impostazioni.log
registro="${XDG_CACHE_HOME:-$HOME/.cache}/impostazioni.log"
mkdir -p "$(dirname "$registro")" 2>/dev/null && exec 2>>"$registro"
echo "--- $(date '+%F %T') impostazioni" >&2
export PATH="/usr/local/bin:/usr/bin:$PATH"
# in quest'ordine (nome del file .desktop, senza ".desktop")
VOCI="impostazioni-schermo impostazioni-aspetto vpn fantasma guardiano-regole cassaforte
      wine-impostazioni wine-programmi cups xfce4-taskmanager"
cartella="${XDG_RUNTIME_DIR:-/tmp}/impostazioni-$(id -u)"
rm -rf "$cartella"; mkdir -p "$cartella" || exit 1
n=10
for v in $VOCI; do
  for d in "/usr/share/applications/$v.desktop" "/usr/share/applications/org.xfce.$v.desktop" \
           /usr/share/applications/*-"$v".desktop; do
    if [ -f "$d" ]; then
      ln -sf "$d" "$cartella/$n-$(basename "$d")"      # il numero davanti tiene l'ordine
      n=$((n + 1))
      break
    fi
  done
done

avvia() { # file .desktop: esegue il suo comando (senza %f, %u...)
  local cmd
  cmd=$(sed -n 's/^Exec=//p' "$1" | head -n1 | sed 's/ *%[a-zA-Z]//g')
  [ -n "$cmd" ] || return 1
  echo "avvio: $cmd" >&2
  setsid sh -c "$cmd" >/dev/null 2>&1 < /dev/null &
}

if command -v yad >/dev/null; then
  elenco=""
  for d in "$cartella"/*.desktop; do
    [ -f "$d" ] || continue
    nome=$(sed -n 's/^Name=//p' "$d" | head -n1)
    icona=$(sed -n 's/^Icon=//p' "$d" | head -n1)
    [ -n "$icona" ] || icona=preferences-system
    [ -n "$nome" ] || continue
    elenco+="$icona"$'\n'"$nome"$'\n'
  done
  scelta=$(printf '%s' "$elenco" | yad --title "Impostazioni" --window-icon preferences-system \
      --list --no-headers --column "Icona:IMG" --column "Nome:TEXT" \
      --width 420 --height 480 --center \
      --text "<span size='x-large' weight='bold'>Impostazioni</span>" \
      --button "Chiudi:2" --button "Apri:0" --separator '|')
  esito=$?
  case $esito in
    0)
      nome=$(cut -d'|' -f2 <<<"$scelta")
      for d in "$cartella"/*.desktop; do
        if [ "$(sed -n 's/^Name=//p' "$d" | head -n1)" = "$nome" ]; then
          avvia "$d"; break
        fi
      done
      exit 0 ;;
    2|252) exit 0 ;;
  esac
  echo "yad non si e' aperto (codice $esito): uso il menu di fuzzel" >&2
fi
# senza yad (o se yad non parte): un elenco semplice
nome=$(for d in "$cartella"/*.desktop; do sed -n 's/^Name=//p' "$d" | head -n1; done \
       | fuzzel --dmenu --prompt "Impostazioni: " --lines 10 --width 36) || exit 0
for d in "$cartella"/*.desktop; do
  if [ "$(sed -n 's/^Name=//p' "$d" | head -n1)" = "$nome" ]; then
    avvia "$d"
    exit 0
  fi
done
EOF
cat > /usr/local/bin/impostazioni-schermo << "EOF"
#!/bin/bash
# Impostazioni dello schermo (creato da lfs.sh): risoluzione e grandezza di testi e
# finestre. Dopo il cambio chiede "Va bene cosi'?": se non rispondi entro 15 secondi
# torna come prima (utile se lo schermo diventa illeggibile).
# Se qualcosa non va, il motivo e' scritto in ~/.cache/impostazioni.log
registro="${XDG_CACHE_HOME:-$HOME/.cache}/impostazioni.log"
mkdir -p "$(dirname "$registro")" 2>/dev/null && exec 2>>"$registro"
echo "--- $(date '+%F %T') impostazioni-schermo" >&2
export PATH="/usr/local/bin:/usr/bin:$PATH"     # anche se aperto da un menu con un PATH corto
TITOLO="Schermo"
ICONA=preferences-desktop-display
COMUNI="2560x1440 1920x1200 1920x1080 1680x1050 1600x900 1440x900 1366x768 1280x1024 1280x800 1280x720 1024x768"
GRANDEZZE="100%|1
125%|1.25
150%|1.5
175%|1.75
200%|2"
usa_yad=0
command -v yad >/dev/null && usa_yad=1

# un messaggio a video: con yad, altrimenti con una notifica, altrimenti con fuzzel
messaggio() { # icona testo
  echo "MESSAGGIO: $2" >&2
  if [ "$usa_yad" = 1 ]; then
    yad --title "$TITOLO" --window-icon "$ICONA" --image "$1" --center --fixed --width 460 \
        --text "$2" --button "OK:0"
    case $? in 0|252) return 0 ;; esac
  fi
  local semplice; semplice=$(printf '%s' "$2" | sed 's/<[^>]*>//g' | tr '\n' ' ')
  notify-send -i "$1" "$TITOLO" "$semplice" 2>/dev/null && return 0
  printf 'OK\n' | fuzzel --dmenu --prompt "$semplice  " --lines 1 --width 60 >/dev/null 2>&1
}

[ -n "${WAYLAND_DISPLAY:-}" ] \
  || { messaggio dialog-error "<b>Lo schermo si regola solo dal desktop.</b>"; exit 1; }
command -v wlr-randr >/dev/null || { messaggio dialog-error "<b>Manca il programma wlr-randr.</b>
Rifai il desktop dal tuo PC:  sudo bash lfs.sh fase2c"; exit 1; }
command -v schermo >/dev/null || { messaggio dialog-error "<b>Manca il comando schermo.</b>
Rifai il desktop dal tuo PC:  sudo bash lfs.sh fase2c"; exit 1; }

if ! attuale=$(schermo attuale 2>&1); then
  messaggio dialog-error "<b>Non trovo lo schermo.</b>
$(printf '%s' "$attuale" | sed 's/&/\&amp;/g; s/</\&lt;/g')"
  exit 1
fi
read -r ora sca_ora <<<"$attuale"
[ -n "$ora" ] || { messaggio dialog-error "<b>Non trovo lo schermo.</b>"; exit 1; }
[[ $sca_ora =~ ^[0-9]+(\.[0-9]+)?$ ]] || sca_ora=1
sca_ora=$(awk -v s="$sca_ora" 'BEGIN { printf "%g", s }')     # 1.000000 -> 1, 1.250000 -> 1.25
echo "ora: $ora grandezza $sca_ora" >&2
# elenco: quelle dello schermo, poi quelle comuni (in una macchina virtuale vanno tutte)
elenco=$( { schermo modi 2>/dev/null; for r in $COMUNI; do echo "$r"; done; } | grep -E '^[0-9]+x[0-9]+$' \
          | awk '!visto[$0]++' | sort -t x -k1,1nr -k2,2nr)
percento=$(awk -v s="$sca_ora" 'BEGIN { printf "%d%%", s * 100 + 0.5 }')
# la scelta di adesso viene segnata con ^ (cosi' yad la mostra gia' scelta)
segna() { awk -v x="$1" '{ print ($0 == x ? "^" $0 : $0) }' | paste -sd '!'; }

scegli_yad() { # stampa "risoluzione|grandezza|"; 0 = Applica, 2/252 = Annulla, altro = yad non va
  yad --title "$TITOLO" --window-icon "$ICONA" --image "$ICONA" \
      --center --fixed --width 460 --form --separator '|' \
      --text "<span size='x-large' weight='bold'>Schermo</span>
Ora: <b>$ora</b>, grandezza <b>$percento</b>" \
      --field "Risoluzione:CB" "$(printf '%s\n' "$elenco" | segna "$ora")" \
      --field "Grandezza di testi e finestre:CB" "$(printf '%s\n' "$GRANDEZZE" | cut -d'|' -f1 | segna "$percento")" \
      --button "Annulla:2" --button "Applica:0"
}
scegli_fuzzel() {
  local r g
  r=$(printf '%s\n' "$elenco" | fuzzel --dmenu --prompt "Risoluzione (ora $ora): " --lines 12 --width 34) || return 2
  g=$(printf '%s\n' "$GRANDEZZE" | cut -d'|' -f1 | fuzzel --dmenu --prompt "Grandezza (ora $percento): " --lines 5 --width 34) || return 2
  echo "$r|$g"
}
chiedi_conferma() {
  if [ "$usa_yad" = 1 ]; then
    yad --title "$TITOLO" --window-icon "$ICONA" --image dialog-question --center --fixed --width 460 \
        --text "<span size='large' weight='bold'>Va bene così?</span>
Se non rispondi, fra 15 secondi torna come prima." \
        --timeout 15 --timeout-indicator bottom --button "Torna come prima:2" --button "Tieni:0"
  else
    [ "$(printf 'Tieni\nTorna come prima\n' | timeout 15 fuzzel --dmenu --prompt 'Va bene cosi? ' --lines 2 --width 34)" = Tieni ]
  fi
}

esito=1
if [ "$usa_yad" = 1 ]; then
  scelta=$(scegli_yad); esito=$?
  case $esito in
    0) ;;
    2|252) exit 0 ;;
    *) echo "yad non si e' aperto (codice $esito): uso i menu di fuzzel" >&2; usa_yad=0 ;;
  esac
fi
if [ "$usa_yad" = 0 ]; then
  scelta=$(scegli_fuzzel) || exit 0
fi
ris=$(cut -d'|' -f1 <<<"$scelta")
gra=$(cut -d'|' -f2 <<<"$scelta")
sca=$(printf '%s\n' "$GRANDEZZE" | awk -F'|' -v g="$gra" '$1 == g { print $2 }')
echo "scelta: $ris $gra" >&2
[[ $ris =~ ^[0-9]+x[0-9]+$ ]] && [ -n "$sca" ] || exit 0
[ "$ris" = "$ora" ] && [ "$sca" = "$sca_ora" ] && exit 0

if ! msg=$(schermo "$ris" "$sca" --non-salvare 2>&1); then
  echo "$msg" >&2
  messaggio dialog-error "<b>Lo schermo non accetta $ris.</b>
Scegline un'altra."
  exit 1
fi
if chiedi_conferma; then
  schermo "$ris" "$sca" >/dev/null 2>&1          # la ricorda anche per i prossimi accessi
  notify-send -i "$ICONA" "Schermo" "$ris, grandezza $gra" 2>/dev/null
else
  schermo "$ora" "$sca_ora" --non-salvare >/dev/null 2>&1
fi
exit 0
EOF
cat > /usr/local/bin/impostazioni-aspetto << "EOF"
#!/bin/bash
# Aspetto (creato da lfs.sh): lo sfondo del desktop e i colori delle finestre
# (chiari o scuri). Vale solo per te; le scelte sono in:
#   ~/.config/sfondo.conf                  lo sfondo
#   ~/.config/gtk-3.0/settings.ini         programmi scuri (gtk-application-prefer-dark-theme)
#   ~/.config/labwc/themerc-override       barre del titolo scure
# Se qualcosa non va, il motivo e' scritto in ~/.cache/impostazioni.log
registro="${XDG_CACHE_HOME:-$HOME/.cache}/impostazioni.log"
mkdir -p "$(dirname "$registro")" 2>/dev/null && exec 2>>"$registro"
echo "--- $(date '+%F %T') impostazioni-aspetto" >&2
export PATH="/usr/local/bin:/usr/bin:$PATH"
TITOLO="Aspetto"
ICONA=preferences-desktop-wallpaper
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
SFONDI="Elegante chiaro|/usr/share/backgrounds/elegante-chiaro.png
Elegante scuro|/usr/share/backgrounds/elegante-scuro.png
Blu (il primo)|/usr/share/backgrounds/sfondo-blu.png"
MIA_IMMAGINE="$HOME/.local/share/sfondi/sfondo-mio.png"
SEGNO="# creato da Impostazioni -> Aspetto (colori scuri)"

command -v yad >/dev/null || { notify-send "$TITOLO" "Manca yad: rifai la Fase 6 (sudo bash lfs.sh fase6)" 2>/dev/null; exit 1; }
finestra() { yad --title "$TITOLO" --window-icon "$ICONA" --center "$@"; }
errore() { echo "ERRORE: $1" >&2; finestra --image dialog-error --fixed --width 460 --text "$1" --button "OK:0"; }

# --- com'e' adesso ---
sfondo_ora=$(sed -n 's/^SFONDO=//p' "$CONF/sfondo.conf" 2>/dev/null | head -n1)
[ -n "$sfondo_ora" ] || sfondo_ora=/usr/share/backgrounds/sfondo-desktop.png
scuro_ora=0
grep -q '^gtk-application-prefer-dark-theme *= *\(1\|true\)' "$CONF/gtk-3.0/settings.ini" 2>/dev/null && scuro_ora=1

voci=""; nome_ora=""
while IFS='|' read -r nome file; do
  [ -f "$file" ] || continue
  if cmp -s "$file" "$sfondo_ora"; then nome_ora=$nome; fi
  voci+="$nome"$'\n'
done <<<"$SFONDI"
[ -z "$nome_ora" ] && [ -f "$sfondo_ora" ] && { nome_ora="La tua immagine"; voci+="La tua immagine"$'\n'; }
voci+="Scegli un'immagine..."
segna() { awk -v x="$1" '{ print ($0 == x ? "^" $0 : $0) }' | paste -sd '!'; }
if [ "$scuro_ora" = 1 ]; then modi="Chiari!^Scuri"; else modi="^Chiari!Scuri"; fi

scelta=$(finestra --image "$ICONA" --fixed --width 480 --form --separator '|' \
  --text "<span size='x-large' weight='bold'>Aspetto</span>
Lo sfondo del desktop e i colori delle finestre." \
  --field "Sfondo:CB" "$(printf '%s\n' "$voci" | segna "$nome_ora")" \
  --field "Colori delle finestre:CB" "$modi" \
  --button "Annulla:2" --button "Applica:0")
esito=$?
[ "$esito" = 0 ] || { [ "$esito" = 2 ] || [ "$esito" = 252 ] || echo "yad: codice $esito" >&2; exit 0; }
sfondo=$(cut -d'|' -f1 <<<"$scelta")
modo=$(cut -d'|' -f2 <<<"$scelta")
echo "scelta: $sfondo / $modo" >&2

# --- sfondo ---
nuovo=""
case "$sfondo" in
  "Scegli un'immagine...")
    f=$(finestra --file --width 820 --height 560 --title "Scegli un'immagine per lo sfondo" \
        --file-filter "Immagini | *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG *.webp *.WEBP") || f=""
    if [ -n "$f" ] && [ -f "$f" ]; then
      mkdir -p "$(dirname "$MIA_IMMAGINE")"
      # swaybg legge le PNG: le altre immagini si convertono (con ffmpeg)
      if ffmpeg -y -loglevel error -i "$f" -frames:v 1 "$MIA_IMMAGINE.nuova.png"; then
        mv -f "$MIA_IMMAGINE.nuova.png" "$MIA_IMMAGINE"; nuovo=$MIA_IMMAGINE
      else
        rm -f "$MIA_IMMAGINE.nuova.png"
        errore "<b>Non riesco a usare questa immagine.</b>
Prova con una PNG o una JPG."
      fi
    fi ;;
  "La tua immagine") nuovo=$sfondo_ora ;;
  *) nuovo=$(printf '%s\n' "$SFONDI" | awk -F'|' -v n="$sfondo" '$1 == n { print $2 }') ;;
esac
if [ -n "$nuovo" ] && [ -f "$nuovo" ]; then
  mkdir -p "$CONF"
  printf 'SFONDO=%s\n' "$nuovo" > "$CONF/sfondo.conf"
  setsid /usr/local/bin/sfondo-desktop >/dev/null 2>&1 < /dev/null &
fi

# --- colori chiari o scuri ---
scuro=0; [ "$modo" = Scuri ] && scuro=1
if [ "$scuro" != "$scuro_ora" ]; then
  mkdir -p "$CONF/gtk-3.0" "$CONF/labwc"
  ini="$CONF/gtk-3.0/settings.ini"
  [ -f "$ini" ] || printf '[Settings]\n' > "$ini"
  sed -i '/^gtk-application-prefer-dark-theme/d' "$ini"
  [ "$scuro" = 1 ] && sed -i '/^\[Settings\]/a gtk-application-prefer-dark-theme = 1' "$ini"
  over="$CONF/labwc/themerc-override"
  if [ "$scuro" = 1 ]; then
    if [ ! -e "$over" ] || grep -qF "$SEGNO" "$over"; then
      cat > "$over" << 'FINE'
# creato da Impostazioni -> Aspetto (colori scuri)
window.active.border.color: #3a3a3e
window.inactive.border.color: #2e2e32
window.active.title.bg.color: #2c2c30
window.inactive.title.bg.color: #232326
window.active.label.text.color: #f5f5f7
window.inactive.label.text.color: #8e8e93
window.active.button.unpressed.image.color: #f5f5f7
window.inactive.button.unpressed.image.color: #8e8e93
menu.border.color: #3a3a3e
menu.items.bg.color: #2c2c30
menu.items.text.color: #f5f5f7
menu.separator.color: #3a3a3e
menu.title.bg.color: #2c2c30
menu.title.text.color: #a1a1a6
osd.bg.color: #2c2c30f0
osd.border.color: #3a3a3e
osd.label.text.color: #f5f5f7
FINE
    else
      echo "~/.config/labwc/themerc-override e' tuo: non lo tocco" >&2
    fi
  elif [ -f "$over" ] && grep -qF "$SEGNO" "$over"; then
    rm -f "$over"
  fi
  labwc --reconfigure >/dev/null 2>&1 || echo "labwc --reconfigure non riuscito" >&2
  # la barra e il dock ripartono con i colori nuovi; gli altri programmi quando li riapri
  if pgrep -u "$(id -u)" -x xfce4-panel >/dev/null; then
    setsid xfce4-panel -r >/dev/null 2>&1 < /dev/null &
  fi
  notify-send -i "$ICONA" "$TITOLO" "Fatto. I programmi gia' aperti cambiano colore quando li riapri." 2>/dev/null
fi
exit 0
EOF
chmod 755 /usr/local/bin/impostazioni /usr/local/bin/impostazioni-schermo /usr/local/bin/impostazioni-aspetto
local t
for t in impostazioni impostazioni-schermo impostazioni-aspetto; do bash -n "/usr/local/bin/$t"; done
cat > /usr/share/applications/impostazioni.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Impostazioni
Comment=Schermo, aspetto, VPN, modalita' fantasma, rete, programmi Windows e altro
Exec=/usr/local/bin/impostazioni
Icon=preferences-system
Terminal=false
Categories=Settings;System;
EOF
cat > /usr/share/applications/impostazioni-schermo.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Schermo
Comment=Risoluzione e grandezza di testi e finestre
Exec=/usr/local/bin/impostazioni-schermo
Icon=preferences-desktop-display
Terminal=false
Categories=Settings;HardwareSettings;
Keywords=risoluzione;monitor;display;grandezza;
EOF
cat > /usr/share/applications/impostazioni-aspetto.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Aspetto
Comment=Sfondo del desktop e finestre chiare o scure
Exec=/usr/local/bin/impostazioni-aspetto
Icon=preferences-desktop-wallpaper
Terminal=false
Categories=Settings;DesktopSettings;
Keywords=sfondo;wallpaper;tema;scuro;chiaro;colori;
EOF
update-desktop-database /usr/share/applications
echo "[OK] Impostazioni pronte: Schermo, Aspetto e le altre (registro: ~/.cache/impostazioni.log)"
}

LISTA_STEP15=(
  "sfondi, simbolo e pulsanti|-|f8_immagini"
  "tema Elegante (programmi e finestre)|-|f8_tema"
  "barra in alto e dock|-|f8_barre"
  "ricerca, notifiche, sfondo, blocco schermo|-|f8_ritocchi"
  "impostazioni (schermo, aspetto)|-|f8_impostazioni"
)

cmd_fase8() {
  serve_root fase8
  titolo "Fase 8 - Aspetto elegante: barra in alto, dock, finestre con i pulsanti tondi"
  assicura_montato
  # le domande subito, cosi' poi lavora da solo fino alla fine
  chiedi_utente
  chiedi_password_fantasma
  # le fasi precedenti con parti nuove (aggiunte dopo) o non finite si completano prima
  completa_fasi_precedenti 14
  titolo "Fase 8 - Aspetto elegante: barra in alto, dock, finestre con i pulsanti tondi"
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP15[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 8 da capo (opzione 'rifai')"
  fi
  info "Non c'e' niente da scaricare. Ci vogliono pochi minuti (disegno gli sfondi)."
  local esito=0
  lancia_in_chroot 15 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase8 MIA_ETICHETTA="Fase 8" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 8 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia). Novita':"
  info "   In alto: barra trasparente con menu, volume, Impostazioni, data e ora"
  info "   In basso: il dock con le app e le finestre aperte"
  info "   Finestre: pulsanti tondi a sinistra (rosso chiude, giallo riduce, verde ingrandisce)"
  info "   Impostazioni -> Aspetto: sfondo (anche una tua immagine) e finestre chiare o scure"
  info "   Se una finestra delle Impostazioni non si apre, il motivo e' in ~/.cache/impostazioni.log"
}

# =============================================================================
#  FASE 9 - PIU' SIMILE A MACOS E WINDOWS
#   - icone "squircle" (angoli molto arrotondati) per Impostazioni, Spegnimento e il
#     browser di riserva: disegni originali, non copie di icone esistenti
#   - gestore file (Thunar) con barra laterale "Preferiti", barra del percorso a
#     "briciole" (come il Finder o Esplora risorse) e icone piu' grandi
#   - finestre: ombre piu' morbide e ampie, angoli un filo piu' arrotondati
#   NOTA: labwc (il gestore delle finestre) non sa fare dissolvenze o animazioni vere
#   (non e' un "compositor" con effetti come quelli di GNOME o KDE); per averle
#   servirebbe cambiare tutto il gestore delle finestre, un lavoro piu' grosso e
#   rischioso che per ora non si fa. Qui si lavora su quello che labwc sa disegnare
#   davvero: ombre e angoli.
#  Niente di questo e' nel libro BLFS ("# NON IN BLFS"): sono file di configurazione e
#  immagini disegnate con Python (vedi Fase 8).
# =============================================================================

f9_icone() {
# NON IN BLFS: icone "squircle" per Impostazioni, Spegnimento e il browser di riserva
local D=/usr/local/lib/elegante/disegna-elegante t
# la versione nuova del programma che disegna (quella della Fase 8 fatta prima
# non sa ancora fare le icone "squircle")
install -vdm755 /usr/local/lib/elegante
cat > "$D" << "EOF"
#!/usr/bin/python3 -I
# Disegna le immagini dell'aspetto "Elegante" (creato da lfs.sh), solo Python:
#   disegna-elegante sfondo FILE.png [chiaro|scuro]   sfondo 1920x1080 a onde morbide
#   disegna-elegante logo FILE.png LATO               il simbolo della distro (menu in alto)
#   disegna-elegante griglia FILE.png LATO            l'icona di "Tutte le app"
#   disegna-elegante pulsanti CARTELLA                i pulsanti tondi colorati delle finestre
#   disegna-elegante icona SIMBOLO FILE.png LATO      icona "squircle" di un'app (Fase 9)
import math, os, struct, sys, zlib

def png(percorso, larghezza, altezza, righe, alfa):
    dati = bytearray()
    for r in righe:
        dati.append(0)
        dati += r
    def blocco(tipo, d):
        return struct.pack(">I", len(d)) + tipo + d + struct.pack(">I", zlib.crc32(tipo + d) & 0xffffffff)
    with open(percorso, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(blocco(b"IHDR", struct.pack(">IIBBBBB", larghezza, altezza, 8, 6 if alfa else 2, 0, 0, 0)))
        f.write(blocco(b"IDAT", zlib.compress(bytes(dati), 9)))
        f.write(blocco(b"IEND", b""))

def colore(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def mescola(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def morbido(x):                       # 0..1 con bordi dolci
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)

# ------------------------------------------------------------------- sfondo
def sfondo(percorso, tono="chiaro"):
    L, A = 1920, 1080
    if tono == "scuro":
        angoli = [colore("#141a3a"), colore("#2a1b4d"), colore("#3d1f3f"), colore("#0d2a3f")]
        onde = [(colore("#5b6cff"), 0.35), (colore("#b45cff"), 0.30), (colore("#ff7a8a"), 0.22)]
    else:
        angoli = [colore("#4f9dff"), colore("#8b6dff"), colore("#ff9a85"), colore("#4cc9f0")]
        onde = [(colore("#ffffff"), 0.42), (colore("#d9c9ff"), 0.55), (colore("#ffe3d3"), 0.55)]
    # tre onde: altezza di base, ampiezza, lunghezza, fase, spessore
    forme = [(0.58, 0.10, 1.25, 0.3, 0.16), (0.70, 0.08, 0.95, 2.1, 0.14), (0.84, 0.06, 1.6, 4.0, 0.12)]
    righe = []
    for y in range(A):
        fy = y / (A - 1)
        riga = bytearray()
        for x in range(L):
            fx = x / (L - 1)
            alto = mescola(angoli[0], angoli[1], fx)
            basso = mescola(angoli[3], angoli[2], fx)
            c = mescola(alto, basso, morbido(fy))
            for (col, forza), (base, amp, lung, fase, spess) in zip(onde, forme):
                centro = base + amp * math.sin(fx * 2 * math.pi / lung + fase) \
                    + 0.025 * math.sin(fx * 9.0 + fase * 2)
                d = (fy - centro) / spess
                if -1.6 < d < 1.0:
                    # sopra l'onda sfuma piano, sotto il bordo e' piu' netto
                    k = forza * (morbido(1 - abs(d) / 1.6) if d < 0 else morbido(1 - d))
                    c = mescola(c, col, k)
            s = ((x * 7 + y * 13) & 3) * 0.25 - 0.375          # niente righe nelle sfumature
            riga += bytes(min(255, max(0, int(v + s + 0.5))) for v in c)
        righe.append(riga)
    png(percorso, L, A, righe, False)

# ------------------------------------------------------------------- dischi
def disegna(lato, funzione, campioni=4):
    """funzione(x, y) con x,y in 0..1 -> (r, g, b, a 0..1) oppure None; bordi morbidi"""
    righe = []
    for y in range(lato):
        riga = bytearray()
        for x in range(lato):
            somma = [0.0, 0.0, 0.0, 0.0]
            for sy in range(campioni):
                for sx in range(campioni):
                    v = funzione((x + (sx + 0.5) / campioni) / lato, (y + (sy + 0.5) / campioni) / lato)
                    if v:
                        r, g, b, a = v
                        somma[0] += r * a; somma[1] += g * a; somma[2] += b * a; somma[3] += a
            n = campioni * campioni
            a = somma[3] / n
            if a <= 0:
                riga += bytes((0, 0, 0, 0))
            else:
                riga += bytes((int(somma[0] / somma[3]), int(somma[1] / somma[3]), int(somma[2] / somma[3]),
                               int(a * 255 + 0.5)))
        righe.append(riga)
    return righe

def logo(percorso, lato):
    """Un cerchio con sfumatura azzurro-viola e un anello bianco (simbolo della distro)."""
    a, b = colore("#2f8bff"), colore("#a55bff")
    def f(x, y):
        d = math.hypot(x - 0.5, y - 0.5)
        if d > 0.46:
            return None
        if 0.20 < d < 0.29 or (0.30 < x < 0.70 and abs(y - 0.5) < 0.04 and d < 0.20):
            return (255, 255, 255, 1.0)
        c = mescola(a, b, morbido((x + y) / 2))
        return (*c, 1.0)
    png(percorso, lato, lato, disegna(lato, f), True)

def griglia(percorso, lato):
    """Icona di "Tutte le app": quadrato arrotondato azzurro con nove puntini bianchi."""
    a, b = colore("#38b6ff"), colore("#6a5cff")
    def f(x, y):
        # quadrato con gli angoli molto arrotondati
        m, r = 0.06, 0.22
        dx = max(abs(x - 0.5) - (0.5 - m - r), 0.0)
        dy = max(abs(y - 0.5) - (0.5 - m - r), 0.0)
        if math.hypot(dx, dy) > r:
            return None
        for cy in (0.31, 0.5, 0.69):
            for cx in (0.31, 0.5, 0.69):
                if math.hypot(x - cx, y - cy) < 0.065:
                    return (255, 255, 255, 1.0)
        return (*mescola(a, b, morbido((x * 0.4 + y * 0.6))), 1.0)
    png(percorso, lato, lato, disegna(lato, f), True)

# --------------------------------------------------------- icone delle app
def _squircle(x, y, m=0.045, r=0.30):
    """Dentro al quadrato con gli angoli molto arrotondati (stile icone macOS)?"""
    dx = max(abs(x - 0.5) - (0.5 - m - r), 0.0)
    dy = max(abs(y - 0.5) - (0.5 - m - r), 0.0)
    return math.hypot(dx, dy) <= r

def _linea(x, y, x1, y1, x2, y2, spessore):
    """Distanza (in unita' dell'icona) dal segmento (x1,y1)-(x2,y2) <= spessore?"""
    dx, dy = x2 - x1, y2 - y1
    l2 = dx * dx + dy * dy
    t = 0 if l2 == 0 else max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / l2))
    px, py = x1 + t * dx, y1 + t * dy
    return math.hypot(x - px, y - py) <= spessore

_SIMBOLI = {}
def _simbolo(nome):
    def _(f): _SIMBOLI[nome] = f; return f
    return _

@_simbolo("globo")                                       # browser: un mondo stilizzato
def _g_globo(x, y):
    d = math.hypot(x - 0.5, y - 0.5)
    if not (0.27 < d < 0.33):
        if abs(x - 0.5) < 0.017 and d < 0.30:
            return True
        if abs(y - 0.5) < 0.017 and d < 0.30:
            return True
        if abs((x - 0.5) * 2.1) < 0.14 and abs(d - 0.0) < 0.30 \
           and abs(math.hypot((x - 0.5) * 2.1, y - 0.5) - 0.30) < 0.017:
            return True
        return False
    return True

@_simbolo("cartella")                                     # gestore file: una cartella
def _g_cartella(x, y):
    corpo = 0.20 < x < 0.80 and 0.40 < y < 0.74
    coperchio = 0.20 < x < 0.44 and 0.32 < y < 0.40
    return corpo or coperchio

@_simbolo("busta")                                         # posta: una busta con la "V"
def _g_busta(x, y):
    bordo = 0.18 < x < 0.82 and 0.32 < y < 0.68
    if not bordo:
        return False
    cornice = x < 0.22 or x > 0.78 or y < 0.36 or y > 0.64
    if cornice:
        return True
    return _linea(x, y, 0.18, 0.32, 0.50, 0.54, 0.028) or _linea(x, y, 0.82, 0.32, 0.50, 0.54, 0.028)

def _pagina(x, y, righe_colore=None):
    """Un foglio verticale con tre righe di "testo"; righe_colore: colore delle righe (altrimenti bianco)."""
    foglio = 0.31 < x < 0.69 and 0.20 < y < 0.80
    if not foglio:
        return None
    for ry in (0.36, 0.48, 0.60):
        if abs(y - ry) < 0.028 and x < 0.62:
            return righe_colore if righe_colore else False
    return True

@_simbolo("documento")                                     # editor di testo: un foglio
def _g_documento(x, y):
    return bool(_pagina(x, y))

@_simbolo("terminale")                                     # terminale: finestra con ">_"
def _g_terminale(x, y):
    cornice = (0.20 < x < 0.80 and 0.26 < y < 0.74) and \
              (x < 0.235 or x > 0.765 or y < 0.295 or y > 0.705)
    if cornice:
        return True
    chevron = _linea(x, y, 0.33, 0.40, 0.44, 0.50, 0.030) or _linea(x, y, 0.33, 0.60, 0.44, 0.50, 0.030)
    cursore = 0.48 < x < 0.60 and 0.565 < y < 0.60
    return chevron or cursore

@_simbolo("ingranaggio")                                   # impostazioni: una ruota dentata
def _g_ingranaggio(x, y):
    dx, dy = x - 0.5, y - 0.5
    d = math.hypot(dx, dy)
    ang = math.atan2(dy, dx)
    dente = 0.025 * (1 + math.cos(ang * 8))
    if 0.14 < d < 0.30 + dente:
        return d > 0.155
    return False

@_simbolo("accensione")                                     # spegnimento: simbolo di accensione
def _g_accensione(x, y):
    dx, dy = x - 0.5, y - 0.5
    d = math.hypot(dx, dy)
    ang = math.degrees(math.atan2(dy, dx))
    anello = 0.24 < d < 0.30 and not (-125 < ang < -55)
    asta = abs(dx) < 0.017 and -0.30 < dy < -0.03
    return anello or asta

def icona_app(percorso, lato, simbolo, c1, c2=None):
    """Icona "squircle" (stile macOS): sfondo a colore pieno (o sfumato c1->c2) col
    simbolo bianco al centro. Disegni originali, non copie di icone esistenti."""
    a = colore(c1); b = colore(c2) if c2 else a
    g = _SIMBOLI[simbolo]
    def f(x, y):
        if not _squircle(x, y):
            return None
        v = g(x, y)
        if v is True:
            return (255, 255, 255, 1.0)
        fondo = mescola(a, b, morbido((x + y) / 2))
        if isinstance(v, str):
            return (*mescola(fondo, colore(v), 0.55), 1.0)
        return (*fondo, 1.0)
    png(percorso, lato, lato, disegna(lato, f), True)

def pulsanti(cartella):
    """Tre dischi colorati (chiudi, riduci, ingrandisci). Passandoci sopra col mouse
    compare il simbolo; nelle finestre non attive sono grigi."""
    os.makedirs(cartella, exist_ok=True)
    lato, r = 40, 0.30
    colori = {"close": ("#ff5f57", "#e0443e"), "iconify": ("#febc2e", "#dea123"), "max": ("#28c840", "#1aab29")}
    def simbolo(tipo, x, y):
        dx, dy = x - 0.5, y - 0.5
        t = 0.035                                            # spessore del segno
        if tipo == "close":
            return (abs(dx - dy) < t * 1.4 or abs(dx + dy) < t * 1.4) and abs(dx) < 0.13 and abs(dy) < 0.13
        if tipo == "iconify":
            return abs(dy) < t and abs(dx) < 0.15
        return (abs(dy) < t and abs(dx) < 0.15) or (abs(dx) < t and abs(dy) < 0.15)
    for tipo, (pieno, bordo) in colori.items():
        for stato in ("active", "inactive", "hover-active", "hover-inactive"):
            inattivo = stato == "inactive"
            col = colore("#d4d4d8") if inattivo else colore(pieno)
            col_bordo = colore("#c0c0c6") if inattivo else colore(bordo)
            con_segno = stato.startswith("hover")
            def f(x, y, col=col, col_bordo=col_bordo, con_segno=con_segno, tipo=tipo):
                d = math.hypot(x - 0.5, y - 0.5)
                if d > r:
                    return None
                if con_segno and simbolo(tipo, x, y):
                    return (90, 30, 25, 0.75) if tipo == "close" else (100, 65, 10, 0.75) if tipo == "iconify" \
                        else (20, 90, 30, 0.75)
                if d > r - 0.03:
                    return (*col_bordo, 1.0)
                return (*col, 1.0)
            nomi = {"active": f"{tipo}-active", "inactive": f"{tipo}-inactive",
                    "hover-active": f"{tipo}_hover-active", "hover-inactive": f"{tipo}_hover-inactive"}
            righe = disegna(lato, f)
            png(os.path.join(cartella, nomi[stato] + ".png"), lato, lato, righe, True)
            if tipo == "max":                                 # finestra gia' ingrandita: stessi pulsanti
                png(os.path.join(cartella, nomi[stato].replace("max", "max_toggled", 1) + ".png"),
                    lato, lato, righe, True)

if __name__ == "__main__":
    cosa = sys.argv[1] if len(sys.argv) > 1 else ""
    if cosa == "sfondo":
        sfondo(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "chiaro")
    elif cosa == "logo":
        logo(sys.argv[2], int(sys.argv[3]))
    elif cosa == "griglia":
        griglia(sys.argv[2], int(sys.argv[3]))
    elif cosa == "pulsanti":
        pulsanti(sys.argv[2])
    elif cosa == "icona":
        icona_app(sys.argv[3], int(sys.argv[4]), sys.argv[2],
                  sys.argv[5], sys.argv[6] if len(sys.argv) > 6 else None)
    else:
        sys.exit("Uso: disegna-elegante sfondo FILE [chiaro|scuro] | logo FILE LATO | griglia FILE LATO"
                 " | pulsanti CARTELLA | icona SIMBOLO FILE LATO COLORE1 [COLORE2]")
EOF
chmod 755 "$D"
python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$D"
grep -q 'def icona_app' "$D" || { echo "Il programma che disegna non sa fare le icone"; return 1; }
for t in 16 22 24 32 48 64 128 256; do
  install -dm755 "/usr/share/icons/hicolor/${t}x${t}/apps"
  python3 -I "$D" icona ingranaggio "/usr/share/icons/hicolor/${t}x${t}/apps/icona-impostazioni.png" "$t" "#8e8e93" "#aeaeb2"
  python3 -I "$D" icona accensione  "/usr/share/icons/hicolor/${t}x${t}/apps/icona-spegnimento.png"   "$t" "#ff5f57" "#ff8a7a"
  python3 -I "$D" icona globo       "/usr/share/icons/hicolor/${t}x${t}/apps/icona-browser.png"       "$t" "#3a82f6" "#60a5fa"
done
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
[ -f /usr/share/applications/impostazioni.desktop ] \
  && sed -i 's|^Icon=.*|Icon=icona-impostazioni|' /usr/share/applications/impostazioni.desktop
[ -f /usr/share/applications/spegnimento.desktop ] \
  && sed -i 's|^Icon=.*|Icon=icona-spegnimento|' /usr/share/applications/spegnimento.desktop
# il browser di riserva (solo se Tor Browser non ha trovato la sua vera icona)
[ -f /usr/share/applications/tor-browser.desktop ] \
  && sed -i 's|^Icon=web-browser$|Icon=icona-browser|' /usr/share/applications/tor-browser.desktop
if command -v update-desktop-database >/dev/null; then update-desktop-database /usr/share/applications; fi
echo "[OK] Icone di Impostazioni, Spegnimento e del browser di riserva"
}

f9_file_manager() {
# NON IN BLFS: Thunar con barra laterale "Preferiti", percorso a briciole (come il
# Finder o Esplora risorse) e icone piu' grandi (configurazione, nessun pacchetto nuovo)
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa; casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
[ -d "$casa" ] || { echo "Non trovo la cartella di $MIA_UTENTE"; return 1; }
install -dm755 /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/thunar.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>

<channel name="thunar" version="1.0">
  <property name="default-view" type="string" value="ThunarIconView"/>
  <property name="last-view" type="string" value="ThunarIconView"/>
  <property name="last-icon-view-zoom-level" type="string" value="THUNAR_ZOOM_LEVEL_150_PERCENT"/>
  <property name="last-side-pane" type="string" value="ThunarShortcutsPane"/>
  <property name="last-side-pane-visible" type="bool" value="true"/>
  <property name="last-show-hidden" type="bool" value="false"/>
  <property name="last-location-bar" type="string" value="ThunarLocationButtons"/>
  <property name="misc-single-click" type="bool" value="false"/>
  <property name="last-window-width" type="int" value="980"/>
  <property name="last-window-height" type="int" value="620"/>
  <property name="last-separator-position" type="int" value="180"/>
</channel>
EOF
# la finestra dell'utente riparte dalla nuova configurazione (come fa la barra in Fase 8)
rm -f "$casa/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"
# "Preferiti" nella barra laterale, come il Finder (solo se non li hai gia' cambiati tu)
mkdir -p "$casa/.config/gtk-3.0"
if [ ! -e "$casa/.config/gtk-3.0/bookmarks" ]; then
  {
    echo "file://$casa Casa"
    [ -d "$casa/Documenti" ] && echo "file://$casa/Documenti Documenti"
    [ -d "$casa/Scaricati" ] && echo "file://$casa/Scaricati Scaricati"
    [ -d "$casa/Immagini" ]  && echo "file://$casa/Immagini Immagini"
  } > "$casa/.config/gtk-3.0/bookmarks"
fi
chown -R "$MIA_UTENTE:" "$casa/.config/gtk-3.0" "$casa/.config/xfce4" 2>/dev/null || true
echo "[OK] Gestore file: barra laterale, percorso a briciole, icone piu' grandi"
}

f9_finestre() {
# Rifiniture di Elegante: ombre piu' morbide e ampie, angoli un filo piu' arrotondati
# (labwc non ha dissolvenze o transizioni: vedi la nota a inizio Fase 9)
local t=/usr/share/themes/Elegante/labwc/themerc
[ -f "$t" ] || { echo "Manca il tema Elegante (serve la Fase 8)"; return 1; }
sed -i -e 's/^window.active.shadow.size:.*/window.active.shadow.size: 46/' \
       -e 's/^window.inactive.shadow.size:.*/window.inactive.shadow.size: 26/' \
       -e 's/^window.active.shadow.color:.*/window.active.shadow.color: #00000055/' \
       -e 's/^window.inactive.shadow.color:.*/window.inactive.shadow.color: #00000022/' \
       "$t"
grep -q '^window.active.shadow.size: 46$' "$t" || { echo "Non riesco a cambiare le ombre"; return 1; }
sed -i 's|<cornerRadius>[0-9]*</cornerRadius>|<cornerRadius>14</cornerRadius>|' /etc/xdg/labwc/rc.xml
grep -q '<cornerRadius>14</cornerRadius>' /etc/xdg/labwc/rc.xml \
  || { echo "Non riesco a cambiare gli angoli delle finestre"; return 1; }
echo "[OK] Ombre piu' morbide e angoli piu' arrotondati"
}

LISTA_STEP16=(
  "icone di Impostazioni e Spegnimento|-|f9_icone"
  "gestore file (barra laterale, percorso a briciole)|-|f9_file_manager"
  "finestre: ombre e angoli|-|f9_finestre"
)

cmd_fase9() {
  serve_root fase9
  titolo "Fase 9 - Piu' simile a macOS e Windows: icone, gestore file, finestre"
  assicura_montato
  chiedi_utente
  chiedi_password_fantasma
  completa_fasi_precedenti 15
  titolo "Fase 9 - Piu' simile a macOS e Windows: icone, gestore file, finestre"
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP16[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 9 da capo (opzione 'rifai')"
  fi
  info "Non c'e' niente da scaricare. Ci vogliono pochi minuti."
  local esito=0
  lancia_in_chroot 16 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase9 MIA_ETICHETTA="Fase 9" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 9 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia). Novita':"
  info "   Impostazioni: nuove icone (ingranaggio grigio, spegnimento rosso)"
  info "   Gestore file: barra laterale con Casa/Documenti/Scaricati/Immagini, percorso"
  info "   a briciole in alto, icone piu' grandi"
  info "   Finestre: ombra piu' morbida e ampia, angoli un filo piu' arrotondati"
  info "   (labwc non sa fare dissolvenze/animazioni: servirebbe cambiare il gestore"
  info "   delle finestre, un lavoro piu' grosso che per ora non si fa)"
}

# =============================================================================
#  FASE 10 - DESKTOP "VETRO" (Hyprland + Quickshell, come nel video)
#   - Hyprland al posto di labwc: finestre con animazioni fluide, sfocatura dietro i
#     pannelli, angoli tondi e ombre. labwc resta di riserva: se Hyprland non parte
#     (o la macchina virtuale non ha l'accelerazione 3D) si apre il desktop di prima
#   - Quickshell per tutta la grafica, con pannelli scritti qui (niente copiato):
#     barra in alto, blocco schermo con l'orologio grande, centro di controllo a
#     destra, cruscotto (meteo, calendario, prestazioni, sfondi), notifiche, ricerca
#     delle app e Impostazioni con il menu a sinistra. Stile grigio scuro "a vetro"
#   - la macchina virtuale si accende con l'accelerazione 3D (virgl)
#  Quasi niente di questo e' nel libro BLFS ("# NON IN BLFS"): le ricette vengono dai
#  file dei progetti (CMakeLists.txt) e dalle distribuzioni Alpine e Void; i controlli
#  dei file scaricati (sha256/sha512) sono quelli di Alpine e Void.
# =============================================================================

FONTI_FASE10=(
  "SPIRV-Headers-vulkan-sdk-1.4.357.0.tar.gz|https://github.com/KhronosGroup/SPIRV-Headers/archive/vulkan-sdk-1.4.357.0/SPIRV-Headers-vulkan-sdk-1.4.357.0.tar.gz|md5:085dd07d487c165c0ca7713d726eb6de"
  "SPIRV-Tools-vulkan-sdk-1.4.357.0.tar.gz|https://github.com/KhronosGroup/SPIRV-Tools/archive/vulkan-sdk-1.4.357.0/SPIRV-Tools-vulkan-sdk-1.4.357.0.tar.gz|md5:c357eec1e33bc95e650aa4c8efdd3b13"
  "pugixml-1.14.tar.gz|https://github.com/zeux/pugixml/releases/download/v1.14/pugixml-1.14.tar.gz|sha256:2f10e276870c64b1db6809050a75e11a897a8d7456c4be5c6b2e35a11168a015"
  "tomlplusplus-3.4.0.tar.gz|https://github.com/marzer/tomlplusplus/archive/v3.4.0/tomlplusplus-v3.4.0.tar.gz|sha512:c227fc8147c9459b29ad24002aaf6ab2c42fac22ea04c1c52b283a0172581ccd4527b33c1931e0ef0d1db6b6a53f9e9882c6d4231c7f3494cf070d0220741aa5"
  "libzip-1.12.1.tar.gz|https://libzip.org/download/libzip-1.12.1.tar.gz|sha256:3b66fe92cbc768d8d4d16e1427bfb7399e15d9c2795c2fc482e7b30a6332a422"
  "muparser-2.3.5.tar.gz|https://github.com/beltoforion/muparser/archive/v2.3.5/muparser-2.3.5.tar.gz|md5:04d4224cb01712207b85af05a255b6fc"
  "abseil-cpp-20250512.1.tar.gz|https://github.com/abseil/abseil-cpp/archive/20250512.1.tar.gz|sha256:9b7a064305e9fd94d124ffa6cc358592eb42b5da588fb4e07d09254aa40086db"
  "re2-2025-11-05.tar.gz|https://github.com/google/re2/archive/2025-11-05.tar.gz|sha256:87f6029d2f6de8aa023654240a03ada90e876ce9a4676e258dd01ea4c26ffd67"
  "udis86-1.7.2.tar.gz|https://downloads.sourceforge.net/udis86/udis86-1.7.2.tar.gz|sha256:9c52ac626ac6f531e1d6828feaad7e797d0f3cce1e9f34ad4e84627022b3c2f4"
  "hyprutils-0.13.1.tar.gz|https://github.com/hyprwm/hyprutils/archive/v0.13.1/hyprutils-v0.13.1.tar.gz|sha512:d090c2e30fe20afea6290f63a8ab4f695350cd61ab02e85b32e19fde02a928388883373dd1539135596091cbeaaac2d7cb2738173bb87c4d770584032f5f7b5a"
  "hyprwayland-scanner-0.4.6.tar.gz|https://github.com/hyprwm/hyprwayland-scanner/archive/v0.4.6/hyprwayland-scanner-v0.4.6.tar.gz|sha512:c82a4e479fff26f2e9797151ce222d05202585bdf4242829713249ee27e53b987d393f92c031da0ec9c61134590442568010040cbc29a7a3631bc09a2cd3f1bb"
  "hyprlang-0.6.8.tar.gz|https://github.com/hyprwm/hyprlang/archive/v0.6.8.tar.gz|sha512:886f474884f5c5ae65d97742aa22476e32260446384a4003b5c1a32511ff3415089cb5835c4442e9eb02b6312cae0a2ad001f97c0ebfb9b6cb4ba5082b89521c"
  "hyprcursor-0.1.13.tar.gz|https://github.com/hyprwm/Hyprcursor/archive/v0.1.13/Hyprcursor-v0.1.13.tar.gz|sha512:ba602d0cdd8b58c9c24763199dcc4ec580152ae5c27dd8e74ee537ed7b7702c4657e8c34afeee4f238d1ff9ede7ca3efbd8fd0a67562beace2c462201d0b904d"
  "hyprgraphics-0.5.1.tar.gz|https://github.com/hyprwm/hyprgraphics/archive/v0.5.1/hyprgraphics-v0.5.1.tar.gz|sha512:5e0a9717536bef833a148e68ad61f479d445dc0e6ee23a0b3b8b922cc1939e0256e26ecfcf7709e4ec057197699c6145cf0b2228785a1061c1412d2b2c962be6"
  "hyprland-protocols-0.7.0.tar.gz|https://github.com/hyprwm/hyprland-protocols/archive/v0.7.0/hyprland-protocols-v0.7.0.tar.gz|sha512:809016a2d25b6cd91befc34d89c4acc3c1fce5628cac490a149f3aa5b413b680cecb4c66e86e59e02c55c2a3cfee2be911cd26c55910527e02e6983245a481a5"
  "hyprwire-0.3.1.tar.gz|https://github.com/hyprwm/hyprwire/archive/v0.3.1/hyprwire-v0.3.1.tar.gz|sha512:eb4d7d71d3101ad33897c06f08095d528a525880fbb20bb69b22d49bd8d920368cddea294125c814ebaf874574e63b268593b94443ab6cb6690d9990fe1d25f5"
  "aquamarine-0.12.0.tar.gz|https://github.com/hyprwm/aquamarine/archive/v0.12.0/aquamarine-v0.12.0.tar.gz|sha512:14eea03cba498ed398f90933bebd987e6d3f319f5223efdeb808e194b4237486d2b05334799415930821b0e17d9478709bea8ab4f9d6c8aaf297e95f251b0b84"
  "glaze-9.0.0.tar.gz|https://github.com/stephenberry/glaze/archive/v9.0.0/glaze-9.0.0.tar.gz|-"
  "Hyprland-0.54.3.tar.gz|https://github.com/hyprwm/Hyprland/archive/v0.54.3/Hyprland-v0.54.3.tar.gz|sha512:cd4c183a5eebcb7f94b0fb670c057363f354fc197baa40d51e20baf6373867754334e6a65bef88b68c34016f0366292d4961d0670f214d747b69d5250d9cee39"
  "qtbase-everywhere-src-6.11.2.tar.xz|https://download.qt.io/archive/qt/6.11/6.11.2/submodules/qtbase-everywhere-src-6.11.2.tar.xz|sha256:5b2e00eccaf5a4d8c14134ffa0ea8dfd0a35ae1ffc7f8d87fa4305a1ed23cf22"
  "qtshadertools-everywhere-src-6.11.2.tar.xz|https://download.qt.io/archive/qt/6.11/6.11.2/submodules/qtshadertools-everywhere-src-6.11.2.tar.xz|sha256:805046b8b7757665586890b375940047e874ae3ab00adb6d3f2b38fc6b200b1c"
  "qtsvg-everywhere-src-6.11.2.tar.xz|https://download.qt.io/archive/qt/6.11/6.11.2/submodules/qtsvg-everywhere-src-6.11.2.tar.xz|sha256:d594337feca84c26fb67fe87b85e6a5c12fda404b611d905f9d138210c311876"
  "qtdeclarative-everywhere-src-6.11.2.tar.xz|https://download.qt.io/archive/qt/6.11/6.11.2/submodules/qtdeclarative-everywhere-src-6.11.2.tar.xz|sha256:215b7b70517e380123eabc6b92243f3c47b6f016a91d126057dbe53551c6b430"
  "CLI11-2.7.2.tar.gz|https://github.com/CLIUtils/CLI11/archive/refs/tags/v2.7.2.tar.gz|sha256:46eef3101da70852ec7af026e09d485ccee81813331c8c6052d39344443b83da"
  "quickshell-0.3.2.tar.gz|https://git.outfoxxed.me/quickshell/quickshell/archive/v0.3.2.tar.gz|sha256:f14115a73c9fff6aa6399f924b632e88c3ce2cead2657f814a7825341f35baad"
)
# Le icone dei pannelli (Material Symbols, licenza Apache 2.0): il file cambia ogni
# tanto, quindi non c'e' un controllo fisso. Se non si scarica si va avanti lo stesso
# (i pannelli usano dei simboli semplici al posto delle icone).
FONT_ICONE_URL="https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
FONT_ICONE_FILE="MaterialSymbolsRounded.ttf"

lavori_pesanti() { # quanti lavori in parallelo per Qt e Hyprland: 1 ogni 2 GB di memoria
  local gb n
  gb=$(awk '/^MemTotal:/ { print int($2 / 1048576) }' /proc/meminfo 2>/dev/null)
  n=$(( ${gb:-4} / 2 )); [ "$n" -ge 1 ] || n=1
  [ "$n" -le "$(nproc)" ] || n=$(nproc)
  echo "$n"
}

f10_spirv_headers() {
# BLFS, pagina "SPIRV-Headers" (servono a SPIRV-Tools)
mkdir build
cd    build
cmake -D CMAKE_INSTALL_PREFIX=/usr -G Ninja ..
ninja
ninja install
}

f10_spirv_tools() {
# BLFS, pagina "SPIRV-Tools" (Quickshell li usa per preparare i suoi effetti grafici)
mkdir build
cd    build
cmake -D CMAKE_INSTALL_PREFIX=/usr     \
      -D CMAKE_BUILD_TYPE=Release      \
      -D SPIRV_WERROR=OFF              \
      -D BUILD_SHARED_LIBS=ON          \
      -D SPIRV_TOOLS_BUILD_STATIC=OFF  \
      -D SPIRV-Headers_SOURCE_DIR=/usr \
      -G Ninja ..
ninja
ninja install
}

f10_pugixml() {
# NON IN BLFS: lettore di file XML (lo usano hyprwayland-scanner e hyprwire)
cmake -B build -G Ninja           \
      -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -D BUILD_SHARED_LIBS=ON
ninja -C build
ninja -C build install
}

f10_tomlplusplus() {
# NON IN BLFS: lettore di file TOML (lo usa hyprcursor)
meson setup build --prefix=/usr --buildtype=release
ninja -C build
ninja -C build install
}

f10_libzip() {
# NON IN BLFS: archivi ZIP (lo usa hyprcursor per i temi dei puntatori)
cmake -B build -G Ninja             \
      -D CMAKE_INSTALL_PREFIX=/usr   \
      -D CMAKE_BUILD_TYPE=Release    \
      -D ENABLE_GNUTLS=OFF           \
      -D ENABLE_MBEDTLS=OFF          \
      -D BUILD_DOC=OFF               \
      -D BUILD_EXAMPLES=OFF          \
      -D BUILD_REGRESS=OFF           \
      -D BUILD_OSSFUZZ=OFF
ninja -C build
ninja -C build install
}

f10_muparser() {
# BLFS, pagina "muparser" (Hyprland lo usa per i calcoli nella configurazione)
mkdir -v build
cd       build
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      ..
make
make install
}

f10_abseil() {
# NON IN BLFS: libreria di base di Google, serve a RE2
cmake -B build -G Ninja               \
      -D CMAKE_INSTALL_PREFIX=/usr     \
      -D CMAKE_BUILD_TYPE=Release      \
      -D BUILD_SHARED_LIBS=ON          \
      -D ABSL_PROPAGATE_CXX_STD=ON     \
      -D CMAKE_CXX_STANDARD=17         \
      -D ABSL_BUILD_TESTING=OFF
ninja -C build
ninja -C build install
}

f10_re2() {
# NON IN BLFS: espressioni regolari veloci (Hyprland le usa nelle regole delle finestre)
cmake -B build -G Ninja             \
      -D CMAKE_INSTALL_PREFIX=/usr   \
      -D CMAKE_BUILD_TYPE=Release    \
      -D BUILD_SHARED_LIBS=ON        \
      -D RE2_USE_ICU=OFF             \
      -D RE2_BUILD_TESTING=OFF
ninja -C build
ninja -C build install
}

f10_udis86() {
# NON IN BLFS: legge le istruzioni del processore (Hyprland lo usa per i suoi "hook")
./configure --prefix=/usr --disable-static --enable-shared --with-python=false
make
make install
}

f10_rsvg_finto() {
# NON IN BLFS: una librsvg "finta". hyprcursor e hyprgraphics la vogliono per le
# immagini SVG, ma la librsvg vera si compila con Rust (pesantissimo). Qui ci sono
# solo le due funzioni che usano: rispondono "SVG non supportato". Va in /opt (solo
# questi pacchetti la vedono) e si collega dentro di loro, non resta installata come
# libreria. Effetto: i temi dei puntatori in SVG non si leggono (si usano quelli
# normali) e gli sfondi SVG non si aprono (si usano PNG e JPG).
local d=/opt/rsvg-finto
rm -rf "$d"
install -vdm755 "$d/include/librsvg-2.0/librsvg" "$d/lib/pkgconfig" "$d/src"
cat > "$d/include/librsvg-2.0/librsvg/rsvg.h" << "EOF"
/* librsvg "finta" (creata da lfs.sh, Fase 10): niente immagini SVG */
#ifndef RSVG_FINTO_H
#define RSVG_FINTO_H
#include <glib-object.h>
#include <cairo.h>
G_BEGIN_DECLS
typedef struct _RsvgHandle RsvgHandle;
typedef struct { double x, y, width, height; } RsvgRectangle;
RsvgHandle *rsvg_handle_new_from_data(const guint8 *data, gsize data_len, GError **error);
gboolean rsvg_handle_render_document(RsvgHandle *handle, cairo_t *cr,
                                     const RsvgRectangle *viewport, GError **error);
G_END_DECLS
#endif
EOF
cat > "$d/src/rsvg.c" << "EOF"
/* librsvg "finta" (creata da lfs.sh, Fase 10): risponde sempre "SVG non supportato" */
#include "librsvg/rsvg.h"
#define ERRORE "immagini SVG non supportate (manca la librsvg vera)"
static GQuark dominio(void) { return g_quark_from_static_string("rsvg-finto"); }
RsvgHandle *rsvg_handle_new_from_data(const guint8 *data, gsize data_len, GError **error) {
  (void)data; (void)data_len;
  g_set_error_literal(error, dominio(), 1, ERRORE);
  return NULL;
}
gboolean rsvg_handle_render_document(RsvgHandle *handle, cairo_t *cr,
                                     const RsvgRectangle *viewport, GError **error) {
  (void)handle; (void)cr; (void)viewport;
  if (error && !*error) g_set_error_literal(error, dominio(), 1, ERRORE);
  return FALSE;
}
EOF
gcc -O2 -fPIC -c "$d/src/rsvg.c" -o "$d/src/rsvg.o" -I"$d/include/librsvg-2.0" \
    $(pkg-config --cflags gobject-2.0 cairo)
ar rcs "$d/lib/librsvg-2.a" "$d/src/rsvg.o"
cat > "$d/lib/pkgconfig/librsvg-2.0.pc" << EOF
prefix=$d
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: librsvg (finta, lfs.sh)
Description: solo le funzioni usate da hyprcursor e hyprgraphics, senza SVG
Version: 2.60.0
Requires: gobject-2.0 cairo
Libs: -L\${libdir} -lrsvg-2
Cflags: -I\${includedir}/librsvg-2.0
EOF
PKG_CONFIG_PATH="$d/lib/pkgconfig" pkg-config --exists librsvg-2.0 \
  || { echo "La librsvg finta non si trova"; return 1; }
echo "[OK] librsvg finta pronta (solo per Hyprland)"
}

f10_hypr() {
# NON IN BLFS: le librerie di Hyprland (hyprutils, hyprlang, aquamarine...), tutte
# uguali: CMake, come nelle ricette di Alpine. -D BUILD_TESTING=OFF: niente prove
# (alcune vogliono GoogleTest, che qui non c'e')
export PKG_CONFIG_PATH="/opt/rsvg-finto/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
# MODIFICA: qui Mesa e' senza libglvnd, quindi non c'e' "OpenGL::OpenGL" (libOpenGL,
# la vuole aquamarine): si usa libGL di Mesa, come fa Hyprland stesso quando c'e'
if ! ls /usr/lib/libOpenGL.so* >/dev/null 2>&1; then
  sed -i 's/OpenGL::OpenGL/OpenGL::GL/g' CMakeLists.txt
fi
cmake -B build -G Ninja             \
      -D CMAKE_INSTALL_PREFIX=/usr   \
      -D CMAKE_INSTALL_LIBDIR=lib    \
      -D CMAKE_BUILD_TYPE=Release    \
      -D BUILD_TESTING=OFF
ninja -C build -j "$(lavori_pesanti)"
ninja -C build install
}

f10_hyprland_protocols() {
# NON IN BLFS: i "protocolli" di Hyprland (file XML che leggono Hyprland e Quickshell)
meson setup build --prefix=/usr --buildtype=release
ninja -C build
ninja -C build install
}

f10_glaze() {
# NON IN BLFS: solo file ".h" (nessuna libreria da compilare), li legge Hyprland per
# salvare/leggere le sue impostazioni in JSON
mkdir build
cd    build
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -D glaze_BUILD_EXAMPLES=OFF  \
      -D glaze_DEVELOPER_MODE=OFF  \
      -D glaze_ENABLE_FUZZING=OFF  \
      -G Ninja ..
ninja install
}

f10_hyprland() {
# NON IN BLFS: Hyprland, come nella ricetta di Alpine (-D NO_HYPRPM=ON: niente
# gestore dei plugin, scaricherebbe codice da internet). Le informazioni sulla
# versione, che di solito prende da git, si danno a mano.
export PKG_CONFIG_PATH="/opt/rsvg-finto/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export GIT_COMMIT_HASH=v0.54.3 GIT_BRANCH=lfs GIT_TAG=v0.54.3 GIT_DIRTY=clean \
       GIT_COMMIT_MESSAGE="compilato da lfs.sh" GIT_COMMIT_DATE=2026 GIT_COMMITS=0
cmake -B build -G Ninja             \
      -D CMAKE_INSTALL_PREFIX=/usr   \
      -D CMAKE_BUILD_TYPE=Release    \
      -D NO_HYPRPM=ON                \
      -D NO_UWSM=ON                  \
      -D BUILD_TESTING=OFF
ninja -C build -j "$(lavori_pesanti)"
ninja -C build install
command -v Hyprland >/dev/null || { echo "Hyprland non si e' installato"; return 1; }
echo "[OK] Hyprland installato"
}

f10_qtbase() {
# BLFS, pagina "Qt-6" (ma un modulo alla volta, solo quelli che servono a Quickshell,
# invece del pacchetto intero da quasi 1 GB). In /opt/qt6 come consiglia il libro.
# MODIFICA: niente ICU, X11 (xcb) e database (sql): a Quickshell non servono.
# QT_UNITY_BUILD=ON compila piu' in fretta (come Gentoo).
cmake -B build -G Ninja                    \
      -D CMAKE_INSTALL_PREFIX=/opt/qt6      \
      -D CMAKE_BUILD_TYPE=Release           \
      -D INSTALL_SYSCONFDIR=/etc/xdg        \
      -D QT_BUILD_EXAMPLES=OFF              \
      -D QT_BUILD_TESTS=OFF                 \
      -D QT_GENERATE_SBOM=OFF               \
      -D QT_UNITY_BUILD=ON                  \
      -D BUILD_WITH_PCH=OFF                 \
      -D QT_FEATURE_rpath=OFF               \
      -D QT_FEATURE_dbus_linked=ON          \
      -D QT_FEATURE_openssl_linked=ON       \
      -D QT_FEATURE_icu=OFF                 \
      -D QT_FEATURE_sql=OFF                 \
      -D QT_FEATURE_xcb=OFF                 \
      -D QT_FEATURE_xlib=OFF                \
      -D QT_FEATURE_wayland=ON              \
      -D QT_FEATURE_journald=ON             \
      -D INPUT_opengl=desktop
ninja -C build -j "$(lavori_pesanti)"
ninja -C build install
find /opt/qt6/ -name \*.prl -exec sed -i -e '/^QMAKE_PRL_BUILD_DIR/d' {} \;
# come nel libro: dove stanno le librerie e i programmi di Qt
# (i sistemi fatti con le versioni vecchie di lfs.sh non hanno ld.so.conf.d: lo aggiungo)
mkdir -p /etc/ld.so.conf.d /etc/profile.d
grep -q '^include /etc/ld.so.conf.d/\*\.conf' /etc/ld.so.conf 2>/dev/null \
  || printf '# Add an include directory\ninclude /etc/ld.so.conf.d/*.conf\n' >> /etc/ld.so.conf
cat > /etc/ld.so.conf.d/qt6.conf << "EOF"
/opt/qt6/lib
EOF
ldconfig
cat > /etc/profile.d/qt6.sh << "EOF"
# Qt6 (creato da lfs.sh, Fase 10)
QT6DIR=/opt/qt6
case ":$PATH:" in *:/opt/qt6/bin:*) ;; *) PATH=$PATH:/opt/qt6/bin ;; esac
export QT6DIR PATH
EOF
[ -x /opt/qt6/bin/qt-configure-module ] || { echo "Qt (base) non si e' installato"; return 1; }
/opt/qt6/bin/qtpaths6 --qt-query 2>/dev/null | grep -q '^QT_VERSION:6.11' \
  || { echo "Qt non risponde come dovrebbe"; return 1; }
echo "[OK] Qt 6 (base) installato in /opt/qt6"
}

f10_qt_modulo() {
# BLFS, pagina "Qt-6": gli altri moduli (shadertools, svg, declarative) si preparano
# con lo strumento di Qt appena installato
# Qt non segna nei programmi dove stanno le sue librerie (rpath spento): il sistema le
# trova solo se "ldconfig" le ha messe in elenco. Prima: le librerie dei moduli gia'
# fatti (declarative usa qsb, che vuole libQt6ShaderTools). Dopo: quelle di questo modulo.
ldconfig
mkdir build
cd    build
/opt/qt6/bin/qt-configure-module .. -- \
      -D QT_BUILD_EXAMPLES=OFF           \
      -D QT_BUILD_TESTS=OFF              \
      -D QT_GENERATE_SBOM=OFF            \
      -D QT_UNITY_BUILD=ON
ninja -j "$(lavori_pesanti)"
ninja install
ldconfig
}

f10_cli11() {
# NON IN BLFS: lettore delle opzioni a riga di comando (solo file .h, serve a Quickshell)
cmake -B build -G Ninja               \
      -D CMAKE_INSTALL_PREFIX=/usr     \
      -D CLI11_BUILD_TESTS=OFF         \
      -D CLI11_BUILD_EXAMPLES=OFF      \
      -D CLI11_BUILD_DOCS=OFF
ninja -C build
ninja -C build install
}

f10_quickshell() {
# NON IN BLFS: Quickshell, come la ricetta di Void. Spente le parti che vogliono
# pacchetti che qui non ci sono: PAM (il blocco schermo controlla la password con
# un aiutante, vedi sotto), polkit, greetd, il gestore dei crash (cpptrace),
# jemalloc, X11 e i3/Sway. I moduli QML vanno dove li cerca Qt (/opt/qt6/qml).
cmake -B build -G Ninja                       \
      -D CMAKE_INSTALL_PREFIX=/usr             \
      -D CMAKE_PREFIX_PATH=/opt/qt6            \
      -D CMAKE_BUILD_TYPE=Release              \
      -D INSTALL_QMLDIR=/opt/qt6/qml           \
      -D DISTRIBUTOR="lfs.sh (Linux From Scratch)" \
      -D CRASH_HANDLER=OFF                     \
      -D USE_JEMALLOC=OFF                      \
      -D SERVICE_PAM=OFF                       \
      -D SERVICE_POLKIT=OFF                    \
      -D SERVICE_GREETD=OFF                    \
      -D X11=OFF                               \
      -D I3=OFF
ninja -C build -j "$(lavori_pesanti)"
ninja -C build install
command -v quickshell >/dev/null || { echo "Quickshell non si e' installato"; return 1; }
echo "[OK] Quickshell installato"
}

f10_icone_pannelli() {
# NON IN BLFS: il carattere con le icone dei pannelli (Material Symbols Rounded,
# di Google, licenza Apache 2.0). Lo scarica lo script sul tuo PC; se non c'e' si va
# avanti lo stesso: i pannelli mostrano dei simboli semplici al posto delle icone.
if [ -s "/sources/$FONT_ICONE_FILE" ]; then
  install -vDm644 "/sources/$FONT_ICONE_FILE" /usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf
  fc-cache -f /usr/share/fonts/material-symbols
  echo "[OK] Icone dei pannelli installate"
else
  echo "[OK] Icone dei pannelli non scaricate: si usano simboli semplici"
fi
}

f10_aiutanti() {
# NON IN BLFS: i programmini del desktop Vetro.
# 1) l'aiutante che controlla la password del blocco schermo (come swaylock: senza
#    Linux-PAM legge /etc/shadow, quindi parte con i permessi di root e li lascia subito)
install -vdm755 /usr/local/libexec /usr/local/lib/vetro /etc/vetro
cat > /usr/local/lib/vetro/vetro-password.c << "EOF"
/* Controlla la password per il blocco schermo del desktop Vetro (creato da lfs.sh,
 * Fase 10). Senza Linux-PAM la password si legge da /etc/shadow, che solo root puo'
 * leggere: per questo il programma parte con i permessi di root (setuid), come
 * swaylock, e li abbandona subito dopo aver letto la riga dell'utente.
 * Legge UNA riga da stdin (la password) e controlla quella dell'utente che lo
 * lancia (mai di un altro). Esce con 0 se e' giusta, 1 se e' sbagliata (dopo
 * 2 secondi, per rallentare chi prova a indovinare), 2 per altri problemi. */
#define _GNU_SOURCE
#include <crypt.h>
#include <pwd.h>
#include <shadow.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char password[512];
    char hash[512];
    struct passwd *utente = getpwuid(getuid());
    struct spwd *ombra;
    struct crypt_data dati;
    char *risultato;
    int giusta = 0;

    if (!utente) return 2;
    ombra = getspnam(utente->pw_name);
    snprintf(hash, sizeof hash, "%s", ombra ? ombra->sp_pwdp : utente->pw_passwd);
    endspent();
    /* da qui in poi niente piu' permessi di root */
    if (setgid(getgid()) != 0 || setuid(getuid()) != 0) return 2;

    if (!fgets(password, sizeof password, stdin)) return 2;
    password[strcspn(password, "\n")] = '\0';

    if (hash[0] != '\0' && hash[0] != '!' && hash[0] != '*') {
        memset(&dati, 0, sizeof dati);
        risultato = crypt_r(password, hash, &dati);
        giusta = risultato != NULL && strcmp(risultato, hash) == 0;
    }
    explicit_bzero(password, sizeof password);
    explicit_bzero(hash, sizeof hash);
    explicit_bzero(&dati, sizeof dati);
    if (!giusta) {
        sleep(2);
        return 1;
    }
    return 0;
}
EOF
gcc -O2 -Wall -o /usr/local/libexec/vetro-password /usr/local/lib/vetro/vetro-password.c -lcrypt
chown root:root /usr/local/libexec/vetro-password
chmod 4755 /usr/local/libexec/vetro-password
# 2) avvio del desktop (Vetro o classico), i pannelli, la scelta del desktop
cat > /usr/local/bin/avvia-desktop << "EOF"
#!/bin/bash
# Avvia il desktop dopo l'accesso dal primo terminale (creato da lfs.sh, Fase 10).
#   Vetro    = Hyprland + Quickshell (animazioni, sfocatura), se c'e' l'accelerazione 3D
#   classico = labwc con la barra di Xfce (quello di prima)
# La scelta e' in ~/.config/desktop-scelto (si cambia con "scegli-desktop").
# Se il Vetro si chiude con un errore entro pochi secondi, parte da solo il classico.
# Esce con 0 se hai chiuso la sessione tu ("Esci"), con 1 se c'e' stato un errore.
export PATH="/usr/local/bin:$PATH"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$CONF" "$HOME/.cache"

scelta=$(cat "$CONF/desktop-scelto" 2>/dev/null)
[ -n "$scelta" ] || scelta=$(cat /etc/vetro/desktop-predefinito 2>/dev/null)
[ -n "$scelta" ] || scelta=vetro

classico() {
    export WLR_RENDERER=pixman
    dbus-run-session labwc > "$HOME/.labwc.log" 2>&1
}

tre_d=no
[ -f /run/vetro/grafica-3d ] && tre_d=$(cat /run/vetro/grafica-3d)
[ -e /etc/vetro/forza-3d ] && tre_d=si

if [ "$scelta" = vetro ] && command -v Hyprland >/dev/null && command -v quickshell >/dev/null; then
    if [ "$tre_d" != si ]; then
        echo "Il desktop Vetro ha bisogno dell'accelerazione 3D, che qui non c'e':"
        echo "parte il desktop classico. (Nella macchina virtuale: sudo lfs.sh avvia)"
        sleep 3
        classico
        exit $?
    fi
    mkdir -p "$CONF/hypr" "$CONF/vetro"
    [ -f "$CONF/hypr/personale.conf" ] || printf '# Le tue modifiche a Hyprland (le legge per ultime)\n' > "$CONF/hypr/personale.conf"
    [ -f "$CONF/hypr/vetro-impostazioni.conf" ] || cp /etc/xdg/hypr/vetro-impostazioni.conf "$CONF/hypr/vetro-impostazioni.conf"
    unset WLR_RENDERER WLR_NO_HARDWARE_CURSORS
    inizio=$SECONDS
    dbus-run-session Hyprland -c /etc/xdg/hypr/vetro.conf > "$HOME/.cache/hyprland.log" 2>&1
    esito=$?
    [ "$esito" -eq 0 ] && exit 0
    if [ $(( SECONDS - inizio )) -lt 30 ]; then
        echo "Il desktop Vetro non e' partito (registro: ~/.cache/hyprland.log)."
        echo "Parte il desktop classico."
        sleep 3
        classico
        exit $?
    fi
    exit 1
fi
classico
EOF
cat > /usr/local/bin/avvio-vetro << "EOF"
#!/bin/bash
# Programmi che partono insieme al desktop Vetro (creato da lfs.sh, Fase 10).
# Lo lancia Hyprland (exec-once in /etc/xdg/hypr/vetro.conf).
export PATH="/usr/local/bin:$PATH"
[ -x /usr/local/bin/avvia-audio ] && /usr/local/bin/avvia-audio >/dev/null 2>&1 &
[ -x /usr/local/bin/guardiano-avvisi ] && /usr/local/bin/guardiano-avvisi >/dev/null 2>&1 &
[ -x /usr/local/bin/benvenuto ] && /usr/local/bin/benvenuto >/dev/null 2>&1 &
exec /usr/local/bin/avvia-pannelli
EOF
cat > /usr/local/bin/avvia-pannelli << "EOF"
#!/bin/bash
# La grafica del desktop Vetro (creato da lfs.sh, Fase 10): Quickshell con i pannelli
# in /etc/xdg/quickshell/vetro. Se si chiude per un errore riparte; se non riesce a
# partire (o parte ma i pannelli non si caricano), al loro posto si aprono barra,
# notifiche e sfondo del desktop classico, cosi' il desktop resta usabile.
# Il motivo e' in ~/.cache/quickshell-vetro.log
export PATH="/usr/local/bin:$PATH"
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_QPA_PLATFORM=wayland
PANNELLI=/etc/xdg/quickshell/vetro
registro="$HOME/.cache/quickshell-vetro.log"
mkdir -p "$HOME/.cache"

riserva() {
    echo "--- $(date '+%F %T') i pannelli non partono: uso quelli di riserva" >> "$registro"
    notify-send -u critical "Desktop Vetro" "I pannelli non partono: uso quelli di riserva. Il motivo e' in ~/.cache/quickshell-vetro.log" 2>/dev/null &
    /usr/local/bin/sfondo-desktop --swaybg >/dev/null 2>&1 &
    mako --font "Adwaita Sans 11" --background-color "#202022e6" --text-color "#ffffff" \
         --border-size 0 --border-radius 14 --padding 14 --default-timeout 6000 >/dev/null 2>&1 &
    [ -x /usr/local/bin/blocca-schermo ] && swayidle -w timeout 600 /usr/local/bin/blocca-schermo >/dev/null 2>&1 &
    exec xfce4-panel >/dev/null 2>&1
}

# i pannelli sono caricati? (rispondono solo se tutti i file si sono caricati bene)
risponde() {
    [ "$(qs -p "$PANNELLI" ipc call vetro ping 2>/dev/null)" = ok ]
}

errori_rapidi=0
while :; do
    inizio=$SECONDS
    echo "--- $(date '+%F %T') avvio" >> "$registro"
    quickshell -p "$PANNELLI" >> "$registro" 2>&1 &
    pid=$!
    caricati=0
    for _ in $(seq 1 20); do
        sleep 1
        kill -0 "$pid" 2>/dev/null || break
        if risponde; then caricati=1; break; fi
    done
    if [ "$caricati" = 1 ]; then
        wait "$pid"
        esito=$?
    else
        echo "--- $(date '+%F %T') i pannelli non rispondono" >> "$registro"
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        esito=1
    fi
    # chiusa con "Esci" da Hyprland: Hyprland non c'e' piu', si esce anche qui
    pgrep -x Hyprland >/dev/null || exit 0
    if [ "$caricati" = 0 ]; then
        errori_rapidi=$(( errori_rapidi + 2 ))     # non si caricano: si riprova una volta sola
    elif [ $(( SECONDS - inizio )) -lt 15 ]; then
        errori_rapidi=$(( errori_rapidi + 1 ))
    else
        errori_rapidi=0
    fi
    echo "--- $(date '+%F %T') chiusa (codice $esito)" >> "$registro"
    [ "$errori_rapidi" -ge 3 ] && riserva
    sleep 1
done
EOF
cat > /usr/local/bin/scegli-desktop << "EOF"
#!/bin/bash
# Sceglie il desktop per il prossimo accesso (creato da lfs.sh, Fase 10):
#   scegli-desktop vetro      Hyprland + Quickshell (animazioni, effetto vetro)
#   scegli-desktop classico   labwc con la barra di Xfce
#   scegli-desktop            chiede con una finestra
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$CONF"
scelta=${1:-}
if [ -z "$scelta" ]; then
    attuale=$(cat "$CONF/desktop-scelto" 2>/dev/null || echo vetro)
    if [ "$attuale" = classico ]; then voci="Vetro!^Classico"; else voci="^Vetro!Classico"; fi
    risposta=$(yad --title "Cambia desktop" --window-icon preferences-desktop --center --fixed --width 460 \
        --form --separator '|' \
        --text "<span size='large' weight='bold'>Quale desktop vuoi?</span>
<b>Vetro</b>: animazioni, effetto vetro, cruscotto (serve l'accelerazione 3D).
<b>Classico</b>: quello di prima, più leggero.
Vale dal prossimo accesso." \
        --field "Desktop:CB" "$voci" --button "Annulla:1" --button "Scegli:0") || exit 0
    case "$(cut -d'|' -f1 <<<"$risposta")" in
        Classico) scelta=classico ;;
        *) scelta=vetro ;;
    esac
fi
case "$scelta" in
    vetro|classico) ;;
    *) echo "Uso: scegli-desktop [vetro|classico]"; exit 1 ;;
esac
echo "$scelta" > "$CONF/desktop-scelto"
msg="Dal prossimo accesso: desktop $scelta. Per cambiarlo subito esci e rientra."
notify-send -i preferences-desktop "Desktop" "$msg" 2>/dev/null || echo "$msg"
EOF
cat > /usr/local/bin/browser-predefinito << "EOF"
#!/bin/sh
# Apre il browser (creato da lfs.sh, Fase 10): Tor Browser se c'e', altrimenti Firefox
if [ -x /usr/local/bin/tor-browser ]; then exec /usr/local/bin/tor-browser "$@"; fi
exec firefox "$@"
EOF
# 3) sfondo e blocco schermo: nel desktop Vetro li fanno i pannelli
cat > /usr/local/bin/sfondo-desktop << "EOF"
#!/bin/sh
# Sfondo del desktop (creato da lfs.sh). Si sceglie da Impostazioni -> Aspetto (la
# scelta e' in ~/.config/sfondo.conf). In modalita' fantasma diventa quello scuro,
# cosi' si vede subito se e' accesa.
#   sfondo-desktop              mette lo sfondo (nel desktop Vetro lo disegnano i pannelli)
#   sfondo-desktop --percorso   scrive solo quale immagine usare
#   sfondo-desktop --swaybg     lo mette comunque con swaybg
img=$(sed -n 's/^SFONDO=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/sfondo.conf" 2>/dev/null | head -n1)
[ -n "$img" ] && [ -f "$img" ] || img=/usr/share/backgrounds/sfondo-desktop.png
if [ -e /etc/fantasma/attivo ] && [ -f /usr/share/backgrounds/sfondo-fantasma.png ]; then
  img=/usr/share/backgrounds/sfondo-fantasma.png
fi
if [ "${1:-}" = --percorso ]; then
  echo "$img"
  exit 0
fi
# desktop Vetro: lo sfondo lo disegna Quickshell (con la dissolvenza)
if [ "${1:-}" != --swaybg ] && pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1 \
   && qs -p /etc/xdg/quickshell/vetro ipc call sfondo aggiorna >/dev/null 2>&1; then
  pkill -u "$(id -u)" -x swaybg
  exit 0
fi
pkill -u "$(id -u)" -x swaybg
exec swaybg -i "$img" -m fill
EOF
cat > /usr/local/bin/blocca-schermo << "EOF"
#!/bin/bash
# Blocca lo schermo (creato da lfs.sh): per sbloccare scrivi la tua password e premi Invio.
# Nel desktop Vetro usa il blocco dei pannelli (orologio grande); se non risponde,
# o nel desktop classico, usa swaylock con lo stesso sfondo del desktop.
if pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1 \
   && qs -p /etc/xdg/quickshell/vetro ipc call blocco blocca >/dev/null 2>&1; then
  exit 0
fi
pgrep -u "$(id -u)" -x swaylock >/dev/null && exit 0
img=$(/usr/local/bin/sfondo-desktop --percorso 2>/dev/null)
[ -n "$img" ] && [ -f "$img" ] || img=/usr/share/backgrounds/sfondo-desktop.png
exec swaylock -f -i "$img" -s fill \
     --font "Adwaita Sans" --indicator-radius 80 --indicator-thickness 6 \
     --inside-color ffffff33 --inside-clear-color ffffff33 --inside-ver-color 0a84ff55 \
     --inside-wrong-color ff5f5755 --ring-color ffffffcc --ring-clear-color febc2eff \
     --ring-ver-color 0a84ffff --ring-wrong-color ff5f57ff --key-hl-color 0a84ffff \
     --bs-hl-color ff5f57ff --line-color 00000000 --line-clear-color 00000000 \
     --line-ver-color 00000000 --line-wrong-color 00000000 --separator-color 00000000 \
     --text-color ffffffff --text-clear-color ffffffff --text-ver-color ffffffff \
     --text-wrong-color ffffffff
EOF
local f
for f in avvia-desktop avvio-vetro avvia-pannelli scegli-desktop browser-predefinito \
         sfondo-desktop blocca-schermo; do
  chmod 755 "/usr/local/bin/$f"
  bash -n "/usr/local/bin/$f"
done
# 4) all'accensione: c'e' l'accelerazione 3D?
install -vdm755 /usr/local/sbin
cat > /usr/local/sbin/controlla-3d << "EOF"
#!/bin/sh
# All'accensione: c'e' l'accelerazione 3D? (creato da lfs.sh, Fase 10)
# Il desktop Vetro (Hyprland) disegna tutto con la scheda grafica: senza 3D sarebbe
# lentissimo, e si usa il desktop classico. Nella macchina virtuale QEMU il 3D c'e'
# quando si accende con "virtio-vga-gl" (lo fa "sudo lfs.sh avvia"): il kernel lo
# scrive come "+virgl". Per forzarlo comunque: sudo touch /etc/vetro/forza-3d
mkdir -p /run/vetro
esito=no
if dmesg 2>/dev/null | grep -q 'features: +virgl'; then
  esito=si
fi
echo "$esito" > /run/vetro/grafica-3d
chmod 644 /run/vetro/grafica-3d
EOF
chmod 755 /usr/local/sbin/controlla-3d
cat > /etc/systemd/system/controlla-3d.service << "EOF"
[Unit]
Description=Controlla se c'e' l'accelerazione 3D (desktop Vetro)
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/controlla-3d

[Install]
WantedBy=multi-user.target
EOF
systemctl enable controlla-3d.service
# 5) "Cambia desktop" tra le app e nelle Impostazioni classiche
cat > /usr/share/applications/scegli-desktop.desktop << "EOF"
[Desktop Entry]
Type=Application
Name=Cambia desktop
Comment=Vetro (animazioni, effetto vetro) o classico (piu' leggero)
Exec=/usr/local/bin/scegli-desktop
Icon=preferences-desktop
Terminal=false
Categories=Settings;
EOF
if [ -f /usr/local/bin/impostazioni ]; then
  grep -q 'scegli-desktop' /usr/local/bin/impostazioni \
    || sed -i 's/^VOCI="impostazioni-schermo impostazioni-aspetto /VOCI="impostazioni-schermo impostazioni-aspetto scegli-desktop /' \
           /usr/local/bin/impostazioni
  # nel desktop Vetro, "Impostazioni" apre quelle nuove (con --classiche le vecchie)
  if ! grep -q 'desktop Vetro' /usr/local/bin/impostazioni; then
    cat > /tmp/vetro-impostazioni-inizio << "FINE"
# desktop Vetro: si aprono le Impostazioni nuove (con --classiche queste)
if [ "${1:-}" != --classiche ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] \
   && qs -p /etc/xdg/quickshell/vetro ipc call pannelli apri impostazioni >/dev/null 2>&1; then
  exit 0
fi
FINE
    sed -i '1r /tmp/vetro-impostazioni-inizio' /usr/local/bin/impostazioni
    rm -f /tmp/vetro-impostazioni-inizio
  fi
  bash -n /usr/local/bin/impostazioni
fi
if [ -f /etc/xdg/labwc/menu.xml ] && ! grep -q 'scegli-desktop' /etc/xdg/labwc/menu.xml; then
  sed -i 's|^  <item label="Spegni, riavvia o esci...">|  <item label="Cambia desktop (Vetro)...">\n    <action name="Execute" command="/usr/local/bin/scegli-desktop" />\n  </item>\n  <item label="Spegni, riavvia o esci...">|' \
      /etc/xdg/labwc/menu.xml
fi
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "[OK] Aiutanti del desktop Vetro pronti"
}

f10_config_hyprland() {
# NON IN BLFS: la configurazione di Hyprland per tutti (animazioni, sfocatura,
# angoli, ombre, tasti) e quella di partenza delle Impostazioni
install -vdm755 /etc/xdg/hypr
cat > /etc/xdg/hypr/vetro.conf << "EOF"
# Hyprland, desktop "Vetro" (creato da lfs.sh, Fase 10).
# Questo file e' per tutti: le TUE modifiche mettile in ~/.config/hypr/personale.conf
# (viene letto per ultimo e vince). Le scelte fatte da Impostazioni finiscono in
# ~/.config/hypr/vetro-impostazioni.conf. Tutti e due li crea vuoti avvia-desktop.

monitor = , preferred, auto, 1

# --- ambiente --------------------------------------------------------------------
env = XCURSOR_SIZE, 24
env = XCURSOR_THEME, AdwaitaLegacy
env = HYPRCURSOR_SIZE, 24
# i programmi GTK3 (Thunar, Mousepad...) si disegnano da soli la barra del titolo
# con i tre pulsanti colorati del tema Elegante
env = GTK_CSD, 1
env = QT_QPA_PLATFORM, wayland
env = MOZ_ENABLE_WAYLAND, 1
env = XDG_CURRENT_DESKTOP, Hyprland
env = XDG_SESSION_TYPE, wayland

# --- aspetto -----------------------------------------------------------------------
general {
    gaps_in = 6
    gaps_out = 12
    border_size = 1
    col.active_border = rgba(ffffff40)
    col.inactive_border = rgba(ffffff14)
    resize_on_border = true
    extend_border_grab_area = 12
    layout = dwindle
}

decoration {
    rounding = 14
    rounding_power = 2.4
    active_opacity = 1.0
    inactive_opacity = 1.0
    dim_inactive = false

    shadow {
        enabled = true
        range = 28
        render_power = 3
        color = rgba(00000066)
        color_inactive = rgba(00000033)
    }

    blur {
        enabled = true
        size = 9
        passes = 3
        noise = 0.02
        contrast = 1.0
        brightness = 0.9
        vibrancy = 0.17
        popups = true
    }
}

animations {
    enabled = true
    bezier = morbida, 0.22, 1, 0.36, 1
    bezier = rapida, 0.15, 0, 0.1, 1
    bezier = elastica, 0.34, 1.36, 0.64, 1
    bezier = lineare, 0, 0, 1, 1
    animation = global, 1, 8, default
    animation = windowsIn, 1, 4.5, elastica, popin 88%
    animation = windowsOut, 1, 3, rapida, popin 90%
    animation = windowsMove, 1, 4.5, morbida, slide
    animation = border, 1, 6, morbida
    animation = fade, 1, 3.5, rapida
    animation = layersIn, 1, 4, morbida, slide
    animation = layersOut, 1, 2.5, rapida, fade
    animation = fadeLayersIn, 1, 3, rapida
    animation = fadeLayersOut, 1, 2.5, rapida
    animation = workspaces, 1, 5, morbida, slidefade 18%
    animation = specialWorkspace, 1, 4, morbida, slidevert
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    disable_splash_rendering = true
    focus_on_activate = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    # se i pannelli ripartono mentre lo schermo e' bloccato, possono riprenderlo
    allow_session_lock_restore = true
}

xwayland {
    force_zero_scaling = true
}

cursor {
    # nelle macchine virtuali il puntatore "hardware" a volte non si vede
    no_hardware_cursors = 1
}

# --- tastiera e mouse --------------------------------------------------------------
input {
    kb_layout = it
    follow_mouse = 1
    sensitivity = 0
    touchpad {
        natural_scroll = true
        tap-to-click = true
    }
}

gesture = 3, horizontal, workspace

# --- finestre ----------------------------------------------------------------------
# come su macOS e Windows le finestre si aprono "libere" (non affiancate): la regola
# e' in ~/.config/hypr/vetro-impostazioni.conf, perche' da Impostazioni -> Finestre si
# puo' scegliere di affiancarle in automatico.

windowrule {
    name = vetro-impostazioni
    match:title = ^(Impostazioni di sistema)$
    float = yes
    center = yes
}

# sfocatura dietro i pannelli di Quickshell (solo dove non sono trasparenti)
layerrule = blur on, ignore_alpha 0.2, match:namespace ^(vetro-.*)$
layerrule = no_anim on, match:namespace ^(vetro-sfondo)$

# --- tasti ------------------------------------------------------------------------
$tasto = SUPER

# tasto Windows da solo: cerca le app (come lo Start o Spotlight)
bindr = $tasto, SUPER_L, global, quickshell:avvio
bind = $tasto, SPACE, global, quickshell:avvio
bind = $tasto, A, global, quickshell:pannello
bind = $tasto, D, global, quickshell:cruscotto
bind = $tasto, I, global, quickshell:impostazioni
bind = $tasto, L, global, quickshell:blocca
bind = $tasto, N, global, quickshell:notifiche

bind = $tasto, RETURN, exec, foot
bind = CTRL ALT, T, exec, foot
bind = $tasto, E, exec, thunar
bind = $tasto, B, exec, /usr/local/bin/browser-predefinito
bind = CTRL SHIFT, ESCAPE, exec, xfce4-taskmanager
bind = , PRINT, exec, /usr/local/bin/schermata
bind = SHIFT, PRINT, exec, /usr/local/bin/schermata area

# finestre
bind = ALT, F4, killactive,
bind = $tasto, Q, killactive,
bind = $tasto, UP, fullscreen, 1
bind = $tasto, F, fullscreen, 0
bind = $tasto, V, togglefloating,
bind = $tasto, DOWN, global, quickshell:riduci
bind = ALT, TAB, cyclenext,
bind = ALT, TAB, alterzorder, top
bind = ALT SHIFT, TAB, cyclenext, prev
bind = ALT SHIFT, TAB, alterzorder, top
bindm = $tasto, mouse:272, movewindow
bindm = $tasto, mouse:273, resizewindow

# scrivanie (workspace)
bind = $tasto, 1, workspace, 1
bind = $tasto, 2, workspace, 2
bind = $tasto, 3, workspace, 3
bind = $tasto, 4, workspace, 4
bind = $tasto, 5, workspace, 5
bind = $tasto SHIFT, 1, movetoworkspace, 1
bind = $tasto SHIFT, 2, movetoworkspace, 2
bind = $tasto SHIFT, 3, movetoworkspace, 3
bind = $tasto SHIFT, 4, movetoworkspace, 4
bind = $tasto SHIFT, 5, movetoworkspace, 5
bind = $tasto CTRL, RIGHT, workspace, e+1
bind = $tasto CTRL, LEFT, workspace, e-1
bind = $tasto, mouse_down, workspace, e+1
bind = $tasto, mouse_up, workspace, e-1

# volume e luminosita'
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl = , XF86AudioPlay, global, quickshell:musica-play
bindl = , XF86AudioNext, global, quickshell:musica-avanti
bindl = , XF86AudioPrev, global, quickshell:musica-indietro

# --- avvio ------------------------------------------------------------------------
exec-once = /usr/local/bin/avvio-vetro

# le scelte fatte da Impostazioni, poi le tue modifiche
source = ~/.config/hypr/vetro-impostazioni.conf
source = ~/.config/hypr/personale.conf
EOF
cat > /etc/xdg/hypr/vetro-impostazioni.conf << "EOF"
# Creato da Impostazioni (desktop Vetro): non modificarlo a mano,
# le tue aggiunte vanno in ~/.config/hypr/personale.conf
animations {
    enabled = true
}
decoration {
    rounding = 14
    blur {
        enabled = true
    }
}
general {
    gaps_in = 6
    gaps_out = 12
}
windowrule {
    name = vetro-finestre-libere
    match:class = .*
    float = yes
}
EOF
echo "[OK] Configurazione di Hyprland pronta"
}

f10_shell() {
# NON IN BLFS: i pannelli (Quickshell), scritti qui: in /etc/xdg/quickshell/vetro
local d=/etc/xdg/quickshell/vetro
rm -rf "$d"
install -vdm755 "$d"
cat > "$d/Anello.qml" << "EOF"
// Anello di avanzamento (processore, memoria, disco...) (creato da lfs.sh, Fase 10)
import QtQuick
import QtQuick.Shapes

Item {
    id: anello
    property real valore: 0            // 0..1
    property real spessore: 8
    property color colore: Tema.accento
    property color fondo: Tema.cartaForte
    property real mostrato: Math.max(0, Math.min(1, valore))

    implicitWidth: 96
    implicitHeight: 96

    Behavior on mostrato { NumberAnimation { duration: Tema.lenta; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: anello.fondo
            strokeWidth: anello.spessore
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: anello.width / 2
                centerY: anello.height / 2
                radiusX: (Math.min(anello.width, anello.height) - anello.spessore) / 2
                radiusY: radiusX
                startAngle: 135
                sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: anello.colore
            strokeWidth: anello.spessore
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: anello.width / 2
                centerY: anello.height / 2
                radiusX: (Math.min(anello.width, anello.height) - anello.spessore) / 2
                radiusY: radiusX
                startAngle: 135
                sweepAngle: Math.max(0.5, 270 * anello.mostrato)
            }
        }
    }
}
EOF
cat > "$d/Applicazioni.qml" << "EOF"
pragma Singleton
// Le app installate e la ricerca (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell

Singleton {
    id: applicazioni

    readonly property var tutte: DesktopEntries.applications.values

    // l'immagine dell'icona: un nome del tema, oppure un file (es. Firefox, Tor Browser)
    function icona(nome) {
        if (!nome || nome === "") return Quickshell.iconPath("application-x-executable");
        if (nome.startsWith("/")) return "file://" + nome;
        return Quickshell.iconPath(nome, "application-x-executable");
    }

    function ordinate() {
        return tutte.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    function preferite(quante) {
        const r = [];
        const lista = Opzioni.preferite;
        for (let i = 0; i < lista.length && r.length < quante; i++) {
            const e = DesktopEntries.byId(lista[i]);
            if (e && r.indexOf(e) < 0) r.push(e);
        }
        // tor-browser e firefox: basta il primo che c'e'
        const browser = r.filter(e => e.id === "tor-browser" || e.id === "firefox");
        if (browser.length > 1) r.splice(r.indexOf(browser[1]), 1);
        const altre = ordinate();
        for (let i = 0; i < altre.length && r.length < quante; i++)
            if (r.indexOf(altre[i]) < 0) r.push(altre[i]);
        return r;
    }

    function cerca(testo, quante) {
        const t = (testo || "").trim().toLowerCase();
        if (t === "") return preferite(quante);
        const prima = [], dopo = [];
        for (let i = 0; i < tutte.length; i++) {
            const e = tutte[i];
            const nome = (e.name || "").toLowerCase();
            const altro = ((e.genericName || "") + " " + (e.comment || "") + " "
                           + (e.keywords || []).join(" ") + " " + (e.id || "")).toLowerCase();
            if (nome.startsWith(t) || nome.indexOf(" " + t) >= 0) prima.push(e);
            else if (nome.indexOf(t) >= 0 || altro.indexOf(t) >= 0) dopo.push(e);
        }
        prima.sort((a, b) => a.name.localeCompare(b.name));
        dopo.sort((a, b) => a.name.localeCompare(b.name));
        return prima.concat(dopo).slice(0, quante);
    }
}
EOF
cat > "$d/Audio.qml" << "EOF"
pragma Singleton
// Il volume (PipeWire) (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: audio

    readonly property var uscita: Pipewire.defaultAudioSink
    readonly property bool pronto: !!(uscita && uscita.audio)
    readonly property real volume: pronto ? uscita.audio.volume : 0
    readonly property bool muto: pronto ? uscita.audio.muted : false
    readonly property string icona: muto || volume <= 0.001 ? "volume_off"
                                   : volume < 0.34 ? "volume_mute"
                                   : volume < 0.67 ? "volume_down" : "volume_up"

    signal cambiato()

    function imposta(v) {
        if (!pronto) return;
        uscita.audio.muted = false;
        uscita.audio.volume = Math.max(0, Math.min(1, v));
    }
    function alternaMuto() { if (pronto) uscita.audio.muted = !uscita.audio.muted; }

    onVolumeChanged: cambiato()
    onMutoChanged: cambiato()

    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
}
EOF
cat > "$d/Avatar.qml" << "EOF"
// La tua immagine (~/.face) o l'iniziale del tuo nome in un cerchio (creato da lfs.sh)
import QtQuick
import Quickshell
import Quickshell.Widgets

ClippingRectangle {
    id: avatar
    implicitWidth: 46
    implicitHeight: 46
    radius: width / 2
    color: Tema.accento

    Text {
        anchors.centerIn: parent
        visible: foto.status !== Image.Ready
        text: (Opzioni.nomeUtente() || "?").charAt(0).toUpperCase()
        font.family: Tema.carattere
        font.pixelSize: avatar.height * 0.45
        font.weight: Font.Bold
        color: Tema.suAccento
    }
    Image {
        id: foto
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        source: "file://" + (Quickshell.env("HOME") || "") + "/.face"
        sourceSize.width: avatar.width * 2
        sourceSize.height: avatar.height * 2
    }
}
EOF
cat > "$d/Avvio.qml" << "EOF"
// Cerca e apri le app (creato da lfs.sh, Fase 10): tasto Windows, Windows+Spazio o
// l'icona in alto a sinistra. Scrivi, scegli con le frecce e premi Invio. Senza
// scrivere niente mostra tutte le app (come il Launchpad).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: avvio

    visible: Stato.avvio || sfumatura.opacity > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vetro-avvio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Stato.avvio ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int scelta: 0
    readonly property var risultati: campo.text.trim() === "" ? Applicazioni.ordinate() : Applicazioni.cerca(campo.text, 40)

    function apri(e) {
        if (!e) return;
        e.execute();
        Stato.avvio = false;
    }

    Connections {
        target: Stato
        function onAvvioChanged() {
            if (Stato.avvio) { campo.text = ""; avvio.scelta = 0; campo.forceActiveFocus(); }
        }
    }

    // velo scuro su tutto lo schermo (dietro si sfoca): cliccandolo si chiude
    Rectangle {
        id: sfumatura
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.32)
        opacity: Stato.avvio ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: Stato.avvio = false }
    }

    Rectangle {
        id: riquadro
        width: Math.min(760, avvio.width - 80)
        height: Math.min(620, avvio.height - 160)
        anchors.horizontalCenter: parent.horizontalCenter
        y: (avvio.height - height) / 2 - 30
        radius: Tema.raggio + 4
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordoForte
        opacity: sfumatura.opacity
        scale: Stato.avvio ? 1 : 0.94
        Behavior on scale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        MouseArea { anchors.fill: parent }       // i clic qui dentro non chiudono

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: 27
                color: Tema.cartaForte
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12
                    Icona { nome: "search"; dimensione: 24; color: Tema.testo2 }
                    TextInput {
                        id: campo
                        Layout.fillWidth: true
                        font.family: Tema.carattere
                        font.pixelSize: 20
                        color: Tema.testo
                        selectionColor: Tema.accento
                        selectedTextColor: Tema.suAccento
                        clip: true
                        focus: true
                        onTextChanged: avvio.scelta = 0
                        Text {
                            anchors.fill: parent
                            visible: campo.text === ""
                            text: "Cerca un'app..."
                            font: campo.font
                            color: Tema.testo3
                        }
                        Keys.onEscapePressed: Stato.avvio = false
                        Keys.onReturnPressed: avvio.apri(avvio.risultati[avvio.scelta])
                        Keys.onEnterPressed: avvio.apri(avvio.risultati[avvio.scelta])
                        Keys.onDownPressed: avvio.scelta = Math.min(avvio.risultati.length - 1, avvio.scelta + (vista.colonne > 1 ? vista.colonne : 1))
                        Keys.onUpPressed: avvio.scelta = Math.max(0, avvio.scelta - (vista.colonne > 1 ? vista.colonne : 1))
                        Keys.onTabPressed: avvio.scelta = Math.min(avvio.risultati.length - 1, avvio.scelta + 1)
                        Keys.onRightPressed: e => {
                            if (vista.colonne > 1 && campo.cursorPosition === campo.text.length)
                                avvio.scelta = Math.min(avvio.risultati.length - 1, avvio.scelta + 1);
                            else e.accepted = false;
                        }
                        Keys.onLeftPressed: e => {
                            if (vista.colonne > 1 && campo.cursorPosition === campo.text.length)
                                avvio.scelta = Math.max(0, avvio.scelta - 1);
                            else e.accepted = false;
                        }
                    }
                }
            }

            GridView {
                id: vista
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                readonly property int colonne: 6
                cellWidth: width / colonne
                cellHeight: 118
                currentIndex: avvio.scelta
                model: ScriptModel { values: avvio.risultati }
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Tema.veloce
                highlight: Rectangle {
                    radius: Tema.raggioMedio
                    color: Tema.cartaForte
                    border.width: 1
                    border.color: Tema.bordoForte
                }
                delegate: Item {
                    id: casella
                    required property var modelData
                    required property int index
                    width: vista.cellWidth
                    height: vista.cellHeight
                    scale: areaCasella.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.veloce } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 56
                            asynchronous: true
                            mipmap: true
                            source: Applicazioni.icona(casella.modelData.icon)
                        }
                        Text {
                            width: vista.cellWidth - 16
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            text: casella.modelData.name
                            font.family: Tema.carattere
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Tema.testo
                        }
                    }
                    MouseArea {
                        id: areaCasella
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: avvio.scelta = casella.index
                        onClicked: avvio.apri(casella.modelData)
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: avvio.risultati.length === 0 ? "Nessuna app trovata"
                      : "Invio per aprire  ·  frecce per scegliere  ·  Esc per chiudere"
                font.family: Tema.carattere
                font.pixelSize: 11
                color: Tema.testo3
            }
        }
    }
}
EOF
cat > "$d/Avvisi.qml" << "EOF"
pragma Singleton
// Le notifiche (creato da lfs.sh, Fase 10): prende il posto di mako. Quelle nuove
// compaiono in alto a destra per qualche secondo, poi restano nel centro di controllo.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: avvisi

    readonly property var tutte: server.trackedNotifications.values
    readonly property int quante: tutte.length
    property var visibili: []

    function mostra(n) {
        const l = visibili.filter(x => x !== n);
        l.unshift(n);
        visibili = l.slice(0, 4);
    }
    function nascondi(n) {
        visibili = visibili.filter(x => x !== n);
    }
    function cancellaTutte() {
        const l = tutte.slice();
        visibili = [];
        for (let i = 0; i < l.length; i++) l[i].dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => avvisi.nascondi(n));
            if (!Opzioni.nonDisturbare || n.urgency === NotificationUrgency.Critical)
                avvisi.mostra(n);
        }
    }
}
EOF
cat > "$d/Barra.qml" << "EOF"
// La barra in alto (creato da lfs.sh, Fase 10): a sinistra le app e le scrivanie,
// al centro data e ora (aprono il cruscotto), a destra volume, notifiche e il
// centro di controllo.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: barra
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: 46
    color: "transparent"
    WlrLayershell.namespace: "vetro-barra"
    WlrLayershell.layer: WlrLayer.Top

    SystemClock {
        id: orologio
        precision: Opzioni.secondi ? SystemClock.Seconds : SystemClock.Minutes
    }

    // "Resta sveglio" (centro di controllo): lo schermo non si spegne
    IdleInhibitor {
        window: barra
        enabled: Stato.restaSveglio
    }

    // ---------------------------------------------------------------- a sinistra
    Rectangle {
        id: sinistra
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 6
        height: 36
        width: filaSinistra.width + 12
        radius: height / 2
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        Behavior on width { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        Row {
            id: filaSinistra
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 6
            spacing: 8

            // le app (come lo Start o il Launchpad)
            Rectangle {
                width: 28; height: 28; radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: areaApp.containsMouse || Stato.avvio ? Tema.cartaSopra : "transparent"
                Behavior on color { ColorAnimation { duration: Tema.veloce } }
                Icona { anchors.centerIn: parent; nome: "apps"; dimensione: 19 }
                MouseArea {
                    id: areaApp
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stato.alterna("avvio")
                }
            }

            // le scrivanie: un pallino per ognuna, quella attiva e' piu' lunga
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: ScriptModel {
                        values: {
                            const l = Hyprland.workspaces.values.filter(w => w.id > 0);
                            return l.length > 0 ? l : [];
                        }
                    }
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool attiva: modelData.focused || modelData.active
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8
                        width: attiva ? 26 : 8
                        radius: 4
                        color: attiva ? Tema.accento : (modelData.toplevels.values.length > 0 ? Tema.testo2 : Tema.testo3)
                        Behavior on width { NumberAnimation { duration: Tema.media; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                        Behavior on color { ColorAnimation { duration: Tema.media } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.activate()
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                width: Math.min(implicitWidth, 320)
                elide: Text.ElideRight
                text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
                font.family: Tema.carattere
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Tema.testo2
                rightPadding: 6
            }
        }
    }

    // ---------------------------------------------------------------- al centro
    Rectangle {
        id: centro
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 6
        height: 36
        width: testoOra.implicitWidth + 34
        radius: height / 2
        color: areaOra.containsMouse || Stato.cruscotto ? Tema.fondoPieno : Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        Behavior on color { ColorAnimation { duration: Tema.veloce } }

        Text {
            id: testoOra
            anchors.centerIn: parent
            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "ddd d MMM") + "    "
                  + orologio.date.toLocaleString(Qt.locale("it_IT"), Opzioni.secondi ? "HH:mm:ss" : "HH:mm")
            font.family: Tema.carattere
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Tema.testo
        }
        MouseArea {
            id: areaOra
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Stato.alterna("cruscotto")
        }
    }

    // ---------------------------------------------------------------- a destra
    Rectangle {
        id: destra
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 6
        height: 36
        width: filaDestra.width + 16
        radius: height / 2
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        Behavior on width { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        Row {
            id: filaDestra
            anchors.centerIn: parent
            spacing: 4

            // modalita' fantasma accesa
            Rectangle {
                visible: Sistema.fantasma
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: testoFantasma.implicitWidth + 30
                radius: 12
                color: Qt.rgba(0.62, 0.42, 1, 0.28)
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Icona { nome: "visibility_off"; dimensione: 15; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        id: testoFantasma
                        text: "Fantasma"
                        font.family: Tema.carattere
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Tema.testo
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["/usr/local/bin/fantasma"])
                }
            }

            // musica: titolo e play/pausa
            Rectangle {
                visible: Musica.attivo !== null && Musica.titolo !== ""
                anchors.verticalCenter: parent.verticalCenter
                height: 28
                width: Math.min(220, filaMusica.implicitWidth + 16)
                radius: 14
                color: areaMusica.containsMouse ? Tema.cartaForte : "transparent"
                clip: true
                Row {
                    id: filaMusica
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    spacing: 6
                    Icona {
                        nome: Musica.suona ? "pause" : "play_arrow"
                        dimensione: 17
                        piena: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Musica.titolo + (Musica.artista !== "" ? "  ·  " + Musica.artista : "")
                        font.family: Tema.carattere
                        font.pixelSize: 12
                        color: Tema.testo2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: areaMusica
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Musica.alterna()
                }
            }

            BottoneBarra {
                icona: Audio.icona
                onCliccato: Audio.alternaMuto()
                onRotella: su => Audio.imposta(Audio.volume + (su ? 0.05 : -0.05))
            }
            BottoneBarra {
                icona: Opzioni.nonDisturbare ? "notifications_off"
                       : (Avvisi.quante > 0 ? "notifications_unread" : "notifications")
                onCliccato: Stato.alterna("pannello")
            }
            BottoneBarra {
                icona: "tune"
                attivo: Stato.pannello
                onCliccato: Stato.alterna("pannello")
            }
        }
    }

    component BottoneBarra: Rectangle {
        id: bottone
        property string icona: "circle"
        property bool attivo: false
        signal cliccato()
        signal rotella(bool su)
        width: 30
        height: 28
        radius: 14
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: attivo ? Tema.accento : (areaB.containsMouse ? Tema.cartaForte : "transparent")
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
        Icona {
            anchors.centerIn: parent
            nome: bottone.icona
            dimensione: 18
            color: bottone.attivo ? Tema.suAccento : Tema.testo
        }
        MouseArea {
            id: areaB
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bottone.cliccato()
            onWheel: e => bottone.rotella(e.angleDelta.y > 0)
        }
    }
}
EOF
cat > "$d/Blocco.qml" << "EOF"
// Il blocco schermo (creato da lfs.sh, Fase 10): orologio grande, saluto e la
// password. Si blocca con Windows+L, dal centro di controllo o da solo dopo i minuti
// scelti in Impostazioni (0 = mai). La password la controlla un piccolo aiutante
// (/usr/local/libexec/vetro-password), perche' qui non c'e' Linux-PAM.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: blocco

    property bool controllo: false        // sta controllando la password
    property string errore: ""
    property int tentativi: 0
    signal sbagliata()

    function verifica(password) {
        if (controllo || password === "") return;
        controllo = true;
        errore = "";
        aiutante.daScrivere = password + "\n";
        aiutante.running = true;
    }

    Process {
        id: aiutante
        property string daScrivere: ""
        command: ["/usr/local/libexec/vetro-password"]
        stdinEnabled: true
        onStarted: { write(daScrivere); daScrivere = ""; }
        onExited: (codice, stato) => {
            blocco.controllo = false;
            if (codice === 0) {
                blocco.tentativi = 0;
                Stato.bloccato = false;
            } else {
                blocco.tentativi++;
                blocco.errore = codice === 1 ? "Password sbagliata" : "Non riesco a controllare la password";
                blocco.sbagliata();
            }
        }
    }

    // dopo i minuti scelti senza toccare niente: blocca (e poi spegne lo schermo)
    Process {
        id: inattivita
        property int secondi: Math.max(0, Opzioni.bloccoMinuti) * 60
        running: secondi > 0
        command: ["swayidle", "-w",
                  "timeout", String(secondi), "qs -p /etc/xdg/quickshell/vetro ipc call blocco blocca",
                  "timeout", String(secondi + 60), "hyprctl dispatch dpms off",
                  "resume", "hyprctl dispatch dpms on"]
        onSecondiChanged: { running = false; riavviaInattivita.restart(); }
    }
    Timer {
        id: riavviaInattivita
        interval: 500
        onTriggered: inattivita.running = inattivita.secondi > 0
    }

    WlSessionLock {
        id: serratura
        locked: Stato.bloccato

        WlSessionLockSurface {
            id: superficie
            color: "#0c0c0e"

            SystemClock { id: orologio; precision: SystemClock.Seconds }

            // sfondo sfocato e scurito
            Image {
                id: immagine
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: "file://" + Sfondi.attuale
                sourceSize.width: 1280
                sourceSize.height: 720
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: immagine
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                brightness: -0.12
                saturation: -0.25
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.12) }
                }
            }

            // entrata morbida
            Item {
                id: contenuto
                anchors.fill: parent
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: Tema.lenta * 2; easing.type: Easing.OutCubic } }

                Column {
                    id: colonna
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -30
                    x: Math.max(60, parent.width * 0.14)
                    spacing: 14

                    Avatar {
                        width: 64
                        height: 64
                    }

                    Column {
                        spacing: -34
                        Text {
                            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "HH")
                            font.family: Tema.carattere
                            font.pixelSize: 168
                            font.weight: Font.Black
                            font.letterSpacing: -6
                            color: "#f4f4f6"
                        }
                        Text {
                            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "mm")
                            font.family: Tema.carattere
                            font.pixelSize: 168
                            font.weight: Font.Black
                            font.letterSpacing: -6
                            color: Qt.rgba(1, 1, 1, 0.72)
                        }
                    }

                    Column {
                        spacing: 4
                        Text {
                            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "dddd d MMMM")
                            font.family: Tema.mono
                            font.pixelSize: 15
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }
                        Text {
                            text: Saluto.frase(orologio.date) + (Opzioni.nomeUtente() !== "" ? ", " + Opzioni.nomeUtente() : "")
                            font.family: Tema.mono
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }

                    // la password
                    Item {
                        id: zonaPassword
                        width: 300
                        height: 54
                        property real scossa: 0
                        transform: Translate { x: zonaPassword.scossa }

                        SequentialAnimation {
                            id: scuoti
                            NumberAnimation { target: zonaPassword; property: "scossa"; to: -14; duration: 50 }
                            NumberAnimation { target: zonaPassword; property: "scossa"; to: 12; duration: 70 }
                            NumberAnimation { target: zonaPassword; property: "scossa"; to: -8; duration: 70 }
                            NumberAnimation { target: zonaPassword; property: "scossa"; to: 0; duration: 60 }
                        }
                        Connections {
                            target: blocco
                            function onSbagliata() { scuoti.restart(); password.text = ""; }
                        }

                        TextInput {
                            id: password
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            font.family: Tema.mono
                            font.pixelSize: 18
                            font.letterSpacing: 4
                            color: "#ffffff"
                            focus: true
                            enabled: !blocco.controllo
                            Component.onCompleted: forceActiveFocus()
                            onAccepted: blocco.verifica(text)
                            onTextChanged: if (text !== "") blocco.errore = ""
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: password.text === ""
                                text: blocco.controllo ? "Controllo..." : (blocco.errore !== "" ? blocco.errore : "Scrivi la password")
                                font.family: Tema.mono
                                font.pixelSize: 14
                                font.letterSpacing: 0
                                color: blocco.errore !== "" ? "#ff8a84" : Qt.rgba(1, 1, 1, 0.55)
                            }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            radius: 1
                            color: blocco.errore !== "" ? "#ff5f57" : Qt.rgba(1, 1, 1, password.activeFocus ? 0.85 : 0.4)
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    Row {
                        spacing: 14
                        topPadding: 6
                        TastoBlocco { icona: "power_settings_new"; onCliccato: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "poweroff"]) }
                        TastoBlocco { icona: "restart_alt"; onCliccato: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "reboot"]) }
                        TastoBlocco { icona: "arrow_forward"; onCliccato: blocco.verifica(password.text) }
                    }
                }

                // in basso: notifiche e un po' di numeri
                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: colonna.x
                    anchors.bottomMargin: 48
                    spacing: 4
                    visible: Opzioni.statisticheBlocco
                    Text {
                        text: (Avvisi.quante === 1 ? "1 notifica" : Avvisi.quante + " notifiche")
                        font.family: Tema.mono
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.8)
                    }
                    Text {
                        text: "CPU " + Math.round(Sistema.cpu * 100) + "%  ·  RAM " + Math.round(Sistema.memoria * 100)
                              + "%" + (Sistema.gpu >= 0 ? "  ·  GPU " + Math.round(Sistema.gpu * 100) + "%" : "")
                        font.family: Tema.mono
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.6)
                    }
                }

                // in basso a destra: la musica, se suona
                Rectangle {
                    visible: Musica.attivo !== null && Musica.titolo !== ""
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 40
                    width: 320
                    height: 64
                    radius: 20
                    color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    Row {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        Column {
                            width: parent.width - 90
                            anchors.verticalCenter: parent.verticalCenter
                            Text { width: parent.width; elide: Text.ElideRight; text: Musica.titolo; font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#ffffff" }
                            Text { width: parent.width; elide: Text.ElideRight; text: Musica.artista; font.family: Tema.carattere; font.pixelSize: 11; color: Qt.rgba(1, 1, 1, 0.6) }
                        }
                        TastoBlocco { width: 36; height: 36; icona: Musica.suona ? "pause" : "play_arrow"; anchors.verticalCenter: parent.verticalCenter; onCliccato: Musica.alterna() }
                        TastoBlocco { width: 36; height: 36; icona: "skip_next"; anchors.verticalCenter: parent.verticalCenter; onCliccato: Musica.avanti() }
                    }
                }
            }
        }
    }

    component TastoBlocco: Rectangle {
        id: tasto
        property string icona: ""
        signal cliccato()
        width: 42
        height: 42
        radius: width / 2
        color: areaT.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1)
        Behavior on color { ColorAnimation { duration: 150 } }
        Icona { anchors.centerIn: parent; nome: tasto.icona; dimensione: 20; color: "#ffffff" }
        MouseArea {
            id: areaT
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tasto.cliccato()
        }
    }
}
EOF
cat > "$d/Calendario.qml" << "EOF"
// Calendario del mese, con le frecce per gli altri mesi (creato da lfs.sh, Fase 10)
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: calendario
    property date oggi: new Date()
    property int spostamento: 0       // mesi avanti/indietro rispetto a oggi
    readonly property date mese: new Date(oggi.getFullYear(), oggi.getMonth() + spostamento, 1)

    readonly property var giorni: {
        const anno = mese.getFullYear(), m = mese.getMonth();
        const primo = (new Date(anno, m, 1).getDay() + 6) % 7;      // lunedi' = 0
        const quanti = new Date(anno, m + 1, 0).getDate();
        const prima = new Date(anno, m, 0).getDate();
        const l = [];
        for (let i = 0; i < 42; i++) {
            const n = i - primo + 1;
            if (n < 1) l.push({ n: prima + n, fuori: true, oggi: false });
            else if (n > quanti) l.push({ n: n - quanti, fuori: true, oggi: false });
            else l.push({
                n: n, fuori: false,
                oggi: n === oggi.getDate() && m === oggi.getMonth() && anno === oggi.getFullYear()
            });
        }
        return l;
    }

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        PulsanteIcona {
            implicitWidth: 28; implicitHeight: 28
            icona: "chevron_left"; dimensioneIcona: 18
            color: "transparent"
            onCliccato: calendario.spostamento--
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: {
                const t = calendario.mese.toLocaleString(Qt.locale("it_IT"), "MMMM yyyy");
                return t.charAt(0).toUpperCase() + t.slice(1);
            }
            font.family: Tema.carattere
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Tema.testo
            MouseArea { anchors.fill: parent; onClicked: calendario.spostamento = 0 }
        }
        PulsanteIcona {
            implicitWidth: 28; implicitHeight: 28
            icona: "chevron_right"; dimensioneIcona: 18
            color: "transparent"
            onCliccato: calendario.spostamento++
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["lu", "ma", "me", "gi", "ve", "sa", "do"]
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: Tema.carattere
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Tema.testo3
            }
        }
        Repeater {
            model: calendario.giorni
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height, 30)
                    height: width
                    radius: width / 2
                    color: modelData.oggi ? Tema.accento : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.n
                    font.family: Tema.carattere
                    font.pixelSize: 12
                    font.weight: modelData.oggi ? Font.Bold : Font.Normal
                    color: modelData.oggi ? Tema.suAccento : (modelData.fuori ? Tema.testo3 : Tema.testo)
                    opacity: modelData.fuori ? 0.6 : 1
                }
            }
        }
    }
}
EOF
cat > "$d/Carta.qml" << "EOF"
// Una "carta" dentro i pannelli: rettangolo chiaro e arrotondato (creato da lfs.sh)
import QtQuick

Rectangle {
    id: carta
    property bool cliccabile: false
    property bool sopra: area.containsMouse
    signal cliccata()

    radius: Tema.raggioMedio
    color: cliccabile && sopra ? Tema.cartaForte : Tema.carta
    border.width: 1
    border.color: Tema.bordo

    Behavior on color { ColorAnimation { duration: Tema.veloce } }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: carta.cliccabile
        hoverEnabled: carta.cliccabile
        cursorShape: carta.cliccabile ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: carta.cliccata()
    }
}
EOF
cat > "$d/Cruscotto.qml" << "EOF"
// Il cruscotto (creato da lfs.sh, Fase 10): si apre cliccando data e ora o con
// Windows+D. Tre schede: Cruscotto (meteo, saluto, orologio, calendario),
// Sfondi e Prestazioni (processore, memoria, disco, rete).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: cruscotto

    visible: Stato.cruscotto || corpo.opacity > 0.01
    anchors { top: true }
    margins { top: 6 }
    implicitWidth: 900
    implicitHeight: 520
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-cruscotto"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: Stato.cruscotto ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [ cruscotto ]
        active: Stato.cruscotto
        onCleared: Stato.cruscotto = false
    }

    SystemClock { id: orologio; precision: SystemClock.Minutes }

    Rectangle {
        id: corpo
        anchors.fill: parent
        radius: Tema.raggio + 4
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        opacity: Stato.cruscotto ? 1 : 0
        transform: [
            Scale {
                origin.x: corpo.width / 2
                origin.y: 0
                xScale: Stato.cruscotto ? 1 : 0.96
                yScale: Stato.cruscotto ? 1 : 0.96
                Behavior on xScale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
                Behavior on yScale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
            },
            Translate {
                y: Stato.cruscotto ? 0 : -16
                Behavior on y { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
            }
        ]
        Behavior on opacity { NumberAnimation { duration: Tema.media } }

        focus: Stato.cruscotto
        Keys.onEscapePressed: Stato.cruscotto = false
        Keys.onTabPressed: Stato.schedaCruscotto = (Stato.schedaCruscotto + 1) % 3

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // --- le schede ------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: Tema.carta
                Rectangle {
                    id: evidenza
                    y: 4
                    height: parent.height - 8
                    width: (parent.width - 8) / 3
                    x: 4 + Stato.schedaCruscotto * width
                    radius: height / 2
                    color: Tema.cartaSopra
                    Behavior on x { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    Repeater {
                        model: [
                            { nome: "Cruscotto", icona: "dashboard" },
                            { nome: "Sfondi", icona: "wallpaper" },
                            { nome: "Prestazioni", icona: "monitoring" }
                        ]
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: parent.width / 3
                            height: parent.height
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Icona {
                                    nome: modelData.icona
                                    dimensione: 18
                                    piena: Stato.schedaCruscotto === index
                                    color: Stato.schedaCruscotto === index ? Tema.testo : Tema.testo2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.nome
                                    font.family: Tema.carattere
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Stato.schedaCruscotto === index ? Tema.testo : Tema.testo2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Stato.schedaCruscotto = parent.index
                            }
                        }
                    }
                }
            }

            // --- il contenuto: scorre di lato cambiando scheda --------------------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Row {
                    id: pagine
                    x: -Stato.schedaCruscotto * (parent.width + 20)
                    spacing: 20
                    height: parent.height
                    Behavior on x { NumberAnimation { duration: Tema.lenta; easing.type: Easing.OutCubic } }

                    PaginaCruscotto { width: pagine.parent.width; height: pagine.height }
                    PaginaSfondi { width: pagine.parent.width; height: pagine.height }
                    PaginaPrestazioni { width: pagine.parent.width; height: pagine.height }
                }
            }
        }
    }

    // ============================================================ scheda Cruscotto
    component PaginaCruscotto: GridLayout {
        id: paginaC
        columns: 3
        rowSpacing: 12
        columnSpacing: 12

        // (i componenti qui sotto non vedono l'orologio della finestra: ne hanno uno)
        SystemClock { id: ora; precision: SystemClock.Minutes }

        // meteo
        Carta {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16
                visible: Opzioni.meteo
                Icona { nome: Meteo.icona; dimensione: 52; piena: true }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: Meteo.temperatura + "°C"
                        font.family: Tema.carattere; font.pixelSize: 34; font.weight: Font.Bold
                        color: Tema.testo
                    }
                    Text {
                        text: Meteo.pronto ? Meteo.descrizione : "Cerco il meteo..."
                        font.family: Tema.carattere; font.pixelSize: 12
                        color: Tema.testo2
                    }
                    Text {
                        visible: Meteo.luogo !== ""
                        text: Meteo.luogo + (Meteo.umidita !== "" ? "  ·  umidità " + Meteo.umidita + "%" : "")
                        font.family: Tema.carattere; font.pixelSize: 11
                        color: Tema.testo3
                    }
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: Meteo.giorni
                    delegate: Column {
                        required property var modelData
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.giorno
                            font.family: Tema.carattere; font.pixelSize: 11; font.weight: Font.DemiBold
                            color: Tema.testo2
                        }
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: modelData.icona; dimensione: 24 }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.max + "° " + modelData.min + "°"
                            font.family: Tema.carattere; font.pixelSize: 11
                            color: Tema.testo2
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !Opzioni.meteo
                text: "Il meteo è spento (Impostazioni → Cruscotto)"
                font.family: Tema.carattere; font.pixelSize: 12
                color: Tema.testo3
            }
        }

        // saluto
        Carta {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                RowLayout {
                    spacing: 10
                    Avatar { Layout.preferredWidth: 42; Layout.preferredHeight: 42 }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        text: Saluto.frase(ora.date) + (Opzioni.nomeUtente() !== "" ? ",\n" + Opzioni.nomeUtente() : "")
                        font.family: Tema.carattere; font.pixelSize: 14; font.weight: Font.DemiBold
                        color: Tema.testo
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Pastiglia { icona: "computer"; testo: Sistema.nomeComputer }
                    Pastiglia { icona: "schedule"; testo: "acceso da " + Sistema.testoAcceso() }
                }
            }
        }

        // orologio grande
        Carta {
            Layout.preferredWidth: 150
            Layout.fillHeight: true
            Column {
                anchors.centerIn: parent
                spacing: -6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ora.date.toLocaleString(Qt.locale("it_IT"), "HH")
                    font.family: Tema.carattere; font.pixelSize: 64; font.weight: Font.Black
                    color: Tema.testo
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ora.date.toLocaleString(Qt.locale("it_IT"), "mm")
                    font.family: Tema.carattere; font.pixelSize: 64; font.weight: Font.Black
                    color: Tema.testo2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 10
                    text: ora.date.toLocaleString(Qt.locale("it_IT"), "dddd").toUpperCase()
                    font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.DemiBold
                    font.letterSpacing: 2
                    color: Tema.testo3
                }
            }
        }

        // calendario
        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Calendario { anchors.fill: parent; anchors.margins: 12; oggi: ora.date }
        }

        // processore, memoria, disco
        Carta {
            Layout.preferredWidth: 236
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                MiniAnello { titolo: "Processore"; valore: Sistema.cpu; icona: "memory" }
                MiniAnello { titolo: "Memoria"; valore: Sistema.memoria; icona: "memory_alt" }
                MiniAnello { titolo: "Disco"; valore: Sistema.disco; icona: "hard_drive" }
            }
        }
    }

    component Pastiglia: Rectangle {
        id: pastiglia
        property string icona: ""
        property string testo: ""
        visible: testo !== ""
        height: 24
        width: rigaP.implicitWidth + 16
        radius: 12
        color: Tema.cartaForte
        Row {
            id: rigaP
            anchors.centerIn: parent
            spacing: 4
            Icona { nome: pastiglia.icona; dimensione: 14; color: Tema.testo2; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: pastiglia.testo
                font.family: Tema.carattere; font.pixelSize: 11
                color: Tema.testo2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component MiniAnello: RowLayout {
        id: mini
        property string titolo: ""
        property real valore: 0
        property string icona: ""
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12
        Item {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            Anello { anchors.fill: parent; valore: mini.valore; spessore: 5 }
            Icona { anchors.centerIn: parent; nome: mini.icona; dimensione: 16; color: Tema.testo2 }
        }
        ColumnLayout {
            spacing: 0
            Text { text: mini.titolo; font.family: Tema.carattere; font.pixelSize: 12; color: Tema.testo2 }
            Text {
                text: Math.round(mini.valore * 100) + "%"
                font.family: Tema.carattere; font.pixelSize: 18; font.weight: Font.Bold
                color: Tema.testo
            }
        }
    }

    // ============================================================ scheda Sfondi
    component PaginaSfondi: ColumnLayout {
        spacing: 12
        GridView {
            id: galleria
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / 4
            cellHeight: cellWidth * 0.62
            model: Sfondi.elenco
            delegate: Item {
                required property var modelData
                width: galleria.cellWidth
                height: galleria.cellHeight
                Rectangle {
                    id: cornice
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Tema.raggioMedio
                    color: Tema.carta
                    border.width: modelData === Sfondi.attuale ? 3 : 1
                    border.color: modelData === Sfondi.attuale ? Tema.accento : Tema.bordo
                    scale: areaSf.containsMouse ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                        sourceSize.height: 200
                        source: "file://" + modelData
                    }
                    MouseArea {
                        id: areaSf
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sfondi.scegli(modelData)
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Clicca un'immagine per metterla come sfondo"
                font.family: Tema.carattere; font.pixelSize: 12
                color: Tema.testo3
            }
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: testoMia.implicitWidth + 48
                radius: 16
                color: areaMia.containsMouse ? Tema.cartaSopra : Tema.cartaForte
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icona { nome: "add_photo_alternate"; dimensione: 17; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        id: testoMia
                        text: "Usa una tua immagine..."
                        font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.Medium
                        color: Tema.testo
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: areaMia
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Stato.cruscotto = false; Quickshell.execDetached(["/usr/local/bin/impostazioni-aspetto"]); }
                }
            }
        }
    }

    // ============================================================ scheda Prestazioni
    component PaginaPrestazioni: GridLayout {
        columns: 3
        rowSpacing: 12
        columnSpacing: 12

        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 2
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Icona { nome: "memory"; dimensione: 20 }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: "Processore" + (Sistema.processore !== "" ? "  ·  " + Sistema.processore : "")
                        font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                        color: Tema.testo
                    }
                    Text {
                        visible: Sistema.temperatura > 0
                        text: Math.round(Sistema.temperatura) + "°C"
                        font.family: Tema.mono; font.pixelSize: 12
                        color: Tema.testo2
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16
                    Item {
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 110
                        Anello { anchors.fill: parent; valore: Sistema.cpu; spessore: 10 }
                        Text {
                            anchors.centerIn: parent
                            text: Math.round(Sistema.cpu * 100) + "%"
                            font.family: Tema.carattere; font.pixelSize: 24; font.weight: Font.Bold
                            color: Tema.testo
                        }
                    }
                    Grafico {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        valori: Sistema.storiaCpu
                        massimo: 1
                    }
                }
            }
        }

        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                RowLayout {
                    Icona { nome: "memory_alt"; dimensione: 20 }
                    Text { text: "Memoria"; font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold; color: Tema.testo }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Anello {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 6
                        height: width
                        valore: Sistema.memoria
                        spessore: 10
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Math.round(Sistema.memoria * 100) + "%"
                        font.family: Tema.carattere; font.pixelSize: 22; font.weight: Font.Bold
                        color: Tema.testo
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Sistema.memoriaUsata.toFixed(1) + " / " + Sistema.memoriaTotale.toFixed(1) + " GB"
                    font.family: Tema.mono; font.pixelSize: 12
                    color: Tema.testo2
                }
            }
        }

        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                RowLayout {
                    Icona { nome: "hard_drive"; dimensione: 20 }
                    Text { text: "Disco"; font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold; color: Tema.testo }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Anello {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 6
                        height: width
                        valore: Sistema.disco
                        spessore: 10
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Math.round(Sistema.disco * 100) + "%"
                        font.family: Tema.carattere; font.pixelSize: 22; font.weight: Font.Bold
                        color: Tema.testo
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Sistema.discoUsato.toFixed(1) + " / " + Sistema.discoTotale.toFixed(1) + " GB"
                    font.family: Tema.mono; font.pixelSize: 12
                    color: Tema.testo2
                }
            }
        }

        Carta {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 2
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Icona { nome: "network_check"; dimensione: 20 }
                    Text {
                        Layout.fillWidth: true
                        text: "Rete"
                        font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                        color: Tema.testo
                    }
                    Icona { nome: "south"; dimensione: 15; color: Tema.accento }
                    Text { text: Sistema.velocita(Sistema.scarica); font.family: Tema.mono; font.pixelSize: 12; color: Tema.testo }
                    Item { Layout.preferredWidth: 8 }
                    Icona { nome: "north"; dimensione: 15; color: Tema.testo3 }
                    Text { text: Sistema.velocita(Sistema.carica); font.family: Tema.mono; font.pixelSize: 12; color: Tema.testo2 }
                }
                Grafico {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    valori: Sistema.storiaScarica
                    valori2: Sistema.storiaCarica
                }
                Text {
                    text: "Da quando è acceso: scaricati " + Sistema.grandezza(Sistema.totaleScaricato)
                          + ", inviati " + Sistema.grandezza(Sistema.totaleCaricato)
                    font.family: Tema.carattere; font.pixelSize: 11
                    color: Tema.testo3
                }
            }
        }
    }
}
EOF
cat > "$d/Cursore.qml" << "EOF"
// Cursore da trascinare (volume, trasparenza...) (creato da lfs.sh, Fase 10)
import QtQuick

Item {
    id: cursore
    property real valore: 0.5          // 0..1
    property string icona: ""
    signal spostato(real valore)

    implicitHeight: 34
    implicitWidth: 200

    Rectangle {
        id: binario
        anchors.fill: parent
        radius: height / 2
        color: Tema.cartaForte
        clip: true

        Rectangle {
            id: pieno
            height: parent.height
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, cursore.valore)))
            radius: height / 2
            color: Tema.accento
            Behavior on width {
                enabled: !trascina.pressed
                NumberAnimation { duration: Tema.veloce; easing.type: Easing.OutCubic }
            }
        }

        Icona {
            visible: cursore.icona !== ""
            nome: cursore.icona
            dimensione: 18
            color: Tema.suAccento
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: trascina
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function calcola(x) { return Math.max(0, Math.min(1, x / width)); }
        onPressed: e => cursore.spostato(calcola(e.x))
        onPositionChanged: e => { if (pressed) cursore.spostato(calcola(e.x)); }
        onWheel: e => cursore.spostato(Math.max(0, Math.min(1, cursore.valore + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
EOF
cat > "$d/Dock.qml" << "EOF"
// Il dock in basso (creato da lfs.sh, Fase 10): le app preferite, quelle aperte e
// le finestre ridotte. Passandoci sopra le icone si ingrandiscono come su macOS.
// Clic: apre l'app, o porta davanti la sua finestra. Si spegne da Impostazioni.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: dock
    required property var modelData
    screen: modelData

    anchors { bottom: true }
    implicitWidth: pillola.width + 40
    implicitHeight: 132
    exclusiveZone: 80
    color: "transparent"
    WlrLayershell.namespace: "vetro-dock"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region { item: pillola }

    function fissate() {
        const r = [];
        const lista = Opzioni.preferite;
        let browser = false;
        for (let i = 0; i < lista.length; i++) {
            const e = DesktopEntries.byId(lista[i]);
            if (!e || r.indexOf(e) >= 0) continue;
            if (e.id === "tor-browser" || e.id === "firefox") {
                if (browser) continue;
                browser = true;
            }
            r.push(e);
        }
        return r;
    }

    function voceDi(e) {
        for (let i = 0; i < voci.length; i++) if (voci[i].entry === e) return voci[i];
        return null;
    }

    // l'elenco: prima le preferite, poi le altre app aperte
    readonly property var voci: {
        const l = [];
        const fisse = fissate();
        for (let i = 0; i < fisse.length; i++)
            l.push({ chiave: fisse[i].id, entry: fisse[i], icona: fisse[i].icon, nome: fisse[i].name, finestre: [] });
        const finestre = Finestre.tutte;
        for (let i = 0; i < finestre.length; i++) {
            const t = finestre[i];
            const app = Finestre.appDi(t);
            if (app === "" || app.startsWith("org.quickshell")) continue;
            const e = DesktopEntries.heuristicLookup(app);
            let v = null;
            for (let j = 0; j < l.length; j++)
                if ((e && l[j].entry === e) || l[j].chiave === app) { v = l[j]; break; }
            if (v === null) {
                v = { chiave: e ? e.id : app, entry: e, icona: e ? e.icon : app, nome: e ? e.name : app, finestre: [] };
                l.push(v);
            }
            v.finestre.push(t);
        }
        return l;
    }

    function clic(v) {
        if (v.finestre.length === 0) {
            if (v.entry) v.entry.execute();
            return;
        }
        // una ridotta: torna; altrimenti la prossima finestra di quell'app
        for (let i = 0; i < v.finestre.length; i++)
            if (Finestre.ridotta(v.finestre[i])) { Finestre.riporta(v.finestre[i]); return; }
        let attiva = -1;
        for (let i = 0; i < v.finestre.length; i++)
            if (v.finestre[i].activated) attiva = i;
        if (attiva >= 0 && v.finestre.length === 1) {
            Finestre.riduci("0x" + v.finestre[0].address.replace(/^0x/, ""));
            return;
        }
        Finestre.riporta(v.finestre[(attiva + 1) % v.finestre.length]);
    }

    property real mouseX: -1000

    Rectangle {
        id: pillola
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 66
        width: fila.width + 20
        radius: 22
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        Behavior on width { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        MouseArea {
            id: sopra
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: e => dock.mouseX = e.x
            onExited: dock.mouseX = -1000
        }

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: ScriptModel { values: dock.voci }
                delegate: Item {
                    id: casella
                    required property var modelData
                    width: 52
                    height: 52

                    readonly property real centro: x + width / 2 + 10
                    readonly property real vicinanza: Math.max(0, 1 - Math.abs(centro - dock.mouseX) / 130)
                    readonly property bool aperta: modelData.finestre.length > 0

                    Item {
                        id: icona
                        anchors.fill: parent
                        transformOrigin: Item.Bottom
                        scale: Opzioni.animazioni ? 1 + 0.42 * casella.vicinanza : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 46
                            asynchronous: true
                            mipmap: true
                            source: Applicazioni.icona(casella.modelData.icona)
                            scale: areaC.pressed ? 0.88 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.veloce } }
                        }
                    }

                    // pallino: l'app e' aperta
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 1
                        width: casella.aperta ? 5 : 0
                        height: 5
                        radius: 2.5
                        color: Tema.testo2
                        Behavior on width { NumberAnimation { duration: Tema.media } }
                    }

                    // il nome sopra l'icona
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -56
                        width: nomeApp.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: Tema.fondoPieno
                        border.width: 1
                        border.color: Tema.bordo
                        opacity: casella.vicinanza > 0.9 ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Tema.veloce } }
                        Text {
                            id: nomeApp
                            anchors.centerIn: parent
                            text: casella.modelData.nome
                            font.family: Tema.carattere
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Tema.testo
                        }
                    }

                    MouseArea {
                        id: areaC
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.clic(casella.modelData)
                    }
                }
            }
        }
    }
}
EOF
cat > "$d/FinestraImpostazioni.qml" << "EOF"
// Impostazioni del desktop Vetro (creato da lfs.sh, Fase 10): a sinistra le voci,
// a destra le scelte. Tutto vale subito e resta salvato. Si apre con Windows+I,
// dal centro di controllo o dall'icona delle Impostazioni.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets

FloatingWindow {
    id: finestra
    title: "Impostazioni di sistema"
    implicitWidth: 1040
    implicitHeight: 700
    minimumSize: Qt.size(880, 580)
    color: "transparent"

    onClosed: Stato.impostazioni = false

    readonly property var voci: [
        { id: "generale",   nome: "Generale",         icona: "home" },
        { id: "aspetto",    nome: "Aspetto",          icona: "palette" },
        { id: "finestre",   nome: "Finestre",         icona: "select_window" },
        { id: "barra",      nome: "Barra e dock",     icona: "dock_to_bottom" },
        { id: "cruscotto",  nome: "Cruscotto e meteo", icona: "partly_cloudy_day" },
        { id: "notifiche",  nome: "Notifiche",        icona: "notifications" },
        { id: "blocco",     nome: "Blocco schermo",   icona: "lock" },
        { id: "schermo",    nome: "Schermo",          icona: "desktop_windows" },
        { id: "sistema",    nome: "Sistema",          icona: "info" }
    ]
    function nomeDi(id) {
        for (let i = 0; i < voci.length; i++) if (voci[i].id === id) return voci[i].nome;
        return "";
    }

    Rectangle {
        id: corpo
        anchors.fill: parent
        radius: Tema.raggio
        color: Tema.fondoPieno
        border.width: 1
        border.color: Tema.bordoForte
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------------------------------------------------- menu a sinistra
            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: Tema.carta

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    // i tre pulsanti tondi e lo spostamento della finestra
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        MouseArea {
                            anchors.fill: parent
                            onPressed: finestra.startSystemMove()
                        }
                        Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Semaforo { colore: Tema.rosso; segno: "close"; onCliccato: Stato.impostazioni = false }
                            Semaforo { colore: Tema.giallo; segno: "remove"; onCliccato: Finestre.riduciAttiva() }
                            Semaforo { colore: Tema.verde; segno: "add"; onCliccato: Hyprland.dispatch("fullscreen 1") }
                        }
                    }

                    // chi sei
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        spacing: 10
                        Avatar { Layout.preferredWidth: 44; Layout.preferredHeight: 44 }
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Opzioni.nomeUtente() || Sistema.utente
                                font.family: Tema.carattere; font.pixelSize: 15; font.weight: Font.DemiBold
                                color: Tema.testo
                            }
                            Text {
                                text: Sistema.nomeComputer
                                font.family: Tema.carattere; font.pixelSize: 11
                                color: Tema.testo2
                            }
                        }
                    }

                    ListView {
                        id: menu
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: finestra.voci
                        currentIndex: {
                            for (let i = 0; i < finestra.voci.length; i++)
                                if (finestra.voci[i].id === Stato.pagina) return i;
                            return 0;
                        }
                        highlightMoveDuration: Tema.media
                        highlight: Rectangle { radius: Tema.raggioPiccolo; color: Tema.accento }
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: menu.width
                            height: 40
                            readonly property bool scelta: Stato.pagina === modelData.id
                            Rectangle {
                                anchors.fill: parent
                                radius: Tema.raggioPiccolo
                                color: areaVoce.containsMouse && !parent.scelta ? Tema.cartaForte : "transparent"
                            }
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Icona {
                                    nome: modelData.icona
                                    dimensione: 19
                                    piena: parent.parent.scelta
                                    color: parent.parent.scelta ? Tema.suAccento : Tema.testo2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.nome
                                    font.family: Tema.carattere; font.pixelSize: 13
                                    font.weight: parent.parent.scelta ? Font.DemiBold : Font.Normal
                                    color: parent.parent.scelta ? Tema.suAccento : Tema.testo
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                id: areaVoce
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Stato.pagina = modelData.id
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------------- pagina a destra
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    MouseArea { anchors.fill: parent; onPressed: finestra.startSystemMove() }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: finestra.nomeDi(Stato.pagina)
                        font.family: Tema.carattere; font.pixelSize: 22; font.weight: Font.Bold
                        color: Tema.testo
                    }
                }

                Flickable {
                    id: scorri
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: pagina.height + 40
                    boundsBehavior: Flickable.StopAtBounds

                    Loader {
                        id: pagina
                        x: 28
                        width: scorri.width - 56
                        opacity: 0
                        sourceComponent: {
                            switch (Stato.pagina) {
                            case "aspetto": return pAspetto;
                            case "finestre": return pFinestre;
                            case "barra": return pBarra;
                            case "cruscotto": return pCruscotto;
                            case "notifiche": return pNotifiche;
                            case "blocco": return pBlocco;
                            case "schermo": return pSchermo;
                            case "sistema": return pSistema;
                            default: return pGenerale;
                            }
                        }
                        onLoaded: { scorri.contentY = 0; entra.restart(); }
                        ParallelAnimation {
                            id: entra
                            NumberAnimation { target: pagina; property: "opacity"; from: 0; to: 1; duration: Tema.media }
                            NumberAnimation { target: pagina; property: "x"; from: 52; to: 28; duration: Tema.media; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }

    // =================================================================== le pagine
    Component {
        id: pGenerale
        ColumnLayout {
            spacing: 16
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                SystemClock { id: oraG; precision: SystemClock.Minutes }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 20
                    Avatar { Layout.preferredWidth: 84; Layout.preferredHeight: 84 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: Saluto.frase(oraG.date) + (Opzioni.nomeUtente() !== "" ? ", " + Opzioni.nomeUtente() : "")
                            font.family: Tema.carattere; font.pixelSize: 24; font.weight: Font.Bold
                            color: Tema.testo
                        }
                        Text {
                            text: oraG.date.toLocaleString(Qt.locale("it_IT"), "dddd d MMMM  ·  HH:mm")
                            font.family: Tema.carattere; font.pixelSize: 13
                            color: Tema.testo2
                        }
                        Text {
                            text: "Tema " + Tema.attuale.nome + "  ·  acceso da " + Sistema.testoAcceso()
                            font.family: Tema.carattere; font.pixelSize: 12
                            color: Tema.testo3
                        }
                    }
                }
            }
            Text {
                text: "Cosa vuoi cambiare?"
                font.family: Tema.carattere; font.pixelSize: 14; font.weight: Font.DemiBold
                color: Tema.testo2
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: finestra.voci.slice(1)
                    delegate: Carta {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        cliccabile: true
                        onCliccata: Stato.pagina = modelData.id
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14
                            Rectangle {
                                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                                radius: 13
                                color: Tema.cartaForte
                                Icona { anchors.centerIn: parent; nome: modelData.icona; dimensione: 22 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.nome
                                font.family: Tema.carattere; font.pixelSize: 14; font.weight: Font.DemiBold
                                color: Tema.testo
                            }
                            Icona { nome: "chevron_right"; dimensione: 20; color: Tema.testo3 }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pAspetto
        ColumnLayout {
            spacing: 16
            Titolo { testo: "Tema" }
            Row {
                spacing: 14
                Repeater {
                    model: Tema.temi
                    delegate: Column {
                        required property var modelData
                        spacing: 8
                        Rectangle {
                            width: 128; height: 84
                            radius: Tema.raggioMedio
                            color: modelData.fondo
                            border.width: Opzioni.tema === modelData.id ? 3 : 1
                            border.color: Opzioni.tema === modelData.id ? Tema.accento : Tema.bordoForte
                            scale: areaT.containsMouse ? 1.04 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.veloce } }
                            Rectangle {
                                x: 12; y: 14; width: 64; height: 10; radius: 5
                                color: modelData.accento
                            }
                            Rectangle {
                                x: 12; y: 32; width: 96; height: 8; radius: 4
                                color: modelData.id === "carta" ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.18)
                            }
                            Rectangle {
                                x: 12; y: 46; width: 76; height: 8; radius: 4
                                color: modelData.id === "carta" ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(1, 1, 1, 0.12)
                            }
                            MouseArea {
                                id: areaT
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Opzioni.tema = modelData.id
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.nome
                            font.family: Tema.carattere; font.pixelSize: 12
                            font.weight: Opzioni.tema === modelData.id ? Font.DemiBold : Font.Normal
                            color: Tema.testo
                        }
                    }
                }
            }
            Titolo { testo: "Effetto vetro" }
            Gruppo {
                Riga {
                    titolo: "Trasparenza dei pannelli"
                    sottotitolo: "Più trasparente: si vede di più lo sfondo, sfocato"
                    Cursore {
                        Layout.preferredWidth: 220
                        valore: (0.95 - Opzioni.opacita) / 0.6
                        onSpostato: v => Opzioni.opacita = Math.round((0.95 - v * 0.6) * 100) / 100
                    }
                }
            }
            Titolo { testo: "Sfondo" }
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: Sfondi.elenco
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 0.6
                        radius: Tema.raggioPiccolo
                        color: Tema.carta
                        border.width: modelData === Sfondi.attuale ? 3 : 1
                        border.color: modelData === Sfondi.attuale ? Tema.accento : Tema.bordo
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 320
                            sourceSize.height: 200
                            source: "file://" + modelData
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Sfondi.scegli(modelData)
                        }
                    }
                }
            }
            Pulsante {
                testo: "Usa una tua immagine..."
                icona: "add_photo_alternate"
                onCliccato: Quickshell.execDetached(["/usr/local/bin/impostazioni-aspetto"])
            }
        }
    }

    Component {
        id: pFinestre
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Animazioni"
                    sottotitolo: "Finestre e pannelli si muovono in modo fluido"
                    Interruttore { acceso: Opzioni.animazioni; onCambiato: v => Opzioni.animazioni = v }
                }
                Riga {
                    titolo: "Sfocatura"
                    sottotitolo: "Lo sfondo dietro i pannelli si vede sfocato (effetto vetro)"
                    Interruttore { acceso: Opzioni.sfocatura; onCambiato: v => Opzioni.sfocatura = v }
                }
                Riga {
                    titolo: "Affianca le finestre"
                    sottotitolo: "Le finestre nuove si dividono lo schermo da sole (per le finestre già aperte: Windows+V)"
                    Interruttore { acceso: Opzioni.affianca; onCambiato: v => Opzioni.affianca = v }
                }
            }
            Gruppo {
                Riga {
                    titolo: "Spazio tra le finestre"
                    sottotitolo: Opzioni.spazi + " pixel"
                    Cursore {
                        Layout.preferredWidth: 220
                        valore: Opzioni.spazi / 32
                        onSpostato: v => Opzioni.spazi = Math.round(v * 32)
                    }
                }
                Riga {
                    titolo: "Angoli arrotondati"
                    sottotitolo: Opzioni.angoli + " pixel"
                    Cursore {
                        Layout.preferredWidth: 220
                        valore: Opzioni.angoli / 28
                        onSpostato: v => Opzioni.angoli = Math.round(v * 28)
                    }
                }
            }
            Gruppo {
                Riga {
                    titolo: "Tasti utili"
                    sottotitolo: "Windows: cerca le app  ·  Windows+A: centro di controllo  ·  Windows+D: cruscotto\n"
                                 + "Alt+Tab: cambia finestra  ·  Windows+↑: ingrandisci  ·  Windows+↓: riduci  ·  Alt+F4: chiudi\n"
                                 + "Windows+1...5: scrivanie  ·  Windows+L: blocca  ·  Stamp: schermata"
                }
            }
        }
    }

    Component {
        id: pBarra
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Dock in basso"
                    sottotitolo: "Le app preferite e quelle aperte"
                    Interruttore { acceso: Opzioni.dock; onCambiato: v => Opzioni.dock = v }
                }
                Riga {
                    titolo: "Secondi nell'orologio"
                    sottotitolo: "Nella barra in alto"
                    Interruttore { acceso: Opzioni.secondi; onCambiato: v => Opzioni.secondi = v }
                }
            }
            Titolo { testo: "App nel dock" }
            Gruppo {
                Repeater {
                    model: Opzioni.preferite
                    delegate: Riga {
                        required property var modelData
                        required property int index
                        readonly property var app: DesktopEntries.byId(modelData)
                        visible: app !== null
                        titolo: app ? app.name : modelData
                        sottotitolo: app ? (app.genericName || app.comment || "") : ""
                        Pulsante {
                            testo: "Togli"
                            icona: "remove"
                            onCliccato: {
                                const l = Opzioni.preferite.slice();
                                l.splice(index, 1);
                                Opzioni.preferite = l;
                            }
                        }
                    }
                }
            }
            Titolo { testo: "Aggiungi un'app al dock" }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 20
                color: Tema.cartaForte
                TextInput {
                    id: cercaApp
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tema.carattere; font.pixelSize: 13
                    color: Tema.testo
                    clip: true
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: cercaApp.text === ""
                        text: "Scrivi il nome dell'app..."
                        font: cercaApp.font
                        color: Tema.testo3
                    }
                }
            }
            Gruppo {
                visible: cercaApp.text !== ""
                Repeater {
                    model: cercaApp.text !== "" ? Applicazioni.cerca(cercaApp.text, 6) : []
                    delegate: Riga {
                        required property var modelData
                        titolo: modelData.name
                        sottotitolo: modelData.genericName || modelData.comment || ""
                        Pulsante {
                            testo: Opzioni.preferite.indexOf(modelData.id) >= 0 ? "Già nel dock" : "Aggiungi"
                            icona: "add"
                            onCliccato: {
                                if (Opzioni.preferite.indexOf(modelData.id) >= 0) return;
                                const l = Opzioni.preferite.slice();
                                l.push(modelData.id);
                                Opzioni.preferite = l;
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pCruscotto
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Meteo"
                    sottotitolo: "Lo chiede a wttr.in ogni mezz'ora (in modalità fantasma passa da Tor)"
                    Interruttore { acceso: Opzioni.meteo; onCambiato: v => Opzioni.meteo = v }
                }
                Riga {
                    titolo: "Città"
                    sottotitolo: "Vuoto: la trova da sola dalla connessione"
                    Rectangle {
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Tema.cartaForte
                        TextInput {
                            id: citta
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            text: Opzioni.citta
                            font.family: Tema.carattere; font.pixelSize: 13
                            color: Tema.testo
                            clip: true
                            onEditingFinished: Opzioni.citta = text.trim()
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: citta.text === "" && !citta.activeFocus
                                text: "es. Roma"
                                font: citta.font
                                color: Tema.testo3
                            }
                        }
                    }
                }
            }
            Gruppo {
                Riga {
                    titolo: "Ora: " + (Meteo.pronto ? Meteo.temperatura + "°C, " + Meteo.descrizione : "non ancora disponibile")
                    sottotitolo: Meteo.luogo
                    Pulsante { testo: "Aggiorna"; icona: "refresh"; onCliccato: Meteo.aggiorna() }
                }
            }
        }
    }

    Component {
        id: pNotifiche
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Non disturbare"
                    sottotitolo: "Le notifiche arrivano lo stesso, ma senza comparire (tranne quelle urgenti)"
                    Interruttore { acceso: Opzioni.nonDisturbare; onCambiato: v => Opzioni.nonDisturbare = v }
                }
                Riga {
                    titolo: Avvisi.quante === 1 ? "1 notifica da leggere" : Avvisi.quante + " notifiche da leggere"
                    sottotitolo: "Le trovi nel centro di controllo (Windows+A)"
                    Pulsante { visible: Avvisi.quante > 0; testo: "Cancella tutte"; icona: "clear_all"; onCliccato: Avvisi.cancellaTutte() }
                }
                Riga {
                    titolo: "Prova"
                    sottotitolo: "Manda una notifica per vedere come appare"
                    Pulsante {
                        testo: "Manda"
                        icona: "send"
                        onCliccato: Quickshell.execDetached(["notify-send", "-a", "Impostazioni", "Ciao!", "Così appaiono le notifiche."])
                    }
                }
            }
        }
    }

    Component {
        id: pBlocco
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Blocca da solo dopo"
                    sottotitolo: "Se non tocchi mouse e tastiera (dal centro di controllo puoi dire \"Resta sveglio\")"
                    Row {
                        spacing: 4
                        Repeater {
                            model: [0, 5, 10, 15, 30, 60]
                            delegate: Rectangle {
                                required property var modelData
                                width: testoMin.implicitWidth + 22
                                height: 32
                                radius: 16
                                color: Opzioni.bloccoMinuti === modelData ? Tema.accento : (areaMin.containsMouse ? Tema.cartaSopra : Tema.cartaForte)
                                Text {
                                    id: testoMin
                                    anchors.centerIn: parent
                                    text: modelData === 0 ? "Mai" : modelData + " min"
                                    font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.Medium
                                    color: Opzioni.bloccoMinuti === modelData ? Tema.suAccento : Tema.testo
                                }
                                MouseArea {
                                    id: areaMin
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Opzioni.bloccoMinuti = modelData
                                }
                            }
                        }
                    }
                }
                Riga {
                    titolo: "Numeri sul blocco schermo"
                    sottotitolo: "Notifiche, processore e memoria in basso a sinistra"
                    Interruttore { acceso: Opzioni.statisticheBlocco; onCambiato: v => Opzioni.statisticheBlocco = v }
                }
                Riga {
                    titolo: "Blocca adesso"
                    sottotitolo: "Anche con Windows+L"
                    Pulsante { testo: "Blocca"; icona: "lock"; onCliccato: { Stato.impostazioni = false; Stato.blocca(); } }
                }
            }
        }
    }

    Component {
        id: pSchermo
        ColumnLayout {
            id: paginaSchermo
            spacing: 16
            property var modi: []
            property string risoluzione: ""
            property real scala: 1

            Process {
                running: true
                command: ["hyprctl", "monitors", "-j"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const m = JSON.parse(this.text)[0];
                            const visti = {};
                            const l = [];
                            for (let i = 0; i < m.availableModes.length; i++) {
                                const r = m.availableModes[i].split("@")[0];
                                if (!visti[r]) { visti[r] = true; l.push(r); }
                            }
                            paginaSchermo.modi = l;
                            paginaSchermo.risoluzione = m.width + "x" + m.height;
                            paginaSchermo.scala = m.scale;
                        } catch (e) {}
                    }
                }
            }

            function applica(r, s) {
                Quickshell.execDetached(["sh", "-c",
                    "printf 'RISOLUZIONE=%s\\nSCALA=%s\\n' \"$1\" \"$2\" > \"$HOME/.config/schermo.conf\" && " +
                    "hyprctl keyword monitor \",$1,auto,$2\" >/dev/null", "vetro", r, String(s)]);
                risoluzione = r;
                scala = s;
            }

            Gruppo {
                Riga {
                    titolo: "Risoluzione"
                    sottotitolo: "Ora: " + paginaSchermo.risoluzione
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 14
                    spacing: 6
                    Repeater {
                        model: paginaSchermo.modi
                        delegate: Rectangle {
                            required property var modelData
                            width: tr.implicitWidth + 22
                            height: 32
                            radius: 16
                            color: modelData === paginaSchermo.risoluzione ? Tema.accento : (ar.containsMouse ? Tema.cartaSopra : Tema.cartaForte)
                            Text {
                                id: tr
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Tema.carattere; font.pixelSize: 12
                                color: modelData === paginaSchermo.risoluzione ? Tema.suAccento : Tema.testo
                            }
                            MouseArea {
                                id: ar
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: paginaSchermo.applica(modelData, paginaSchermo.scala)
                            }
                        }
                    }
                }
            }
            Gruppo {
                Riga {
                    titolo: "Grandezza di testi e finestre"
                    sottotitolo: Math.round(paginaSchermo.scala * 100) + "%"
                    Row {
                        spacing: 4
                        Repeater {
                            model: [1, 1.25, 1.5, 2]
                            delegate: Rectangle {
                                required property var modelData
                                width: ts.implicitWidth + 22
                                height: 32
                                radius: 16
                                color: Math.abs(modelData - paginaSchermo.scala) < 0.01 ? Tema.accento : (areaScala.containsMouse ? Tema.cartaSopra : Tema.cartaForte)
                                Text {
                                    id: ts
                                    anchors.centerIn: parent
                                    text: Math.round(modelData * 100) + "%"
                                    font.family: Tema.carattere; font.pixelSize: 12
                                    color: Math.abs(modelData - paginaSchermo.scala) < 0.01 ? Tema.suAccento : Tema.testo
                                }
                                MouseArea {
                                    id: areaScala
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: paginaSchermo.applica(paginaSchermo.risoluzione, modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pSistema
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga { titolo: "Computer"; sottotitolo: Sistema.nomeComputer }
                Riga { titolo: "Utente"; sottotitolo: Sistema.utente }
                Riga { titolo: "Processore"; sottotitolo: Sistema.processore }
                Riga { titolo: "Memoria"; sottotitolo: Sistema.memoriaTotale.toFixed(1) + " GB" }
                Riga { titolo: "Disco"; sottotitolo: Sistema.discoUsato.toFixed(1) + " GB usati su " + Sistema.discoTotale.toFixed(1) + " GB" }
                Riga { titolo: "Kernel Linux"; sottotitolo: Sistema.kernel }
                Riga { titolo: "Desktop"; sottotitolo: "Vetro (Hyprland + Quickshell)" }
            }
            Titolo { testo: "Altre impostazioni" }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: [
                        { id: "vpn", nome: "VPN", icona: "vpn_lock" },
                        { id: "fantasma", nome: "Modalità fantasma", icona: "visibility_off" },
                        { id: "guardiano-regole", nome: "Guardiano della rete", icona: "shield" },
                        { id: "cassaforte", nome: "Cassaforte", icona: "lock" },
                        { id: "wine-programmi", nome: "Programmi Windows", icona: "window" },
                        { id: "cups", nome: "Stampanti", icona: "print" },
                        { id: "xfce4-taskmanager", nome: "Gestione attività", icona: "monitoring" },
                        { id: "impostazioni", nome: "Impostazioni classiche", icona: "tune" }
                    ].filter(v => !!DesktopEntries.byId(v.id))
                    delegate: Carta {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        cliccabile: true
                        onCliccata: {
                            // le Impostazioni classiche (a finestre di yad), non queste
                            if (modelData.id === "impostazioni") {
                                Quickshell.execDetached(["/usr/local/bin/impostazioni", "--classiche"]);
                                return;
                            }
                            const e = DesktopEntries.byId(modelData.id);
                            if (e) e.execute();
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12
                            Icona { nome: modelData.icona; dimensione: 22 }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.nome
                                font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                                color: Tema.testo
                            }
                            Icona { nome: "open_in_new"; dimensione: 16; color: Tema.testo3 }
                        }
                    }
                }
            }
            Gruppo {
                Riga {
                    titolo: "Desktop classico"
                    sottotitolo: "Al prossimo accesso torna il desktop di prima (labwc). Per tornare qui apri «Cambia desktop» tra le app"
                    Pulsante {
                        testo: "Usa il classico"
                        icona: "swap_horiz"
                        onCliccato: Quickshell.execDetached(["/usr/local/bin/scegli-desktop", "classico"])
                    }
                }
            }
        }
    }

    // =================================================================== pezzi comuni
    component Titolo: Text {
        property string testo: ""
        text: testo
        Layout.topMargin: 4
        font.family: Tema.carattere
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: Tema.testo2
    }

    // un gruppo di righe dentro una carta
    component Gruppo: Rectangle {
        id: gruppo
        default property alias contenuto: colonnaG.data
        Layout.fillWidth: true
        implicitHeight: colonnaG.implicitHeight
        radius: Tema.raggioMedio
        color: Tema.carta
        border.width: 1
        border.color: Tema.bordo
        ColumnLayout {
            id: colonnaG
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
        }
    }

    // una riga: titolo e spiegazione a sinistra, il comando a destra
    component Riga: Item {
        id: riga
        property string titolo: ""
        property string sottotitolo: ""
        default property alias comando: postoComando.data
        Layout.fillWidth: true
        implicitHeight: Math.max(58, testi.implicitHeight + 24)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16
            ColumnLayout {
                id: testi
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: riga.titolo
                    wrapMode: Text.Wrap
                    font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                    color: Tema.testo
                }
                Text {
                    Layout.fillWidth: true
                    visible: riga.sottotitolo !== ""
                    text: riga.sottotitolo
                    wrapMode: Text.Wrap
                    font.family: Tema.carattere; font.pixelSize: 11
                    color: Tema.testo2
                }
            }
            RowLayout { id: postoComando; spacing: 8 }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            height: 1
            color: Tema.bordo
        }
    }

    component Pulsante: Rectangle {
        id: puls
        property string testo: ""
        property string icona: ""
        signal cliccato()
        implicitHeight: 34
        implicitWidth: rigaPu.implicitWidth + 26
        radius: 17
        color: areaPu.containsMouse ? Tema.cartaSopra : Tema.cartaForte
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
        Row {
            id: rigaPu
            anchors.centerIn: parent
            spacing: 6
            Icona { visible: puls.icona !== ""; nome: puls.icona; dimensione: 16; anchors.verticalCenter: parent.verticalCenter }
            Text { text: puls.testo; font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.Medium; color: Tema.testo; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: areaPu; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: puls.cliccato() }
    }

    component Semaforo: Rectangle {
        id: sem
        property color colore: "red"
        property string segno: ""
        signal cliccato()
        width: 14
        height: 14
        radius: 7
        color: colore
        border.width: 1
        border.color: Qt.darker(colore, 1.2)
        Icona {
            anchors.centerIn: parent
            visible: areaSem.containsMouse
            nome: sem.segno
            dimensione: 11
            color: Qt.rgba(0, 0, 0, 0.6)
        }
        MouseArea { id: areaSem; anchors.fill: parent; hoverEnabled: true; onClicked: sem.cliccato() }
    }
}
EOF
cat > "$d/Finestre.qml" << "EOF"
pragma Singleton
// Le finestre aperte (creato da lfs.sh, Fase 10). Hyprland non sa "ridurre a icona":
// quando un programma lo chiede (il pulsante giallo), la finestra va in una scrivania
// nascosta e compare nel dock; cliccandola torna dov'era.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: finestre

    readonly property string nascoste: "special:ridotte"
    readonly property var tutte: Hyprland.toplevels.values

    function appDi(t) {
        if (t && t.wayland && t.wayland.appId) return t.wayland.appId;
        if (t && t.lastIpcObject && t.lastIpcObject["class"]) return t.lastIpcObject["class"];
        return "";
    }
    function ridotta(t) {
        return !!(t && t.workspace && t.workspace.name === nascoste);
    }
    function riduci(indirizzo) {
        if (!indirizzo) return;
        Hyprland.dispatch("movetoworkspacesilent " + nascoste + ",address:" + indirizzo);
    }
    function riduciAttiva() {
        const t = Hyprland.activeToplevel;
        if (t && t.address) riduci("0x" + t.address.replace(/^0x/, ""));
    }
    function riporta(t) {
        if (!t || !t.address) return;
        const ind = "0x" + t.address.replace(/^0x/, "");
        if (ridotta(t)) {
            const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            Hyprland.dispatch("movetoworkspace " + ws + ",address:" + ind);
        }
        Hyprland.dispatch("focuswindow address:" + ind);
        Hyprland.dispatch("alterzorder top,address:" + ind);
    }
    function finestreDi(app) {
        const r = [];
        for (let i = 0; i < tutte.length; i++)
            if (appDi(tutte[i]).toLowerCase() === app.toLowerCase()) r.push(tutte[i]);
        return r;
    }

    Connections {
        target: Hyprland
        function onRawEvent(evento) {
            // "minimized>>INDIRIZZO,1": un programma chiede di ridursi a icona
            if (evento.name === "minimized") {
                const parti = String(evento.data).split(",");
                if (parti.length >= 2 && parti[1] === "1")
                    finestre.riduci("0x" + parti[0].replace(/^0x/, ""));
            }
            if (evento.name === "openwindow" || evento.name === "closewindow"
                    || evento.name === "movewindowv2" || evento.name === "movewindow")
                Hyprland.refreshToplevels();
        }
    }
}
EOF
cat > "$d/Grafico.qml" << "EOF"
// Grafico a linea (rete, processore) (creato da lfs.sh, Fase 10)
import QtQuick

Canvas {
    id: grafico
    property var valori: []
    property var valori2: []
    property color colore: Tema.accento
    property color colore2: Tema.testo3
    property real massimo: 0           // 0 = automatico

    implicitHeight: 80
    implicitWidth: 240
    renderStrategy: Canvas.Cooperative

    onValoriChanged: requestPaint()
    onValori2Changed: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function linea(ctx, v, colore, max, riempi) {
        if (!v || v.length < 2) return;
        const passo = width / (v.length - 1);
        ctx.beginPath();
        for (let i = 0; i < v.length; i++) {
            const x = i * passo;
            const y = height - 2 - (height - 6) * Math.min(1, v[i] / max);
            if (i === 0) ctx.moveTo(x, y);
            else {
                const xp = (i - 1) * passo;
                const yp = height - 2 - (height - 6) * Math.min(1, v[i - 1] / max);
                ctx.bezierCurveTo(xp + passo / 2, yp, x - passo / 2, y, x, y);
            }
        }
        ctx.strokeStyle = colore;
        ctx.lineWidth = 2;
        ctx.stroke();
        if (riempi) {
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.rgba(colore.r, colore.g, colore.b, 0.35));
            g.addColorStop(1, Qt.rgba(colore.r, colore.g, colore.b, 0.0));
            ctx.fillStyle = g;
            ctx.fill();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        let max = massimo;
        if (max <= 0) {
            max = 1;
            for (let i = 0; i < valori.length; i++) max = Math.max(max, valori[i]);
            for (let i = 0; i < valori2.length; i++) max = Math.max(max, valori2[i]);
            max *= 1.15;
        }
        linea(ctx, valori2, colore2, max, false);
        linea(ctx, valori, colore, max, true);
    }
}
EOF
cat > "$d/Icona.qml" << "EOF"
// Un'icona dal carattere Material Symbols (creato da lfs.sh, Fase 10). Se il
// carattere non c'e' mostra un simbolo semplice al suo posto.
import QtQuick

Text {
    id: icona

    property string nome: "circle"
    property real dimensione: 20
    property bool piena: false

    readonly property var riserva: ({
        "search": "⌕", "close": "✕", "check": "✓", "add": "+", "remove": "−",
        "chevron_left": "‹", "chevron_right": "›", "expand_more": "⌄",
        "play_arrow": "▶", "pause": "⏸", "skip_next": "⏭", "skip_previous": "⏮",
        "power_settings_new": "⏻", "lock": "🔒", "settings": "⚙", "notifications": "🔔",
        "sunny": "☀", "cloud": "☁", "rainy": "☂", "weather_snowy": "❄", "thunderstorm": "⚡",
        "volume_up": "🔊", "volume_off": "🔇", "apps": "▦", "dark_mode": "☾", "light_mode": "☼"
    })

    font.family: Tema.iconeOk ? Tema.fontIcone : Tema.carattere
    font.pixelSize: dimensione
    font.variableAxes: Tema.iconeOk ? { "FILL": piena ? 1 : 0, "wght": 400, "opsz": 24 } : {}
    text: Tema.iconeOk ? nome : (riserva[nome] || "•")
    color: Tema.testo
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering

    Behavior on color { ColorAnimation { duration: Tema.veloce } }
}
EOF
cat > "$d/Interruttore.qml" << "EOF"
// Interruttore acceso/spento, con l'animazione (creato da lfs.sh, Fase 10)
import QtQuick

Item {
    id: interruttore
    property bool acceso: false
    signal cambiato(bool valore)

    implicitWidth: 46
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: interruttore.acceso ? Tema.accento : Tema.cartaSopra
        Behavior on color { ColorAnimation { duration: Tema.media } }

        Rectangle {
            id: pallino
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: interruttore.acceso ? parent.width - width - 3 : 3
            color: interruttore.acceso ? Tema.suAccento : "#ffffff"
            Behavior on x { NumberAnimation { duration: Tema.media; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on color { ColorAnimation { duration: Tema.media } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: interruttore.cambiato(!interruttore.acceso)
    }
}
EOF
cat > "$d/Meteo.qml" << "EOF"
pragma Singleton
// Il meteo (creato da lfs.sh, Fase 10): lo chiede a wttr.in ogni 30 minuti.
// Si spegne o si sceglie la citta' da Impostazioni -> Cruscotto.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: meteo

    property bool pronto: false
    property string temperatura: "--"
    property string percepita: ""
    property string descrizione: ""
    property string luogo: ""
    property string icona: "cloud"
    property string umidita: ""
    property string vento: ""
    property var giorni: []       // [{ giorno, min, max, icona }]

    function iconaPer(codice) {
        const c = Number(codice);
        if (c === 113) return "sunny";
        if (c === 116) return "partly_cloudy_day";
        if (c === 119 || c === 122) return "cloud";
        if ([143, 248, 260].indexOf(c) >= 0) return "foggy";
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return "thunderstorm";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(c) >= 0) return "weather_snowy";
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) >= 0) return "weather_mix";
        return "rainy";
    }

    function aggiorna() {
        if (!Opzioni.meteo) return;
        if (!richiesta.running) richiesta.running = true;
    }

    Process {
        id: richiesta
        command: ["curl", "-sf", "--max-time", "15",
                  "https://wttr.in/" + encodeURIComponent(Opzioni.citta) + "?format=j1&lang=it"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    const ora = d.current_condition[0];
                    meteo.temperatura = ora.temp_C;
                    meteo.percepita = ora.FeelsLikeC;
                    meteo.umidita = ora.humidity;
                    meteo.vento = ora.windspeedKmph;
                    meteo.descrizione = (ora.lang_it && ora.lang_it.length > 0)
                        ? ora.lang_it[0].value : ora.weatherDesc[0].value;
                    meteo.icona = meteo.iconaPer(ora.weatherCode);
                    const area = d.nearest_area && d.nearest_area[0];
                    meteo.luogo = area ? area.areaName[0].value : Opzioni.citta;
                    const nomi = ["dom", "lun", "mar", "mer", "gio", "ven", "sab"];
                    const g = [];
                    for (let i = 0; i < d.weather.length; i++) {
                        const w = d.weather[i];
                        const data = new Date(w.date + "T12:00:00");
                        const mezzo = w.hourly && w.hourly.length > 4 ? w.hourly[4] : null;
                        g.push({
                            giorno: i === 0 ? "oggi" : nomi[data.getDay()],
                            min: w.mintempC, max: w.maxtempC,
                            icona: mezzo ? meteo.iconaPer(mezzo.weatherCode) : "cloud"
                        });
                    }
                    meteo.giorni = g;
                    meteo.pronto = true;
                } catch (e) {
                    console.log("meteo: risposta non valida");
                }
            }
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: Opzioni.meteo
        repeat: true
        triggeredOnStart: true
        onTriggered: meteo.aggiorna()
    }

    Connections {
        target: Opzioni
        function onCittaChanged() { meteo.aggiorna(); }
        function onMeteoChanged() { meteo.aggiorna(); }
    }
}
EOF
cat > "$d/Musica.qml" << "EOF"
pragma Singleton
// I lettori musicali e video (MPRIS) (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: musica

    readonly property var lettori: Mpris.players.values
    readonly property var attivo: {
        for (let i = 0; i < lettori.length; i++)
            if (lettori[i].isPlaying) return lettori[i];
        return lettori.length > 0 ? lettori[0] : null;
    }
    readonly property bool suona: attivo !== null && attivo.isPlaying
    readonly property string titolo: attivo ? (attivo.trackTitle || attivo.identity || "") : ""
    readonly property string artista: attivo ? (attivo.trackArtist || "") : ""
    readonly property string copertina: attivo ? (attivo.trackArtUrl || "") : ""

    function alterna() { if (attivo && attivo.canTogglePlaying) attivo.togglePlaying(); }
    function avanti() { if (attivo && attivo.canGoNext) attivo.next(); }
    function indietro() { if (attivo && attivo.canGoPrevious) attivo.previous(); }
}
EOF
cat > "$d/Notifiche.qml" << "EOF"
// Le notifiche nuove, in alto a destra (creato da lfs.sh, Fase 10). Entrano da
// destra e dopo qualche secondo spariscono (restano nel centro di controllo).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: finestra

    visible: Avvisi.visibili.length > 0 && !Stato.pannello && !Stato.bloccato
    anchors { top: true; right: true }
    margins { top: 6; right: 10 }
    implicitWidth: 380
    implicitHeight: Math.max(1, lista.contentHeight)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-notifiche"
    WlrLayershell.layer: WlrLayer.Overlay

    ListView {
        id: lista
        anchors.fill: parent
        interactive: false
        spacing: 8
        model: ScriptModel { values: Avvisi.visibili }

        delegate: SchedaAvviso {
            id: scheda
            required property var modelData
            width: lista.width
            avviso: modelData
            onChiudi: Avvisi.nascondi(modelData)

            // si nasconde da sola (le urgenti restano finche' non le chiudi)
            Timer {
                running: !scheda.urgente && !areaSopra.containsMouse
                interval: scheda.avviso && scheda.avviso.expireTimeout > 0
                          ? Math.min(15000, scheda.avviso.expireTimeout * 1000) : 6000
                onTriggered: Avvisi.nascondi(scheda.modelData)
            }
            MouseArea {
                id: areaSopra
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: 420; to: 0; duration: Tema.lenta; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tema.media }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; to: 420; duration: Tema.media; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: Tema.media }
            }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Tema.media; easing.type: Easing.OutCubic }
        }
    }
}
EOF
cat > "$d/Opzioni.qml" << "EOF"
pragma Singleton
// Le scelte fatte da Impostazioni (creato da lfs.sh, Fase 10). Sono salvate in
// ~/.config/vetro/impostazioni.json; quelle che riguardano le finestre anche in
// ~/.config/hypr/vetro-impostazioni.conf (lo legge Hyprland).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: opzioni

    readonly property string casa: Quickshell.env("HOME") || "/tmp"
    readonly property string cartella: casa + "/.config/vetro"
    readonly property string fileHyprland: casa + "/.config/hypr/vetro-impostazioni.conf"

    property alias tema: dati.tema
    property alias opacita: dati.opacita
    property alias animazioni: dati.animazioni
    property alias sfocatura: dati.sfocatura
    property alias affianca: dati.affianca
    property alias spazi: dati.spazi
    property alias angoli: dati.angoli
    property alias dock: dati.dock
    property alias secondi: dati.secondi
    property alias meteo: dati.meteo
    property alias citta: dati.citta
    property alias nonDisturbare: dati.nonDisturbare
    property alias bloccoMinuti: dati.bloccoMinuti
    property alias statisticheBlocco: dati.statisticheBlocco
    property alias preferite: dati.preferite
    property alias nomeMostrato: dati.nomeMostrato
    property bool caricato: false

    FileView {
        id: file
        path: opzioni.cartella + "/impostazioni.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { opzioni.caricato = true; opzioni.applicaFinestre(); }
        onLoadFailed: {
            // prima volta: il file non c'e' ancora, lo crea con i valori normali
            opzioni.caricato = true;
            writeAdapter();
            opzioni.applicaFinestre();
        }
        onAdapterUpdated: {
            writeAdapter();
            opzioni.applicaFinestre();
        }

        JsonAdapter {
            id: dati
            property string tema: "ombra"
            property real opacita: 0.58
            property bool animazioni: true
            property bool sfocatura: true
            property bool affianca: false
            property int spazi: 12
            property int angoli: 14
            property bool dock: true
            property bool secondi: false
            property bool meteo: true
            property string citta: ""
            property bool nonDisturbare: false
            property int bloccoMinuti: 10
            property bool statisticheBlocco: true
            property string nomeMostrato: ""
            property list<string> preferite: [
                "tor-browser", "firefox", "thunar", "thunderbird",
                "libreoffice-writer", "org.xfce.mousepad", "foot"
            ]
        }
    }

    // --- lo schermo: risoluzione e grandezza (le sceglie anche Impostazioni -> Schermo,
    // e il programma "schermo" del desktop classico: stesso file ~/.config/schermo.conf)
    property string risoluzione: ""
    property string scala: "1"
    property bool schermoLetto: false
    function leggiSchermo(t) {
        schermoLetto = true;
        const r = /^RISOLUZIONE=(\d+x\d+)/m.exec(t);
        const s = /^SCALA=([0-9.]+)/m.exec(t);
        risoluzione = r ? r[1] : "";
        scala = s ? s[1] : "1";
        applicaFinestre();
    }
    FileView {
        path: opzioni.casa + "/.config/schermo.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: opzioni.leggiSchermo(text())
        onLoadFailed: opzioni.leggiSchermo("")
    }

    // il file di adesso, per non far ricaricare Hyprland se non cambia niente
    FileView {
        id: confAttuale
        path: opzioni.fileHyprland
        blockLoading: true
        printErrors: false
    }

    // --- finestre: la parte che legge Hyprland -----------------------------------
    function testoHyprland() {
        let t = "# Creato da Impostazioni (desktop Vetro): non modificarlo a mano,\n";
        t += "# le tue aggiunte vanno in ~/.config/hypr/personale.conf\n";
        if (risoluzione !== "")
            t += "monitor = , " + risoluzione + ", auto, " + scala + "\n";
        t += "animations {\n    enabled = " + (animazioni ? "true" : "false") + "\n}\n";
        t += "decoration {\n    rounding = " + angoli + "\n";
        t += "    blur {\n        enabled = " + (sfocatura ? "true" : "false") + "\n    }\n}\n";
        t += "general {\n    gaps_in = " + Math.round(spazi / 2) + "\n    gaps_out = " + spazi + "\n}\n";
        if (!affianca)
            t += "windowrule {\n    name = vetro-finestre-libere\n    match:class = .*\n    float = yes\n}\n";
        return t;
    }

    property string ultimoHyprland: ""
    function applicaFinestre() {
        if (!caricato || !schermoLetto)
            return;
        const t = testoHyprland();
        if (t === ultimoHyprland)
            return;
        ultimoHyprland = t;
        if (t === confAttuale.text())
            return;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && hyprctl reload >/dev/null",
            "vetro", fileHyprland, t]);
    }

    function nomeUtente() {
        if (nomeMostrato !== "")
            return nomeMostrato;
        const u = Quickshell.env("USER") || "";
        return u.length > 0 ? u.charAt(0).toUpperCase() + u.slice(1) : "";
    }
}
EOF
cat > "$d/Osd.qml" << "EOF"
// Il volume a schermo quando lo cambi (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: osd

    property bool mostra: false
    property bool pronto: false

    visible: mostra || corpo.opacity > 0.01
    anchors { bottom: true }
    margins { bottom: 110 }
    implicitWidth: 300
    implicitHeight: 56
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    Timer { interval: 3000; running: true; onTriggered: osd.pronto = true }
    Timer { id: nascondi; interval: 1600; onTriggered: osd.mostra = false }

    Connections {
        target: Audio
        function onCambiato() {
            if (!osd.pronto || Stato.pannello) return;
            osd.mostra = true;
            nascondi.restart();
        }
    }

    Rectangle {
        id: corpo
        anchors.fill: parent
        radius: height / 2
        color: Tema.fondoPieno
        border.width: 1
        border.color: Tema.bordo
        opacity: osd.mostra ? 1 : 0
        scale: osd.mostra ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Tema.media } }
        Behavior on scale { NumberAnimation { duration: Tema.media; easing.type: Easing.OutBack } }

        Row {
            anchors.centerIn: parent
            spacing: 14
            Icona { nome: Audio.icona; dimensione: 24; piena: true; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                width: 180
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Tema.cartaSopra
                Rectangle {
                    height: parent.height
                    radius: 4
                    width: parent.width * (Audio.muto ? 0 : Math.min(1, Audio.volume))
                    color: Tema.accento
                    Behavior on width { NumberAnimation { duration: Tema.veloce } }
                }
            }
            Text {
                width: 34
                text: Math.round((Audio.muto ? 0 : Audio.volume) * 100)
                font.family: Tema.carattere
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Tema.testo
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
EOF
cat > "$d/Pannello.qml" << "EOF"
// Il centro di controllo, a destra (creato da lfs.sh, Fase 10): saluto e ora,
// "resta sveglio", ricerca delle app, musica, schermate, comandi rapidi, volume,
// notifiche e spegnimento. Si apre con l'icona in alto a destra o Windows+A.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: pannello

    visible: Stato.pannello || sfondo.opacity > 0.01
    anchors { top: true; bottom: true; right: true }
    margins { top: 6; bottom: 10; right: 10 }
    implicitWidth: 412
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "vetro-pannello"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: Stato.pannello ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [ pannello ]
        active: Stato.pannello
        onCleared: Stato.pannello = false
    }

    SystemClock { id: orologio; precision: SystemClock.Minutes }

    // dopo la chiusura del pannello: la schermata (cosi' il pannello non c'e' nella foto)
    property var schermataDopo: []
    Timer {
        id: attesaSchermata
        interval: 450
        onTriggered: Quickshell.execDetached(pannello.schermataDopo)
    }
    function schermata(area) {
        schermataDopo = area ? ["/usr/local/bin/schermata", "area"] : ["/usr/local/bin/schermata"];
        Stato.pannello = false;
        attesaSchermata.restart();
    }

    Rectangle {
        id: sfondo
        anchors.fill: parent
        radius: Tema.raggio
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        opacity: Stato.pannello ? 1 : 0
        transform: Translate {
            x: Stato.pannello ? 0 : 48
            Behavior on x { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        focus: Stato.pannello
        Keys.onEscapePressed: Stato.pannello = false
        onVisibleChanged: if (visible) cerca.text = ""

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // --- saluto e ora -------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 78
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 16
                    spacing: 12
                    Avatar { Layout.preferredWidth: 46; Layout.preferredHeight: 46 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Saluto.frase(orologio.date) + (Opzioni.nomeUtente() !== "" ? ", " + Opzioni.nomeUtente() : "")
                            font.family: Tema.carattere
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: Tema.testo
                        }
                        Text {
                            text: orologio.date.toLocaleString(Qt.locale("it_IT"), "dddd d MMMM")
                            font.family: Tema.carattere
                            font.pixelSize: 12
                            color: Tema.testo2
                        }
                    }
                    Text {
                        text: orologio.date.toLocaleString(Qt.locale("it_IT"), "HH:mm")
                        font.family: Tema.carattere
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        color: Tema.testo
                    }
                }
            }

            // --- resta sveglio -------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    Icona { nome: "coffee"; dimensione: 22; piena: Stato.restaSveglio }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Resta sveglio"
                            font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                            color: Tema.testo
                        }
                        Text {
                            text: Stato.restaSveglio ? "Lo schermo non si spegne e non si blocca" : "Risparmio energetico normale"
                            font.family: Tema.carattere; font.pixelSize: 11
                            color: Tema.testo2
                        }
                    }
                    Interruttore {
                        acceso: Stato.restaSveglio
                        onCambiato: v => Stato.restaSveglio = v
                    }
                }
            }

            // --- cerca le app ---------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 44 + griglia.height + 22
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 18
                        color: Tema.cartaForte
                        border.width: cerca.activeFocus ? 1 : 0
                        border.color: Tema.accento
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8
                            Icona { nome: "search"; dimensione: 18; color: Tema.testo2 }
                            TextInput {
                                id: cerca
                                Layout.fillWidth: true
                                font.family: Tema.carattere
                                font.pixelSize: 13
                                color: Tema.testo
                                selectionColor: Tema.accento
                                selectedTextColor: Tema.suAccento
                                clip: true
                                Text {
                                    anchors.fill: parent
                                    visible: cerca.text === ""
                                    text: "Cerca un'app"
                                    font: cerca.font
                                    color: Tema.testo3
                                }
                                Keys.onReturnPressed: {
                                    if (griglia.app.length > 0) {
                                        griglia.app[0].execute();
                                        Stato.pannello = false;
                                    }
                                }
                                Keys.onEscapePressed: Stato.pannello = false
                            }
                        }
                    }
                    Grid {
                        id: griglia
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6
                        readonly property var app: Applicazioni.cerca(cerca.text, 8)
                        Repeater {
                            model: griglia.app
                            delegate: Rectangle {
                                required property var modelData
                                width: (griglia.width - 18) / 4
                                height: 70
                                radius: Tema.raggioPiccolo
                                color: areaApp.containsMouse ? Tema.cartaForte : "transparent"
                                Behavior on color { ColorAnimation { duration: Tema.veloce } }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    IconImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        implicitSize: 34
                                        asynchronous: true
                                        source: Applicazioni.icona(modelData.icon)
                                    }
                                    Text {
                                        width: 82
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: modelData.name
                                        font.family: Tema.carattere
                                        font.pixelSize: 11
                                        color: Tema.testo
                                    }
                                }
                                MouseArea {
                                    id: areaApp
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { parent.modelData.execute(); Stato.pannello = false; }
                                }
                            }
                        }
                    }
                }
            }

            // --- musica ---------------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 12
                    ClippingRectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: 12
                        color: Tema.cartaForte
                        Icona {
                            anchors.centerIn: parent
                            visible: copertina.status !== Image.Ready
                            nome: "music_note"
                            dimensione: 22
                            color: Tema.testo2
                        }
                        Image {
                            id: copertina
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: Musica.copertina
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Musica.attivo ? (Musica.titolo || "Senza titolo") : "Niente in riproduzione"
                            font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                            color: Tema.testo
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Musica.attivo ? (Musica.artista || Musica.attivo.identity || "") : "Fai partire un brano o un video"
                            font.family: Tema.carattere; font.pixelSize: 11
                            color: Tema.testo2
                        }
                    }
                    Row {
                        spacing: 2
                        PulsanteIcona { implicitWidth: 32; implicitHeight: 32; icona: "skip_previous"; color: "transparent"; onCliccato: Musica.indietro() }
                        PulsanteIcona { implicitWidth: 36; implicitHeight: 36; icona: Musica.suona ? "pause" : "play_arrow"; attivo: true; onCliccato: Musica.alterna() }
                        PulsanteIcona { implicitWidth: 32; implicitHeight: 32; icona: "skip_next"; color: "transparent"; onCliccato: Musica.avanti() }
                    }
                }
            }

            // --- schermata -------------------------------------------------------------
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10
                    Icona { nome: "screenshot_monitor"; dimensione: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: "Schermata"; font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold; color: Tema.testo }
                        Text { text: "Salvata in Immagini"; font.family: Tema.carattere; font.pixelSize: 11; color: Tema.testo2 }
                    }
                    Bottoncino { testo: "Schermo"; icona: "fullscreen"; onCliccato: pannello.schermata(false) }
                    Bottoncino { testo: "Area"; icona: "crop"; onCliccato: pannello.schermata(true) }
                }
            }

            // --- comandi rapidi -------------------------------------------------------
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Tessera {
                    Layout.fillWidth: true
                    icona: Opzioni.nonDisturbare ? "do_not_disturb_on" : "do_not_disturb_off"
                    titolo: "Non disturbare"
                    sottotitolo: Opzioni.nonDisturbare ? "Acceso" : "Spento"
                    attiva: Opzioni.nonDisturbare
                    onCliccata: Opzioni.nonDisturbare = !Opzioni.nonDisturbare
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: "visibility_off"
                    titolo: "Modalità fantasma"
                    sottotitolo: Sistema.fantasma ? "Tutto passa da Tor" : "Spenta"
                    attiva: Sistema.fantasma
                    onCliccata: { Stato.pannello = false; Quickshell.execDetached(["/usr/local/bin/fantasma"]); }
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: Tema.chiaro ? "light_mode" : "dark_mode"
                    titolo: Tema.chiaro ? "Tema chiaro" : "Tema scuro"
                    sottotitolo: Tema.attuale.nome
                    attiva: Tema.chiaro
                    onCliccata: Opzioni.tema = Tema.chiaro ? "ombra" : "carta"
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: "animation"
                    titolo: "Animazioni"
                    sottotitolo: Opzioni.animazioni ? "Fluide" : "Spente"
                    attiva: Opzioni.animazioni
                    onCliccata: Opzioni.animazioni = !Opzioni.animazioni
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: "blur_on"
                    titolo: "Sfocatura"
                    sottotitolo: Opzioni.sfocatura ? "Effetto vetro" : "Spenta"
                    attiva: Opzioni.sfocatura
                    onCliccata: Opzioni.sfocatura = !Opzioni.sfocatura
                }
                Tessera {
                    Layout.fillWidth: true
                    icona: "settings"
                    titolo: "Impostazioni"
                    sottotitolo: "Tutte le scelte"
                    onCliccata: Stato.apriImpostazioni("generale")
                }
            }

            // --- volume ---------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Cursore {
                    Layout.fillWidth: true
                    valore: Audio.muto ? 0 : Audio.volume
                    icona: Audio.icona
                    onSpostato: v => Audio.imposta(v)
                }
                Text {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((Audio.muto ? 0 : Audio.volume) * 100) + "%"
                    font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.DemiBold
                    color: Tema.testo2
                }
            }

            // --- notifiche --------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Avvisi.quante > 0 ? "Notifiche (" + Avvisi.quante + ")" : "Nessuna notifica"
                    font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                    color: Tema.testo2
                }
                Bottoncino {
                    visible: Avvisi.quante > 0
                    testo: "Cancella"
                    icona: "clear_all"
                    onCliccato: Avvisi.cancellaTutte()
                }
            }
            ListView {
                id: listaAvvisi
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: ScriptModel { values: Avvisi.tutte.slice().reverse() }
                delegate: SchedaAvviso {
                    required property var modelData
                    width: listaAvvisi.width
                    avviso: modelData
                    compatta: true
                }
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tema.media } }
                displaced: Transition { NumberAnimation { property: "y"; duration: Tema.media; easing.type: Easing.OutCubic } }
            }

            // --- spegnimento -----------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Spegnimento { icona: "lock"; testo: "Blocca"; conferma: false; onFatto: Stato.blocca() }
                Spegnimento { icona: "logout"; testo: "Esci"; onFatto: Quickshell.execDetached(["hyprctl", "dispatch", "exit"]) }
                Spegnimento { icona: "restart_alt"; testo: "Riavvia"; onFatto: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "reboot"]) }
                Spegnimento { icona: "power_settings_new"; testo: "Spegni"; onFatto: Quickshell.execDetached(["sudo", "-n", "/usr/bin/systemctl", "poweroff"]) }
            }
        }
    }

    // pulsante piccolo con testo
    component Bottoncino: Rectangle {
        id: b
        property string testo: ""
        property string icona: ""
        signal cliccato()
        implicitHeight: 30
        implicitWidth: rigaB.implicitWidth + 20
        radius: 15
        color: areaBot.containsMouse ? Tema.cartaSopra : Tema.cartaForte
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
        Row {
            id: rigaB
            anchors.centerIn: parent
            spacing: 5
            Icona { visible: b.icona !== ""; nome: b.icona; dimensione: 15; anchors.verticalCenter: parent.verticalCenter }
            Text { text: b.testo; font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.Medium; color: Tema.testo; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: areaBot; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.cliccato() }
    }

    // pulsante di spegnimento: il primo clic chiede conferma, il secondo esegue
    component Spegnimento: Rectangle {
        id: s
        property string icona: ""
        property string testo: ""
        property bool conferma: true
        property bool chiede: false
        signal fatto()
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Tema.raggioMedio
        color: chiede ? Tema.rosso : (areaS.containsMouse ? Tema.cartaForte : Tema.carta)
        border.width: 1
        border.color: Tema.bordo
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: s.icona; dimensione: 20; color: s.chiede ? "#ffffff" : Tema.testo }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: s.chiede ? "Sicuro?" : s.testo
                font.family: Tema.carattere; font.pixelSize: 11; font.weight: Font.Medium
                color: s.chiede ? "#ffffff" : Tema.testo2
            }
        }
        Timer { id: annulla; interval: 3000; onTriggered: s.chiede = false }
        MouseArea {
            id: areaS
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!s.conferma || s.chiede) { s.chiede = false; s.fatto(); }
                else { s.chiede = true; annulla.restart(); }
            }
        }
    }
}
EOF
cat > "$d/PulsanteIcona.qml" << "EOF"
// Pulsante tondo con un'icona (creato da lfs.sh, Fase 10)
import QtQuick

Rectangle {
    id: pulsante
    property string icona: "circle"
    property real dimensioneIcona: 20
    property bool attivo: false
    property string suggerimento: ""
    property color coloreIcona: attivo ? Tema.suAccento : Tema.testo
    signal cliccato()

    implicitWidth: 40
    implicitHeight: 40
    radius: height / 2
    color: attivo ? Tema.accento : (area.containsMouse ? Tema.cartaSopra : Tema.cartaForte)
    scale: area.pressed ? 0.92 : 1

    Behavior on color { ColorAnimation { duration: Tema.veloce } }
    Behavior on scale { NumberAnimation { duration: Tema.veloce; easing.type: Easing.OutCubic } }

    Icona {
        anchors.centerIn: parent
        nome: pulsante.icona
        dimensione: pulsante.dimensioneIcona
        color: pulsante.coloreIcona
        piena: pulsante.attivo
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pulsante.cliccato()
    }
}
EOF
cat > "$d/Saluto.qml" << "EOF"
pragma Singleton
// Il saluto secondo l'ora (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell

Singleton {
    function frase(data) {
        const h = data.getHours();
        if (h >= 5 && h < 13) return "Buongiorno";
        if (h >= 13 && h < 18) return "Buon pomeriggio";
        if (h >= 18 && h < 23) return "Buonasera";
        return "Buonanotte";
    }
}
EOF
cat > "$d/SchedaAvviso.qml" << "EOF"
// Una notifica: icona, programma, titolo, testo e pulsanti (creato da lfs.sh)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: scheda
    property var avviso: null
    property bool compatta: false
    signal chiudi()

    readonly property bool urgente: avviso !== null && avviso.urgency === NotificationUrgency.Critical
    readonly property string iconaApp: {
        if (!avviso) return "";
        if (avviso.appIcon && avviso.appIcon !== "")
            return avviso.appIcon.startsWith("/") ? "file://" + avviso.appIcon
                 : Quickshell.iconPath(avviso.appIcon, "dialog-information");
        return Quickshell.iconPath("dialog-information");
    }

    implicitHeight: Math.max(colonna.implicitHeight, 38) + 24
    radius: Tema.raggioMedio
    color: compatta ? Tema.carta : Tema.fondoPieno
    border.width: 1
    border.color: urgente ? Tema.rosso : Tema.bordo

    RowLayout {
        id: riga
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 10
            color: Tema.cartaForte
            IconImage {
                anchors.centerIn: parent
                visible: !(scheda.avviso && scheda.avviso.image)
                implicitSize: 26
                asynchronous: true
                source: scheda.iconaApp
            }
            Image {
                anchors.fill: parent
                visible: !!(scheda.avviso && scheda.avviso.image)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: scheda.avviso && scheda.avviso.image ? scheda.avviso.image : ""
            }
        }

        ColumnLayout {
            id: colonna
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: scheda.avviso ? (scheda.avviso.appName || "Avviso") : ""
                    font.family: Tema.carattere
                    font.pixelSize: 11
                    color: Tema.testo3
                }
                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 11
                    color: areaX.containsMouse ? Tema.cartaSopra : "transparent"
                    Icona { anchors.centerIn: parent; nome: "close"; dimensione: 15; color: Tema.testo2 }
                    MouseArea {
                        id: areaX
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (scheda.avviso) scheda.avviso.dismiss(); scheda.chiudi(); }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: scheda.avviso ? scheda.avviso.summary : ""
                font.family: Tema.carattere
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Tema.testo
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                wrapMode: Text.Wrap
                maximumLineCount: scheda.compatta ? 2 : 5
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: scheda.avviso ? scheda.avviso.body : ""
                font.family: Tema.carattere
                font.pixelSize: 12
                color: Tema.testo2
                linkColor: Tema.accento
                onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: scheda.avviso !== null && scheda.avviso.actions.length > 0
                spacing: 6
                Repeater {
                    model: scheda.avviso ? scheda.avviso.actions : []
                    delegate: Rectangle {
                        required property var modelData
                        height: 28
                        width: testoAzione.implicitWidth + 24
                        radius: 14
                        color: areaAzione.containsMouse ? Tema.cartaSopra : Tema.cartaForte
                        Text {
                            id: testoAzione
                            anchors.centerIn: parent
                            text: modelData.text
                            font.family: Tema.carattere
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Tema.testo
                        }
                        MouseArea {
                            id: areaAzione
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
EOF
cat > "$d/Sfondi.qml" << "EOF"
pragma Singleton
// Lo sfondo del desktop (creato da lfs.sh, Fase 10). La scelta resta in
// ~/.config/sfondo.conf, come per il desktop classico: e' sfondo-desktop a dire
// quale immagine usare (in modalita' fantasma quella scura).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sfondi

    property string attuale: "/usr/share/backgrounds/sfondo-desktop.png"
    property var elenco: []
    readonly property string fileScelta: (Quickshell.env("HOME") || "/tmp") + "/.config/sfondo.conf"

    function aggiorna() {
        if (!percorso.running) percorso.running = true;
        if (!lista.running) lista.running = true;
    }

    function scegli(file) {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf 'SFONDO=%s\\n' \"$2\" > \"$1\"",
            "vetro", fileScelta, file]);
        attuale = file;
        ritardo.restart();
    }

    Process {
        id: percorso
        command: ["/usr/local/bin/sfondo-desktop", "--percorso"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p !== "") sfondi.attuale = p;
            }
        }
    }

    Process {
        id: lista
        command: ["sh", "-c",
            "for f in /usr/share/backgrounds/*.png /usr/share/backgrounds/*.jpg " +
            "\"$HOME\"/.local/share/sfondi/*.png \"$HOME\"/.local/share/sfondi/*.jpg; do " +
            "[ -f \"$f\" ] || continue; case \"$f\" in */sfondo-fantasma.png|*/sfondo-desktop.png) continue ;; esac; " +
            "echo \"$f\"; done"]
        stdout: StdioCollector {
            onStreamFinished: sfondi.elenco = this.text.split("\n").filter(r => r.trim() !== "")
        }
    }

    // la scelta puo' cambiare anche da fuori (Impostazioni classiche, modalita' fantasma)
    FileView {
        path: sfondi.fileScelta
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); ritardo.restart(); }
    }

    Timer {
        id: ritardo
        interval: 300
        onTriggered: sfondi.aggiorna()
    }

    Component.onCompleted: aggiorna()
}
EOF
cat > "$d/Sfondo.qml" << "EOF"
// Lo sfondo del desktop su uno schermo, con la dissolvenza quando cambia (lfs.sh)
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: finestra
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "vetro-sfondo"
    color: "#101012"

    property bool primoSopra: true
    property string mostrato: ""

    function cambia(file) {
        const sorgente = "file://" + file;
        if (sorgente === mostrato) return;
        mostrato = sorgente;
        if (primoSopra) secondo.source = sorgente;
        else primo.source = sorgente;
    }

    Component.onCompleted: cambia(Sfondi.attuale)
    Connections {
        target: Sfondi
        function onAttualeChanged() { finestra.cambia(Sfondi.attuale); }
    }

    Image {
        id: primo
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: finestra.width
        sourceSize.height: finestra.height
        opacity: finestra.primoSopra ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.lenta * 2; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && source.toString() === finestra.mostrato) finestra.primoSopra = true
    }
    Image {
        id: secondo
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: finestra.width
        sourceSize.height: finestra.height
        opacity: finestra.primoSopra ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tema.lenta * 2; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && source.toString() === finestra.mostrato) finestra.primoSopra = false
    }
}
EOF
cat > "$d/Sistema.qml" << "EOF"
pragma Singleton
// Processore, memoria, disco, rete, da quanto e' acceso (creato da lfs.sh, Fase 10).
// Legge /proc ogni 2 secondi con un solo comando.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sis

    property real cpu: 0                 // 0..1
    property real memoria: 0             // 0..1
    property real memoriaUsata: 0        // GB
    property real memoriaTotale: 0       // GB
    property real disco: 0               // 0..1
    property real discoUsato: 0          // GB
    property real discoTotale: 0         // GB
    property real scarica: 0             // byte al secondo
    property real carica: 0
    property real totaleScaricato: 0     // byte da quando e' acceso
    property real totaleCaricato: 0
    property real temperatura: -1        // gradi, -1 = non si sa
    property real gpu: -1                // 0..1, -1 = non si sa
    property real acceso: 0              // secondi
    property var storiaCpu: []
    property var storiaScarica: []
    property var storiaCarica: []
    property bool fantasma: false
    property string nomeComputer: ""
    property string kernel: ""
    property string processore: ""
    readonly property string utente: Quickshell.env("USER") || "utente"

    property var _cpuPrima: null
    property var _retePrima: null
    property real _tempoPrima: 0
    readonly property int punti: 40

    function aggiungi(lista, v) {
        const l = lista.slice();
        l.push(v);
        while (l.length < punti) l.unshift(0);
        while (l.length > punti) l.shift();
        return l;
    }

    function testoAcceso() {
        const s = Math.floor(acceso);
        const g = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
        if (g > 0) return g + "g " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + " min";
    }

    function velocita(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
        if (b >= 1024) return Math.round(b / 1024) + " KB/s";
        return Math.round(b) + " B/s";
    }

    function grandezza(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576) return Math.round(b / 1048576) + " MB";
        return Math.round(b / 1024) + " KB";
    }

    function analizza(testo) {
        let parte = "";
        let rxTot = 0, txTot = 0;
        const righe = testo.split("\n");
        for (let i = 0; i < righe.length; i++) {
            const r = righe[i].trim();
            if (r.startsWith("#")) { parte = r; continue; }
            if (r === "") continue;
            const c = r.split(/\s+/);
            if (parte === "#STAT" && c[0] === "cpu") {
                const n = c.slice(1).map(Number);
                const inattivo = n[3] + (n[4] || 0);
                const totale = n.reduce((a, b) => a + b, 0);
                if (_cpuPrima !== null) {
                    const dt = totale - _cpuPrima.totale;
                    const di = inattivo - _cpuPrima.inattivo;
                    if (dt > 0) cpu = Math.max(0, Math.min(1, 1 - di / dt));
                }
                _cpuPrima = { totale: totale, inattivo: inattivo };
            } else if (parte === "#MEM") {
                if (c[0] === "MemTotal:") memoriaTotale = Number(c[1]) / 1048576;
                if (c[0] === "MemAvailable:" && memoriaTotale > 0) {
                    memoriaUsata = memoriaTotale - Number(c[1]) / 1048576;
                    memoria = memoriaUsata / memoriaTotale;
                }
            } else if (parte === "#NET") {
                const nome = c[0].replace(":", "");
                if (nome === "lo" || c.length < 10) continue;
                rxTot += Number(c[1]);
                txTot += Number(c[9]);
            } else if (parte === "#UP") {
                acceso = Number(c[0]);
            } else if (parte === "#DISK" && c.length >= 4) {
                discoTotale = Number(c[1]) / 1048576;
                discoUsato = Number(c[2]) / 1048576;
                disco = discoTotale > 0 ? discoUsato / discoTotale : 0;
            } else if (parte === "#TEMP") {
                temperatura = Number(c[0]) / 1000;
            } else if (parte === "#GPU") {
                gpu = Number(c[0]) / 100;
            } else if (parte === "#FANTASMA") {
                fantasma = c[0] === "si";
            }
        }
        const ora = Date.now() / 1000;
        if (_retePrima !== null && ora > _tempoPrima) {
            const dt = ora - _tempoPrima;
            scarica = Math.max(0, (rxTot - _retePrima.rx) / dt);
            carica = Math.max(0, (txTot - _retePrima.tx) / dt);
        }
        _retePrima = { rx: rxTot, tx: txTot };
        _tempoPrima = ora;
        totaleScaricato = rxTot;
        totaleCaricato = txTot;
        storiaCpu = aggiungi(storiaCpu, cpu);
        storiaScarica = aggiungi(storiaScarica, scarica);
        storiaCarica = aggiungi(storiaCarica, carica);
    }

    Process {
        id: lettore
        command: ["sh", "-c",
            "echo '#STAT'; head -n1 /proc/stat; " +
            "echo '#MEM'; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; " +
            "echo '#NET'; tail -n +3 /proc/net/dev; " +
            "echo '#UP'; cat /proc/uptime; " +
            "echo '#DISK'; df -Pk / | tail -n 1; " +
            "echo '#TEMP'; cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null; " +
            "echo '#GPU'; cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n 1; " +
            "echo '#FANTASMA'; [ -e /etc/fantasma/attivo ] && echo si || echo no"]
        stdout: StdioCollector {
            onStreamFinished: sis.analizza(this.text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!lettore.running) lettore.running = true
    }

    Process {
        id: info
        running: true
        command: ["sh", "-c",
            "cat /etc/hostname 2>/dev/null || uname -n; uname -r; " +
            "sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = this.text.split("\n");
                sis.nomeComputer = (r[0] || "").trim();
                sis.kernel = (r[1] || "").trim();
                sis.processore = (r[2] || "").trim();
            }
        }
    }
}
EOF
cat > "$d/Stato.qml" << "EOF"
pragma Singleton
// Quali pannelli sono aperti (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell

Singleton {
    id: stato

    property bool pannello: false        // centro di controllo (a destra)
    property bool cruscotto: false       // meteo, calendario, prestazioni
    property int schedaCruscotto: 0
    property bool avvio: false           // cerca le app
    property bool impostazioni: false    // finestra delle Impostazioni
    property string pagina: "generale"
    property bool bloccato: false        // blocco schermo
    property bool restaSveglio: false    // lo schermo non si spegne e non si blocca

    function chiudiTutto() {
        pannello = false;
        cruscotto = false;
        avvio = false;
    }

    function alterna(nome) {
        let era = false;
        if (nome === "pannello") era = pannello;
        else if (nome === "cruscotto") era = cruscotto;
        else if (nome === "avvio") era = avvio;
        chiudiTutto();
        if (era) return;
        if (nome === "pannello") pannello = true;
        else if (nome === "cruscotto") cruscotto = true;
        else if (nome === "avvio") avvio = true;
    }

    function apriCruscotto(scheda) {
        chiudiTutto();
        schedaCruscotto = scheda;
        cruscotto = true;
    }

    function apriImpostazioni(p) {
        chiudiTutto();
        if (p) pagina = p;
        impostazioni = true;
    }

    function blocca() {
        chiudiTutto();
        bloccato = true;
    }
}
EOF
cat > "$d/Tema.qml" << "EOF"
pragma Singleton
// Colori, caratteri e misure del desktop "Vetro" (creato da lfs.sh, Fase 10).
// Il tema si sceglie da Impostazioni -> Aspetto.
import QtQuick
import Quickshell

Singleton {
    id: tema

    readonly property string nome: Opzioni.tema
    readonly property bool chiaro: nome === "carta"
    readonly property real opacita: Math.max(0.25, Math.min(0.95, Opzioni.opacita))

    readonly property var temi: [
        { id: "ombra",      nome: "Ombra",      fondo: "#17171a", accento: "#ececf0" },
        { id: "grafite",    nome: "Grafite",    fondo: "#1d2024", accento: "#a9b4c2" },
        { id: "mezzanotte", nome: "Mezzanotte", fondo: "#14162a", accento: "#8c96ff" },
        { id: "rosa",       nome: "Rosa",       fondo: "#21171c", accento: "#ff9ab6" },
        { id: "carta",      nome: "Carta",      fondo: "#f4f4f6", accento: "#2f6df6" }
    ]
    readonly property var attuale: {
        for (let i = 0; i < temi.length; i++)
            if (temi[i].id === nome) return temi[i];
        return temi[0];
    }

    // fondi "a vetro": semitrasparenti, Hyprland sfoca quello che c'e' dietro
    readonly property color base: attuale.fondo
    readonly property color fondo: Qt.rgba(base.r, base.g, base.b, opacita)
    readonly property color fondoPieno: Qt.rgba(base.r, base.g, base.b, Math.min(1, opacita + 0.25))
    readonly property color carta: chiaro ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
    readonly property color cartaForte: chiaro ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.11)
    readonly property color cartaSopra: chiaro ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.17)
    readonly property color bordo: chiaro ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.09)
    readonly property color bordoForte: chiaro ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.18)

    readonly property color accento: attuale.accento
    readonly property color suAccento: (nome === "ombra" || nome === "grafite") ? "#121214" : "#ffffff"
    readonly property color testo: chiaro ? "#1d1d1f" : "#f2f2f5"
    readonly property color testo2: chiaro ? "#55555c" : "#a6a6ae"
    readonly property color testo3: chiaro ? "#86868e" : "#6c6c75"
    readonly property color rosso: "#ff5f57"
    readonly property color giallo: "#febc2e"
    readonly property color verde: "#30d158"

    readonly property int raggio: 24
    readonly property int raggioMedio: 18
    readonly property int raggioPiccolo: 12
    readonly property int spazio: 12

    readonly property string carattere: "Adwaita Sans"
    readonly property string mono: "Adwaita Mono"
    readonly property string fontIcone: "Material Symbols Rounded"
    readonly property bool iconeOk: Qt.fontFamilies().indexOf(fontIcone) >= 0

    // durata delle animazioni (0 se spente da Impostazioni)
    readonly property int veloce: Opzioni.animazioni ? 160 : 0
    readonly property int media: Opzioni.animazioni ? 280 : 0
    readonly property int lenta: Opzioni.animazioni ? 460 : 0
}
EOF
cat > "$d/Tessera.qml" << "EOF"
// "Tessera" dei comandi rapidi: icona, nome e stato, accesa o spenta (creato da lfs.sh)
import QtQuick

Rectangle {
    id: tessera
    property string icona: "circle"
    property string titolo: ""
    property string sottotitolo: ""
    property bool attiva: false
    signal cliccata()

    implicitHeight: 62
    radius: Tema.raggioMedio
    color: attiva ? Tema.accento : (area.containsMouse ? Tema.cartaForte : Tema.carta)
    border.width: 1
    border.color: attiva ? "transparent" : Tema.bordo
    scale: area.pressed ? 0.96 : 1

    Behavior on color { ColorAnimation { duration: Tema.media } }
    Behavior on scale { NumberAnimation { duration: Tema.veloce; easing.type: Easing.OutCubic } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 10

        Rectangle {
            width: 36
            height: 36
            radius: 18
            anchors.verticalCenter: parent.verticalCenter
            color: tessera.attiva ? Qt.rgba(0, 0, 0, 0.12) : Tema.cartaForte
            Icona {
                anchors.centerIn: parent
                nome: tessera.icona
                dimensione: 20
                piena: tessera.attiva
                color: tessera.attiva ? Tema.suAccento : Tema.testo
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 46 - 10
            spacing: 1
            Text {
                width: parent.width
                text: tessera.titolo
                elide: Text.ElideRight
                font.family: Tema.carattere
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: tessera.attiva ? Tema.suAccento : Tema.testo
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: tessera.sottotitolo
                elide: Text.ElideRight
                font.family: Tema.carattere
                font.pixelSize: 11
                color: tessera.attiva ? Qt.rgba(Tema.suAccento.r, Tema.suAccento.g, Tema.suAccento.b, 0.7) : Tema.testo2
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tessera.cliccata()
    }
}
EOF
cat > "$d/shell.qml" << "EOF"
//@ pragma AppId org.quickshell.vetro
//@ pragma IconTheme AdwaitaLegacy
// Desktop "Vetro" (creato da lfs.sh, Fase 10): il punto di partenza di Quickshell.
// Ogni pezzo e' in un file a parte, qui accanto. Comandi da terminale:
//   qs -p /etc/xdg/quickshell/vetro ipc call pannelli apri pannello|cruscotto|avvio|impostazioni
//   qs -p /etc/xdg/quickshell/vetro ipc call blocco blocca
//   qs -p /etc/xdg/quickshell/vetro ipc call sfondo aggiorna
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: radice

    // su ogni schermo: sfondo, barra in alto, dock in basso
    Variants {
        model: Quickshell.screens
        delegate: Component { Sfondo {} }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component { Barra {} }
    }
    Variants {
        model: Opzioni.dock ? Quickshell.screens : []
        delegate: Component { Dock {} }
    }

    Pannello {}
    Cruscotto {}
    Avvio {}
    Notifiche {}
    Osd {}
    Blocco {}

    LazyLoader {
        active: Stato.impostazioni
        FinestraImpostazioni {}
    }

    // --- i tasti (li manda Hyprland: vedi "global" in hyprland.conf) -------------------
    GlobalShortcut { name: "avvio"; description: "Cerca le app"; onPressed: Stato.alterna("avvio") }
    GlobalShortcut { name: "pannello"; description: "Centro di controllo"; onPressed: Stato.alterna("pannello") }
    GlobalShortcut { name: "cruscotto"; description: "Cruscotto"; onPressed: Stato.alterna("cruscotto") }
    GlobalShortcut { name: "notifiche"; description: "Notifiche"; onPressed: Stato.alterna("pannello") }
    GlobalShortcut { name: "impostazioni"; description: "Impostazioni"; onPressed: Stato.apriImpostazioni("") }
    GlobalShortcut { name: "blocca"; description: "Blocca lo schermo"; onPressed: Stato.blocca() }
    GlobalShortcut { name: "riduci"; description: "Riduci la finestra"; onPressed: Finestre.riduciAttiva() }
    GlobalShortcut { name: "musica-play"; description: "Play/pausa"; onPressed: Musica.alterna() }
    GlobalShortcut { name: "musica-avanti"; description: "Brano dopo"; onPressed: Musica.avanti() }
    GlobalShortcut { name: "musica-indietro"; description: "Brano prima"; onPressed: Musica.indietro() }

    // --- comandi da fuori (blocca-schermo, sfondo-desktop, il menu delle app) ----------
    // risponde "ok" solo se tutti i pannelli si sono caricati (lo usa avvia-pannelli)
    IpcHandler {
        target: "vetro"
        function ping(): string { return "ok"; }
    }
    IpcHandler {
        target: "blocco"
        function blocca(): void { Stato.blocca(); }
    }
    IpcHandler {
        target: "sfondo"
        function aggiorna(): void { Sfondi.aggiorna(); }
    }
    IpcHandler {
        target: "pannelli"
        function apri(nome: string): void {
            if (nome === "impostazioni") Stato.apriImpostazioni("");
            else if (nome === "cruscotto") Stato.apriCruscotto(0);
            else Stato.alterna(nome);
        }
        function chiudi(): void { Stato.chiudiTutto(); }
    }

    // i servizi partono subito (notifiche, finestre ridotte, meteo)
    Component.onCompleted: {
        Avvisi.quante;
        Finestre.nascoste;
        Meteo.pronto;
    }
}
EOF
# gli sfondi nuovi (disegnati con Python, come quelli della Fase 8)
cat > /usr/local/lib/vetro/disegna-vetro << "EOF"
#!/usr/bin/python3 -I
# Disegna gli sfondi del desktop "Vetro" (creato da lfs.sh, Fase 10), solo Python:
#   disegna-vetro FILE.png [notte|alba|nebbia]
# Scuro e sfocato, con tante luci morbide (come una foto fuori fuoco): "notte" con
# riflessi rosa, "alba" caldo, "nebbia" grigio. Disegni originali, niente foto.
import math, random, struct, sys, zlib

L, A = 1920, 1080

def png(percorso, righe):
    dati = bytearray()
    for r in righe:
        dati.append(0)
        dati += r
    def blocco(tipo, d):
        return struct.pack(">I", len(d)) + tipo + d + struct.pack(">I", zlib.crc32(tipo + d) & 0xffffffff)
    with open(percorso, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(blocco(b"IHDR", struct.pack(">IIBBBBB", L, A, 8, 2, 0, 0, 0)))
        f.write(blocco(b"IDAT", zlib.compress(bytes(dati), 9)))
        f.write(blocco(b"IEND", b""))

def colore(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5))

def morbido(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)

TEMI = {
    "notte":  {"alto": "#24252b", "basso": "#0c0d10",
               "luci": ["#f6eef1", "#f2c6d2", "#e48aa4", "#ffffff", "#c9b8ff"]},
    "alba":   {"alto": "#2b2320", "basso": "#100c0b",
               "luci": ["#ffe7d1", "#ffc39a", "#ff9a7a", "#ffffff", "#f7d0b8"]},
    "nebbia": {"alto": "#2a2c30", "basso": "#121316",
               "luci": ["#f2f3f5", "#d9dde3", "#b8c0cc", "#ffffff", "#e8e8ea"]},
}

def disegna(percorso, nome):
    tema = TEMI.get(nome, TEMI["notte"])
    alto, basso = colore(tema["alto"]), colore(tema["basso"])
    luci = [colore(c) for c in tema["luci"]]
    caso = random.Random(1310)

    # fondo: sfumatura in diagonale e angoli piu' scuri
    R = [0.0] * (L * A); G = [0.0] * (L * A); B = [0.0] * (L * A)
    for y in range(A):
        fy = y / (A - 1)
        for x in range(L):
            fx = x / (L - 1)
            t = morbido(0.65 * fy + 0.35 * fx)
            dx, dy = fx - 0.42, fy - 0.45
            vignetta = 1.0 - 0.45 * morbido(math.hypot(dx * 1.1, dy * 1.4) / 0.75)
            i = y * L + x
            R[i] = (alto[0] + (basso[0] - alto[0]) * t) * vignetta
            G[i] = (alto[1] + (basso[1] - alto[1]) * t) * vignetta
            B[i] = (alto[2] + (basso[2] - alto[2]) * t) * vignetta

    def disco(cx, cy, r, col, forza, anello, bordo=0.25):
        x0, x1 = max(0, int(cx - r - 2)), min(L - 1, int(cx + r + 2))
        y0, y1 = max(0, int(cy - r - 2)), min(A - 1, int(cy + r + 2))
        for y in range(y0, y1 + 1):
            dy = y - cy
            for x in range(x0, x1 + 1):
                d = math.hypot(x - cx, dy) / r
                if d >= 1.0:
                    continue
                # bordo morbido e un anello un po' piu' chiaro (le luci fuori fuoco)
                k = forza * (1.0 - morbido((d - (1 - bordo)) / bordo)) \
                    * (1.0 + anello * morbido((d - 0.55) / 0.35))
                i = y * L + x
                R[i] += (col[0] - R[i]) * k
                G[i] += (col[1] - G[i]) * k
                B[i] += (col[2] - B[i]) * k

    def alone(cx, cy, r, col, forza):
        # luce larghissima e sfumata (niente bordo)
        x0, x1 = max(0, int(cx - r)), min(L - 1, int(cx + r))
        y0, y1 = max(0, int(cy - r)), min(A - 1, int(cy + r))
        for y in range(y0, y1 + 1):
            dy = (y - cy) / r
            for x in range(x0, x1 + 1):
                dx = (x - cx) / r
                d2 = dx * dx + dy * dy
                if d2 >= 1.0:
                    continue
                k = forza * math.exp(-4.0 * d2) * (1.0 - d2)
                i = y * L + x
                R[i] += (col[0] - R[i]) * k
                G[i] += (col[1] - G[i]) * k
                B[i] += (col[2] - B[i]) * k

    # grandi aloni (profondita')
    alone(L * 0.30, A * 0.34, 700, luci[4], 0.10)
    alone(L * 0.72, A * 0.62, 640, luci[1], 0.12)
    alone(L * 0.95, A * 0.05, 420, luci[0], 0.06)
    # luci enormi e quasi trasparenti (molto fuori fuoco)
    for n in range(5):
        disco(caso.uniform(0, L), caso.uniform(0, A), caso.uniform(200, 280),
              luci[caso.choice([0, 1])], 0.035, 0.0, 0.5)
    # tante luci lungo una diagonale (come un ramo fiorito fuori fuoco)
    for n in range(46):
        t = caso.random()
        cx = L * (0.05 + 0.9 * t) + caso.gauss(0, 120)
        cy = A * (0.15 + 0.62 * t) + caso.gauss(0, 140) - 90 * math.sin(t * 3.1)
        r = caso.choice([28, 36, 44, 58, 70, 88, 110, 140, 170])
        col = luci[caso.choice([0, 0, 1, 1, 1, 2, 3])]
        forza = caso.uniform(0.04, 0.17) * (1.15 if r < 60 else 0.8)
        disco(cx, cy, r, col, forza, caso.uniform(0.05, 0.35), caso.uniform(0.18, 0.35))
    # qualche puntino piccolo
    for n in range(26):
        t = caso.random()
        cx = L * (0.05 + 0.9 * t) + caso.gauss(0, 220)
        cy = A * (0.15 + 0.62 * t) + caso.gauss(0, 220)
        disco(cx, cy, caso.uniform(3, 7), luci[3], caso.uniform(0.06, 0.18), 0.0, 0.6)

    righe = []
    for y in range(A):
        riga = bytearray()
        for x in range(L):
            i = y * L + x
            s = (((x * 7 + y * 13) & 3) * 0.25 - 0.375) / 255.0       # niente righe nelle sfumature
            riga += bytes((min(255, max(0, int((R[i] + s) * 255 + 0.5))),
                           min(255, max(0, int((G[i] + s) * 255 + 0.5))),
                           min(255, max(0, int((B[i] + s) * 255 + 0.5)))))
        righe.append(riga)
    png(percorso, righe)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Uso: disegna-vetro FILE.png [notte|alba|nebbia]")
    disegna(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "notte")
EOF
chmod 755 /usr/local/lib/vetro/disegna-vetro
python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' /usr/local/lib/vetro/disegna-vetro
local s
for s in notte alba nebbia; do
  python3 -I /usr/local/lib/vetro/disegna-vetro "/usr/share/backgrounds/vetro-$s.png" "$s"
done
[ "$(ls "$d"/*.qml | wc -l)" -ge 30 ] || { echo "Mancano dei file dei pannelli"; return 1; }
echo "[OK] Pannelli del desktop Vetro installati ($(ls "$d"/*.qml | wc -l) file)"
}

f10_sessione() {
# NON IN BLFS: dall'accesso parte "avvia-desktop" (Vetro, o il classico se manca il 3D)
[ -n "${MIA_UTENTE:-}" ] || { echo "Manca il nome dell'utente"; return 1; }
local casa; casa=$(getent passwd "$MIA_UTENTE" | cut -d: -f6)
[ -d "$casa" ] || { echo "Non trovo la cartella di $MIA_UTENTE"; return 1; }
local p
for p in "$casa/.bash_profile" /usr/local/share/fantasma/casa/.bash_profile; do
  [ -f "$p" ] || continue
  sed -i -e 's|dbus-run-session labwc > "\$HOME/.labwc.log" 2>&1|/usr/local/bin/avvia-desktop|' \
         -e 's|Il registro e. in: \$HOME/.labwc.log|I registri sono in ~/.cache/hyprland.log e ~/.labwc.log|' \
         -e 's|Per riprovare scrivi:  labwc      (oppure la vecchia grafica:  sway)|Per riprovare scrivi:  avvia-desktop|' "$p"
  grep -q 'avvia-desktop' "$p" || { echo "Non riesco a cambiare l'avvio in $p"; return 1; }
  bash -n "$p"
done
# lo sfondo nuovo, se non ne hai scelto uno tu
if [ ! -f "$casa/.config/sfondo.conf" ]; then
  install -dm755 "$casa/.config"
  echo "SFONDO=/usr/share/backgrounds/vetro-notte.png" > "$casa/.config/sfondo.conf"
  chown -R "$MIA_UTENTE:" "$casa/.config"
fi
# il desktop di partenza per tutti (chi non ha scelto): Vetro
echo vetro > /etc/vetro/desktop-predefinito
echo "[OK] All'accesso parte il desktop Vetro (o il classico, se manca il 3D)"
}

LISTA_STEP17=(
  "SPIRV-Headers|SPIRV-Headers-vulkan-sdk-1.4.357.0.tar.gz|f10_spirv_headers"
  "SPIRV-Tools|SPIRV-Tools-vulkan-sdk-1.4.357.0.tar.gz|f10_spirv_tools"
  "pugixml (XML)|pugixml-1.14.tar.gz|f10_pugixml"
  "toml++ (TOML)|tomlplusplus-3.4.0.tar.gz|f10_tomlplusplus"
  "libzip (ZIP)|libzip-1.12.1.tar.gz|f10_libzip"
  "muParser (calcoli)|muparser-2.3.5.tar.gz|f10_muparser"
  "Abseil|abseil-cpp-20250512.1.tar.gz|f10_abseil"
  "RE2 (espressioni regolari)|re2-2025-11-05.tar.gz|f10_re2"
  "udis86|udis86-1.7.2.tar.gz|f10_udis86"
  "librsvg finta (solo per Hyprland)|-|f10_rsvg_finto"
  "hyprutils|hyprutils-0.13.1.tar.gz|f10_hypr"
  "hyprwayland-scanner|hyprwayland-scanner-0.4.6.tar.gz|f10_hypr"
  "hyprlang|hyprlang-0.6.8.tar.gz|f10_hypr"
  "hyprcursor|hyprcursor-0.1.13.tar.gz|f10_hypr"
  "hyprgraphics|hyprgraphics-0.5.1.tar.gz|f10_hypr"
  "hyprland-protocols|hyprland-protocols-0.7.0.tar.gz|f10_hyprland_protocols"
  "hyprwire|hyprwire-0.3.1.tar.gz|f10_hypr"
  "aquamarine|aquamarine-0.12.0.tar.gz|f10_hypr"
  "glaze (JSON per Hyprland)|glaze-9.0.0.tar.gz|f10_glaze"
  "Hyprland|Hyprland-0.54.3.tar.gz|f10_hyprland"
  "Qt 6 (base, la parte piu' lunga)|qtbase-everywhere-src-6.11.2.tar.xz|f10_qtbase"
  "Qt 6 (shadertools)|qtshadertools-everywhere-src-6.11.2.tar.xz|f10_qt_modulo"
  "Qt 6 (svg)|qtsvg-everywhere-src-6.11.2.tar.xz|f10_qt_modulo"
  "Qt 6 (declarative, QML)|qtdeclarative-everywhere-src-6.11.2.tar.xz|f10_qt_modulo"
  "CLI11|CLI11-2.7.2.tar.gz|f10_cli11"
  "Quickshell|quickshell-0.3.2.tar.gz|f10_quickshell"
  "icone dei pannelli|-|f10_icone_pannelli"
  "aiutanti (password, avvio, sfondo)|-|f10_aiutanti"
  "configurazione di Hyprland|-|f10_config_hyprland"
  "pannelli (Quickshell) e sfondi|-|f10_shell"
  "avvio del desktop Vetro|-|f10_sessione"
)

cmd_fase10() {
  serve_root fase10
  titolo "Fase 10 - Desktop Vetro: Hyprland e Quickshell (animazioni, effetto vetro)"
  assicura_montato
  # le domande subito, cosi' poi lavora da solo fino alla fine
  chiedi_utente
  chiedi_password_fantasma
  # le fasi precedenti con parti nuove (aggiunte dopo) o non finite si completano prima
  completa_fasi_precedenti 16
  titolo "Fase 10 - Desktop Vetro: Hyprland e Quickshell (animazioni, effetto vetro)"
  if [ "${2:-}" = rifai ]; then
    local r; for r in "${LISTA_STEP17[@]}"; do rm -f "$(segno_di "$r")"; done
    info "Rifaccio la Fase 10 da capo (opzione 'rifai')"
  fi
  titolo "Scarico i sorgenti della Fase 10 (circa 120 MB)"
  scarica_fonti "${FONTI_FASE10[@]}"
  if [ ! -s "$LFS/sources/$FONT_ICONE_FILE" ]; then
    info "Icone dei pannelli (Material Symbols):"
    scarica "$FONT_ICONE_URL" "$LFS/sources/$FONT_ICONE_FILE" \
      || { rm -f "$LFS/sources/$FONT_ICONE_FILE" "$LFS/sources/$FONT_ICONE_FILE.part"
           avviso "Non sono riuscito a scaricare le icone: i pannelli useranno simboli semplici"; }
  fi
  info "Ci vogliono 1-3 ore (Qt e' grande). Lascia il terminale aperto."
  local esito=0
  lancia_in_chroot 17 MIA_UTENTE="$UTENTE" MIA_COMANDO=fase10 MIA_ETICHETTA="Fase 10" || esito=$?
  [ "$esito" -eq 0 ] || exit "$esito"
  titolo "FASE 10 COMPLETATA"
  info "Accendi la distro (sudo $0 avvia): ora parte con l'accelerazione 3D e il desktop Vetro."
  info "   Tasto Windows: cerca le app      Windows+A: centro di controllo"
  info "   Windows+D (o clic sull'ora): cruscotto con meteo, calendario e prestazioni"
  info "   Windows+I: Impostazioni          Windows+L: blocco schermo"
  info "   Alt+Tab: cambia finestra         Windows+freccia su/giu': ingrandisci/riduci"
  info "   Se il 3D non c'e', parte il desktop classico. Per sceglierlo tu: app 'Cambia desktop'"
  info "   Se i pannelli non partono, il motivo e' in ~/.cache/quickshell-vetro.log"
}

# =============================================================================
#  TUTTO - un solo comando per costruire tutta la distro (step 1 -> 6)
# =============================================================================
chiedi_impostazioni() {
  # nome della distro
  if [ -z "${NOME:-}" ] && [ ! -f "$CONF_DIR/nome-distro" ] && [ -t 0 ]; then
    local n; read -r -p "  Come vuoi chiamare la tua distro? [MiaDistro]: " n || true
    NOME=$(pulisci_nome "${n:-MiaDistro}")
  fi
  salva_nome
  ok "Nome della distro: $(cat "$CONF_DIR/nome-distro")"
  # password di root (si imposta da sola alla fine dello step 3)
  if [ -f "$LFS_IMG" ]; then assicura_montato; [ -e "$STATO_DIR/fatto/password-root" ] && return 0; fi
  [ -t 0 ] || { avviso "Nessun terminale: la password di root la imposterai dopo con 'sudo $0 password'"; return 0; }
  local p1 p2
  while true; do
    read -r -s -p "  Scegli la password di root del nuovo sistema: " p1; echo
    read -r -s -p "  Riscrivila: " p2; echo
    if [ -z "$p1" ]; then avviso "La password non puo' essere vuota"
    elif [ "$p1" != "$p2" ]; then avviso "Le due password sono diverse, riprova"
    else break; fi
  done
  PASSWORD_ROOT=$p1
  ok "Password ricevuta (la imposto io al momento giusto)"
}

cmd_tutto() {
  serve_root tutto
  # il PC non deve andare in sospensione durante le ore di compilazione
  if [ -z "${MIA_INIBITO:-}" ] && command -v systemd-inhibit >/dev/null 2>&1 \
     && systemd-inhibit --what=idle --why=prova true >/dev/null 2>&1; then
    exec systemd-inhibit --what=sleep:idle --who="mia-distro" --why="Sto costruendo la tua distro" \
      env MIA_INIBITO=1 bash "$0" tutto
  fi
  local grafica=1
  [ "${GRAFICA:-si}" = no ] && grafica=0
  if [ "$grafica" -eq 1 ]; then titolo "Costruisco TUTTA la tua distro (Fase 1 + grafica + programmi + desktop + Wine + uso quotidiano + sicurezza + fantasma + aspetto + macOS/Windows + desktop Vetro)"
  else titolo "Costruisco la tua distro (solo Fase 1, senza grafica)"; fi
  info "Ti faccio qualche domanda adesso, poi va avanti da solo per diverse ore."
  info "Il PC non andra' in sospensione finche' lavoro. Se si ferma, rilancia: riparte da dove era."
  chiedi_impostazioni
  [ "$grafica" -eq 0 ] || chiedi_utente
  [ "$grafica" -eq 0 ] || chiedi_password_fantasma
  local t0=$SECONDS
  cmd_step1
  cmd_step2
  cmd_step3
  cmd_step4
  cmd_step5
  cmd_step6
  [ "$grafica" -eq 0 ] || cmd_fase2
  [ "$grafica" -eq 0 ] || cmd_fase2b
  [ "$grafica" -eq 0 ] || cmd_fase2c
  [ "$grafica" -eq 0 ] || cmd_fase3
  [ "$grafica" -eq 0 ] || cmd_fase4
  [ "$grafica" -eq 0 ] || cmd_fase5
  [ "$grafica" -eq 0 ] || cmd_fase6
  [ "$grafica" -eq 0 ] || cmd_fase7
  [ "$grafica" -eq 0 ] || cmd_fase8
  [ "$grafica" -eq 0 ] || cmd_fase9
  [ "$grafica" -eq 0 ] || cmd_fase10
  titolo "LA TUA DISTRO E' PRONTA! (in $(durata $(( SECONDS - t0 ))))"
  info "Accendila in una macchina virtuale:   sudo $0 avvia        (oppure: sudo $0 avvia uefi)"
  info "Per VirtualBox o VMware:              sudo $0 esporta virtualbox   /   sudo $0 esporta vmware"
  info "Copia di sicurezza:                   sudo $0 backup"
  if [ -t 0 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    local r; read -r -t 120 -p "  La accendo adesso? [S/n] " r || r=s
    case "${r:-s}" in [nN]*) ;; *) cmd_avvia avvia || avviso "Accensione non riuscita: prova 'sudo $0 avvia'" ;; esac
  fi
}

# =============================================================================
#  STATO e STEP 1 completo
# =============================================================================
cmd_stato() {
  titolo "Stato del progetto"
  if [ -f "$LFS_IMG" ]; then
    ok "Disco virtuale: $LFS_IMG ($LFS_SIZE max, occupa $(du -h "$LFS_IMG" | cut -f1))"
  else avviso "Disco virtuale non ancora creato"; fi
  if montato; then ok "Montato su $LFS (usato: $(df -h --output=used "$LFS" | tail -n1 | tr -d ' '))"
  else avviso "Non montato (usa: sudo $0 monta)"; fi
  if [ -f "$LFS/sources/md5sums" ]; then ok "Sorgenti: $(find "$LFS/sources" -maxdepth 1 -type f ! -name '*.part' | wc -l) file"
  else avviso "Sorgenti non ancora scaricati"; fi
  if id lfs >/dev/null 2>&1; then ok "Utente lfs presente"; else avviso "Utente lfs non ancora creato"; fi
  local s fatti tot
  local nome_s cmd_s
  for s in 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do
    local -n lista="LISTA_STEP$s"
    fatti=$(quanti_fatti "${lista[@]}"); tot=${#lista[@]}
    case $s in
      7) nome_s="Fase 2 (grafica)"; cmd_s=fase2 ;;
      8) nome_s="Fase 2b (programmi)"; cmd_s=fase2b ;;
      9) nome_s="Fase 2c (desktop)"; cmd_s=fase2c ;;
      10) nome_s="Fase 3 (Wine, programmi .exe)"; cmd_s=fase3 ;;
      11) nome_s="Fase 4 (uso quotidiano)"; cmd_s=fase4 ;;
      12) nome_s="Fase 5 (ufficio, posta, blocco schermo)"; cmd_s=fase5 ;;
      13) nome_s="Fase 6 (sicurezza)"; cmd_s=fase6 ;;
      14) nome_s="Fase 7 (modalita' fantasma)"; cmd_s=fase7 ;;
      15) nome_s="Fase 8 (aspetto elegante)"; cmd_s=fase8 ;;
      16) nome_s="Fase 9 (piu' simile a macOS/Windows)"; cmd_s=fase9 ;;
      17) nome_s="Fase 10 (desktop Vetro: Hyprland e Quickshell)"; cmd_s=fase10 ;;
      *) nome_s="Step $s"; cmd_s="step$s" ;;
    esac
    if [ "$fatti" -ge "$tot" ]; then ok "$nome_s: fatto"
    elif [ "$fatti" -gt 0 ]; then avviso "$nome_s: a meta', $fatti/$tot passaggi (rilancia: sudo $0 $cmd_s)"
    else avviso "$nome_s: da fare"; fi
  done
}

cmd_step1() {
  serve_root step1
  cmd_controlla
  cmd_disco
  cmd_sorgenti
  cmd_utente
  cmd_stato
  titolo "STEP 1 COMPLETATO"
  info "Il PC e' pronto per lo step 2:  sudo $0 step2"
  info "Dopo un riavvio ricordati di rimontare il disco:  sudo $0 monta"
}

aiuto() { awk 'NR > 2 && /^# =====/ { exit } NR > 2' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-}" in
  step1) cmd_step1 ;;      controlla) cmd_controlla ;;
  step2) cmd_step2 ;;      _step2_lfs) _step2_lfs ;;
  step3) cmd_step3 ;;      _step3_chroot) _step3_chroot ;;
  password) cmd_password ;; backup) cmd_backup ;;
  fase2) cmd_fase2 "$@" ;;  fase2b) cmd_fase2b "$@" ;;  fase2c) cmd_fase2c "$@" ;;
  fase3) cmd_fase3 "$@" ;;  fase4) cmd_fase4 "$@" ;;
  fase5) cmd_fase5 "$@" ;;  fase6) cmd_fase6 "$@" ;;  fase7) cmd_fase7 "$@" ;;
  fase8) cmd_fase8 "$@" ;;  fase9) cmd_fase9 "$@" ;;  fase10) cmd_fase10 "$@" ;;
  step4) cmd_step4 "$@" ;; _step4_chroot) _step4_chroot ;;
  step5) cmd_step5 "$@" ;; step6) cmd_step6 "$@" ;;
  _step_chroot) _step_chroot "$2" ;;
  avvia) cmd_avvia "$@" ;; esporta) cmd_esporta "$@" ;;
  tutto) cmd_tutto ;;
  _pacchetto) _pacchetto "$2" "$3" ;;
  disco) cmd_disco ;;      sorgenti)  cmd_sorgenti ;;
  utente) cmd_utente ;;    monta)     cmd_monta ;;
  smonta) cmd_smonta ;;    stato)     cmd_stato ;;
  *) aiuto ;;
esac
