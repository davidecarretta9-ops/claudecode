# Vetro su Arch — un solo lfs.sh

Data: 2026-11-04 · Stato: da approvare

## 1. Obiettivo

Un solo file, `lfs.sh`, che si usa come il vecchio:

```bash
sudo bash lfs.sh fase10     # crea o aggiorna la macchina virtuale con Vetro su Arch
sudo bash lfs.sh avvia      # la accende con lo schermo
```

Niente archinstall a mano, niente guida da seguire, niente secondo file. Prende il
posto di `vetro-arch.sh` + `vetro-vm.sh` + guida (il vecchio `lfs.sh` della distro LFS
resta nel progetto e non si tocca; il nuovo si consegna come file `lfs.sh`).

## 2. I comandi

| Comando | Dove | Cosa fa |
|---|---|---|
| `sudo bash lfs.sh fase10` | sul PC | La prima volta: chiede utente e password (e quella del fantasma, Invio = la stessa), installa QEMU se manca, scarica la ISO di Arch del mese e la controlla (sha256), crea il disco, installa Arch da sola, poi installa Vetro. Le volte dopo: aggiorna Vetro nella macchina (rifa' solo i passi cambiati). Senza finestra: l'avanzamento si legge nel terminale. Alla fine la macchina si spegne e dice "ora: sudo bash lfs.sh avvia". |
| `sudo bash lfs.sh avvia` | sul PC | Accende la macchina con lo schermo (3D se c'e', due uscite, tavoletta, audio, cartella condivisa). |
| `sudo bash lfs.sh registri` | sul PC | Accende la macchina senza schermo, raccoglie i registri e li mette in `~/vetro-arch/condivisa/registri-vetro.txt`; si spegne. |
| `sudo bash lfs.sh controlla` | sul PC | Come sopra, ma scrive nel terminale come sta la macchina. |
| `sudo bash lfs.sh installa` | dentro un Arch (anche un PC vero) | Installa o aggiorna Vetro su quel computer (era `vetro-arch.sh`). |
| `sudo bash lfs.sh controlla` / `registri` / `rifai PASSO` | dentro Arch | Come prima in `vetro-arch.sh`. |

`controlla` e `registri` capiscono da soli dove sono: dentro Arch (c'e' `/etc/arch-release`
e non c'e' il disco della macchina) lavorano su quel computer, se no sulla macchina
virtuale. Senza comando: l'aiuto.

## 3. Come funziona

### 3.1 Sul PC (Fedora, Ubuntu…)

- Tutto in `~/vetro-arch` dell'utente che ha fatto `sudo`: `disco.qcow2` (40 GB),
  la ISO, `condivisa/` (cartella condivisa con la macchina, montata in `/mnt/vetro`).
- QEMU gira come quell'utente (non come root), come nel vecchio `cmd_avvia`.
- Installazione di Arch: dalla ISO (montata in sola lettura) si prendono kernel e
  initramfs e i parametri di archiso (`archisobasedir`, `archisosearchuuid` o
  `archisolabel`); QEMU parte con `-kernel/-initrd` e
  `script=http://10.0.2.2:8765/installa-arch console=ttyS0`, senza schermo, la seriale
  nel terminale. La ISO di Arch esegue da sola lo script passato con `script=`.
- Un piccolo server sul PC (solo `127.0.0.1:8765`, la macchina lo vede come
  `10.0.2.2:8765`) dà `installa-arch`, `installa.conf` (utente e impronte delle
  password, fatte con `openssl passwd -6`: la password in chiaro non esce dal PC) e
  `lfs.sh`.
- Comandi alla macchina: il PC scrive il comando in `condivisa/.comando` (`installa`,
  `registri`, `controlla`) e copia `lfs.sh` in `condivisa/`; poi la accende senza schermo.

### 3.2 L'installazione di Arch (`installa-arch`, gira nella ISO)

Scrive tutto anche sulla seriale (si vede nel terminale). Disco `/dev/vda`: tabella DOS,
una partizione ext4 (con `-O encrypt`, per la cassaforte). `pacstrap -K` con `base linux
linux-firmware e2fsprogs grub sudo` (+ `openssh` no). Poi: fuso Europe/Rome,
`it_IT.UTF-8`, tastiera `it`, nome `vetro`, l'utente nel gruppo `wheel` con la password
dall'impronta, `/etc/vetro/utente`, `/etc/vetro/fantasma.hash` (0600), rete via cavo
(`10-cavo.network`, networkd + resolved), GRUB per BIOS con `console=tty0
console=ttyS0,115200`, la cartella condivisa in `/etc/fstab` (`vetro /mnt/vetro 9p
trans=virtio,version=9p2000.L,nofail,x-systemd.automount 0 0`), il servizio
`vetro-comando`, `lfs.sh` in `/usr/local/sbin/lfs.sh`. Alla fine si spegne. Se qualcosa
va storto: messaggio chiaro sulla seriale e si spegne lo stesso (il PC lo dice).

### 3.3 Il servizio `vetro-comando` (nella macchina, a ogni accensione)

Dopo la rete: se `/mnt/vetro/.comando` c'e' (o, senza 9p, se
`http://10.0.2.2:8765/.comando` risponde), lo legge, lo toglie, copia `/mnt/vetro/lfs.sh`
in `/usr/local/sbin/lfs.sh`, esegue `lfs.sh <comando>` con l'uscita sulla console
(seriale) e spegne la macchina. Senza comando non fa niente (accensione normale).

### 3.4 Password del fantasma

`password_fantasma` usa `/etc/vetro/fantasma.hash` se c'e' (poi lo cancella); se no
chiede come prima.

## 4. Cosa non cambia

Tutto Vetro (grafica nuova, fantasma, Guardiano, Wi-Fi, VPN…) e il motore dei passi.
`installa` dentro Arch fa esattamente quello che faceva `vetro-arch.sh`.

## 5. Limiti e scelte

- Disco della macchina **non cifrato** (niente password del disco a ogni accensione).
- La macchina parte in BIOS (niente firmware UEFI da installare).
- Con la modalita' fantasma accesa (di serie) gli aggiornamenti di `fase10` scaricano
  da Tor: piu' lenti.
- Servono sul PC: `sudo`, `curl`, `python3`, `openssl`, QEMU (si installa da solo con
  `dnf` o `apt`), circa 15 GB liberi.
- L'installazione vera di Arch non si puo' provare qui (i siti di Arch non si
  raggiungono): si prova con le prove finte e poi nella macchina dell'utente.

## 6. Come si controlla

1. Prove automatiche: comandi e loro scelta, parametri della ISO, comandi di QEMU,
   `installa-arch` (sintassi e contenuto), servizio `vetro-comando` in una radice finta,
   password del fantasma dall'impronta, il file unico da cima a fondo in una radice finta.
2. Nella macchina dell'utente: `sudo bash lfs.sh fase10` arriva a "Fatto"; `sudo bash
   lfs.sh avvia` mostra la schermata di accesso; un secondo `fase10` aggiorna senza
   reinstallare; `registri` produce il file.
