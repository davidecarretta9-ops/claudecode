# Vetro su Arch — nuova grafica: piano di lavoro

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** rifare la grafica del desktop Vetro come nel video dell'utente (barra unica scura in basso con pillole, finestre chiare arrotondate con accento blu, menu compatto, accesso e blocco con elementi grandi), tenendo tutte le funzioni.

**Architecture:** ogni pezzo grafico nuovo è diviso in due: una **Vista** (`*Vista.qml`, solo QtQuick + `Tema`/`Icona`, riceve i dati come proprietà e manda segnali) e un **involucro** Quickshell (PanelWindow, servizi, Hyprland) che le passa i dati veri. Le Viste si disegnano qui in immagine con PySide6 (strumento delle anteprime). Sfondi e carattere vanno nello script come file.

**Tech Stack:** Bash (vetro-arch.sh), QML/Quickshell, Hyprland + hyprbars, GTK 3/4 CSS, Python (PIL solo per gli strumenti di sviluppo, PySide6 per prove e anteprime).

**Spec:** `docs/superpowers/specs/2026-11-02-vetro-nuova-grafica-design.md`

## Global Constraints

- Nomi, commenti e testi in italiano semplice; ogni file nuovo dice "(creato da vetro-arch.sh)".
- Niente nome o logo lunariaOS; niente immagini prese dal video.
- Colori: accento `#1a8cff`; pannelli scuri `#1f242c` al 92 %, bordo bianco 10 %; pillole bianco 6 % con bordo bianco 14 %; "Non disturbare" acceso fondo `#c0262d` 35 %, bordo `#ff5a5f` 50 %; app chiare fondo `#f5f7fa`, testo `#15181d`, testo secondario `#6b7280`.
- Angoli: finestre 18, barra 14, menu e riquadri 16, pillole tonde. Barra alta 48 px, staccata 8 px.
- Carattere `DM Sans` (file `DMSans[opsz,wght].ttf` di google/fonts `2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc`, sha256 `8cd08d97e89c24d0aa92edd2f0f4c8ee6195eee9b7c9f154865a58b02f0c1c0d`) dentro lo script con `OFL.txt`.
- Le Viste usano solo `QtQuick`, `QtQuick.Layouts`, `Tema`, `Icona`; quelle dell'accesso (`PasswordPillola`, `AccessoVista`) **niente `Tema`** (colori scritti dentro: `Tema` legge le scelte dell'utente).
- Prove: `bash arch/test/esegui.sh` → `=== TUTTO OK`; QML senza errori `[syntax]` di `pyside6-qmllint`.
- Niente servizi nuovi; letture del sistema dentro il `Process` di `Sistema.qml` che c'è già.

## Review Focus

- **Più schermi**: la barra c'è su ogni schermo; menu, centro di controllo e riquadro musica si aprono una volta sola → prova in Task 5 (`test_barra_su_ogni_schermo`).
- **PC senza batteria, senza Wi-Fi o senza musica**: le pillole mancanti spariscono senza errori → prove in Task 4 (`test_senza_batteria`, `test_solo_cavo`) e Task 5 (scena `barra-vuota` delle anteprime).
- **Titoli e nomi lunghissimi** (brano, utente, app): tagliati con "…", la pillola non supera 260 px → prova in Task 5 (scena `barra-lunga`) e Task 7 (`test_nome_lungo`).
- **Password sbagliata** all'accesso e al blocco: la pillola trema, dice "Password sbagliata", si svuota e resta pronta → prova in Task 7 e Task 8 (`test_password_sbagliata`).
- **Modalità fantasma accesa**: nella pillola di sistema compare l'icona del fantasma → prova in Task 5 (`test_icona_fantasma`).

---

### Task 1: Fondamenta — carattere, colori, logo, tema GTK chiaro

**Files:**
- Create: `arch/file/usr/share/fonts/dm-sans/DMSans.ttf`, `arch/file/usr/share/fonts/dm-sans/OFL.txt`, `arch/file/usr/share/icons/hicolor/scalable/apps/vetro.svg`, `arch/file/etc/xdg/vetro/gtk-3.0.css`, `arch/file/etc/xdg/vetro/gtk-4.0.css`, `arch/test/test-grafica.sh`
- Modify: `arch/file/etc/xdg/quickshell/vetro/Tema.qml`, `Opzioni.qml` (valori di partenza), `arch/file/etc/gtk-3.0/settings.ini`, `arch/file/etc/gtk-4.0/settings.ini`, `arch/file/usr/local/bin/avvia-desktop` (copia dei CSS), `arch/src/40-fase2-desktop.sh` (`FILE_DESKTOP`), `arch/test/test-fase2.sh` (valori GTK)

**Interfaces:**
- Produces `Tema`: nuovo tema `{ id: "vetro", nome: "Vetro", fondo: "#1f242c", accento: "#1a8cff" }` primo in `temi`; `carattere: "DM Sans"`; nuove proprietà `pillola`, `pillolaBordo`, `rossoFondo`, `rossoBordo`, `appFondo` (`#f5f7fa`), `appCarta` (`#ffffff`), `appTesto` (`#15181d`), `appTesto2` (`#6b7280`), `appTesto3` (`#9aa1ab`), `appBordo`, `appSopra`, `raggioFinestra: 18`, `raggioBarra: 14`, `raggioRiquadro: 16`, `altezzaBarra: 48`, `staccoBarra: 8`.
- `Opzioni` di partenza: `tema: "vetro"`, `opacita: 0.92`, `angoli: 18`.
- `settings.ini` (3 e 4): `gtk-application-prefer-dark-theme=0`, `gtk-font-name=DM Sans 11`.
- `avvia-desktop`: copia `/etc/xdg/vetro/gtk-3.0.css` in `~/.config/gtk-3.0/gtk.css` (e 4.0) se manca o se la prima riga è `/* Vetro (creato da vetro-arch.sh)`.
- CSS GTK 3: fondo finestra `#f5f7fa`, `.sidebar row` arrotondate 10 px, `.sidebar row:selected` fondo `#1a8cff` testo bianco; GTK 4: `@define-color accent_bg_color #1a8cff;` e `accent_color`.

- [ ] **Step 1: Test** `test-grafica.sh`: `test_carattere` (sha256 del ttf uguale al valore sopra, `OFL.txt` presente), `test_tema` (`Tema.qml` contiene `id: "vetro"`, `"#1a8cff"`, `appFondo`, `altezzaBarra: 48`; `Opzioni.qml` contiene `property string tema: "vetro"` e `property int angoli: 18`), `test_logo` (`vetro.svg` è XML con `<svg`), `test_gtk` (CSS con `/* Vetro (creato da vetro-arch.sh)` in prima riga e `#1a8cff`), `test_avvia_desktop_css` (con `HOME` finto: dopo `avvia-desktop` con `Hyprland` finto esiste `~/.config/gtk-3.0/gtk.css`; un `gtk.css` dell'utente senza la prima riga Vetro non viene toccato). In `test-fase2.sh` le attese GTK diventano `prefer-dark-theme=0` e `DM Sans 11`.
- [ ] **Step 2: Esegui** `bash arch/test/test-grafica.sh` → FALLITO.
- [ ] **Step 3: Scrivi** i file (carattere e licenza dalla copia di google/fonts alla versione sopra), aggiorna `FILE_DESKTOP` con `usr/share/fonts/dm-sans usr/share/icons/hicolor/scalable/apps/vetro.svg etc/xdg/vetro`.
- [ ] **Step 4: Esegui** `bash arch/test/esegui.sh` → `=== TUTTO OK`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: carattere DM Sans, colori, logo e GTK chiaro"`

### Task 2: Strumento delle anteprime

**Files:**
- Create: `arch/strumenti/anteprima.py`, `arch/strumenti/anteprima/qmldir`, `arch/strumenti/anteprima/Opzioni.qml` (finta), `arch/strumenti/anteprima/Quickshell/qmldir`, `arch/strumenti/anteprima/Quickshell/Singleton.qml`, `arch/strumenti/anteprima/scene/prova.qml`, `arch/test/test-anteprime.sh`

**Interfaces:**
- `python anteprima.py USCITA [--icone FILE_TTF] [--solo NOME]`: copia in una cartella temporanea `Tema.qml`, `Icona.qml`, `PasswordPillola.qml` e tutti i `*Vista.qml` di `arch/file/etc/xdg/quickshell/vetro`, poi i file finti di `arch/strumenti/anteprima/`; carica `DMSans.ttf` (e le icone se date); per ogni `scene/NOME.qml` (radice con `width`/`height`) salva `USCITA/NOME.png` con `QT_QPA_PLATFORM=offscreen`. Errori QML → stampati, uscita 1.
- `qmldir` della cartella temporanea: `singleton Tema 1.0 Tema.qml`, `singleton Opzioni 1.0 Opzioni.qml`.
- Le scene usano gli sfondi veri da `arch/file/usr/share/backgrounds` attraverso la proprietà di contesto `sfondi` (percorso).

- [ ] **Step 1: Test** `test-anteprime.sh`: `test_scena_prova` (`anteprima.py` su `prova.qml` — un `Rectangle` con `Tema.accento` e `Icona` — crea `prova.png` grande quanto la scena e l'uscita è 0), `test_errore_qml` (una scena con un tipo inesistente → uscita 1 e il nome del file nel messaggio). Senza PySide6 la prova fallisce dicendo come installarlo.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi** lo strumento e i file finti.
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: strumento delle anteprime"`

### Task 3: Sfondi e puntatore

**Files:**
- Create: `arch/strumenti/disegna-sfondi.py`, `arch/file/usr/share/backgrounds/vetro-{sfera,nuvole,cielo,onde,magenta,argento}.jpg`
- Modify: `arch/file/usr/local/lib/vetro/disegna-cursori`, `arch/file/etc/xdg/quickshell/vetro/Sfondi.qml`, `arch/file/usr/local/bin/sfondo-desktop`, `arch/src/40-fase2-desktop.sh` (via i vecchi sfondi disegnati, dentro la cartella `usr/share/backgrounds`), `arch/test/test-grafica.sh`, `arch/test/test-fase2.sh`
- Delete: `arch/file/usr/local/lib/vetro/disegna-vetro`

**Interfaces:**
- `python3 arch/strumenti/disegna-sfondi.py CARTELLA` (PIL, solo sviluppo): 6 JPG 2560×1440, qualità 88: **sfera** (azzurro `#cfe6fb`→`#8cc4f5`, sfera blu `#1a8cff` sfumata grande a destra in alto, 3 archi bianchi sottili), **nuvole** (blu notte `#0b1f3a`→`#1b4f7d`, nuvole morbide a rilievo, scie diagonali chiare, puntini), **cielo** (`#0b3a6e` in alto → `#4fb3ef` → `#bfe6fb` in basso), **onde** (blu notte con nastri blu luminosi), **magenta** (nero con forme rosa `#d21dbb` luminose), **argento** (grigio chiaro in alto → blu notte in basso, stella a quattro punte a linea sottile).
- Sfondo di partenza `/usr/share/backgrounds/vetro-sfera.jpg` (in `Sfondi.qml` e in `sfondo-desktop`).
- `disegna-cursori`: freccia bianca con contorno nero di 2 px su 24, punta e angoli arrotondati; funzione `freccia(lato) -> list[list[(r,g,b,a)]]` usabile dalle prove.

- [ ] **Step 1: Test** in `test-grafica.sh`: `test_sfondi` (6 file, iniziano con `FF D8`, 2560×1440 letti dall'intestazione JPEG, ognuno sotto 700 KB), `test_sfondo_di_partenza` (`Sfondi.qml` e `sfondo-desktop` contengono `vetro-sfera.jpg`, nessuno contiene `sfondo-desktop.png`), `test_f2_senza_disegna_vetro` (`f2_desktop` con radice finta non chiama `disegna-vetro` e installa `vetro-sfera.jpg`); in Python `test_cursore.py`: `freccia(24)` ha pixel neri opachi sul bordo sinistro (colonna 1, righe 3–14) e bianchi dentro (colonna 4, riga 8).
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Disegna** gli sfondi, guardali (immagini piccole), adatta cursori e script.
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: sfondi nuovi e puntatore arrotondato"`

### Task 4: Letture di batteria e rete per la barra

**Files:**
- Create: `arch/file/etc/xdg/quickshell/vetro/Letture.js`, `arch/test/python/test_letture.py`
- Modify: `arch/file/etc/xdg/quickshell/vetro/Sistema.qml`

**Interfaces:**
- `Letture.js` (`.pragma library`): `batteria(testo) -> { livello: int (-1 se non c'è), carica: bool }` dal blocco `#BAT` (righe `capacity status`); `rete(testo) -> { tipo: "wifi"|"cavo"|"nessuna", segnale: 0..4 }` dal blocco `#RETE` (righe `NOME wireless|cavo up|down` più le righe di `/proc/net/wireless` `NOME: X QUALITA. ...`, segnale = qualità/70 in 4 tacche).
- `Sistema.qml`: il comando del `Process` aggiunge `#BAT` (`/sys/class/power_supply/BAT*/capacity` e `status`) e `#RETE`; nuove proprietà `batteria: int` (-1), `inCarica: bool`, `reteTipo: string`, `reteSegnale: int`.

- [ ] **Step 1: Test** `test_letture.py` (con `QJSEngine` come `test_schermi.py`): `test_batteria` (`"85 Discharging"` → 85, false), `test_in_carica` (`"40 Charging"` → 40, true), `test_senza_batteria` (`""` → -1), `test_wifi` (wlan0 up + qualità 56 → wifi, 3), `test_solo_cavo` (enp1s0 cavo up, nessuna wireless → cavo), `test_niente` (tutto down → nessuna).
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi** `Letture.js` e il pezzo di `Sistema.qml`.
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: letture di batteria e rete"`

### Task 5: Barra unica in basso e riquadro della musica

**Files:**
- Create: `BarraVista.qml`, `MusicaVista.qml`, `MusicaRiquadro.qml` (in `arch/file/etc/xdg/quickshell/vetro/`), `arch/strumenti/anteprima/scene/{barra,barra-vuota,barra-lunga,musica}.qml`, `arch/test/test-barra.sh`
- Modify: `Barra.qml` (riscritta: involucro in basso), `shell.qml`, `Stato.qml` (`musica`), `Musica.qml` (posizione e durata), `Opzioni.qml` (via `dock`), `FinestraImpostazioni.qml` (via l'interruttore del dock), `Pannello.qml`, `Cruscotto.qml`, `Notifiche.qml`, `Osd.qml` (posizioni sopra la barra), `arch/file/etc/xdg/hypr/vetro.conf` (layerrule della barra)
- Delete: `Dock.qml`

**Interfaces:**
- `BarraVista` (Item): proprietà `app: var` (lista di `{ nome, icona (url), aperta, attiva }`), `nonDisturbare: bool`, `musica: bool`, `musicaTitolo: string`, `musicaCopertina: string`, `iconaRete: string`, `iconaVolume: string`, `batteria: int`, `inCarica: bool`, `fantasma: bool`, `ora: string`, `menuAperto: bool`, `pannelloAperto: bool`; segnali `logoCliccato()`, `appCliccata(int indice)`, `nonDisturbareCliccato()`, `musicaCliccata()`, `sistemaCliccato()`, `oraCliccata()`. Pillola musica larga al massimo 260 px con `elide`.
- `MusicaVista` (Item 380×170): `titolo`, `artista`, `copertina`, `posizione: real` (s), `durata: real` (s), `suona: bool`; segnali `indietro()`, `alterna()`, `avanti()`, `sposta(real secondi)`. Fondo: copertina ridotta a 1×1 px e stirata (colore medio) sopra `#1f242c`, poi velo scuro al 45 %.
- `Barra.qml`: `PanelWindow` in basso su ogni schermo (`anchors { bottom; left; right }`, `implicitHeight: Tema.altezzaBarra + 2 * Tema.staccoBarra`, `exclusiveZone` uguale), riempie `BarraVista` con `Opzioni.preferite`, `Finestre`, `Applicazioni`, `Musica`, `Audio`, `Sistema`, `Opzioni.nonDisturbare`; tiene la logica del clic del vecchio `Dock.qml` (apri / porta davanti / riduci); si aggiunge a `Stato.barre`.
- `Stato.musica: bool` (in `chiudiTutto` e `alterna`). `MusicaRiquadro.qml`: `PanelWindow` in basso a destra sopra la barra con `MusicaVista`.
- `Musica.qml`: `posizione`, `durata` (dal lettore MPRIS, aggiornate da un `Timer` di 1 s solo con `Stato.musica` aperto), `sposta(secondi)`.
- Posizioni: `Pannello` margini `{ top: 10, bottom: Tema.altezzaBarra + 2 * Tema.staccoBarra + 8, right: 10 }`; `Notifiche` e `Cruscotto` ancorati in basso con lo stesso margine; `Osd` sopra la barra.

- [ ] **Step 1: Test** `test-barra.sh`: `test_barra_su_ogni_schermo` (`shell.qml` ha `Variants` con `model: Quickshell.screens` e `Barra {}`, niente `Dock`), `test_niente_dock` (`Dock.qml` non c'è; nessun `.qml` contiene `Opzioni.dock`), `test_barra_in_basso` (`Barra.qml` contiene `anchors { bottom: true; left: true; right: true }` e `BarraVista`), `test_icona_fantasma` (`BarraVista.qml` contiene `visible: vista.fantasma`), `test_posizioni` (`Pannello.qml` contiene `bottom: Tema.altezzaBarra`), `test_qml` (qmllint senza `[syntax]` sui file nuovi), `test_anteprime_barra` (scene `barra`, `barra-vuota`, `barra-lunga`, `musica` senza errori).
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi** Viste, involucri e scene; guarda le anteprime accanto ai fotogrammi 0:02–0:03 e 0:09 del video e correggi.
- [ ] **Step 4: Esegui** `bash arch/test/esegui.sh` → `=== TUTTO OK`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: barra unica in basso e riquadro della musica"`

### Task 6: Menu delle app compatto

**Files:**
- Create: `MenuVista.qml`, `arch/strumenti/anteprima/scene/{menu,menu-cerca}.qml`
- Modify: `Avvio.qml` (involucro in basso a sinistra), `arch/test/test-barra.sh`

**Interfaces:**
- `MenuVista` (Item largo 420): `risultati: var` (`{ nome, icona }`), `scelta: int`, `tutte: bool`, `testo: string` (sola lettura, dal campo); segnali `cercato(string testo)`, `aperta(int indice)`, `tutteCliccato()`, `chiudi()`, `su()`, `giu()`; funzione `metti_a_fuoco()`. Campo "Cerca" con lente, riga "Tutte le app" con icona `apps`; con `tutte` una griglia di 4 colonne alta al massimo metà schermo.
- `Avvio.qml`: `PanelWindow` `anchors { bottom; left }`, margini `{ bottom: Tema.altezzaBarra + 2 * Tema.staccoBarra + 6, left: Tema.staccoBarra }`, tastiera `Exclusive` da aperto, `HyprlandFocusGrab` con `Stato.barre`; usa `Applicazioni.cerca`/`ordinate` come oggi.

- [ ] **Step 1: Test** in `test-barra.sh`: `test_menu` (`Avvio.qml` contiene `MenuVista` e `anchors { bottom: true; left: true }`; `MenuVista.qml` contiene `"Cerca"` e `"Tutte le app"`), anteprime `menu` e `menu-cerca` senza errori.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi**, confronta con il fotogramma 0:11.
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: menu delle app compatto"`

### Task 7: Pillola della password e schermata di accesso

**Files:**
- Create: `PasswordPillola.qml`, `AccessoVista.qml`, `arch/strumenti/anteprima/scene/{accesso,accesso-errore}.qml`, `arch/test/test-accesso-grafica.sh`
- Modify: `accesso.qml` (usa `AccessoVista`, sfondo `vetro-nuvole.jpg`)

**Interfaces:**
- `PasswordPillola` (Item 440×64, niente `Tema`): `testo` (alias del campo), `controllo: bool`, `errore: string`, `suggerimento: string` ("Scrivi la password"); segnale `invio(string password)`; funzioni `sbagliata()` (trema, svuota, mostra `errore`) e `metti_a_fuoco()`. Fondo `#0f2340` all'85 %, pallini bianchi 18 px, pulsante occhio (`visibility`/`visibility_off`) che cambia `echoMode`. Carattere `DM Sans`.
- `AccessoVista` (Item a tutto schermo, niente `Tema`): `utenti: var` (nomi), `scelto: int`, `sfondo: string`, `controllo: bool`, `errore: string`, `ora: date`; segnali `entra(string password)`, `cambiaUtente()`, `spegni()`, `riavvia()`; funzione `sbagliata()`. Al centro: cerchio 56 px con l'iniziale + nome 30 px grassetto bianco (taglio con "…" oltre 420 px), sotto `PasswordPillola`; in basso a destra due pulsanti tondi 44 px.
- `accesso.qml`: tiene `Greetd` e la lettura di `/etc/passwd`; collega `entra` → `createSession`, `authFailure` → `sbagliata()`.

- [ ] **Step 1: Test** `test-accesso-grafica.sh`: `test_accesso_usa_vista` (`accesso.qml` contiene `AccessoVista` e `vetro-nuvole.jpg`, ancora `Greetd.createSession` e `Greetd.launch`), `test_niente_tema` (`PasswordPillola.qml` e `AccessoVista.qml` non contengono `Tema.`), `test_occhio` (`PasswordPillola.qml` contiene `TextInput.Normal` e `TextInput.Password`), `test_password_sbagliata` (`function sbagliata()` in entrambe e `"Password sbagliata"` in `accesso.qml`), `test_nome_lungo` (`AccessoVista.qml` contiene `elide: Text.ElideRight`), anteprime `accesso` e `accesso-errore` senza errori; qmllint.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi**, confronta con il fotogramma 0:05.
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: schermata di accesso con la pillola della password"`

### Task 8: Schermata di blocco

**Files:**
- Create: `BloccoVista.qml`, `arch/strumenti/anteprima/scene/blocco.qml`
- Modify: `Blocco.qml` (usa `BloccoVista`, sfondo `vetro-cielo.jpg`; via numeri e musica in basso), `Opzioni.qml` e `FinestraImpostazioni.qml` (via `statisticheBlocco`), `arch/test/test-accesso-grafica.sh`

**Interfaces:**
- `BloccoVista` (Item a tutto schermo): `ora: date`, `nome: string`, `sfondo: string`, `controllo: bool`, `errore: string`; segnale `invio(string password)`; funzione `sbagliata()`. In alto a sinistra (margine 64 px): data 18 px (`dddd d MMMM`, italiano) e sotto l'ora 160 px bianca, peso leggero, alone bianco al 25 %; in basso al centro iniziale + nome e `PasswordPillola`.
- `Blocco.qml`: tiene `PamContext` (`vetro-blocco`) e i minuti di inattività.

- [ ] **Step 1: Test** in `test-accesso-grafica.sh`: `test_blocco` (`Blocco.qml` contiene `BloccoVista`, `PamContext` e `vetro-cielo.jpg`; `BloccoVista.qml` contiene `font.pixelSize: 160` e `PasswordPillola`), `test_password_sbagliata_blocco` (`Blocco.qml` chiama `sbagliata()` sul fallimento), `test_niente_statistiche` (nessun `.qml` contiene `statisticheBlocco`), anteprima `blocco` senza errori.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi**, confronta con il fotogramma 0:08.
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: schermata di blocco con l'orologio grande"`

### Task 9: Finestre chiare (Hyprland e barre del titolo)

**Files:**
- Modify: `arch/file/etc/xdg/hypr/vetro.conf`, `arch/file/usr/local/bin/vetro-barre-aggiorna`, `arch/test/test-fase2.sh` (attese di hyprbars)

**Interfaces:**
- `vetro.conf`: `border_size = 0`, `rounding = 18`, ombra `range = 24`, `color = rgba(0000002e)`.
- hyprbars: `bar_height = 34`, `bar_color = rgba(f6f8fbff)`, `col.text = rgba(15181dff)`, `bar_text_font = DM Sans`, `bar_text_size = 12`, tasti senza cerchio (`rgba(00000000)`) con simboli scuri `rgba(15181dff)`: `✕`, `■`, `–` in quest'ordine da destra.

- [ ] **Step 1: Test** in `test-fase2.sh`: `test_conf_hyprland` aspetta `rounding = 18` e `border_size = 0`; `test_barre_versione` aspetta `bar_color = rgba(f6f8fbff)`, `bar_text_font = DM Sans` e `hyprbars-button = rgba(00000000), 22, ■,`.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: finestre chiare con barre del titolo chiare"`

### Task 10: Impostazioni chiare

**Files:**
- Create: `VoceLato.qml`, `arch/strumenti/anteprima/scene/impostazioni-lato.qml`
- Modify: `FinestraImpostazioni.qml`, `Interruttore.qml`, `Cursore.qml` (proprietà `suChiaro`), `arch/test/test-accesso-grafica.sh`

**Interfaces:**
- `VoceLato` (Item alto 40): `icona: string`, `testo: string`, `scelta: bool`; segnale `cliccata()`. Scelta: pillola `Tema.accento` (raggio 10) con testo e icona bianchi; non scelta: icona a contorno `Tema.appTesto`, al passaggio `Tema.appSopra`.
- `FinestraImpostazioni.qml`: fondo `Tema.appFondo`, riquadri `Tema.appCarta`, testi `Tema.appTesto`/`appTesto2`/`appTesto3`, bordi `Tema.appBordo`; titolo del lato "Impostazioni" 20 px grassetto; le voci con `VoceLato`.
- `Interruttore` e `Cursore`: `property bool suChiaro: false`; vero → colori `app*`.

- [ ] **Step 1: Test**: `test_impostazioni_chiare` (`FinestraImpostazioni.qml` contiene `VoceLato` e `Tema.appFondo`; non contiene `Tema.fondoPieno`), `test_su_chiaro` (`Interruttore.qml` e `Cursore.qml` contengono `suChiaro`), anteprima `impostazioni-lato` senza errori; qmllint.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi**, confronta con i fotogrammi 0:06 e 0:12.
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "grafica: impostazioni chiare come le app"`

### Task 11: Anteprime finali, file unico e consegna

**Files:**
- Modify: `arch/dist/vetro-arch.sh` (rigenerato), `arch/GUIDA-INSTALLAZIONE.md` (una riga sulla nuova grafica, se serve)

- [ ] **Step 1:** `python arch/strumenti/anteprima.py ANTEPRIME --icone MaterialSymbolsRounded.ttf` → tutte le scene; un foglio unico con le anteprime accanto ai fotogrammi del video; correggi quello che stona (ogni correzione con la sua prova se cambia un comportamento).
- [ ] **Step 2:** `bash arch/costruisci.sh && bash arch/test/esegui.sh` → `=== TUTTO OK`; prova del file unico in radice finta (come nel Task 13 della base).
- [ ] **Step 3: Commit** — `git commit -m "grafica: vetro-arch.sh con la nuova grafica"`; push; manda all'utente le anteprime, `vetro-arch.sh`, `vetro-vm.sh` e la guida.
