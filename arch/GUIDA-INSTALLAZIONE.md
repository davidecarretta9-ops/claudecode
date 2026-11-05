# oversicaOS — come si usa lfs.sh

`lfs.sh` è un solo file: crea una macchina virtuale con **Arch Linux + oversicaOS** e la
tiene aggiornata. oversicaOS ha l'interfaccia di **Caelestia** (barra a sinistra che
compare quando porti il mouse al bordo, menu delle app, pannelli, impostazioni) con il
logo, lo sfondo e le impostazioni di oversicaOS, e tutte le protezioni di sempre:
modalità fantasma, firewall, Guardiano della rete, VPN, DNS cifrato, cassaforte,
programmi Windows nel recinto.

Serve un PC Linux (Fedora, Ubuntu…) con almeno **8 GB di RAM**, **15 GB liberi** e
internet. QEMU si installa da solo se manca.

## 1. Crea la macchina

```bash
sudo bash lfs.sh fase10
```

- La prima volta chiede il **nome del tuo utente** (minuscole, es. `davide`), la
  **password** e quella dell'**utente fantasma** (Invio = la stessa).
- Poi fa tutto da solo: scarica Arch (circa 1,2 GB, controllato), installa Arch e poi
  oversicaOS. L'interfaccia (Caelestia e Quickshell) si compila sul posto: ci vuole
  circa un'ora e mezza. I messaggi scorrono nel terminale.
- Se si ferma (rete caduta…), **rilancia lo stesso comando**: riprende da dove era.

## 2. Accendila

```bash
sudo bash lfs.sh avvia
```

Compare la schermata di accesso (uguale a quella di blocco): scrivi la password e premi
Invio. Con **Tab** passi all'**utente fantasma** (tutto in memoria, sparisce allo
spegnimento). Chiudi la finestra per spegnere; schermo intero con Ctrl+Alt+F.

La **modalità fantasma è accesa di serie** (internet passa tutto da Tor, più lento):
quando è accesa vedi l'icona dell'occhio barrato nella barra. La spegni da
**Impostazioni → Privacy e sicurezza → Modalità fantasma**.

### I tasti principali (Windows = il tasto con il logo)

| Tasto | Cosa fa |
|---|---|
| Windows (premuto e lasciato) o Windows+Spazio | menu delle app |
| Windows+I | Impostazioni |
| Windows+D | pannello in alto (musica, meteo, prestazioni) |
| Windows+N | notifiche |
| Windows+A | comandi rapidi (Wi-Fi, Bluetooth, non disturbare…) |
| Windows+L | blocca lo schermo |
| Ctrl+Alt+Canc | spegni, riavvia, esci |
| Windows+Invio | terminale |
| Windows+E | file |
| Windows+B | browser |
| Windows+Q o Alt+F4 | chiudi la finestra |
| Windows+Giù / Windows+S | riduci la finestra / mostra le finestre ridotte |
| Stamp / Windows+Maiusc+S | foto dello schermo / di una parte |

### Il tuo avatar

**Impostazioni → Account**: scegli capelli, colore, pelle e maglia del personaggio a
pixel (stile Oversica Lodge) e premi **Salva**. Compare nel blocco, nell'accesso e nel
pannello in alto.

## 3. Aggiornare

Quando ricevi un `lfs.sh` nuovo:

```bash
sudo bash lfs.sh fase10
```

Aggiorna oversicaOS dentro la macchina, rifacendo solo le parti cambiate. Poi di nuovo
`sudo bash lfs.sh avvia`.

## Se qualcosa non va

Se al posto della schermata di accesso compare una **finestra di testo che chiede il
nome utente**, è l'accesso di riserva (la schermata non si è caricata): scrivi il tuo
utente, Invio, poi la password, Invio. Il desktop parte lo stesso. Poi mandami i
registri (qui sotto).

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

Al riavvio dopo l'installazione la rete passa a NetworkManager (quella che usa
l'interfaccia): Wi-Fi e cavo si gestiscono da **Impostazioni → Rete**.

Tutti i file della macchina virtuale stanno in `~/vetro-arch` (disco, ISO di Arch,
cartella condivisa `condivisa/`, che dentro la macchina è `/mnt/vetro`).

oversicaOS è basato su [Caelestia](https://github.com/caelestia-dots/shell) (licenza
GPL-3).
