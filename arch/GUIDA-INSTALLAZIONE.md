# Vetro su Arch — come si usa lfs.sh

`lfs.sh` è un solo file: crea una macchina virtuale con **Arch Linux + il desktop
Vetro** (modalità fantasma, firewall, Guardiano della rete, VPN, cassaforte,
programmi Windows nel recinto) e la tiene aggiornata.

Serve un PC Linux (Fedora, Ubuntu…) con almeno **8 GB di RAM**, **15 GB liberi** e
internet. QEMU si installa da solo se manca.

## 1. Crea la macchina

```bash
sudo bash lfs.sh fase10
```

- La prima volta chiede il **nome del tuo utente** (minuscole, es. `davide`), la
  **password** e quella dell'**utente fantasma** (Invio = la stessa).
- Poi fa tutto da solo: scarica Arch (circa 1,2 GB, controllato), installa Arch e poi
  Vetro. I messaggi scorrono nel terminale. Ci vuole circa un'ora.
- Se si ferma (rete caduta…), **rilancia lo stesso comando**: riprende da dove era.

## 2. Accendila

```bash
sudo bash lfs.sh avvia
```

Compare la schermata di accesso di Vetro: entra con il tuo utente. Chiudi la finestra
per spegnere; schermo intero con Ctrl+Alt+F.

La **modalità fantasma è accesa di serie** (internet passa tutto da Tor, più lento): la
spegni dal centro di controllo (clic sulla pillola con Wi-Fi e volume, in basso a
destra nella barra) → *Modalità fantasma*.

## 3. Aggiornare

Quando ricevi un `lfs.sh` nuovo:

```bash
sudo bash lfs.sh fase10
```

Aggiorna Vetro dentro la macchina, rifacendo solo le parti cambiate. Poi di nuovo
`sudo bash lfs.sh avvia`.

## Se qualcosa non va

Se la barra e i pannelli si bloccano, si riaprono da soli entro circa 20 secondi.
Per farlo subito premi **Ctrl+Alt+Backspace** (chiude i pannelli, che ripartono).

```bash
sudo bash lfs.sh registri
```

Raccoglie tutti i registri della macchina in **un solo file**:
`~/vetro-arch/condivisa/registri-vetro.txt`. Mandalo così com'è.

```bash
sudo bash lfs.sh controlla
```

Dice come sta la macchina (RAM usata, servizi, modalità fantasma, passi fatti).

## Su un PC vero (senza macchina virtuale)

Installa Arch (con `archinstall`: disco **ext4**, profilo **minimal**, audio
**pipewire**, rete "copia la configurazione della ISO", il tuo utente con sudo), poi:

```bash
sudo bash lfs.sh installa
```

Tutti i file della macchina virtuale stanno in `~/vetro-arch` (disco, ISO di Arch,
cartella condivisa `condivisa/`, che dentro la macchina è `/mnt/vetro`).
