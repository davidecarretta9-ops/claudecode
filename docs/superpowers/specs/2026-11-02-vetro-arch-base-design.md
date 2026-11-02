# Vetro su Arch — progetto della base

Data: 2026-11-02 · Stato: da approvare

## 1. Obiettivo

Un sistema operativo personale, basato su **Arch Linux**, pensato per **AI locale e
cybersicurezza**, leggero il più possibile per lasciare la RAM ai modelli AI.
Riprende tutto quello che c'è già nella distro costruita con `lfs.sh` (desktop
"Vetro", modalità fantasma, Guardiano della rete, ecc.) e lo porta su Arch.

Questo documento riguarda solo il **primo sottoprogetto: la base**. Gli altri
avranno ciascuno il proprio documento, piano e lavoro.

### Il progetto intero, diviso in sottoprogetti

| # | Sottoprogetto | Cosa fa |
|---|---|---|
| 1 | **Base** (questo documento) | Arch + desktop leggero con aspetto GNOME + funzioni di sicurezza già esistenti + `.exe` |
| 2 | Motore AI locale | Modelli compressi (quantizzati) che girano sul processore, nel minimo di RAM |
| 3 | Assistente sullo schermo | Legge lo schermo (riconoscimento del testo), riassume e spiega i testi lunghi, spiega il testo selezionato col mouse |
| 4 | Antivirus con AI | Controlla i file scaricati (firme e regole note + spiegazione dell'AI) |
| 5 | Rete avanzata | Pannello completo per le regole di entrata e uscita, IP nascosto |
| 6 | File protetti | Niente esce dal disco senza il permesso dell'utente |

## 2. Vincoli e decisioni prese

- **Computer di destinazione:** PC con 8 GB di RAM, **senza scheda video
  dedicata** (solo quella integrata). L'AI dei sottoprogetti 2–4 gira sul
  processore: modelli piccoli (circa 3 miliardi di parametri, compressi,
  ~2–2,5 GB). Per leggere lo schermo si usa il riconoscimento del testo (OCR), non
  un modello "che vede" le immagini (troppo pesante senza GPU).
- **Desktop:** motore leggero **Hyprland + pannelli Quickshell** (quelli di Vetro),
  con **l'aspetto di GNOME**. Niente GNOME vero (circa 1,3 GB di RAM contro
  0,4–0,5 GB).
- **Installazione:** prima **uno script** da lanciare su un Arch appena
  installato; quando funziona, una **ISO** che usa lo stesso script.
- **Forma:** **un solo file**, `vetro-arch.sh`, come `lfs.sh`: messaggi in
  italiano, passi numerati, riparte da dove si è fermato, ogni passo con il suo
  controllo `[OK]`. Si aggiorna mandando il file nuovo e rilanciandolo.
- **Solo pacchetti ufficiali di Arch** (niente AUR). Quello che manca nei
  repository ufficiali lo compila lo script dai sorgenti originali, con controllo
  del file scaricato (come fa `lfs.sh`).
- **Funzioni da portare:** tutte quelle che ci sono già (supposizione accettata).

## 3. Cosa fa `vetro-arch.sh`

Si lancia come root su un Arch installato con `archinstall` (profilo "minimal",
disco **ext4**, **tutto il disco cifrato con LUKS**: i passi esatti sono nella
guida d'installazione che accompagna lo script).

Comandi:

```
vetro-arch.sh              fa tutto (o riprende da dove era)
vetro-arch.sh controlla    RAM occupata, servizi, firewall, fantasma e Tor, Guardiano
vetro-arch.sh registri     raccoglie i registri in un file (nella cartella condivisa)
vetro-arch.sh rifai PASSO  rifà un passo
```

Fasi, ognuna fatta di passi con un segno "fatto" e un'impronta del testo (se lo
script cambia un passo, quel passo si rifà da solo, come in `lfs.sh` Fase 10):

1. **Sistema leggero**
   - solo i servizi indispensabili accesi;
   - **zram** (memoria compressa, ~metà della RAM) come area di scambio: con
     8 GB si comporta come circa 12 GB per i modelli AI;
   - **systemd-oomd**: se la memoria finisce chiude il programma più grosso invece
     di bloccare il PC;
   - utente con gruppi e permessi come in `lfs.sh`.
2. **Desktop**
   - Hyprland, Quickshell, greetd, PipeWire, i portali del desktop, caratteri
     Adwaita Sans/Mono, icone Adwaita (vettoriali: nitide), tema GTK Adwaita
     scuro, il nostro tema di puntatori "Vetro" (freccia bianca stile Windows);
   - i pannelli Vetro (barra, dock, cruscotto, centro di controllo, pagina delle
     app, notifiche, blocco schermo, Impostazioni), presi da `lfs.sh` e adattati;
   - barre del titolo delle finestre (plugin hyprbars, installato con `hyprpm`,
     lo strumento ufficiale di Hyprland per i plugin).
3. **Programmi**: Tor Browser (installato e aggiornato dal suo programma ufficiale
   `torbrowser-launcher`, che controlla le firme), Thunderbird, LibreOffice in
   italiano, Thunar, Mousepad, terminale foot, Wine per i `.exe`.
4. **Sicurezza**: le funzioni di `lfs.sh` (sezione 5).

## 4. Aspetto, accesso, più schermi

- **Aspetto GNOME**: colori, caratteri, angoli arrotondati e animazioni morbide
  come GNOME; programmi GTK con Adwaita scuro.
- **Barra in alto** come in Vetro oggi: a sinistra app e scrivanie, al centro data
  e ora (aprono il cruscotto), a destra niente. Dock in basso.
- **Barre del titolo**: pulsanti a destra (riduci, ingrandisci, chiudi), grigi e
  tondi come in GNOME. Si trascina la barra per spostare la finestra.
- **Accesso**: `greetd` con una schermata disegnata dai pannelli, uguale al blocco
  schermo (orologio grande, sfondo sfocato, password). Il desktop parte **solo
  dopo** la password giusta. Si sceglie l'utente (il tuo o *fantasma*). Spegni e
  riavvia dalla schermata. Le password le controlla PAM, per l'accesso e per il
  blocco schermo.
- **Più schermi**: barra, dock e sfondo su ogni schermo. In Impostazioni →
  Schermo: risoluzione di ogni schermo, posizione (destra, sinistra, sopra), quale
  è il principale, "duplica schermo". Le scelte restano salvate.
- **Personalizzazione**: le Impostazioni di Vetro di oggi (temi, sfondi, barra,
  dock, cruscotto).

## 5. Sicurezza

**Portate da `lfs.sh` (Python e bash, quasi senza cambiamenti):**

- **Firewall** (iptables): in entrata solo le risposte a quello che chiedi tu.
- **Guardiano della rete**: il primo collegamento di ogni programma dell'utente si
  ferma (NFQUEUE) e chiede il permesso; regole salvate.
- **Modalità fantasma, accesa di serie**: tutto passa da Tor (anche gli altri
  programmi), scheda di rete e nome del computer camuffati, niente IPv6, webcam e
  microfono spenti, registri solo in memoria. Pulsante "Spegni" subito, che
  mostra l'errore se non riesce.
- **Utente fantasma**: cartella personale in memoria, sparisce allo spegnimento.
- **VPN WireGuard**, **DNS cifrato** (systemd-resolved), **cassaforte** cifrata
  (fscrypt su ext4).
- **`.exe` con Wine nel "recinto"** (bubblewrap): i programmi Windows non vedono i
  file e la rete senza permesso.

**Cambiamenti per Arch:**

- **Tutto il disco cifrato (LUKS)**, scelto in `archinstall`.
- **Rete**: `systemd-networkd` + `iwd` per il Wi-Fi (più leggeri di
  NetworkManager; la modalità fantasma usa già networkd). `iwd` cambia l'indirizzo
  della scheda Wi-Fi a ogni rete.
- **Wi-Fi nel centro di controllo**: elenco delle reti, collegati e scollegati
  (con `iwd`).
- **Password**: PAM di Arch al posto dell'aiutante `vetro-password`.

## 6. Prove

**Macchina virtuale sul PC dell'utente (Fedora)**, con un secondo script,
`vetro-vm.sh`, che gira sul PC:

- crea il disco virtuale e avvia la ISO ufficiale di Arch per installare;
- accende la macchina con accelerazione 3D (virtio-vga-gl), tavoletta USB per il
  mouse e **due schermi** (`max_outputs=2`);
- crea una **cartella condivisa** tra PC e macchina (9p): ci va `vetro-arch.sh`,
  ci arriva il file dei registri. Le opzioni di QEMU partono da quelle che
  `lfs.sh avvia` usa già.

**Errori**: ogni passo che fallisce si ferma con un messaggio in italiano e il
nome del registro; rilanciando riprende da lì. Scaricamenti con nuovi tentativi;
pacchetti con le firme di pacman; sorgenti con il loro controllo.

## 7. Quando la base è finita

Partendo da un Arch appena installato (minimal, ext4, LUKS) e lanciando
`vetro-arch.sh`:

1. All'accensione compare la schermata di accesso stile Vetro, chiede la
   password; si può scegliere anche l'utente fantasma.
2. Il desktop ha l'aspetto di GNOME; barra, dock e pannelli rispondono al mouse
   (passaggio e clic).
3. Da fermo, dopo l'accesso, usa **meno di 700 MB di RAM** (misurato da
   `vetro-arch.sh controlla`).
4. La modalità fantasma è accesa: i siti vedono l'indirizzo di Tor; "Spegni"
   funziona subito.
5. Il Guardiano chiede il permesso al primo collegamento di un programma.
6. Un `.exe` di prova si apre; Tor Browser, Thunderbird e LibreOffice partono.
7. Con due schermi: barra e dock su tutti e due; la risoluzione si cambia per
   ciascuno.
8. Lo script rilanciato non rompe niente.

## 8. Fuori da questa base

Motore AI, assistente sullo schermo, antivirus con AI, pannello avanzato della
rete, blocco dei file in uscita, la ISO. La base però prepara il terreno: poca
RAM occupata, zram, systemd-oomd, regole di rete pronte, cattura dello schermo
disponibile in Quickshell.

## 9. Rischi e punti da verificare nel piano

- **Pacchetti**: verificare nel piano che Quickshell, `torbrowser-launcher`, yad e
  gli altri siano nei repository ufficiali di Arch. Se uno non c'è, lo script lo
  compila dai sorgenti con il controllo del file.
- **Plugin hyprbars**: `hyprpm` scarica e compila il plugin per la versione di
  Hyprland installata; dopo ogni aggiornamento di Hyprland va ricompilato
  (lo script lo fa con un servizio dopo gli aggiornamenti).
- **Mouse sui pannelli**: nella distro `lfs.sh` i pannelli non ricevevano il mouse
  (causa non trovata). Su Arch con i pacchetti ufficiali va verificato per primo
  (criterio 2).
- **Cartella condivisa**: se il QEMU di Fedora non ha il 9p, `vetro-vm.sh` usa un
  piccolo server sul PC (la macchina virtuale lo raggiunge all'indirizzo
  10.0.2.2) per passare lo script e ricevere i registri.
- **Prove**: da questo ambiente non si raggiungono i server di Arch: lo script si
  prova nella macchina virtuale dell'utente; qui si controllano sintassi, pezzi
  eseguibili su file di prova e i file QML (come fatto per `lfs.sh`).
