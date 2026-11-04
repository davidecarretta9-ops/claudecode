# oversicaOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lfs.sh` (un solo file, come oggi) installa e aggiorna oversicaOS: il vero Caelestia a versione fissa con i ritocchi di oversicaOS al posto dei pannelli di Vetro, più logo, sfondo, nome, accesso uguale al blocco, italiano, avatar Lodge e le pagine nuove delle impostazioni.

**Architecture:** Un file nuovo `arch/src/45-caelestia.sh` scarica con `git` i sorgenti a commit fisso (il commit è il controllo d'integrità), applica i ritocchi (`.patch` + file nuovi sovrapposti) e compila Quickshell, m3shapes, Caelestia shell e cli. I file di oversicaOS stanno in `arch/file` come sempre; `arch/costruisci.sh` produce il solo `arch/dist/lfs.sh`. Il cambio di rete (NetworkManager) è un passo a parte, eseguito per ultimo e attivo dal riavvio dopo.

**Tech Stack:** bash (motore dei passi di `lfs.sh`), Hyprland 0.57 (Lua), Quickshell/QML (Caelestia), Python 3 (Pillow per immagini, renderer avatar), gettext `.po` (traduzione), prove: `arch/test/*.sh`, `arch/test/python/test_*.py` (PySide6 + lupa).

**Spec:** `docs/superpowers/specs/2026-11-04-oversicaos-design.md`

## Global Constraints

- Caelestia shell `bcbb5d5139d5159839c7362d8f4954ccc7dbd67d`, cli `fdb3e47038c77ec8e7bb6010ffbcae00501d420b`, Quickshell `9b0f339b19057f4731bf3b48293307d7ef241671` (da `https://github.com/quickshell-mirror/quickshell`), m3shapes `32ad9ce328bb77ed349b40a3be10ee9ea610b8ab`, materialyoucolor 3.0.4 sdist sha256 `30b8dde034dce180845b0eaf52f72c5b22cd5b60bd7aff96804febae4e266276`.
- Nome visibile **oversicaOS**; nomi interni (`/etc/vetro`, `vetro-*`, `lfs.sh`, funzioni) invariati.
- Logo "Orbita": anello aperto in alto a destra, puntino `#d9704a`, segno `#eeece4` su scuro, `#1f201c` su chiaro, punte tonde.
- Sfondo predefinito "Grafite" 2560×1440, JPEG < 700 KB.
- Barra: solo quella di Caelestia a sinistra, `bar.persistent = false`.
- Modalità fantasma non cambia più lo sfondo.
- Tutti i testi per l'utente in italiano semplice; commenti nei file come oggi ("creato da lfs.sh").
- Hyprland legge solo Lua: ogni `hl.*` passa da `test_lua.py` (Hyprland finto con `api_hyprland.json`).
- Ogni download fuori dai pacchetti ha versione fissa e controllo (commit git o sha256).
- Il risultato consegnato è **un solo file**: `arch/dist/lfs.sh`.

## Review Focus

1. Aggiornamento di una macchina già installata (rete iwd/networkd, pannelli vecchi, `~/.config/hypr/*.lua` esistenti): `fase10` deve finire senza perdere la rete a metà e il desktop deve partire con Caelestia → prova in Task 9 (`test_rete_cambia_al_riavvio`).
2. Un ritocco che non si applica (Caelestia cambiato o file corrotto): l'installazione si ferma con messaggio chiaro, non installa metà → Task 3 (`test_ritocco_che_non_si_applica`).
3. Utente che ha già un `~/.config/caelestia/shell.json` suo: le scelte di oversicaOS si aggiungono solo dove mancano, non sovrascrivono → Task 5 (`test_config_non_sovrascrive`).
4. App installate dall'utente con Wine (voci `wine-Programs-*`): devono restare nel menu, si nascondono solo gli strumenti di Wine → Task 6 (`test_programmi_windows_restano`).
5. Avatar con scelte mancanti o fuori elenco in `avatar.json`: si usa la scelta predefinita, mai un'immagine rotta → Task 13 (`test_scelte_strane`).

---

## Tappa 1 — Base

### Task 1: Sorgenti a versione fissa

**Files:**
- Create: `arch/src/45-caelestia.sh`
- Modify: `arch/src/20-pacchetti.sh` (`compila_quickshell`, `installa_quickshell`)
- Test: `arch/test/test-caelestia.sh`

**Interfaces:**
- Produces: `CAELESTIA_SHELL_COMMIT`, `CAELESTIA_CLI_COMMIT`, `QUICKSHELL_COMMIT`, `M3SHAPES_COMMIT`, `MATERIALYOU_URL`, `MATERIALYOU_SHA256`; `scarica_git URL COMMIT CARTELLA` (0 se la cartella contiene esattamente COMMIT, altrimenti `muori "Non riesco a scaricare NOME alla versione giusta"`); `scarica_controllato URL SHA256 FILE`.

- [ ] **Step 1: prove che falliscono** in `test-caelestia.sh`: `test_scarica_git_giusto` (finto `git` che crea la cartella e risponde a `rev-parse HEAD` con il commit → esito 0, chiamato `git fetch --depth 1 origin COMMIT`), `test_scarica_git_commit_diverso` (rev-parse risponde altro → esce 1, messaggio contiene "versione giusta", cartella rimossa), `test_scarica_controllato_sha_sbagliato` (curl finto scrive "x" → esce 1, file non resta), `test_quickshell_sempre_compilato` (anche se `pacman -Si quickshell` riesce, `installa_quickshell` chiama `scarica_git https://github.com/quickshell-mirror/quickshell 9b0f339…` e `cmake`).
- [ ] **Step 2:** `bash arch/test/test-caelestia.sh` → FALLISCE (funzioni mancanti).
- [ ] **Step 3:** scrivi le funzioni in `45-caelestia.sh` (`git init`, `git remote add`, `git fetch --depth 1 origin COMMIT`, `git checkout -q FETCH_HEAD`, controllo `rev-parse`); `compila_quickshell` usa `scarica_git` al posto di curl+tar (togli `QUICKSHELL_URL/SHA256`), `installa_quickshell` compila sempre (Caelestia vuole la versione git).
- [ ] **Step 4:** `bash arch/test/test-caelestia.sh && bash arch/test/test-pacchetti.sh` → tutto ok.
- [ ] **Step 5:** commit `lfs: sorgenti di Caelestia e Quickshell a versione fissa (git)`.

### Task 2: Pacchetti e compilazione di Caelestia

**Files:**
- Modify: `arch/src/45-caelestia.sh`, `arch/src/40-fase2-desktop.sh` (`PKG_FASE2`)
- Test: `arch/test/test-caelestia.sh`

**Interfaces:**
- Consumes: Task 1.
- Produces: `PKG_CAELESTIA=(...)`; `compila_caelestia` (in ordine: libcava se serve, m3shapes, materialyoucolor, cli, shell; `muori` con il nome del pezzo se una compilazione fallisce); `CAELESTIA_SORGENTE` (cartella dei sorgenti preparati, usata da Task 3).

- [ ] **Step 1: prove**: `test_ordine_compilazione` (finti git/cmake/python/pkg-config; `.chiamate` contiene in quest'ordine `m3shapes`, `materialyoucolor`, `cli`, `shell`), `test_cmake_shell` (chiamato `cmake … -DVERSION=oversica -DGIT_REVISION=bcbb5d5… -DDISTRIBUTOR=oversicaOS -DENABLE_MODULES=extras;plugin;shell`), `test_libcava_dai_pacchetti` (`pkg-config --exists libcava` riesce → niente compilazione di libcava), `test_compilazione_che_fallisce` (cmake finto esce 1 sulla shell → esce 1, messaggio contiene "Caelestia").
- [ ] **Step 2:** prove → FALLISCONO.
- [ ] **Step 3:** `PKG_CAELESTIA` = dipendenze dello spec §4.1 dai pacchetti ufficiali + `git gettext python-build python-installer python-hatch python-hatch-vcs python-pillow pybind11 python-setuptools networkmanager cava`; materialyoucolor: `scarica_controllato` sdist → `python -m build --wheel --no-isolation` → `python -m installer`; cli: `python -m build --wheel --no-isolation` → `python -m installer`; libcava: se manca `pkg-config libcava|cava`, `muori` con messaggio "manca libcava" (la versione da compilare si sceglie solo se serve davvero sulla macchina: ledger).
- [ ] **Step 4:** `bash arch/test/test-caelestia.sh && bash arch/test/test-pacchetti.sh` → ok.
- [ ] **Step 5:** commit `lfs: compila Caelestia (m3shapes, materialyoucolor, cli, shell)`.

### Task 3: Ritocchi di oversicaOS

**Files:**
- Create: `arch/file/usr/local/lib/vetro/caelestia/ritocchi/` (cartella dei `.patch`, numerati `NN-nome.patch`), `arch/file/usr/local/lib/vetro/caelestia/nuovi/` (file da sovrapporre, stessi percorsi dei sorgenti), `arch/test/caelestia-originali/` (copie dei soli file di Caelestia toccati dai patch, al commit fisso)
- Modify: `arch/src/45-caelestia.sh`
- Test: `arch/test/test-ritocchi.sh`

**Interfaces:**
- Produces: `applica_ritocchi SORGENTE` (copia `nuovi/` sopra, poi `patch -p1 --forward --batch` per ogni `.patch` in ordine; al primo errore `muori "Un ritocco di oversicaOS non si applica a Caelestia (NOME): lfs.sh va aggiornato"`); chiamata da `compila_caelestia` prima di `cmake`. Ogni task successivo che tocca Caelestia aggiunge il suo `.patch` e la copia dell'originale in `caelestia-originali/`.

- [ ] **Step 1: prove**: `test_tutti_i_ritocchi_si_applicano` (copia `caelestia-originali/` in una cartella, `applica_ritocchi` → esito 0, nessun `.rej`), `test_ritocco_che_non_si_applica` (originale cambiato a mano → esce 1, messaggio contiene il nome del patch), `test_nuovi_sovrapposti` (un file di `nuovi/` finisce nel sorgente).
- [ ] **Step 2:** → FALLISCONO. **Step 3:** implementa. **Step 4:** ok. **Step 5:** commit `lfs: ritocchi di oversicaOS su Caelestia`.

Come si fanno i patch: in un clone di Caelestia al commit fisso, modifica, `git diff > NN-nome.patch`, copia gli originali toccati in `caelestia-originali/`.

### Task 4: Logo, nome e os-release

**Files:**
- Create: `arch/strumenti/disegna-logo.py` (Orbita: SVG + PNG), `arch/file/usr/share/icons/hicolor/scalable/apps/oversicaos.svg`, `arch/file/usr/share/icons/hicolor/{16,24,32,48,64,128,256,512}x…/apps/oversicaos.png`, `arch/file/usr/share/icons/hicolor/scalable/apps/oversicaos-tessera.svg`, `arch/file/etc/os-release`
- Modify: `arch/src/30-fase1-sistema.sh` (nuovo passo `nome`), `arch/file/usr/local/lib/vetro/installa-arch` (hostname `oversica`, `GRUB_DISTRIBUTOR="oversicaOS"`)
- Test: `arch/test/test-nome.sh`

**Interfaces:**
- Produces: icona `oversicaos` (Caelestia la usa da sola: `LOGO=oversicaos` in os-release, `general.logo` vuoto); passo `nome|f1_nome|etc/os-release …` (installa os-release e icone, `hostnamectl set-hostname oversica`, `GRUB_DISTRIBUTOR` in `/etc/default/grub` + `grub-mkconfig` se c'è grub).

- [ ] **Step 1: prove**: `test_os_release` (righe esatte `NAME="oversicaOS"`, `PRETTY_NAME="oversicaOS"`, `ID=oversicaos`, `ID_LIKE=arch`, `LOGO=oversicaos`), `test_icone` (svg e 8 png con la misura giusta, letta dall'header PNG), `test_f1_nome` (finti hostnamectl/grub-mkconfig: chiamati `hostnamectl set-hostname oversica`, `/etc/default/grub` contiene `GRUB_DISTRIBUTOR="oversicaOS"`), `test_installa_arch_nome` (contiene `oversica` come hostname e GRUB_DISTRIBUTOR).
- [ ] **Step 2–4:** fallisce → implementa (disegno come la bozza A approvata) → ok.
- [ ] **Step 5:** commit `lfs: logo Orbita e nome oversicaOS`.

### Task 5: Caelestia come desktop

**Files:**
- Modify: `arch/src/40-fase2-desktop.sh` (`f2_desktop`: installa pacchetti + `compila_caelestia`; `FILE_DESKTOP` senza i pannelli di Vetro), `arch/file/usr/local/bin/avvia-pannelli` (avvia `qs -c caelestia`), `arch/file/usr/local/bin/avvia-desktop` (prima volta: `oversica-config`), `arch/file/etc/xdg/hypr/vetro.lua` (tasti e regole di Caelestia), `arch/src/90-comandi.sh` (registri: `~/.cache/quickshell-vetro.log` resta il nome del registro)
- Create: `arch/file/usr/local/bin/oversica-config` (Python), `arch/file/usr/local/lib/vetro/caelestia/nuovi/daemons/Oversica.qml` (+ patch su `shell.qml` per caricarlo)
- Test: `arch/test/test-pannelli.sh`, `arch/test/python/test_lua.py`, `arch/test/python/test_config.py`

**Interfaces:**
- Consumes: Task 2 (`compila_caelestia`), Task 3.
- Produces: `IpcHandler { target: "oversica"; function ping(): string }` che risponde `ok` (avvia-pannelli lo usa con `qs -c caelestia ipc call oversica ping`); `oversica-config` = unisce in `~/.config/caelestia/shell.json` solo le chiavi mancanti: `bar.persistent=false`, `general.language="it"`, `paths.wallpaperDir="/usr/share/backgrounds"`, `launcher.hiddenApps=[]` (filtro vero nel Task 6), `general.apps.terminal=["foot"]`, `general.apps.explorer=["thunar"]`.

- [ ] **Step 1: prove**: `test_config.py::test_config_nuova` (file mancante → scrive le chiavi sopra), `test_config_non_sovrascrive` (`bar.persistent=true` già scritto dall'utente → resta true, le altre si aggiungono), `test_config_rovinata` (JSON non valido → copia `shell.json.rovinato` e ne scrive uno nuovo); `test_pannelli.sh`: `test_avvia_caelestia` (chiamato `quickshell -c caelestia`, ping `ipc call oversica ping`), le due prove di blocco già esistenti adattate; `test_lua.py::ProvaDesktop.test_tasti` con le scorciatoie di Caelestia: `SUPER + SUPER_L` (release) → `global caelestia:launcher`, `SUPER + L` → `global caelestia:lock`, `CTRL + ALT + DELETE` → `global caelestia:session`, `SUPER + A` → `global caelestia:sidebar`, `SUPER + D` → `global caelestia:dashboard`, `XF86AudioPlay` → `global caelestia:mediaToggle`, `PRINT` → `global caelestia:screenshot`; regole livelli `caelestia-(drawers|background)` animazione `fade`, `caelestia-(border-exclusion|area-picker)` `no_anim`; nessun `quickshell:` rimasto; avvio: `hl.exec_cmd("/usr/local/bin/avvio-vetro")` invariato.
- [ ] **Step 2–4:** fallisce → implementa (tasti presi da `caelestia-dots/hypr/hyprland/keybinds.lua` e `rules.lua` a commit `01d2df329240be60148d25804690779a078c6378`, GPL-3, adattati) → ok.
- [ ] **Step 5:** commit `lfs: Caelestia al posto dei pannelli di Vetro`.

### Task 6: Menu senza app di sistema

**Files:**
- Create: `arch/file/usr/local/lib/vetro/caelestia/nuovi/utils/FiltroApp.js`, patch `NN-menu-filtro.patch` su `modules/launcher/services/Apps.qml`
- Test: `arch/test/python/test_filtro_app.py`

**Interfaces:**
- Produces: `FiltroApp.nascosta(app) -> bool` (app = `{id, categories, noDisplay}`); Apps.qml filtra con `!FiltroApp.nascosta(a) && !Strings.testRegexList(hiddenApps, a.id)`.
- Regola: nascosta se `noDisplay`; se l'id corrisponde a `^(wine|winecfg|org\.winehq\.)` o `^wine-(notepad|regedit|uninstaller|winecfg|wordpad|oleview|winemine|winhelp|mime-msi|winefile|cmd|taskmgr|control|iexplore|msiexec)`; se le categorie contengono `System` o `Settings` **e** nessuna di `TerminalEmulator`, `FileManager`, `Monitor`; se l'id è in `["avahi-discover","bssh","bvnc","qv4l2","qvidcap","lstopo","nm-connection-editor","foot-server","footclient","thunar-settings","thunar-bulk-rename","xfce4-about","cmake-gui","designer","linguist","assistant","qdbusviewer","electron","jshell","yad-icon-browser"]` (ledger: aggiungere quelli trovati nella macchina).

- [ ] **Step 1: prove** (QJSEngine): `test_strumenti_wine_nascosti`, `test_programmi_windows_restano` (`wine-Programs-Notepad++` visibile), `test_terminale_e_file_restano` (foot `System;TerminalEmulator`, thunar `System;FileManager`), `test_impostazioni_nascoste` (`Settings;DesktopSettings`), `test_app_normali` (firefox `Network;WebBrowser`).
- [ ] **Step 2–4.** **Step 5:** commit `lfs: menu senza app di sistema`.

### Task 7: Sfondo Grafite e fantasma senza cambio di sfondo

**Files:**
- Modify: `arch/strumenti/disegna-sfondi.py` (funzione `grafite()` come la bozza approvata, con estremi dell'anello tondi), `arch/file/usr/local/bin/sfondo-desktop` (niente sfondo fantasma), `arch/src/60-fase4-sicurezza.sh` (non disegnare più `sfondo-fantasma.png`), `arch/file/etc/xdg/vetro/gtk-3.0.css` e `gtk-4.0.css` (app GTK come Thunar: accento `#d9704a`, fondi grafite; la prima riga resta `/* Vetro (creato da vetro-arch.sh)` perché avvia-desktop la riconosce)
- Create: `arch/file/usr/share/backgrounds/oversica-grafite.jpg`, `arch/file/usr/local/lib/vetro/caelestia/nuovi/assets/wallpaper.webp` (stessa immagine, è lo sfondo di riserva di Caelestia), patch `NN-fantasma-barra.patch` (icona `visibility_off` negli StatusIcons della barra quando esiste `/etc/fantasma/attivo`, letta con FileView)
- Test: `arch/test/test-grafica.sh`

- [ ] **Step 1: prove**: `test_sfondo_grafite`, `test_gtk_arancio` (`gtk-4.0.css` contiene `@define-color accent_bg_color #d9704a;`) (JPEG 2560x1440 < 700 KB), `test_wallpaper_webp` (header `RIFF….WEBP`), `test_fantasma_non_cambia_sfondo` (`sfondo-desktop --percorso` con `/etc/fantasma/attivo` finto non stampa `sfondo-fantasma`), `test_patch_fantasma` (il patch contiene `/etc/fantasma/attivo` e `visibility_off`).
- [ ] **Step 2–4.** **Step 5:** commit `lfs: sfondo Grafite, fantasma con icona nella barra`.

### Task 8: Rete con NetworkManager (attiva dal riavvio)

**Files:**
- Modify: `arch/src/40-fase2-desktop.sh` (togli il passo `rete` di iwd), `arch/src/60-fase4-sicurezza.sh` (ultimo passo `rete` nuovo: `f4_rete`), `arch/src/30-fase1-sistema.sh` (non spegnere più NetworkManager), `arch/file/etc/systemd/system/fantasma-avvio.service` (`Before=` anche `NetworkManager.service`), `arch/src/90-comandi.sh` (`SERVIZI_VETRO`: `NetworkManager` al posto di `systemd-networkd iwd`), `arch/file/usr/local/sbin/vetro-comando` (aspetta la rete anche con NM)
- Create: `arch/file/etc/NetworkManager/conf.d/10-oversica.conf` (`[main] dns=systemd-resolved`)
- Delete: `arch/file/etc/systemd/network/10-wifi.network`, `arch/file/etc/iwd/main.conf`, `arch/file/usr/local/bin/vetro-wifi`, `arch/test/python/test_wifi.py`
- Test: `arch/test/test-rete.sh`

**Interfaces:**
- Produces: passo `rete|f4_rete|etc/NetworkManager/conf.d/10-oversica.conf` ultimo in `FASE4`: `installa_pacchetti networkmanager`, installa il conf, `systemctl enable NetworkManager.service NetworkManager-wait-online.service`, `systemctl disable systemd-networkd.service systemd-networkd-wait-online.service iwd.service` — **niente `start`/`stop`** (vale dal riavvio); `10-cavo.network` resta per il primo avvio della macchina nuova.

- [ ] **Step 1: prove**: `test_rete_cambia_al_riavvio` (chiamati enable/disable come sopra, mai `systemctl start NetworkManager` né `stop`), `test_rete_ultimo_passo` (ultimo elemento di `FASE4` inizia con `rete|`), `test_leggero_non_spegne_nm` (`f1_leggero` non disabilita `NetworkManager.service`), `test_fantasma_prima_di_nm`.
- [ ] **Step 2–4.** **Step 5:** commit `lfs: rete con NetworkManager (dal riavvio)`.

### Task 9: Via i pannelli di Vetro, file unico della tappa 1

**Files:**
- Delete: in `arch/file/etc/xdg/quickshell/vetro/` tutto tranne ciò che serve a `accesso.qml` fino al Task 10 (`accesso.qml`, `AccessoVista.qml`, `PasswordPillola.qml`, `Tema.qml`, `Icona.qml`); prove dei pannelli tolti (`test-barra.sh`, parti di `test-grafica.sh`, `test-anteprime.sh` per le Viste tolte, `test_schermi.py`, `test_letture.py`, `ProvaHyprJs` dove non serve più)
- Modify: `arch/src/40-fase2-desktop.sh` (al passo `desktop`: `rm -rf` dei pannelli vecchi in `/etc/xdg/quickshell/vetro` tranne quelli sopra)
- Test: tutta la suite

- [ ] **Step 1:** `test_pannelli_vecchi_tolti` (dopo `f2_desktop` in radice finta con un vecchio `Barra.qml` → non esiste più; `accesso.qml` esiste).
- [ ] **Step 2–4:** `bash arch/test/esegui.sh` → `=== TUTTO OK`; `bash arch/costruisci.sh` → `arch/dist/lfs.sh`, `bash -n` ok, `_estrai` contiene i ritocchi.
- [ ] **Step 5:** commit `lfs: tappa 1 di oversicaOS (Caelestia, logo, sfondo, menu, rete)`.

## Tappa 2 — Accesso e italiano

### Task 10: Accesso uguale al blocco

**Files:**
- Create: `…/caelestia/nuovi/accesso.qml` (radice del greeter dentro la cartella di Caelestia, così `qs.*` funziona), `…/caelestia/nuovi/modules/lock/AccessoGreetd.qml` (stessa interfaccia di `Pam.qml` usata da `Center`/`InputField`: `passwd.active`, `state`, `buffer`, `lockMessage`, `handleKey()`, `flashMsg`; dietro usa `Greetd.createSession/respond/launch`), patch `NN-blocco-avatar.patch` (`ProfilePic` legge `/var/lib/AccountsService/icons/<utente>` se esiste, poi `~/.face`)
- Modify: `arch/file/etc/vetro/accesso-hyprland.lua` (`qs -p /etc/xdg/quickshell/caelestia/accesso.qml`), `arch/src/40-fase2-desktop.sh` (`f2_accesso`), tolti gli ultimi file di `/etc/xdg/quickshell/vetro`
- Test: `arch/test/test-fase2-accesso.sh`, `arch/test/python/test_lua.py::ProvaAccesso`

**Interfaces:**
- Consumes: `/etc/vetro/utente` (nome dell'utente), avatar pubblico del Task 13.
- Produces: greeter che lancia `/usr/local/bin/avvia-desktop` dopo la password giusta.

- [ ] **Step 1: prove**: `ProvaAccesso.test_avvia_la_schermata_e_poi_esce` aggiornata al nuovo percorso; `test_greeter_file` (`accesso.qml` contiene `Greetd.createSession`, `Greetd.launch`, `/usr/local/bin/avvia-desktop`, usa `LockSurface`/`Content` di Caelestia); `test_vecchi_file_tolti`.
- [ ] **Step 2–4.** **Step 5:** commit `lfs: accesso uguale al blocco di Caelestia`.

### Task 11: Italiano

**Files:**
- Create: `…/caelestia/nuovi/plugin/src/Caelestia/I18n/it.po`, patch `NN-italiano.patch` (`po_files` contiene `it.po`), `arch/test/caelestia-testi.txt` (tutti i `Tr.tr*("…")` di Caelestia al commit fisso, una riga ciascuno)
- Test: `arch/test/python/test_italiano.py`

- [ ] **Step 1: prove**: `test_po_valido` (lettura con `polib`-free parser semplice: ogni voce ha msgid/msgstr), `test_tutte_le_voci_tradotte` (ogni riga di `caelestia-testi.txt` ha un msgstr non vuoto), `test_segnaposto` (`%1`, `%n`, `%L1` uguali in msgid e msgstr), `test_voci_esistenti` (nessun msgid che non sia in `caelestia-testi.txt`).
- [ ] **Step 2–4.** **Step 5:** commit `lfs: Caelestia in italiano`.

## Tappa 3 — Avatar e Account

### Task 12: Dati dei pixel e disegnatore dell'avatar

**Files:**
- Create: `arch/file/usr/share/oversica/avatar/pixel.json` (griglia 16×24: corpo, 6 capigliature, tavolozze: capelli 8, pelle 6, maglia 8 — tinte come Lodge), `arch/file/usr/local/bin/oversica-avatar` (Python: `oversica-avatar disegna SCELTE.json USCITA.png [--lato 256]`), `…/caelestia/nuovi/utils/Avatar.js` (`griglia(dati, scelte) -> [[colore|null]]`)
- Test: `arch/test/python/test_avatar.py`

**Interfaces:**
- Produces: scelte = `{"capelli": "corti|folti|lunghi|raccolti|ricci|rasati", "coloreCapelli": 0-7, "pelle": 0-5, "maglia": 0-7}`; predefinite `{"capelli":"corti","coloreCapelli":2,"pelle":1,"maglia":2}`.

- [ ] **Step 1: prove**: `test_stessa_immagine` (due disegni uguali byte per byte), `test_ogni_scelta_cambia` (per ogni campo, cambiarlo cambia almeno un pixel e solo nelle zone di quel campo), `test_js_uguale_python` (griglia JS da QJSEngine == griglia Python), `test_scelte_strane` (`{"capelli":"blu","pelle":99}` → usa le predefinite per quei campi, PNG valido), `test_png_pixel_netti` (256×256, ogni blocco 16×16… colore unico).
- [ ] **Step 2–4.** **Step 5:** commit `lfs: avatar a pixel in stile Lodge`.

### Task 13: Pagina Account

**Files:**
- Create: `…/caelestia/nuovi/modules/nexus/pages/AccountPage.qml` (nome mostrato, anteprima avatar con `Avatar.js`, scelte come le foto di Lodge, Salva/Annulla, "Cambia password" apre il terminale con `passwd`), `arch/file/usr/local/sbin/oversica-avatar-pubblica` (copia `~/.face` dell'utente in `/var/lib/AccountsService/icons/<utente>`, 644), regola sudo in `arch/file/etc/sudoers.d/` come gli aiutanti di Vetro, patch `NN-nexus-account.patch` (voce in `PageRegistry.pages` + `PageCompRegistry.pageComps` alla stessa posizione)
- Test: `arch/test/test-account.sh`, `arch/test/python/test_avatar.py`

- [ ] **Step 1: prove**: `test_pubblica_avatar` (radice finta: file copiato, permessi 644, rifiuta percorsi con `..`), `test_sudoers_solo_aiutante`, `test_patch_registro_allineato` (dopo `applica_ritocchi` sugli originali: stesso numero di voci in `pages` e `pageComps`, "Account" in entrambe alla stessa posizione).
- [ ] **Step 2–4.** **Step 5:** commit `lfs: pagina Account con avatar`.

## Tappa 4 — Pagine nuove delle impostazioni

### Task 14: Pagine Schermo, Tastiera/mouse, Accessibilità (file Lua di Hyprland)

**Files:**
- Create: `…/nexus/pages/SchermoPage.qml`, `TastieraPage.qml`, `AccessibilitaPage.qml`, `…/caelestia/nuovi/utils/HyprImpostazioni.js` (porta `Hypr.js`: `impostazioni(o, schermi, scelte)` → testo di `~/.config/hypr/vetro-impostazioni.lua`, ora con tastiera, velocità, scorrimento naturale, tocco per clic, animazioni), patch del registro
- Test: `arch/test/python/test_lua.py` (testo generato passa l'Hyprland finto), `test_schermi.py` riportato su `HyprImpostazioni.js`

- [ ] Prove: `test_impostazioni_predefinite_come_il_file`, `test_tastiera_us` (`input.kb_layout="us"`), `test_touchpad` (`input.touchpad.natural_scroll`, `input.touchpad.tap_to_click`), `test_meno_animazioni` (`animations.enabled=false`), le prove degli schermi di oggi. Poi implementa, suite ok, commit `lfs: impostazioni Schermo, Tastiera e Accessibilità`.

### Task 15: Privacy e sicurezza, Energia e blocco, Notifiche, Data e ora, Archiviazione

**Files:**
- Create: `…/nexus/pages/PrivacyPage.qml` (fantasma, firewall, Guardiano, DNS cifrato, cassaforte: chiamano `fantasma`, `vpn`, `cassaforte`, `guardiano-regole` e gli aiutanti sudo di oggi), `EnergiaPage.qml` (`general.idle.timeout` di Caelestia, `powerprofilesctl`), `NotifichePage.qml` (Non disturbare di Caelestia), `DataOraPage.qml` (`timedatectl set-timezone` via nuovo aiutante `oversica-data` con sudoers), `ArchiviazionePage.qml` (`df -h /`, `gio trash --empty`, `~/.cache` temporanei), patch del registro
- Create: `arch/file/usr/local/sbin/oversica-data`
- Test: `arch/test/test-impostazioni.sh`

- [ ] Prove: `test_oversica_data_fuso_valido` (accetta `Europe/Rome`, rifiuta `../../etc`), `test_oversica_data_24h`, `test_pagine_registrate` (tutte le pagine dello spec §6.3 in `pages` e `pageComps` alla stessa posizione, in quest'ordine: Account, Sfondo e stile, Schermo, Rete, Dispositivi connessi, Audio, Privacy e sicurezza, Energia e blocco, Notifiche, Tastiera mouse e touchpad, Data e ora, Archiviazione, Accessibilità, Aggiornamenti, Pannelli, App, Lingua e area, Informazioni), `test_qml_sintassi` (pyside6-qmllint `[syntax]` assente su tutti i file nuovi). Poi implementa, suite ok, commit `lfs: le altre pagine delle impostazioni`.

### Task 16: File unico, guida, consegna

**Files:**
- Modify: `arch/GUIDA-INSTALLAZIONE.md` (oversicaOS, tasti principali, fantasma), `arch/src/00-testa.sh` (testi "oversicaOS"), `arch/src/90-comandi.sh` (`aiuto`)
- Test: suite intera + `test-tutto.sh`

- [ ] Patch `NN-informazioni.patch` su `AboutPage.qml`: riga "oversicaOS è basato su Caelestia (GPL-3)" con il collegamento al progetto; prova che il patch la contiene.
- [ ] `test-tutto.sh` aggiornato: il giro completo con i finti di Caelestia (git, cmake, python) finisce, poi la seconda volta non rifà nulla.
- [ ] `bash arch/test/esegui.sh` → `=== TUTTO OK`; `bash arch/costruisci.sh`; `bash -n arch/dist/lfs.sh`; `_estrai` contiene ritocchi, avatar, logo, sfondo.
- [ ] Revisione finale del ramo; commit `lfs: oversicaOS completo`; push; consegna di `arch/dist/lfs.sh`.
