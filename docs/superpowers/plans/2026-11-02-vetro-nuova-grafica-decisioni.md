# Vetro su Arch, nuova grafica — decisioni prese durante il lavoro

Ogni riga: cosa si e' deciso, perche', e cosa costa se e' sbagliato.

## Decisioni

- Pre-flight: T2 strumento anteprime copia Tema, Icona, PasswordPillola e *Vista.qml -> T10 usa VoceLato.qml (non e' una Vista). Ruling: lo strumento copia anche VoceLato.qml (elenco di file "puri" nello strumento) — costo: nessuno.
- Pre-flight: T7 PasswordPillola/AccessoVista senza Tema, ma Icona usa Tema. Ruling: nell'accesso le icone sono Text con il carattere "Material Symbols Rounded" (con simbolo di riserva se manca) — costo: nessuno.
- Task 1: Ruling: avvia-desktop legge i CSS da VETRO_CSS (di serie /etc/xdg/vetro) per poterlo provare con una casa finta — costo: nessuno.
- Task 1: Ruling: f2_desktop rifa' la cache dei caratteri (fc-cache) dopo aver messo i file: prima si rifaceva solo quando scaricava le icone, e DM Sans poteva non vedersi — test_fc_cache_dopo_caratteri RED->GREEN — costo: un secondo in piu'.
- Task 1: Ruling: test_aspetto_gnome (base) ora aspetta tema "vetro" e GTK chiaro con DM Sans (requisito cambiato dalla nuova grafica) — costo: nessuno.
- Task 1: Ruling: CSS GTK 3 con selettori espliciti (*:selected, .sidebar row, placessidebar row...): Adwaita GTK 3 non usa i colori con nome per quasi niente; GTK 4 con @define-color e variabili --accent-bg-color (libadwaita vecchio e nuovo) — costo: qualche widget GTK 3 puo' restare col blu di Adwaita.
- Task 2: Ruling: lo strumento scrive un qmldir con tutti i pezzi copiati (con un qmldir nella cartella l'import implicito usa solo quello) e le scene vengono copiate accanto come "scena-NOME.qml"; opzione --scene CARTELLA per la prova dell'errore — costo: nessuno.
- Task 2: Ruling: gli avvisi QML che nominano un file .qml (es. ReferenceError) contano come errori della scena: meglio severi — costo: un avviso innocuo puo' far fallire un'anteprima.
- Task 3: Ruling: la prova del puntatore usa immagine(freccia(), 24) che c'era gia' (pixel ARGB) invece di una nuova freccia(lato); bordo 2.2 su 24 (anche la mano piu' spessa, 1.8) — costo: nessuno.
- Task 3: Ruling: sfondi disegnati con PIL+numpy (solo sviluppo) e messi nello script come JPG (~1,8 MB in tutto); nastri di "onde" come poligoni (le linee spesse di PIL facevano tacche) — costo: lo script cresce di ~2,4 MB in base64.
- Task 3: Ruling: anche accesso.qml (vetro-nuvole.jpg) e blocca-schermo di riserva (vetro-cielo.jpg) passano ai nuovi sfondi subito, perche' i vecchi .png non si disegnano piu' — costo: nessuno.
- Task 4: Ruling: batteria "Full" conta come attaccata (carica=true); schede di rete senza "device" (lo, vpn, ifb) non contano; senza riga di qualita' il Wi-Fi vale 3 tacche — costo: nessuno.
- Task 5: Ruling: MusicaVista usa ClippingRectangle di Quickshell.Widgets (copertina arrotondata); nelle anteprime c'e' un finto ClippingRectangle (angoli dritti) — costo: nelle anteprime la copertina ha gli angoli dritti.
- Task 5: Ruling: il colore della copertina si prende con un Canvas 2x2 (drawImage a 1 px e getImageData), funziona anche nelle anteprime — costo: nessuno.
- Task 5: Ruling: aggiunto Tema.sopraBarra (altezza barra + 2 stacchi + 6) usato da pannello, notifiche, cruscotto, OSD e riquadro musica; il layerrule di vetro.conf (vetro-.*) copre gia' vetro-barra e vetro-musica, niente da cambiare — costo: nessuno.
- Task 5: Ruling: la barra mette ora "ddd d  HH:mm" (es. "lun 15  14:23") come nel video; le app senza icona mostrano un quadratino colorato con l'iniziale; niente nomi delle app al passaggio del mouse (la barra e' una finestra bassa) — costo: il nome dell'app non compare sopra l'icona.
- Task 5: Ruling: le scritte "dock" in Impostazioni diventano "barra"; la pagina si chiama "Barra" — costo: nessuno.
- Task 6: Ruling: nuovo pezzo IconaApp.qml (icona dell'app o quadratino con l'iniziale) usato da barra e menu, aggiunto ai file "puri" delle anteprime; MenuVista ha anche scrivi(t) per l'anteprima della ricerca; scena in piu' "menu-tutte" — costo: nessuno.
- Task 6: Ruling: il menu sta nello strato Top (prima Overlay a tutto schermo con velo scuro): ora e' un riquadro piccolo che si chiude cliccando fuori (HyprlandFocusGrab) — costo: niente velo scuro dietro.
- Task 7: Ruling: nell'accesso le icone (occhio, spegni, riavvia, cambia utente) sono Text con il carattere Material Symbols e un simbolo di riserva; PasswordPillola ha anche il segnale tabulazione() (Tab = utente dopo); niente orologio all'accesso (nel video non c'e') — costo: all'accesso non si vede l'ora.
- Task 8: Ruling: BloccoVista ha anche i segnali spegni()/riavvia() (il blocco di prima aveva i due tasti); alone dell'orologio fatto con 4 copie trasparenti (MultiEffect non si vede nelle anteprime); via saluto, numeri e musica dal blocco (come nel video) e via l'opzione statisticheBlocco — costo: sul blocco non si vedono piu' notifiche e numeri.
- Task 8: Ruling: il bordo rosso della pillola resta solo finche' il campo e' vuoto (appena riscrivi torna normale) — costo: nessuno.
- Task 9: Ruling: le attese su hyprbars stanno in test_conf_hyprland (controllano il testo di vetro-barre-aggiorna), non in test_barre_versione; anche vetro-impostazioni.conf di partenza passa a rounding = 18 (se no vinceva il 14) — test RED->GREEN — costo: nessuno.
- Task 9: Ruling: inactive_button_color trasparente (tasti senza cerchio anche sulle finestre non attive); ombra piu' leggera (rgba(0000002e)) per le finestre chiare — costo: nessuno.
- Task 10: Ruling: i colori di FinestraImpostazioni passano in blocco ai token app* (carta->appCarta, cartaForte->appSopra, cartaSopra/bordo/bordoForte->appBordo, testo*->appTesto*); le Icona senza colore diventano appTesto2; il lato ha il titolo "Impostazioni" e VoceLato al posto della ListView con evidenziatore (niente animazione dell'evidenziatore) — costo: qualche dettaglio di colore da ritoccare dopo la prova vera.
- Task 10: Ruling: Interruttore e Cursore con suChiaro: true diventano grigi su chiaro solo nelle parti "spente" (binario); accento e pallino restano — costo: nessuno.
- Task 11: Ruling: dal confronto col video, il riquadro della musica prende tinta e saturazione della copertina (HSL, luce 0.17) invece di un grigio scurito: nel video e' colorato pieno — costo: nessuno (solo aspetto, controllato nell'anteprima).
- Task 11: Ruling: il file unico pesa 2,7 MB (sfondi e carattere dentro) — costo: download un po' piu' grande.
- Final: Ruling: niente piu' pallini delle scrivanie e titolo della finestra attiva (stavano nella barra in alto, che nel video non c'e'); le scrivanie restano con Windows+1..5 e Windows+Ctrl+frecce — costo: non si vede su quale scrivania sei.

## Revisione finale

- Final review: self-review (niente revisore separato: le regole di questa sessione non permettono di avviare altri agenti senza che l'utente lo chieda). Nessun problema critico o importante trovato; corretti solo testi (commento di Avvisi.qml e una frase della guida che diceva "in alto a destra").
- Final: minor (deferred): nella pillola musica della barra la copertina piccola ha gli angoli dritti (solo il riquadro grande usa ClippingRectangle).
- Final: minor (deferred): le icone delle app nella barra si ricaricano quando si apre o chiude una finestra (l'elenco si ricrea): un attimo di sfarfallio possibile.

## Avanzamento

- Task 1: complete (commits 0330fb1..f49c92c, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 2: complete (commits f49c92c..ccd9d9f, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 3: complete (commits ccd9d9f..b4e4a09, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 4: complete (commits b4e4a09..d926643, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 5: complete (commits d926643..56b0b21, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 6: complete (commits 56b0b21..df1c735, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 7: complete (commits df1c735..065aacb, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 8: complete (commits 065aacb..290b6fe, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 9: complete (commits 290b6fe..f8be856, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 10: complete (commits f8be856..4c8054f, tests: bash arch/test/esegui.sh → === TUTTO OK)
- Task 11: complete (commits 4c8054f..ec5e6b8, tests: bash arch/test/esegui.sh → === TUTTO OK)
