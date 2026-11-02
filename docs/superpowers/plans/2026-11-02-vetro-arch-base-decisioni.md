# Vetro su Arch — decisioni prese durante il lavoro

Ogni riga: cosa si e' deciso, perche', e cosa costa se e' sbagliato.

## Decisioni

- - T1 cmd_tutto <- T2 abilita_multilib/controlla_tutti_i_pacchetti: T1 viene prima di T2. Ruling: cmd_tutto chiama abilita_multilib e controlla_tutti_i_pacchetti solo se definite (declare -F) — l'ordine dei compiti lo impone — costo se sbagliato: un controllo dei pacchetti saltato in caso di nome diverso.
- Task 1: Ruling: la guardia "non parte se VETRO_PROVA=1" contraddice test_file_unico (VETRO_PROVA=1 ... aiuto deve stampare) — principale parte quando il file e' eseguito (BASH_SOURCE == $0), i test caricano src/*.sh con source; VETRO_PROVA resta solo per i comportamenti di prova — costo se sbagliato: nessuno, i test non eseguono il file unico se non apposta.
- Task 1: Ruling: per verificare l'archivio serve un comando interno — principale "_estrai CARTELLA" estrae l'archivio; costruisci.sh accetta [CARTELLA_FILE] [USCITA] per costruire in una cartella di prova senza toccare arch/file — costo: un comando nascosto in piu'.
- Task 1: Ruling: con VETRO_RADICE non vuota, esegui rifiuta (esce 127) i comandi senza un finto, cosi' i test non lanciano mai pacman/systemctl veri — costo: nessuno nell'uso reale (VETRO_RADICE vuota).
- Task 1: Ruling: i passi girano in una sottoshell in sottofondo (& + wait) invece che dentro un if, perche' bash ignora set -e nelle condizioni — costo: i passi non leggono dalla tastiera (le domande si fanno prima delle fasi).
- Task 2: Ruling: controlla_tutti_i_pacchetti non compila Quickshell (le librerie Qt per compilarlo non ci sono ancora): esclude quickshell dal controllo; la Fase 2 usa installa_quickshell (pacman se c'e', altrimenti compila_quickshell) — costo se sbagliato: un errore di Quickshell arriva in Fase 2 invece che all'inizio.
- Task 2: Ruling: test_quickshell_ripiego "non_chiamato cmake" combaciava con la riga pacman delle dipendenze — il controllo giusto e' "cmake -S" (la compilazione) — costo: nessuno.
- Task 2: Ruling: test_ripresa_dopo_errore (Task 1) ora prepara pacman.conf e pacman finto, perche' cmd_tutto accende multilib quando il pezzo dei pacchetti c'e' — costo: nessuno.
- Task 3: Ruling: systemd-zram-setup@zram0 e' generato da zram-generator a ogni avvio e non si puo' abilitare (systemctl enable fallirebbe) — si installa solo la configurazione — costo: nessuno, zram parte al riavvio.
- Task 4: Ruling: test-importati.sh scritto dopo l'importazione (il piano lo mette al passo 4): verificato che fallisca rompendo apposta un QML e uno script, poi ripristinati — costo: nessuno. Saltati da riscrivere: home-fantasma.mount (Task 9), tor-browser.desktop (Task 8).
- Task 5: Ruling: la versione di Hyprland si legge con "pacman -Q hyprland" invece di "hyprctl version -j" (hyprctl vuole Hyprland acceso, all'installazione non lo e') — costo: nessuno.
- Task 5: Ruling: pulsanti delle barre con simboli ✕ □ – (non vuoti) per riconoscerli come in GNOME — costo: se il carattere non ha i simboli si vedono quadratini.
- Task 5: Ruling: PKG_FASE2 + base-devel (gcc e make per hyprbars, l'Arch minimal non li ha) + swaylock (blocco di riserva di blocca-schermo) — costo: ~150 MB su disco, niente RAM.
- Task 5: Ruling: se il plugin non si scarica o non si compila, vetro-barre-aggiorna scrive un vetro-barre.conf con solo un commento ed esce 0 (barre mancanti ma installazione avanti) — costo: niente barre finche' non si rilancia.
- Task 5: Ruling: tolto da FinestraImpostazioni il riquadro "Desktop classico" (scegli-desktop/labwc non esistono su Arch); Stato.bloccato torna false, Blocco perde il suggerimento Ctrl+Alt+F2 e lo sblocco del submap (con greetd non servono) — costo: nessuno.
- Task 5: Ruling: impronta accetta anche cartelle (tutti i file dentro, in ordine) e c'e' installa_cartella, per non elencare 40 file nella riga del passo — costo: nessuno.
- Task 5: Ruling: disegna-cursori/disegna-vetro ricevono percorsi con la radice (percorso ...), cosi' nelle prove non scrivono fuori; test_f2_desktop aspetta "python3 -I $RADICE/usr/local/lib/vetro/disegna-cursori $RADICE/usr/share/icons/Vetro" — costo: nessuno nell'uso vero (radice vuota).
- Task 5: Ruling: esegui cerca il finto per nome (basename) anche se il comando e' un percorso intero — costo: nessuno.
- Task 5: Ruling: test_ripresa_dopo_errore svuota FASE2..4 (ora le fasi vere esistono e non c'entrano con la ripresa) — costo: nessuno.
- Task 5: Ruling: shell.qml e gli env di vetro.conf non avevano parti di LFS da togliere (GTK_CSD era gia' stato tolto) — lasciati — costo: nessuno.
- Task 6: Ruling: Schermi.regole senza nessuna scelta salvata per gli schermi presenti restituisce "" (restano preferred/auto e i nuovi schermi si sistemano da soli); uno schermo senza scelta, quando altri ne hanno, diventa "preferred, auto, 1" — costo: nessuno.
- Task 6: Ruling: esegui.sh usa ~/.vetro-qt/bin/python (con PySide6) per le prove Python se c'e'; test_schermi fallisce (non salta) se PySide6 manca, come qmllint — costo: serve il venv per le prove.
- Task 6: Ruling: accesso.qml prende gli utenti da /etc/passwd (UID 1000-59999, shell non nologin), cosi' compaiono il tuo e fantasma senza liste fisse — costo: nessuno.
- Task 6: Ruling: niente passo "schermi" separato — Schermi.js sta in etc/xdg/quickshell/vetro, gia' installata dal passo desktop; c'e' solo il passo "accesso" — costo: nessuno.
- Task 6: Ruling: accesso.qml non chiama Qt.quit(): Greetd.launch(cmd) di Quickshell esce da solo (quit=true di base); poi exec-once fa "hyprctl dispatch exit" — costo: nessuno.
- Task 6: Ruling: accesso.qml non usa Tema/Opzioni (colori fissi): leggono le scelte dell'utente e riscriverebbero l'Hyprland della schermata — costo: la schermata di accesso non segue il tema scelto.
- Task 6: Ruling: accesso-hyprland.conf ha anche "monitor = Virtual-1, 1920x1080, auto, 1" (nella VM parte a 800x600 come in lfs) — costo: nessuno sui PC veri (regola con nome solo per la VM).
- Task 6: Ruling: aggiunto il carattere delle icone (Material Symbols Rounded) in f2_desktop: non c'e' in Arch ufficiale, si scarica da GitHub alla versione 10ecc147... con sha256 7e74e365...; se manca la rete o il controllo non passa il passo si ferma (si rilancia) — costo: 15 MB su disco; senza, le icone dei pannelli sarebbero parole.
- Task 6: Ruling: esegui.sh lancia Python con -B (niente __pycache__ nel repo) — costo: nessuno.
- Task 7: Ruling: il sorgente di iwd non si raggiunge da qui: leggi_elenco accetta le stelline (accese prima del grigio, come le colora iwctl) e i numeri in dBm (anche x100); vetro-wifi chiede prima "get-networks rssi-dbms" e se non va "get-networks" — costo: se il formato vero e' diverso il riquadro resta vuoto (si vede nella prova in VM, Task 13).
- Task 7: Ruling: la scheda Wi-Fi si trova in /sys/class/net/*/wireless (non "wlan0" fisso) — costo: nessuno.
- Task 7: Ruling: collega senza password usa "iwctl --dont-ask" (reti aperte o salvate); se fallisce e la rete e' protetta il riquadro chiede la password; con password usa "--passphrase" (per un attimo visibile nell'elenco dei processi del tuo utente) — costo: basso su un PC personale.
- Task 7: Ruling: il riquadro sta in un file a parte, Wifi.qml, usato in Pannello.qml con "Wifi { }" (Pannello e' gia' lungo 490 righe) — costo: nessuno.
- Task 7: Ruling: f2_rete accende subito systemd-resolved e solo se parte collega /etc/resolv.conf allo stub (se no l'installazione resterebbe senza DNS); networkd e iwd partono al riavvio — costo: nessuno.
- Task 8: Ruling: PKG_FASE3 + xdg-utils: dentro il recinto il nostro xdg-open prende il posto di /usr/bin/xdg-open (su Arch /usr/local/bin/xdg-open non c'e'), e fuori serve per aprire i link — costo: nessuno.
- Task 8: Ruling: test_script controlla wine con ast.parse (e' Python, non bash) e tor-browser/browser-predefinito con sh -n (sono sh) — costo: nessuno.
- Task 8: Ruling: tor-browser mette sia TOR_PROVIDER=none (Tor Browser 13+) sia TOR_SKIP_LAUNCH=1 (prima), porta 9150: la modalita' fantasma (Task 9) deve tenere Tor su 9150 — costo: se cambia la porta, Tor Browser in fantasma non va.
- Task 8: Ruling: la voce di torbrowser-launcher (torbrowser.desktop) e quella di Wine (wine.desktop) si coprono con copie in /usr/local/share/applications (vengono prima di /usr/share e pacman non le tocca): la prima nascosta, la seconda apre i .exe nel recinto — costo: nessuno.
- Task 8: Ruling: mimeapps.list ha anche cartelle -> thunar, testo -> mousepad, .exe/.msi -> wine.desktop; tra le preferite del dock "firefox" diventa "org.mozilla.Thunderbird" (il nome della voce di Thunderbird su Arch) — costo: nessuno.
- Task 8: Ruling: l'utente fantasma (casa in memoria) fa scaricare Tor Browser a torbrowser-launcher a ogni accesso: niente copia di sistema come in lfs — costo: ~100 MB da scaricare e ~300 MB di RAM a ogni sessione fantasma; da rivedere al Task 9.
- Task 9: Ruling: incidente nelle prove: la prima volta test_fantasma.py ha girato sul vecchio fantasma-aiuto (senza VETRO_RADICE) e ha scritto 6 file nel /etc della macchina di prova (non dell'utente); tolti a mano e la prova ora si ferma se lo script non usa RADICE — costo: nessuno.
- Task 9: Ruling: due passi, "fantasma" (firewall, Guardiano, modalita' fantasma) e "utente-fantasma", invece di uno — costo: nessuno.
- Task 9: Ruling: gruppo "guardiano" (tu + fantasma) e GUARDIANO_GRUPPO=guardiano nel servizio: con "wheel" l'utente fantasma non poteva rispondere al Guardiano e restava senza internet — costo: il fantasma puo' anche cambiare le regole della rete (sono le stesse per tutti).
- Task 9: Ruling: la password del fantasma la chiede cmd_tutto alla fine (password_fantasma), non il passo: i passi girano senza tastiera (stdin /dev/null, uscita nel registro) — costo: se salti la domanda, il fantasma non entra finche' non fai "sudo passwd fantasma".
- Task 9: Ruling: pacchetti della fase 4 con "pacman -T" (solo quelli che mancano): se c'e' gia' iptables-nft, "pacman -S iptables --noconfirm" si fermerebbe sul conflitto — costo: nessuno.
- Task 9: Ruling: "fantasma" accesa: il pulsante Spegni spegne subito (niente seconda domanda), come chiede la prova del piano — costo: un clic in meno di conferma.
- Task 9: Ruling: la modalita' accesa di serie scrive /etc/systemd/resolved.conf.d/99-fantasma.conf: i passi dopo "fantasma" non devono riavviare systemd-resolved (DNS su Tor che ancora non c'e'); al Task 10 i passi DNS/VPN vanno PRIMA di "fantasma" — costo: se no, internet si ferma a meta' installazione.
- Task 9: Ruling: avvia-desktop per il fantasma mette anche TZ=UTC e HISTFILE=/dev/null (greetd non legge .bash_profile); aggiunto .config/benvenuto-fatto nella casa del fantasma (niente benvenuto a ogni accesso) e lo sfondo/icona disegnati con disegna-fantasma come in lfs — costo: nessuno.
- Task 10: Ruling: il file del DNS si chiama 10-vetro-dns.conf (non vetro-dns.conf): systemd-resolved legge i file in ordine alfabetico e "vetro-dns" verrebbe dopo "99-fantasma", annullando il DNS verso Tor in modalita' fantasma — costo: nessuno.
- Task 10: Ruling: 20-cavo e 25-wifi.network con UseDNS=no, SendHostname=no, IPv6PrivacyExtensions=yes (come 20-privacy.conf di lfs): senza, le domande DNS andrebbero anche al router in chiaro — costo: se il DNS cifrato e' bloccato dalla rete (porta 853) i siti non si aprono finche' non si mette DNSOverTLS=opportunistic.
- Task 10: Ruling: il passo dns non riavvia systemd-resolved (vale dal riavvio): l'installazione non resta senza DNS su reti che bloccano il TLS — costo: nessuno.
- Task 10: Ruling: la VPN installa systemd-resolvconf se manca "resolvconf" (wg-quick lo usa per i DNS della VPN; senza, una VPN con DNS= non si accende) — costo: nessuno.
- Task 10: Ruling: cassaforte guarda "findmnt -T /home" (il disco che contiene /home, anche se /home non e' una partizione sua): fa gia' da ripiego su / — costo: nessuno.
- Task 10: Ruling: ordine fase 4: dns, vpn, cassaforte, fantasma, utente-fantasma (vedi Ruling del Task 9) — costo: nessuno.
- Task 11: Ruling: "controlla" mostra anche la modalita' fantasma spenta come semplice informazione (non [!!]): spenta non e' un errore — costo: nessuno.
- Task 11: Ruling: "registri" usa /mnt/vetro se la cartella esiste (montata o no) e scrive con "|| true" (un comando che manca non ferma la raccolta); hyprctl gira come utente con "runuser ... hyprctl -i 0" — costo: nessuno.
- Task 12: Ruling: la macchina virtuale parte in BIOS (niente firmware UEFI da installare); archinstall sceglie da solo il bootloader — costo: non si prova l'avvio UEFI.
- Task 12: Ruling: --prova scrive il comando con virgolette solo dove servono (printf %q metteva "\" davanti a ogni virgola, illeggibile) — costo: nessuno.
- Task 12: Ruling: aggiunto VETRO_VM_SOLO_FUNZIONI=1 per provare scegli_iso (la scelta della ISO con la data dalla lista sha256) — costo: nessuno.
- Task 12: Ruling: il server senza 9p accetta PUT solo di file con nome semplice (niente cartelle, niente nomi con il punto davanti) fino a 200 MB e ascolta solo su 127.0.0.1 — costo: nessuno.
- Task 13: Ruling: aggiunta test-tutto.sh (tutto il giro di cmd_tutto in una cartella finta, poi rilancio = niente da rifare); verificato che fallisce rompendo apposta la fase 3. Il file unico dist/vetro-arch.sh provato a mano allo stesso modo con il carattere vero (impronta giusta) — costo: nessuno.
- Task 13: Ruling: la prova nella macchina virtuale (step 3) la fa l'utente: da qui i siti di Arch non si raggiungono — costo: errori che si vedono solo su Arch vero arrivano dopo, con "registri".
- Final: Ruling: nessuna regola "permetti" di serie per Tor Browser nel Guardiano (in lfs c'era per /opt/tor-browser): con torbrowser-launcher il percorso e' nella casa di ogni utente — il Guardiano chiede la prima volta — costo: una domanda in piu' al primo avvio di Tor Browser.

## Revisione finale

- Final review: self-review (niente revisore separato: le regole di questa sessione non permettono di avviare altri agenti senza che l'utente lo chieda)
- Final: fixed /etc/guardiano-rete mai creata -> guardiano-rete.service non parte (ReadWritePaths) e i programmi restano senza internet — test_fase4 (regole 644) RED→GREEN, suite 324/324 + 15 Python
- Final: fixed schermata di accesso senza tastiera italiana (password con simboli sbagliata) — test_greetd kb_layout RED→GREEN, suite 324/324
- Final: fixed file di rete dopo quelli di archinstall (20-wlan.network vinceva: DNS del router e nome del PC inviati) -> 10-cavo/10-wifi.network — test_ordine_file_rete RED→GREEN, suite 324/324
- Final: fixed vetro-vm.sh installa senza ISO usciva muto (pipefail) — test_installa_senza_iso RED→GREEN, suite 324/324
- Final: minor (deferred): l'utente fantasma non e' nel gruppo che iwd lascia usare (wheel): il riquadro Wi-Fi non gli funziona (la rete gia' salvata si collega lo stesso)
- Final: minor (deferred): vetro-vm.sh crea dice "non riesco a leggere sha256sums" anche quando la lista c'e' ma manca la riga della ISO

## Avanzamento

- Task 1: complete (commits dd3f28f..9684152, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 2: complete (commits 9684152..9df1e63, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 3: complete (commits 9df1e63..d8299ac, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 4: complete (commits d8299ac..7a0433f, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 5: complete (commits 7a0433f..2974004, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 6: complete (commits 2974004..f13eb48, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 7: complete (commits f13eb48..6c25989, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 8: complete (commits 6c25989..2fa393c, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 9: complete (commits 2fa393c..07935cd, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 10: complete (commits 07935cd..437486f, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 11: complete (commits 437486f..32b7bb7, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 12: complete (commits 32b7bb7..317e044, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 13: complete (commits 317e044..2e95898, tests: bash arch/test/esegui.sh → === TUTTO OK)
