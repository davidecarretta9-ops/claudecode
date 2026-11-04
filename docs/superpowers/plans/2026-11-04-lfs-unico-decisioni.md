# Un solo lfs.sh — decisioni prese durante il lavoro

Ogni riga: cosa si e' deciso, perche', e cosa costa se e' sbagliato.

## Decisioni

- Pre-flight: T1 principale chiama pc_fase10/pc_avvia/pc_comando (Task 3): fino al Task 3 non esistono. Ruling: principale le chiama solo se definite (declare -F), se no muore con un messaggio — costo: nessuno.
- Task 1: Ruling: la cartella della macchina sta in cartella_pc() (90-comandi.sh, con VETRO_PC per le prove) invece di pc_cartella nel pezzo PC: serve gia' a dove_sono — costo: nessuno.
- Task 1: Ruling: "tutto" resta come altro nome di "installa"; senza comando ora si vede l'aiuto (prima partiva l'installazione); cmd_tutto scrive $VETRO_STATO/installato alla fine — costo: chi lanciava "sudo bash vetro-arch.sh" senza niente ora vede l'aiuto.
- Task 2: Ruling: installa-arch prende 10-cavo.network, vetro-comando e il servizio estraendo lfs.sh (lfs.sh _estrai) invece di scaricarli uno per uno; aggiunti mirror sicuro in cima, attesa di pacman-init, controllo del nome utente e delle impronte, modules-load per 9p, systemd-networkd-wait-online abilitato (serve a network-online.target), radice bloccata (si entra con l'utente e sudo) — costo: nessuno.
- Task 2: Ruling: vetro-comando e il suo servizio li mette solo installa-arch (solo nella macchina virtuale), non i passi di Vetro: su un PC vero non devono cercare il server 10.0.2.2 a ogni accensione — costo: se cambiano, la macchina gia' fatta tiene la versione vecchia.
- Task 2: Ruling: comandi accettati solo installa/registri/controlla (un .comando diverso non si esegue e non spegne); senza 9p i registri tornano al PC con PUT sul server — costo: nessuno.
- Task 3: Ruling: fase10 non si rifiuta di partire su un PC con Arch (il piano diceva "non su Arch"): un PC con Arch puo' volere la macchina virtuale; dentro la macchina non lo lancia nessuno — costo: nessuno.
- Task 3: Ruling: la riuscita si sa da file che la macchina scrive sul PC: .arch-ok (installa-arch, PUT al server) e .esito ok|errore (vetro-comando, nella cartella condivisa o PUT); il server accetta PUT di nomi col punto solo per questi due — costo: nessuno.
- Task 3: Ruling: il piede del file unico (costruisci.sh) cambia gia' qui: VETRO_LFS = il file stesso e trap pulisci (ferma il server e cancella i file estratti); serve_root dice "sudo bash lfs.sh COMANDO" — costo: nessuno.
- Task 3: Ruling: registri aggiunge anche "journalctl -b -1" (la macchina si accende apposta per raccoglierli: il problema e' nell'accensione prima) — test_registri_condivisa RED->GREEN — costo: nessuno.
- Task 3: Ruling: le prove del flusso di fase10 sostituiscono i pezzi lenti (ISO, kernel, server, QEMU) con funzioni finte che registrano; i pezzi veri (mount della ISO, download, server, QEMU) si provano solo nella macchina dell'utente — costo: errori in quei pezzi si vedono solo alla prova vera.
- Task 4: Ruling: la guida diventa "come si usa lfs.sh" (fase10, avvia, aggiornare, registri, controlla, PC vero con installa); il vecchio dist/vetro-arch.sh, vm/vetro-vm.sh e test-vm.sh sono tolti (tutto e' in lfs.sh) — costo: chi aveva i file vecchi deve usare lfs.sh.
- Final: Ruling: l'installazione si basa sul parametro script= della ISO di Arch (lo script .automated_script.sh della ISO): da qui non si puo' verificare sulla ISO del mese — se manca, fase10 si ferma con "L'installazione di Arch non e' riuscita" e il registro — costo: servirebbe un altro modo di avviare l'installazione.

## Revisione finale

- Final review: self-review (niente revisore separato: le regole di questa sessione non permettono di avviare altri agenti senza che l'utente lo chieda). Controllati a mano: tee sulla seriale, trap d'errore con spegnimento, mirror e chiavi di pacman, partizione e GRUB, impronte via env nel chroot, PUT dei segni al server, ordine server/copia di lfs.sh, dove_sono dentro la macchina (root senza disco = arch). Nessun problema critico o importante trovato.
- Final: minor (deferred): linux-firmware (~400 MB) si installa anche nella macchina virtuale, dove non serve.
- Final: minor (deferred): con la modalita' fantasma accesa, gli aggiornamenti di fase10 scaricano da Tor (lenti).

## Avanzamento

- Task 1: complete (commits e61e389..282746f, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 2: complete (commits 282746f..af096a6, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 3: complete (commits af096a6..0be4f47, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 4: complete (commits 0be4f47..ca4df1c, tests: bash arch/test/esegui.sh → === TUTTO OK)
