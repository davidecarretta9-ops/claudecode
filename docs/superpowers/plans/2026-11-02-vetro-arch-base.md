# Vetro su Arch — piano di lavoro della base

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** uno script unico, `vetro-arch.sh`, che trasforma un Arch Linux appena installato nel sistema "Vetro" (desktop leggero con aspetto GNOME, accesso con greetd, funzioni di sicurezza di `lfs.sh`), più `vetro-vm.sh` per provarlo in una macchina virtuale.

**Architecture:** i sorgenti stanno in `arch/` divisi per responsabilità: pezzi di script in `arch/src/` e file da installare in `arch/file/`, che rispecchia il disco di destinazione. `arch/costruisci.sh` li unisce in un solo file, `arch/dist/vetro-arch.sh`: gli script uno dopo l'altro, più un archivio `tar.gz` in base64 in fondo. Ogni scrittura passa da `VETRO_RADICE` e ogni comando di sistema da `esegui`, così tutto si prova in una radice finta con comandi finti.

**Tech Stack:** bash 5, Python 3 (solo libreria standard), QML/Quickshell, Hyprland, greetd, systemd (networkd, resolved, oomd, zram-generator), iwd, iptables (backend nft), Tor, WireGuard, bubblewrap, Wine. Prove: bash, `python3 -m unittest`, `pyside6-qmllint` (PySide6 in un venv usa e getta).

**Spec:** `docs/superpowers/specs/2026-11-02-vetro-arch-base-design.md`

## Global Constraints

- Messaggi per l'utente in italiano, parole semplici; righe di controllo che iniziano con `[OK]`.
- Un solo file da scaricare: `arch/dist/vetro-arch.sh`. Si lancia come root su Arch (`/etc/arch-release` deve esistere).
- Solo pacchetti dei repository ufficiali di Arch (core, extra, multilib): niente AUR. Unico ripiego: Quickshell compilato dai sorgenti v0.3.2 (`https://git.outfoxxed.me/quickshell/quickshell/archive/v0.3.2.tar.gz`, sha256 `f14115a73c9fff6aa6399f924b632e88c3ce2cead2657f814a7825341f35baad`) se `pacman -Si quickshell` fallisce.
- Disco: ext4 + LUKS (scelti in `archinstall`, guida in `arch/GUIDA-INSTALLAZIONE.md`).
- Desktop: Hyprland + Quickshell, aspetto GNOME (Adwaita scuro, Adwaita Sans/Mono, icone Adwaita), barra in alto: sinistra app + scrivanie, centro data e ora, destra niente; dock in basso; pulsanti delle finestre a destra (riduci, ingrandisci, chiudi), grigi e tondi.
- Accesso: greetd; il desktop parte solo dopo la password; scelta utente (il proprio o `fantasma`); password con PAM.
- Rete: systemd-networkd + systemd-resolved + iwd (niente NetworkManager).
- Memoria: zram (metà della RAM) + systemd-oomd; da fermo dopo l'accesso **< 700 MB** usati.
- Modalità fantasma accesa di serie; durante l'installazione niente comandi su rete, nome del computer o firewall dell'ospite (solo file e `systemctl enable`).
- Ogni passo: riparte da dove era; rilanciato con lo stesso testo non rifà niente; se il suo testo o i suoi file cambiano si rifà da solo.

## Review Focus

- **Script interrotto a metà** (rete che cade durante `pacman`): rilanciandolo riprende dal passo fallito, senza rifare né duplicare i passi finiti → prova in Task 1 (`test_ripresa_dopo_errore`).
- **Lanciato da utente normale o non su Arch**: si ferma subito con un messaggio chiaro e non tocca niente → prova in Task 1 (`test_non_root_non_arch`).
- **Primo avvio senza internet con la modalità fantasma accesa**: l'accesso e il desktop funzionano, "Spegni" risponde subito → prova in Task 9 (`test_spegni_senza_tor`).
- **Disco non ext4** (btrfs scelto per sbaglio): la cassaforte lo dice e salta, il resto dello script continua → prova in Task 10 (`test_cassaforte_senza_ext4`).
- **Uno schermo staccato o attaccato con il desktop acceso**: barra e dock compaiono e spariscono, le regole salvate non citano schermi assenti → prova in Task 6 (`test_regole_schermi_spariti`).

---

## Struttura dei file

```
arch/
  costruisci.sh                 unisce src/ e file/ in dist/vetro-arch.sh
  GUIDA-INSTALLAZIONE.md        archinstall passo passo (minimal, ext4, LUKS, rete del CD)
  src/00-testa.sh               costanti, messaggi, radice, esegui, installa_file
  src/10-passi.sh               motore dei passi: segni, impronte, ripresa, registri
  src/20-pacchetti.sh           multilib, controllo e installazione pacchetti, ripiego Quickshell
  src/30-fase1-sistema.sh       sistema leggero
  src/40-fase2-desktop.sh       desktop, accesso, schermi, Wi-Fi
  src/50-fase3-programmi.sh     programmi
  src/60-fase4-sicurezza.sh     sicurezza
  src/90-comandi.sh             comandi tutto/controlla/registri/rifai e avvio
  file/...                      file installati (stesso percorso sul disco di destinazione)
  strumenti/importa-da-lfs.py   copia una volta i file da lfs.sh in file/
  vm/vetro-vm.sh                macchina virtuale sul PC (Fedora)
  test/lib.sh                   radice finta, comandi finti, confronti
  test/esegui.sh                esegue tutti i test-*.sh e i test Python
  test/test-*.sh                prove dei pezzi di script
  test/python/test_*.py         prove dei programmi Python
  dist/vetro-arch.sh            generato da costruisci.sh (si consegna questo)
```

---

### Task 1: Scheletro, motore dei passi e costruzione del file unico

**Files:**
- Create: `arch/src/00-testa.sh`, `arch/src/10-passi.sh`, `arch/src/90-comandi.sh`, `arch/costruisci.sh`, `arch/test/lib.sh`, `arch/test/esegui.sh`, `arch/test/test-passi.sh`, `arch/file/.gitkeep`

**Interfaces:**
- Produces (00-testa.sh): `info MSG`, `ok MSG` (stampa `  [OK] MSG`), `avviso MSG`, `muori MSG` (exit 1); `serve_root`; `controlla_arch` (muore se manca `$VETRO_RADICE/etc/arch-release`); `percorso P` → `"$VETRO_RADICE$P"`; `esegui CMD...` (esegue il comando; con `VETRO_RADICE` non vuoto lo cerca prima in `$VETRO_RADICE/.finti`); `installa_file REL...` (copia `$VETRO_FILE/REL` in `$(percorso /REL)` tenendo i permessi, crea le cartelle); variabili `VETRO_RADICE` (vuota), `VETRO_STATO=$(percorso /var/lib/vetro-arch)`, `VETRO_FILE` (cartella dei file estratti).
- Produces (10-passi.sh): `impronta FUNZIONE [REL...]` → sha256 di `declare -f FUNZIONE` più il contenuto dei file elencati; `passo NOME FUNZIONE [REL...]` → salta se `$VETRO_STATO/fatto/NOME` contiene la stessa impronta, altrimenti esegue FUNZIONE in una sottoshell con `set -Eeuo pipefail` e registro `$VETRO_STATO/registri/NOME.log`; se fallisce: `muori` con le ultime 15 righe del registro; se riesce scrive il segno con l'impronta; `rifai_passo NOME` toglie il segno.
- Produces (90-comandi.sh): `principale "$@"` con `tutto` (predefinito), `controlla`, `registri`, `rifai NOME`, `aiuto`; non parte se `VETRO_PROVA=1` (i test lo includono con `source`). Le liste dei passi arrivano dai task dopo: `FASE1 FASE2 FASE3 FASE4`, array di righe `"nome|funzione|file1 file2"`.
- Produces (costruisci.sh): `bash arch/costruisci.sh` → scrive `arch/dist/vetro-arch.sh` = shebang + `src/*.sh` in ordine + riga `__VETRO_ARCHIVIO__` + `tar -C arch/file -cz . | base64 -w 76`; all'avvio lo script estrae l'archivio in una cartella temporanea (`VETRO_FILE`) e la cancella all'uscita.
- Produces (test/lib.sh): `radice_finta` (crea `RADICE`, esporta `VETRO_RADICE`, `VETRO_FILE=arch/file`, `VETRO_PROVA=1`, crea `etc/arch-release`); `finto CMD [ESITO]` (crea `$RADICE/.finti/CMD` che aggiunge `CMD argomenti` a `$RADICE/.chiamate` ed esce con ESITO); `uguale ATTESO OTTENUTO DESCR`; `contiene FILE TESTO`; `esiste P`; `chiamato TESTO` (TESTO è in `.chiamate`); `riassunto` (exit 1 se qualcosa è fallito).

- [ ] **Step 1: Scrivi i test in `arch/test/test-passi.sh`**
  - `test_passo_una_volta`: un passo che aggiunge "x" a un file, eseguito due volte → il file contiene una sola "x".
  - `test_impronta_cambiata`: ridefinisci la funzione con un testo diverso → `passo` la riesegue (due "x").
  - `test_ripresa_dopo_errore`: tre passi, il secondo esce con 1 → `principale tutto` esce con 1, il primo ha il segno, il terzo no; dopo aver corretto il secondo, `principale tutto` esegue solo il secondo e il terzo.
  - `test_non_root_non_arch`: senza `etc/arch-release` → `controlla_arch` esce con 1 e il messaggio contiene "Arch"; con utente diverso da 0 `serve_root` esce con 1 (prova in sottoshell con `EUID` finto tramite `VETRO_EUID`).
  - `test_file_unico`: `bash arch/costruisci.sh`, poi `bash -n arch/dist/vetro-arch.sh` riesce e `VETRO_PROVA=1 bash arch/dist/vetro-arch.sh aiuto` stampa l'elenco dei comandi; un file in `arch/file/prova.txt` estratto dall'archivio è uguale all'originale.
- [ ] **Step 2: Esegui e verifica che falliscano** — `bash arch/test/esegui.sh` → FALLITO (le funzioni non esistono).
- [ ] **Step 3: Scrivi `00-testa.sh`, `10-passi.sh`, `90-comandi.sh`, `costruisci.sh`, `lib.sh`, `esegui.sh`** secondo le interfacce sopra (`serve_root` legge `${VETRO_EUID:-$EUID}`).
- [ ] **Step 4: Esegui** — `bash arch/test/esegui.sh` → tutti `ok`, uscita 0.
- [ ] **Step 5: Commit** — `git add arch && git commit -m "arch: scheletro, motore dei passi e file unico"`

---

### Task 2: Pacchetti

**Files:**
- Create: `arch/src/20-pacchetti.sh`, `arch/test/test-pacchetti.sh`

**Interfaces:**
- Consumes: `esegui`, `percorso`, `muori`, `ok` (Task 1).
- Produces: `abilita_multilib` (toglie il `#` alle due righe `[multilib]` e `Include` di `$(percorso /etc/pacman.conf)`, poi `esegui pacman -Sy`); `controlla_pacchetti PKG...` (per ognuno `esegui pacman -Si PKG`; stampa i mancanti; esce con 1 se ne manca qualcuno); `installa_pacchetti PKG...` (`esegui pacman -S --needed --noconfirm PKG...`, fino a 3 tentativi); `compila_quickshell` (scarica il tarball v0.3.2, controlla lo sha256 delle Global Constraints, compila con cmake/ninja, installa in `/usr`); `controlla_tutti_i_pacchetti` → `controlla_pacchetti` su tutti gli array `PKG_FASE1..PKG_FASE4` definiti (dai task delle fasi), tranne `quickshell` che se manca passa a `compila_quickshell`; `cmd_tutto` (Task 1) la chiama prima delle fasi, dopo `abilita_multilib`.

- [ ] **Step 1: Test** in `test-pacchetti.sh`:
  - `test_multilib`: un `pacman.conf` con `#[multilib]` e `#Include = /etc/pacman.d/mirrorlist` subito sotto → dopo `abilita_multilib` le due righe sono senza `#`, le altre righe uguali; rifarlo non cambia il file.
  - `test_mancanti`: `pacman` finto che fallisce solo per `-Si inesistente` → `controlla_pacchetti hyprland inesistente` esce con 1 e stampa "inesistente".
  - `test_tentativi`: `pacman` finto che fallisce le prime due volte → `installa_pacchetti foot` riesce, `.chiamate` ha 3 righe `pacman -S --needed --noconfirm foot`.
  - `test_controllo_iniziale`: `PKG_FASE1=(a)`, `PKG_FASE3=(b)`, `pacman -Si b` che fallisce → `controlla_tutti_i_pacchetti` esce con 1 e stampa "b" prima di qualunque `pacman -S`.
  - `test_quickshell_ripiego`: con `pacman -Si quickshell` che fallisce, `curl` finto che scrive un file sbagliato → `compila_quickshell` esce con 1 e il messaggio contiene "controllo".
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi `20-pacchetti.sh`.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: pacchetti ufficiali e ripiego per Quickshell"`

---

### Task 3: Fase 1 — sistema leggero

**Files:**
- Create: `arch/src/30-fase1-sistema.sh`, `arch/file/etc/systemd/zram-generator.conf`, `arch/file/etc/systemd/oomd.conf.d/vetro.conf`, `arch/file/etc/systemd/journald.conf.d/vetro.conf`, `arch/test/test-fase1.sh`

**Interfaces:**
- Consumes: `passo`, `installa_file`, `installa_pacchetti`, `esegui`.
- Produces: `PKG_FASE1=(zram-generator python sudo)`; `FASE1=("leggero|f1_leggero|etc/systemd/zram-generator.conf etc/systemd/oomd.conf.d/vetro.conf etc/systemd/journald.conf.d/vetro.conf" "utente|f1_utente|")`; `utente_vetro` → nome dell'utente (da `$(percorso /etc/vetro/utente)`, altrimenti il primo con UID 1000 da `getent passwd 1000`, scritto poi in `/etc/vetro/utente`).
- Valori: `zram-generator.conf` = `[zram0]` / `zram-size = ram / 2` / `compression-algorithm = zstd`; `oomd`: `[OOM]` / `DefaultMemoryPressureDurationSec=20s`; `journald`: `SystemMaxUse=100M`. `f1_leggero` abilita `systemd-oomd.service` e `systemd-zram-setup@zram0.service` (gestito dal generatore) e disattiva i servizi non usati se presenti: `NetworkManager.service`, `cups.service`, `bluetooth.service` (solo se nessun dispositivo bluetooth: `ls /sys/class/bluetooth` vuoto). `f1_utente` aggiunge l'utente ai gruppi `wheel video input audio` e scrive `/etc/sudoers.d/00-vetro` (`%wheel ALL=(ALL) ALL`, permessi 440).

- [ ] **Step 1: Test** `test-fase1.sh`: `test_file_leggero` (i tre file ci sono con i valori sopra), `test_servizi` (`chiamato "systemctl enable systemd-oomd.service"`, `chiamato "systemctl disable --now NetworkManager.service"` solo se il file del servizio esiste nella radice finta), `test_utente` (con `getent` finto che restituisce `mario:x:1000:...` → `/etc/vetro/utente` = `mario`, `chiamato "usermod -aG wheel,video,input,audio mario"`, sudoers con permessi 440).
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi la fase e i file.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: fase 1, sistema leggero"`

---

### Task 4: Importare i file di Vetro da `lfs.sh`

**Files:**
- Create: `arch/strumenti/importa-da-lfs.py`, `arch/test/python/test_importa.py`, i file importati sotto `arch/file/`, `arch/test/test-importati.sh`

**Interfaces:**
- Produces: `python3 -I arch/strumenti/importa-da-lfs.py lfs.sh arch/file` → per ogni heredoc `cat > PERCORSO << "EOF"` (delimitatore tra virgolette) dentro le funzioni `f10_shell f10_aiutanti f10_config_hyprland f10_cursori f6_guardiano f6_cassaforte f6_vpn f6_recinto_wine f6_tor_browser f7_fantasma f7_utente_fantasma` scrive il contenuto in `arch/file/PERCORSO` (per `f10_shell` `"$d/X.qml"` diventa `etc/xdg/quickshell/vetro/X.qml`). Se lo stesso percorso compare più volte vince **l'ultima** definizione. Permesso 755 ai file sotto `usr/local/bin`, `usr/local/sbin`, `usr/local/lib`, 644 agli altri, 440 a `etc/sudoers.d/*`. Stampa l'elenco dei file scritti e quello degli heredoc saltati (senza virgolette: vanno riscritti a mano nei task dopo).
- Non importare: `vetro-password.c`, `controlla-3d`, `controlla-3d.service`, `scegli-desktop`, `scegli-desktop.desktop` (servivano solo con LFS).

- [ ] **Step 1: Test** `test_importa.py`: con un finto `lfs.sh` di due funzioni (`f10_shell` con `cat > "$d/A.qml" << "EOF"`, e `f7_fantasma` con due definizioni di `/usr/local/bin/x`) → `A.qml` in `etc/xdg/quickshell/vetro/`, `usr/local/bin/x` ha il testo della seconda definizione e permesso 755; un heredoc `<< EOF` senza virgolette compare tra i saltati.
- [ ] **Step 2: Esegui** `python3 -I -m unittest discover -s arch/test/python` → FALLITO.
- [ ] **Step 3: Scrivi lo strumento, poi lancialo** sul vero `lfs.sh`.
- [ ] **Step 4: Test** `test-importati.sh`: almeno 34 file `.qml`; `bash -n` riesce su ogni script bash importato; `python3 -I -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())'` riesce sui Python (`fantasma-aiuto`, `guardiano-rete`, `cassaforte`, `disegna-*`); `pyside6-qmllint` non segnala errori `[syntax]` sui `.qml`. Esegui → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: file di Vetro importati da lfs.sh"`

---

### Task 5: Fase 2 — desktop con aspetto GNOME

**Files:**
- Create: `arch/src/40-fase2-desktop.sh`, `arch/test/test-fase2.sh`
- Modify: `arch/file/etc/xdg/hypr/vetro.conf`, `arch/file/etc/xdg/quickshell/vetro/Tema.qml`, `arch/file/etc/xdg/quickshell/vetro/Blocco.qml`, `arch/file/etc/xdg/quickshell/vetro/shell.qml`, `arch/file/usr/local/bin/avvia-desktop`, `arch/file/usr/local/bin/avvia-pannelli`
- Create: `arch/file/etc/pam.d/vetro-blocco`, `arch/file/etc/gtk-3.0/settings.ini`, `arch/file/etc/gtk-4.0/settings.ini`, `arch/file/usr/local/bin/vetro-barre-aggiorna`, `arch/file/etc/pacman.d/hooks/vetro-barre.hook`

**Interfaces:**
- Produces: `PKG_FASE2=(hyprland quickshell greetd xdg-desktop-portal-hyprland pipewire wireplumber pipewire-pulse adwaita-fonts adwaita-icon-theme gnome-themes-extra grim slurp swayidle libnotify jq git cmake ninja meson cpio)`; `FASE2=("desktop|f2_desktop|...")` più i passi dei Task 6 e 7.
- `vetro.conf` (da quello importato): togli gli `env` di LFS (`XCURSOR_THEME` resta `Vetro`), tieni `vetro-schermo.conf`, `vetro-barre.conf`, `debug {}`, il submap `vetro-accesso` va tolto (con greetd non serve); `vetro-barre.conf` scritto da `vetro-barre-aggiorna` con `bar_buttons_alignment = right` e tre `hyprbars-button` nell'ordine chiudi, ingrandisci, riduci (da destra), colore `rgba(ffffff26)`, simbolo vuoto, comandi come in `lfs.sh` (`killactive`, `fullscreen 1`, `global quickshell:riduci`).
- `Tema.qml`: palette Adwaita scura come tema predefinito `adwaita` (`fondo "#242424"`, `accento "#3584e4"`, testo `"#ffffff"`), gli altri temi restano.
- `etc/gtk-3.0/settings.ini` e `etc/gtk-4.0/settings.ini`: `[Settings]` / `gtk-theme-name=Adwaita` / `gtk-application-prefer-dark-theme=1` / `gtk-icon-theme-name=Adwaita` / `gtk-cursor-theme-name=Vetro` / `gtk-cursor-theme-size=24` / `gtk-font-name=Adwaita Sans 11`.
- `Blocco.qml`: la password con `PamContext { config: "vetro-blocco" }` (Quickshell.Services.Pam) al posto del `Process` su `vetro-password`; `etc/pam.d/vetro-blocco` = `auth include system-auth` / `account include system-auth`.
- `avvia-desktop`: niente desktop classico né controllo 3D; scrive `~/.config/hypr/vetro-schermo.conf` come oggi e fa `exec Hyprland -c /etc/xdg/hypr/vetro.conf`. `avvia-pannelli`: niente `riserva` con xfce4-panel; dopo 3 errori rapidi una notifica "I pannelli non partono" e riprova ogni 30 s.
- `vetro-barre-aggiorna` (con `--commit-per VERSIONE FILE` stampa solo il commit trovato): legge la versione da `hyprctl version -j` (campo `tag`, es. `v0.54.3`), scarica `https://github.com/hyprwm/hyprland-plugins/archive/refs/heads/main.tar.gz`, trova in `hyprpm.toml` la riga il cui commento è la versione (`# 0.54.3`) e ne prende il secondo commit, scarica quel commit, `make -C hyprbars all`, installa `/usr/lib/hyprland-plugins/hyprbars.so`, scrive `/etc/xdg/hypr/vetro-barre.conf`. Senza riga per la versione: scrive un `vetro-barre.conf` vuoto e un avviso. L'hook pacman lo lancia dopo ogni aggiornamento di `hyprland`.

- [ ] **Step 1: Test** `test-fase2.sh`:
  - `test_conf_hyprland`: `vetro.conf` non contiene `vetro-accesso`, contiene `env = XCURSOR_THEME, Vetro` e `source = ~/.config/hypr/vetro-schermo.conf`.
  - `test_barre_versione`: con un `hyprpm.toml` di prova (`["521ece4...", "6acc073..."], # 0.54.3`) → `vetro-barre-aggiorna --commit-per 0.54.3 FILE` stampa `6acc073...`; con `0.99.0` non stampa niente ed esce con 1; `vetro-barre-aggiorna` con `hyprctl` finto che dice `{"tag":"v0.99.0"}` lascia `vetro-barre.conf` con solo un commento.
  - `test_blocco_pam`: `Blocco.qml` contiene `PamContext` e non contiene `vetro-password`; `etc/pam.d/vetro-blocco` contiene `auth include system-auth`.
  - `test_qml`: `pyside6-qmllint` senza errori `[syntax]` su tutti i `.qml`.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Fai le modifiche e scrivi `f2_desktop`** (installa i pacchetti, i file del desktop, i puntatori con `disegna-cursori`, gli sfondi con `disegna-vetro`, lancia `vetro-barre-aggiorna`, `systemctl --global enable pipewire wireplumber`).
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: fase 2, desktop con aspetto GNOME"`

---

### Task 6: Accesso con greetd e più schermi

**Files:**
- Create: `arch/file/etc/greetd/config.toml`, `arch/file/etc/vetro/accesso-hyprland.conf`, `arch/file/etc/xdg/quickshell/vetro/accesso.qml`, `arch/file/etc/xdg/quickshell/vetro/Schermi.js`, `arch/test/test-fase2-accesso.sh`, `arch/test/python/test_schermi.py`
- Modify: `arch/src/40-fase2-desktop.sh` (passi `accesso` e `schermi`), `arch/file/etc/xdg/quickshell/vetro/FinestraImpostazioni.qml` (pagina Schermo), `arch/file/etc/xdg/quickshell/vetro/Opzioni.qml`

**Interfaces:**
- `config.toml`: `[terminal] vt = 1` / `[default_session] command = "Hyprland -c /etc/vetro/accesso-hyprland.conf"` / `user = "greeter"`.
- `accesso-hyprland.conf`: niente tasti; `exec-once = qs -p /etc/xdg/quickshell/vetro/accesso.qml; hyprctl dispatch exit`; stesso `XCURSOR_THEME`.
- `accesso.qml`: aspetto del blocco schermo; elenco utenti = il proprio (da `/etc/vetro/utente`) e `fantasma`; usa `Greetd` (Quickshell.Services.Greetd): `createSession(utente)`, risponde alla domanda della password, poi `launch(["/usr/local/bin/avvia-desktop"])` e `Qt.quit()`; password sbagliata → scuote il campo e dice "Password sbagliata"; tasti Spegni/Riavvia (`systemctl poweroff|reboot`).
- `Schermi.js` (libreria JS pura, `.pragma library`): `regole(schermi, scelte)` → testo di regole Hyprland, una riga `monitor = NOME, RISOLUZIONE, POSIZIONE, SCALA` per ogni schermo **presente** in `schermi` (array da `hyprctl monitors -j`: `name`, `width`, `height`); `scelte` = oggetto per nome `{ risoluzione, posizione: "destra"|"sinistra"|"sopra"|"duplica", principale: bool, scala }`; il principale va a `0x0`, gli altri relativi a lui; `duplica` diventa `monitor = NOME, preferred, auto, 1, mirror, PRINCIPALE`.
- Opzioni.qml salva le scelte in `~/.config/vetro/schermi.json` e scrive `regole(...)` in `vetro-impostazioni.conf` al posto della vecchia riga `monitor = , ...`.

- [ ] **Step 1: Test** `test_schermi.py` (esegue `Schermi.js` con `QJSEngine` di PySide6):
  - `test_due_schermi_destra`: `Virtual-1` principale 1920x1080, `Virtual-2` a destra → righe `monitor = Virtual-1, 1920x1080, 0x0, 1` e `monitor = Virtual-2, 1920x1080, 1920x0, 1`.
  - `test_duplica`: `Virtual-2` `duplica` → `monitor = Virtual-2, preferred, auto, 1, mirror, Virtual-1`.
  - `test_regole_schermi_spariti`: `scelte` per `Virtual-2` ma `schermi` contiene solo `Virtual-1` → nessuna riga per `Virtual-2`.
  - In `test-fase2-accesso.sh`: `test_greetd` (config con `user = "greeter"` e il comando sopra; `chiamato "systemctl enable greetd.service"`; `chiamato "systemctl disable getty@tty1.service"`), `test_accesso_qml` (qmllint senza `[syntax]`; il file contiene `Greetd` e `launch`).
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi i file e i passi** (`f2_accesso`: pacchetti, file, utente `greeter` nel gruppo `video`, `systemctl enable greetd.service`, `systemctl disable getty@tty1.service`).
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: accesso con greetd e piu' schermi"`

---

### Task 7: Rete e Wi-Fi nel centro di controllo

**Files:**
- Create: `arch/file/etc/systemd/network/20-cavo.network`, `arch/file/etc/systemd/network/25-wifi.network`, `arch/file/etc/iwd/main.conf`, `arch/file/usr/local/bin/vetro-wifi`, `arch/test/python/test_wifi.py`, `arch/test/test-rete.sh`
- Modify: `arch/file/etc/xdg/quickshell/vetro/Pannello.qml` (riquadro Wi-Fi), `arch/src/40-fase2-desktop.sh` (passo `rete`)

**Interfaces:**
- `20-cavo.network`: `[Match] Name=en* eth*` / `[Network] DHCP=yes`; `25-wifi.network`: `[Match] Name=wl*` / `[Network] DHCP=yes` / `IgnoreCarrierLoss=3s`; `main.conf`: `[General] EnableNetworkConfiguration=false` / `AddressRandomization=network`.
- `vetro-wifi` (Python, libreria standard, parla con iwd via `iwctl`): `vetro-wifi elenco` → JSON `[{"nome": str, "segnale": 0..4, "protetta": bool, "collegata": bool}]` ordinato per segnale; `vetro-wifi collega NOME [PASSWORD]`; `vetro-wifi scollega`. Funzione interna `leggi_elenco(testo_iwctl) -> list` (toglie i colori ANSI di `iwctl station wlan0 get-networks`).
- Pannello.qml: riquadro "Wi-Fi" visibile solo se `vetro-wifi elenco` restituisce qualcosa; clic su una rete → campo password se protetta.
- Passo `rete`: `PKG_FASE2 += (iwd)`; abilita `systemd-networkd systemd-resolved iwd`; collega `/etc/resolv.conf` a `/run/systemd/resolve/stub-resolv.conf`.

- [ ] **Step 1: Test** `test_wifi.py`: `test_elenco` con un testo vero di `iwctl` (con codici colore, una rete collegata `>`, segnali `****` e `**`) → due voci, la prima `collegata: True`, `segnale: 4`; `test_vuoto` (nessuna rete) → `[]`. `test-rete.sh`: file con i valori sopra, `chiamato "systemctl enable systemd-networkd.service systemd-resolved.service iwd.service"`, `resolv.conf` è un collegamento allo stub.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi i file, `vetro-wifi` e il riquadro.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: rete con networkd e iwd, Wi-Fi nel centro di controllo"`

---

### Task 8: Fase 3 — programmi

**Files:**
- Create: `arch/src/50-fase3-programmi.sh`, `arch/file/etc/xdg/mimeapps.list`, `arch/test/test-fase3.sh`
- Modify: `arch/file/usr/local/bin/tor-browser`, `arch/file/usr/local/bin/browser-predefinito`, `arch/file/usr/local/bin/wine` (recinto)

**Interfaces:**
- `PKG_FASE3=(torbrowser-launcher thunderbird thunderbird-i18n-it libreoffice-fresh libreoffice-fresh-it thunar mousepad foot yad wine wine-mono wine-gecko bubblewrap)` (dopo `abilita_multilib`).
- `tor-browser`: avvia `torbrowser-launcher`; con la modalità fantasma accesa usa il Tor del sistema (`TOR_SKIP_LAUNCH=1`, `TOR_SOCKS_PORT=9150`) come faceva in `lfs.sh`.
- `mimeapps.list`: `text/html`, `application/xhtml+xml`, `x-scheme-handler/http`, `x-scheme-handler/https`, `application/pdf` → `tor-browser.desktop`; niente `firefox`.
- `wine` (recinto): stessi permessi di `lfs.sh`, percorsi di Arch (`/usr/bin/wine`).

- [ ] **Step 1: Test** `test-fase3.sh`: `test_multilib_prima` (in `.chiamate` `pacman -Sy` viene prima di `pacman -S ... wine`), `test_mime` (nessuna riga con `firefox`, le cinque righe su `tor-browser.desktop`), `test_script` (`bash -n` su `tor-browser`, `browser-predefinito`, `wine`).
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi la fase e adatta gli script.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: fase 3, programmi"`

---

### Task 9: Fase 4 — firewall, Guardiano, modalità fantasma, utente fantasma

**Files:**
- Create: `arch/src/60-fase4-sicurezza.sh`, `arch/file/etc/modules-load.d/vetro.conf`, `arch/file/etc/systemd/system/home-fantasma.mount` (riscritto: era un heredoc senza virgolette), `arch/test/python/test_fantasma.py`, `arch/test/test-fase4.sh`
- Modify: `arch/file/usr/local/bin/avvia-desktop`, `arch/file/usr/local/sbin/fantasma-aiuto`, `arch/file/usr/local/sbin/firewall-avvia`, `arch/file/usr/local/sbin/guardiano-rete`, `arch/file/etc/systemd/system/tor-fantasma.service`, `arch/file/usr/local/share/fantasma/casa/.bash_profile`

**Interfaces:**
- `PKG_FASE4=(iptables tor wireguard-tools)`.
- `modules-load.d/vetro.conf`: `nfnetlink_queue`, `xt_owner`, `xt_NFQUEUE`.
- `fantasma-aiuto`: tutte le scritture e letture di file passano da `RADICE = os.environ.get("VETRO_RADICE", "")` (es. `RADICE + "/etc/fantasma"`); tiene le azioni `accendi spegni stato pronto attendi avvio prepara`; `tor-fantasma.service` con `User=tor` (utente del pacchetto `tor` di Arch).
- `fantasma`: il caso "accesa" mostra subito Spegni (come l'ultima versione di `lfs.sh`).
- Utente fantasma: creato con `useradd -m -G video,input,audio fantasma` se manca, password chiesta all'utente al primo giro (`passwd fantasma`, saltata con `VETRO_PROVA=1`); `home-fantasma.mount` con `uid`/`gid` dell'utente `fantasma` scritti al momento; `.bash_profile` del fantasma non avvia più labwc (con greetd il desktop lo avvia `avvia-desktop`). Per questo `avvia-desktop`, se `id -un` è `fantasma`, prima lancia `sudo -n /usr/local/sbin/fantasma-aiuto accendi` e, se non riesce, non avvia il desktop (messaggio ed esce con 1).
- Passo `fantasma`: `fantasma-aiuto prepara` + `touch /etc/fantasma/predefinita` (accesa di serie, una volta sola), `systemctl enable fantasma-avvio.service firewall.service guardiano-rete.service`.

- [ ] **Step 1: Test** `test_fantasma.py` (importa `fantasma-aiuto` come modulo con `VETRO_RADICE` in una cartella temporanea e `comando` sostituito da una lista):
  - `test_prepara`: scrive `etc/fantasma/attivo`, `etc/tor/fantasma.torrc`, `etc/systemd/resolved.conf.d/99-fantasma.conf`, e l'unico comando è `systemctl enable tor-fantasma.service`.
  - `test_spegni`: dopo `prepara`, `spegni()` toglie `etc/fantasma/attivo` e i file con il segno, non tocca un file senza il segno.
  - `test_spegni_senza_tor` (script `fantasma`, in `test-fase4.sh`): con `sudo` finto che risponde `acceso` a `stato` ed esce 1 a `pronto`, `yad` finto che registra gli argomenti ed esce 2 → la prima finestra ha il pulsante `Spegni:2` e nelle chiamate c'è `fantasma-aiuto spegni`, senza `attendi`.
  - `test_desktop_fantasma`: `avvia-desktop` con `id` finto che risponde `fantasma` e `sudo` finto che esce 1 → esce con 1 e `Hyprland` non è nelle chiamate; con `sudo` che esce 0 → `Hyprland -c /etc/xdg/hypr/vetro.conf` è chiamato dopo `fantasma-aiuto accendi`.
  - `test_fase4`: `modules-load.d/vetro.conf` con le tre righe; `chiamato "systemctl enable fantasma-avvio.service firewall.service guardiano-rete.service"`; `/etc/fantasma/predefinita` esiste.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Adatta i programmi e scrivi la fase.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: fase 4, firewall, Guardiano e modalita' fantasma"`

---

### Task 10: Fase 4 — VPN, DNS cifrato, cassaforte

**Files:**
- Modify: `arch/src/60-fase4-sicurezza.sh` (passi `vpn`, `dns`, `cassaforte`), `arch/file/usr/local/sbin/vpn-aiuto`, `arch/file/usr/local/bin/cassaforte`
- Create: `arch/file/etc/systemd/resolved.conf.d/vetro-dns.conf`, `arch/test/test-fase4b.sh`

**Interfaces:**
- `vetro-dns.conf` (uguale a `10-dns-cifrato.conf` di `lfs.sh`): `[Resolve]` / `DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net` / `FallbackDNS=` / `DNSOverTLS=yes` / `Domains=~.` / `LLMNR=no` / `MulticastDNS=no`.
- Passo `cassaforte`: se il file system di `/home` non è ext4 (`findmnt -no FSTYPE /home`, con ripiego su `/`) → `avviso "La cassaforte ha bisogno di ext4: la salto"` e il passo finisce bene; se è ext4 → `tune2fs -O encrypt DISCO` (una volta sola, solo se manca la funzione) e installa `cassaforte`.

- [ ] **Step 1: Test** `test-fase4b.sh`: `test_dns` (valori sopra), `test_cassaforte_senza_ext4` (`findmnt` finto che stampa `btrfs` → il passo esce con 0, nessuna chiamata `tune2fs`, l'avviso è nel registro), `test_cassaforte_ext4` (`findmnt` → `ext4`, `dumpe2fs` finto senza `encrypt` → `chiamato "tune2fs -O encrypt"`), `test_vpn` (`bash -n` su `vpn` e `vpn-aiuto`).
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi i passi e adatta gli script.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: VPN, DNS cifrato e cassaforte"`

---

### Task 11: Comandi `controlla` e `registri`

**Files:**
- Modify: `arch/src/90-comandi.sh`
- Create: `arch/test/test-comandi.sh`

**Interfaces:**
- `cmd_controlla`: stampa una riga per voce, `[OK]` o `[!!]`: RAM usata (`MemTotal - MemAvailable` da `$(percorso /proc/meminfo)`, `[OK]` se < 700 MB), servizi attivi (`greetd systemd-networkd iwd firewall guardiano-rete systemd-oomd`, con `systemctl is-active`), zram (`/sys/block/zram0` esiste), modalità fantasma (`/etc/fantasma/attivo`) e Tor (`fantasma-aiuto pronto`), passi non fatti.
- `cmd_registri`: scrive `registri-vetro.txt` nella cartella condivisa se montata (`/mnt/vetro`), altrimenti in `/root`: registri dei passi falliti, `journalctl -b -p warning` (ultime 300), `~/.cache/hyprland.log`, `~/.cache/quickshell-vetro.log`, `hyprctl monitors devices layers` dell'utente se il desktop è acceso.

- [ ] **Step 1: Test** `test-comandi.sh`: `test_ram` (`meminfo` finto con 8000000 kB totali e 7400000 disponibili → riga `[OK] RAM usata: 585 MB`; con 7000000 → `[!!]`), `test_registri_condivisa` (con `RADICE/mnt/vetro` presente il file va lì e contiene le intestazioni delle sezioni).
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi i comandi.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: comandi controlla e registri"`

---

### Task 12: Macchina virtuale `vetro-vm.sh` e guida d'installazione

**Files:**
- Create: `arch/vm/vetro-vm.sh`, `arch/GUIDA-INSTALLAZIONE.md`, `arch/test/test-vm.sh`

**Interfaces:**
- `vetro-vm.sh crea` → disco `~/vetro-arch/disco.qcow2` (40G) e scarica la ISO di Arch del mese da `https://geo.mirror.pkgbuild.com/iso/latest/` controllandola con il `sha256sums.txt` dello stesso indirizzo; `vetro-vm.sh installa` → avvia dalla ISO; `vetro-vm.sh avvia` → avvia dal disco; `--prova` stampa il comando QEMU invece di lanciarlo.
- Opzioni QEMU (da `cmd_avvia` di `lfs.sh`): `-machine q35,accel=kvm -cpu host` (o `tcg` senza `/dev/kvm`), `-m 8192`, `-device virtio-vga-gl,max_outputs=2,xres=1920,yres=1080`, `-display gtk,gl=on,zoom-to-fit=on`, `-device qemu-xhci -device usb-tablet`, rete `user`, audio come in `lfs.sh`, cartella condivisa `~/vetro-arch/condivisa` con `-virtfs local,path=…,mount_tag=vetro,security_model=mapped-xattr`. Senza 9p: server Python su `127.0.0.1:8765` (GET e PUT) raggiungibile dalla macchina come `http://10.0.2.2:8765`.
- Guida: archinstall con lingua italiana, disco **ext4**, **cifratura LUKS** con password, profilo **minimal**, audio **pipewire**, rete **"copia la configurazione della ISO"** (networkd + iwd), utente con sudo; poi `mount -t 9p -o trans=virtio,version=9p2000.L vetro /mnt/vetro` e `bash /mnt/vetro/vetro-arch.sh`.

- [ ] **Step 1: Test** `test-vm.sh`: `bash -n arch/vm/vetro-vm.sh`; `vetro-vm.sh avvia --prova` (con `qemu-system-x86_64` finto che dice di avere `virtio-vga-gl` e 9p) stampa `max_outputs=2`, `usb-tablet`, `mount_tag=vetro`; senza 9p stampa l'indirizzo `10.0.2.2:8765`.
- [ ] **Step 2: Esegui** → FALLITO.
- [ ] **Step 3: Scrivi lo script e la guida.**
- [ ] **Step 4: Esegui** → `ok`.
- [ ] **Step 5: Commit** — `git commit -m "arch: macchina virtuale di prova e guida d'installazione"`

---

### Task 13: File unico e prova finale nella macchina virtuale

**Files:**
- Modify: `arch/dist/vetro-arch.sh` (rigenerato)

- [ ] **Step 1: Costruisci e prova tutto qui** — `bash arch/costruisci.sh && bash arch/test/esegui.sh` → tutti `ok`; `VETRO_PROVA=1 bash arch/dist/vetro-arch.sh aiuto` stampa i comandi; `wc -c arch/dist/vetro-arch.sh`.
- [ ] **Step 2: Commit** — `git commit -m "arch: vetro-arch.sh pronto per la prova"`; manda all'utente `vetro-arch.sh`, `vetro-vm.sh` e la guida.
- [ ] **Step 3: Prova dell'utente nella macchina virtuale** (non si può fare da qui): segue la guida, lancia lo script, poi controlla gli 8 punti della sezione 7 della spec e lancia `vetro-arch.sh controlla`. Ogni punto che non va: `vetro-arch.sh registri`, si legge il file, si corregge con un test che riproduce il problema, si rimanda il file.
