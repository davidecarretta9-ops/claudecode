# Vetro su Arch — guida d'installazione

Vetro su Arch è Arch Linux con il desktop Vetro: aspetto di GNOME ma leggero
(Hyprland + pannelli Quickshell), modalità fantasma (tutto passa da Tor),
firewall, Guardiano della rete, VPN, DNS cifrato, cassaforte e programmi Windows
nel recinto.

Si fa in due tempi:

1. installi un **Arch Linux di base** con `archinstall` (il programma di
   installazione di Arch);
2. lanci **`vetro-arch.sh`**, che aggiunge tutto il resto.

Servono: un PC (o una macchina virtuale) con almeno **4 GB di RAM** (meglio 8),
**30 GB di disco** e **internet**.

---

## A. Prova in una macchina virtuale (consigliato la prima volta)

Sul tuo PC Linux, nella stessa cartella metti `vetro-vm.sh` e `vetro-arch.sh`.

1. Installa QEMU (una volta sola):
   - Fedora: `sudo dnf install qemu-system-x86 qemu-img`
   - Ubuntu: `sudo apt install qemu-system-x86 qemu-utils`
2. Prepara disco e ISO di Arch (scarica circa 1,2 GB e la controlla):

   ```bash
   bash vetro-vm.sh crea
   ```

3. Accendi la macchina dalla ISO:

   ```bash
   bash vetro-vm.sh installa
   ```

4. Nella macchina segui la **parte C** (archinstall). Alla fine spegni con
   `poweroff`.
5. Da adesso accendi la macchina così:

   ```bash
   bash vetro-vm.sh avvia
   ```

6. Fai la **parte D** (vetro-arch.sh). Il file è nella cartella condivisa
   `~/vetro-arch/condivisa` del tuo PC; dentro la macchina la apri così:

   ```bash
   sudo mkdir -p /mnt/vetro
   sudo mount -t 9p -o trans=virtio,version=9p2000.L vetro /mnt/vetro
   ```

   Se `vetro-vm.sh` ti ha detto che il tuo QEMU non ha 9p, scarica il file così
   (il tuo PC, visto dalla macchina, è `10.0.2.2`):

   ```bash
   curl -O http://10.0.2.2:8765/vetro-arch.sh
   ```

La macchina ha due schermi virtuali (per provare i più schermi): il secondo si
apre dal menu *Visualizza* di QEMU.

## B. Installazione su un PC vero

1. Scarica la ISO da <https://archlinux.org/download/> e scrivila su una
   chiavetta USB (per esempio con Fedora Media Writer o balenaEtcher).
2. Accendi il PC dalla chiavetta.
3. Collegati a internet: con il cavo va da solo; per il Wi-Fi scrivi `iwctl`,
   poi `station wlan0 connect NOME-RETE`, la password e `exit`.
4. Segui la **parte C**, poi la **parte D** (copia `vetro-arch.sh` su una
   chiavetta, oppure scaricalo).

## C. Arch di base con archinstall

Nella schermata nera della ISO:

```bash
loadkeys it
archinstall
```

Scegli così (frecce e Invio; le voci non scritte lasciale come sono):

| Voce di archinstall | Cosa scegliere |
|---|---|
| Archinstall language | Italiano (se c'è) |
| Locales | tastiera `it`, lingua `it_IT.UTF-8` |
| Mirrors | Italy |
| Disk configuration | *Use a best-effort default partition layout* → il disco → file system **ext4** (serve alla cassaforte) |
| Disk encryption | **LUKS**, con una password (all'accensione la chiede: senza, il disco non si legge) |
| Bootloader | quello proposto (Grub o systemd-boot) |
| Hostname | `vetro` |
| Root password | una password (o lasciala vuota: userai `sudo`) |
| User account | il tuo utente, con **superuser (sudo): sì** |
| Profile | **minimal** (il desktop lo mette vetro-arch.sh) |
| Audio | **pipewire** |
| Network configuration | **Copy ISO network configuration to installation** (systemd-networkd + iwd) |
| Timezone | Europe/Rome |

Poi *Install*. Alla domanda finale (chroot) rispondi **no**, poi `reboot`
(in macchina virtuale: `poweroff` e poi `bash vetro-vm.sh avvia`).

## D. Vetro con vetro-arch.sh

Accendi, scrivi la password del disco, entra con il tuo utente e lancia:

```bash
sudo bash /mnt/vetro/vetro-arch.sh
```

(su un PC vero: `sudo bash vetro-arch.sh` nella cartella dove l'hai messo).

- Ci vuole un po' (scarica circa 2 GB). Se si ferma, **rilancia lo stesso
  comando**: riprende da dove era.
- Alla fine chiede la **password dell'utente fantasma** (l'utente con la casa in
  memoria: quello che fai lì sparisce allo spegnimento).
- Poi: `reboot`. Compare la schermata di accesso di Vetro.

La **modalità fantasma è accesa di serie**: internet passa tutto da Tor (più
lento). La spegni dal centro di controllo (in alto a destra) → *Modalità fantasma*.

## Se qualcosa non va

```bash
sudo bash /mnt/vetro/vetro-arch.sh controlla
```

dice cosa funziona e cosa no (RAM usata, servizi, modalità fantasma, passi).

```bash
sudo bash /mnt/vetro/vetro-arch.sh registri
```

raccoglie tutti i registri in **un solo file**: `registri-vetro.txt` nella
cartella condivisa (`~/vetro-arch/condivisa` sul tuo PC) oppure in `/root`.
Mandalo così com'è. Senza 9p lo carichi sul tuo PC con:

```bash
sudo curl -T /root/registri-vetro.txt http://10.0.2.2:8765/
```

Per rifare un solo passo: `sudo bash vetro-arch.sh rifai NOME-PASSO` e poi di
nuovo `sudo bash vetro-arch.sh`.
