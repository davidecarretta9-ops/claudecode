# oversicaOS — Caelestia dentro Vetro

Data: 2026-11-04 · Stato: da approvare

## 1. Obiettivo

Trasformare il desktop di Vetro (installato da `lfs.sh`) in **oversicaOS**: grafica,
pannelli, menu, impostazioni e comportamenti **uguali a Caelestia** (le foto mandate
dall'utente: video "¡CAELESTIA en Linux!"), con il marchio dell'utente (Oversica) e
con tutte le funzioni di sicurezza di Vetro.

Si usa **il vero Caelestia** (licenza GPL-3: si può usare e modificare citandolo), a
una versione fissa, con dei ritocchi di oversicaOS. L'utente lo installa e aggiorna
come oggi: `sudo bash lfs.sh fase10`, poi `sudo bash lfs.sh avvia`.

## 2. Riferimenti

| Cosa | Da dove |
|---|---|
| Grafica e comportamenti | 5 foto del video: pannello in alto (Dashboard, Media, Performance, Weather), menu in basso con comandi (`>wallpaper`, `>scheme`…), scelta dello sfondo a carosello, pannello in basso a destra (Keep awake, registrazione, Quick toggles), impostazioni "Nexus", barra sottile a sinistra |
| Logo | Oversica (sito dell'utente, oversica.com): cerchio aperto con un puntino arancione |
| Avatar | Oversica Lodge (dell'utente): personaggio a pixel con capelli, colore capelli, pelle, maglia |
| Codice | `caelestia-dots/shell` e `caelestia-dots/cli` (GitHub, GPL-3) |

## 3. Scelte dell'utente

- **Barra:** solo quella di Caelestia, verticale a sinistra, **a comparsa** (si vede
  quando il mouse arriva al bordo). Niente barra o dock in basso.
- **Approccio:** Caelestia vero + Vetro (non rifatto a mano, non Caelestia "nudo").
- **Logo:** "A — Orbita" (anello aperto in alto a destra, puntino arancione
  nell'apertura), tratto spesso e punte tonde.
- **Sfondo predefinito:** "Grafite" (quasi nero, grande anello grigio, puntino
  arancione che brilla).
- **Nome:** **oversicaOS** dove si vede. I nomi interni (`/etc/vetro`, `vetro-*`,
  `lfs.sh`) restano: rinominarli romperebbe gli aggiornamenti delle macchine già fatte.
- **Impostazioni:** quelle di Caelestia (tradotte) più le pagine del §6.3.

## 4. Come si monta

### 4.1 Versioni fisse

| Pezzo | Versione | Come si installa |
|---|---|---|
| Caelestia shell | `bcbb5d5139d5159839c7362d8f4954ccc7dbd67d` (3 nov 2026) | scaricato come archivio da GitHub, controllato (sha256), compilato con CMake (`extras;plugin;shell`) |
| Caelestia cli | `fdb3e47038c77ec8e7bb6010ffbcae00501d420b` (quella fissata da Caelestia shell) | archivio controllato, `python -m build --wheel`, installato nel sistema |
| Quickshell | `9b0f339b19057f4731bf3b48293307d7ef241671` (quella fissata da Caelestia) | compilato dai sorgenti (oggi `lfs.sh` sa già farlo per la v0.3.2: si cambia solo la versione) |
| m3shapes (forme Material) | `32ad9ce328bb77ed349b40a3be10ee9ea610b8ab` | compilato dai sorgenti |
| materialyoucolor (Python) | 3.0.4 (PyPI) | la ruota per la versione di Python di Arch, controllata (sha256 preso da PyPI al momento del piano) |
| libcava | se il pacchetto `cava` di Arch fornisce `libcava`/`cava.pc` si usa quello; se no si compila libcava a una versione fissa scelta nel piano | pacman o compilato |

Le dipendenze che Arch ha nei pacchetti ufficiali (ddcutil, brightnessctl, aubio,
libqalculate, power-profiles-daemon, networkmanager, lm_sensors, fish, swappy, grim,
slurp, wl-clipboard, cliphist, fuzzel, ffmpeg, qt6-imageformats, qt6-multimedia,
qt6-shadertools, ttf-cascadia-code-nerd…) si installano con pacman; `lfs.sh` le
controlla prima di cominciare, come oggi. I caratteri che non sono nei pacchetti
(Rubik, Material Symbols) si scaricano a versione fissa e si controllano.

### 4.2 I ritocchi di oversicaOS

I sorgenti di Caelestia non si modificano a mano: `lfs.sh` contiene una cartella di
**ritocchi** (file `.patch` piccoli e file QML nuovi) che applica dopo aver scaricato
Caelestia. Se un ritocco non si applica più (versione cambiata), l'installazione si
ferma con un messaggio chiaro invece di dare un desktop rotto.

### 4.3 Avvio del desktop

- `avvia-desktop` (dopo l'accesso) avvia Hyprland con `vetro.lua`.
- `avvia-pannelli` avvia `qs -c caelestia` (al posto dei pannelli di Vetro) e lo
  riavvia se si chiude o si blocca, come oggi.
- Prima volta: scrive `~/.config/caelestia/shell.json` con le scelte di oversicaOS
  (barra non fissa, lingua italiana, sfondo Grafite, avatar).
- `vetro.lua` riceve i tasti e le regole che servono a Caelestia (scorciatoie
  `caelestia:*`, sfocatura dei suoi pannelli) al posto di quelli dei pannelli di Vetro.

### 4.4 Rete

Caelestia parla con **NetworkManager**: il passo "rete" passa da iwd + systemd-networkd
a NetworkManager (che usa systemd-resolved per i nomi, come oggi). Modalità fantasma,
firewall, Guardiano e DNS cifrato lavorano a un livello diverso e restano. Nella
macchina virtuale il cavo si collega da solo. Durante l'aggiornamento il cambio di
rete si fa **per ultimo**, così il download dei pacchetti non si interrompe.

### 4.5 Cosa si toglie

I pannelli di Vetro in `/etc/xdg/quickshell/vetro` (barra, centro di controllo,
cruscotto, menu, notifiche, blocco, impostazioni): li sostituisce Caelestia. Con loro
sparisce il blocco del centro di controllo segnalato dall'utente. `Hypr.js` e le prove
sui comandi in Lua restano dove servono (accesso, barre del titolo).

## 5. Aspetto

### 5.1 Logo

- Anello aperto in alto a destra con il puntino arancione `#d9704a` nell'apertura;
  colore del segno: crema `#eeece4` su scuro, grafite `#1f201c` su chiaro.
- File: SVG + PNG (16, 24, 32, 48, 64, 128, 256, 512) nel tema di icone, icona
  "tessera" (quadrato arrotondato grafite), scritta "oversicaOS".
- Dove: cima della barra (al posto del logo di Caelestia), menu, accesso, blocco,
  pagina Informazioni, menu di avvio (GRUB: nome della voce).

### 5.2 Sfondo

- "Grafite" 2560×1440, JPEG sotto 700 KB, disegnato da `strumenti/disegna-sfondi.py`;
  diventa lo sfondo predefinito di Caelestia (i colori dell'interfaccia nascono da lui:
  toni grafite e arancio). Gli sfondi di oggi restano tra quelli da scegliere.
- Modalità fantasma: **non cambia più lo sfondo**; nella barra compare l'icona del
  fantasma quando è accesa.

### 5.3 Nome

`/etc/os-release` con `NAME="oversicaOS"`, `PRETTY_NAME="oversicaOS"`,
`ID=oversicaos`, `ID_LIKE=arch`; nome del computer `oversica`; voce di GRUB
"oversicaOS"; testi di accesso, blocco e Informazioni.

## 6. Funzioni

### 6.1 Accesso uguale al blocco

La schermata di accesso (greetd) usa **gli stessi pezzi del blocco di Caelestia**
(orologio grande al centro, avatar, campo password con la sua animazione, meteo e
stato del sistema ai lati). Cambia solo il "motore": controlla la password con greetd
e poi avvia il desktop. Utente unico: niente scelta dell'utente. Tastiera italiana.

### 6.2 Menu senza app di sistema

Il menu di Caelestia nasconde:
- Wine e i suoi pezzi (Wine, winecfg, Blocco note di Wine, Registro, Disinstalla…);
- le voci con categoria `System` o `Settings` e quelle con `NoDisplay`;
- un elenco fisso di strumenti (impostazioni dei singoli programmi, server del
  terminale, strumenti di Qt…).

Restano visibili: Terminale, File, Impostazioni (Nexus), le app normali. Da
Impostazioni → App si può mostrare di nuovo una voce nascosta (lista di Caelestia).

### 6.3 Impostazioni (Nexus)

Pagine di Caelestia tradotte: Sfondo e stile, Rete (Wi-Fi, cavo, VPN), Dispositivi
connessi (Bluetooth), Audio, Aggiornamenti, Pannelli, App, Lingua e area,
Informazioni (con "basato su Caelestia, GPL-3").

Pagine nuove di oversicaOS:

| Pagina | Cosa si fa | Con cosa |
|---|---|---|
| Account | nome mostrato, **avatar Lodge** (§6.4), cambio password | `~/.face`, `passwd` |
| Schermo | risoluzione, posizione di più schermi, scala, luce notturna, luminosità | Hyprland (file Lua), hyprsunset, brightnessctl/ddcutil |
| Privacy e sicurezza | modalità fantasma, firewall, Guardiano della rete, DNS cifrato, cassaforte | i comandi di Vetro di oggi |
| Energia e blocco | blocco dopo X minuti, spegnimento dello schermo, profilo energetico | hypridle/Caelestia, power-profiles-daemon |
| Notifiche | Non disturbare | Caelestia |
| Tastiera, mouse e touchpad | lingua della tastiera, velocità, scorrimento naturale, tocco per clic | Hyprland (file Lua) |
| Data e ora | fuso orario, formato 24 ore | timedatectl |
| Archiviazione | spazio usato, svuota cestino e file temporanei | df, gio |
| Accessibilità | testo più grande, meno animazioni | Caelestia, Hyprland |

Le pagine che richiedono la password di amministratore (fantasma, firewall, data)
usano gli aiutanti di Vetro che già esistono (sudo senza password solo per quei
comandi).

### 6.4 Avatar in stile Lodge

- Personaggio a pixel visto di fronte (stesso stile di Lodge), disegnato per
  oversicaOS. Scelte: **capelli** Corti, Folti, Lunghi, Raccolti, Ricci, Rasati;
  **colore capelli** 8; **pelle** 6; **maglia** 8 (stesse tinte di Lodge).
- I pixel stanno in **un solo file di dati** (JSON) usato sia dall'anteprima nelle
  Impostazioni sia dal programma che crea l'immagine: quello che vedi è quello che salvi.
- "Salva" scrive `~/.face` (PNG 256×256, pixel netti) e `~/.config/oversica/avatar.json`;
  l'avatar compare nel blocco, nell'accesso e nel pannello in alto.

### 6.5 Lingua

Si aggiunge la traduzione italiana dei testi di Caelestia (il suo sistema `Tr`), almeno
per tutto ciò che compare nelle foto, nel blocco, nel menu e nelle impostazioni.

## 7. Cosa resta di Vetro

Modalità fantasma (accesa di serie), firewall, Guardiano della rete, VPN, DNS cifrato,
cassaforte, utente fantasma, programmi Windows (Wine, nascosto dal menu), Thunar per i
file (colori di oversicaOS), Tor Browser, Thunderbird, barre del titolo (hyprbars),
`lfs.sh fase10 | avvia | registri | controlla`.

## 8. Limiti e rischi

- **Memoria:** circa 300 MB in più di oggi (Caelestia è più ricco).
- **Macchina virtuale:** Caelestia usa molti effetti grafici; con la scheda video
  virtuale può essere più lento che su un PC vero.
- **Aggiornamenti di Caelestia:** non arrivano da soli; si cambia la versione fissa in
  `lfs.sh` (e si controllano i ritocchi).
- **Traduzione:** alcune scritte rare di Caelestia possono restare in inglese.
- **Avatar:** pixel nuovi nello stile di Lodge; se l'utente manda i file di Lodge si
  possono usare quelli.

## 9. Prove

- Prove automatiche come oggi (`arch/test/esegui.sh`): installazione con comandi
  finti (download, controllo sha256, ritocchi applicati, compilazioni chiamate),
  file Lua con l'Hyprland finto, filtro del menu (elenco di voci .desktop di prova),
  avatar (stessi dati → stessa immagine, ogni scelta cambia i pixel giusti),
  pagine nuove caricate con il Quickshell finto senza errori, os-release e nome.
- Anteprime in PNG di avatar, logo e sfondo per l'utente.
- Prova finale dell'utente nella macchina: `fase10`, `avvia`, controllo delle schermate.

## 10. Ordine dei lavori

Il piano sarà diviso in tappe; ognuna consegna un `lfs.sh` che funziona:

1. **Base:** Caelestia installato e avviato al posto dei pannelli di Vetro, rete
   NetworkManager, menu senza app di sistema, logo, sfondo, nome oversicaOS.
2. **Accesso uguale al blocco** e traduzione italiana.
3. **Avatar Lodge** e pagina Account.
4. **Le altre pagine nuove** delle impostazioni (§6.3).
