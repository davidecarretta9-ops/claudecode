# Vetro su Arch — la nuova grafica

Data: 2026-11-02 · Stato: da approvare

## 1. Obiettivo

Rifare la grafica del desktop Vetro (vetro-arch.sh) **come nel video** mandato
dall'utente (promozione di un altro sistema Linux, lunariaOS): una sola barra scura
in basso con "pillole" a destra, finestre chiare e molto arrotondate con accento blu,
menu delle app compatto e scuro, schermata di accesso e di blocco con elementi grandi.

Restano tutte le funzioni di oggi (modalità fantasma, Guardiano, Wi-Fi, VPN,
cassaforte, impostazioni, più schermi) e il desktop resta leggero.

### Non si copia

- **Nome e logo lunariaOS**: al loro posto il logo di Vetro (disegnato nuovo).
- **I loro sfondi esatti**: se ne disegnano di nuovi nello stesso stile.
- **Le loro app** (file, orologio, foto): restano le app leggere (Thunar, Mousepad…),
  colorate nello stesso stile (scelta dell'utente: "App leggere colorate così").

## 2. Riferimento: cosa si vede nel video

| Momento | Cosa |
|---|---|
| 0:02–0:03 | Barra unica in basso, scura, angoli arrotondati: a sinistra logo, lineetta, icone delle app a colori (al passaggio del mouse un riquadro chiaro dietro l'icona); a destra pillole "Do not Disturb" (rossa), Wi-Fi + volume + batteria, poi data e ora |
| 0:04 | Barra degli strumenti bianca a pillola con icone nere grandi (cerca, importa, filtro, ordina) |
| 0:05 | Accesso: foto tonda + nome in grassetto bianco, sotto una pillola blu scuro con pallini bianchi grandi e un occhio a destra; sfondo notte con nuvole |
| 0:06 | Barra su sfondo scuro: pillola musica (copertina + titolo), pillola timer bordata di blu |
| 0:06–0:07 | Finestra chiara, angoli ~20 px, lato con "Recents" (icona + titolo), "Favorites" in grigio, cartelle con icona a contorno, voce scelta = pillola blu piena con testo bianco |
| 0:07 | Finestra piccola: barra del titolo chiara, titolo al centro, – ■ ✕ neri a destra |
| 0:08 | Blocco: orologio enorme in alto a sinistra, data piccola sopra, cielo azzurro |
| 0:09 | Riquadro musica: copertina, titolo, autore, tempi, barra con pallino ad anello, ⏮ ▶ ⏭, colorato come la copertina |
| 0:11 | Menu: riquadro scuro con "Search" e "View all apps" |
| 0:12 | App con lato: titolo in grassetto, "+" in un cerchio, voce scelta blu |

## 3. Misure e colori

| Cosa | Valore |
|---|---|
| Carattere | **DM Sans** (libero, licenza OFL), file variabile `DMSans[opsz,wght].ttf` di google/fonts (versione `2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc`, sha256 `8cd08d97e89c24d0aa92edd2f0f4c8ee6195eee9b7c9f154865a58b02f0c1c0d`), **messo dentro lo script** con la sua licenza: niente download |
| Accento | `#1a8cff` (pillola della voce scelta, tasti principali) |
| Pannelli scuri (barra, menu, centro di controllo) | fondo `#1f242c` al 92 %, bordo bianco al 10 % |
| Pillole della barra | fondo bianco al 6 %, bordo bianco al 14 %, tutta tonda; "Non disturbare" acceso: fondo `#c0262d` al 35 %, bordo `#ff5a5f` al 50 % |
| Finestre e app | fondo `#f5f7fa`, testo `#15181d`, testo secondario `#6b7280` |
| Angoli | finestre 18 px, barra 14 px, menu e riquadri 16 px, pillole tonde |
| Barra | alta 48 px, staccata 8 px dai bordi, su ogni schermo |

## 4. I pezzi

### 4.1 Barra unica in basso (prende il posto di barra in alto e dock)

- **Sinistra:** logo di Vetro (clic → menu delle app), lineetta verticale sottile, poi le
  app preferite e quelle aperte (icone a colori 30 px). Passandoci sopra: riquadro
  chiaro arrotondato dietro l'icona. App aperta: puntino sotto. Clic: apre l'app o
  porta davanti la sua finestra (come il dock di oggi). Le finestre ridotte stanno qui.
- **Destra**, pillole:
  1. **Non disturbare**: c'è solo quando è acceso (rossa); clic → spento.
  2. **Musica**: solo se qualcosa suona; copertina + titolo; clic → **riquadro musica**
     sopra la barra (copertina, titolo, autore, tempi, barra di avanzamento con
     pallino ad anello, ⏮ ▶ ⏭), colorato con il colore della copertina.
  3. **Sistema**: Wi-Fi, volume, batteria (se c'è); in modalità fantasma anche
     l'icona del fantasma; clic → centro di controllo.
  4. **Data e ora** (es. "lun 15 14:23", senza pillola); clic → cruscotto (calendario).
- Le finestre non vanno sotto la barra.

### 4.2 Menu delle app

Riquadro scuro largo 420 px sopra il logo, in basso a sinistra. In alto il campo
"Cerca" con lente; sotto "Tutte le app" con icona a griglia. Scrivendo: elenco dei
risultati (icona + nome), frecce e Invio come oggi. "Tutte le app": griglia di tutte
le app dentro il riquadro, che si allunga fino a metà schermo. Si apre anche con il
tasto Windows.

### 4.3 Centro di controllo, cruscotto, notifiche, impostazioni

- Centro di controllo e cruscotto: stesso contenuto di oggi, stile dei pannelli scuri,
  il centro di controllo si apre **in basso a destra** sopra la barra.
- Notifiche: stesso stile, in basso a destra sopra la barra.
- Finestra Impostazioni: **chiara come le app del video**: lato con titolo in
  grassetto, voci con icona a contorno, voce scelta = pillola blu con testo bianco.

### 4.4 Schermata di accesso (greetd)

- Sfondo **"nuvole"**: notte blu con nuvole morbide a rilievo e scie diagonali.
- Al centro: foto tonda (56 px) + nome in grassetto bianco (30 px) sulla stessa riga;
  clic sul nome o Tab → utente dopo.
- Sotto: pillola larga 440 px, alta 64, fondo `#0f2340` all'85 %, pallini bianchi
  grandi, a destra l'**occhio** per vedere la password; vuota: "Scrivi la password".
- Password sbagliata: la pillola trema e dice "Password sbagliata".
- In basso a destra: spegni e riavvia (tondi, piccoli).

### 4.5 Schermata di blocco

- Sfondo **"cielo"**: azzurro, più scuro in alto.
- In alto a sinistra: data piccola (es. "domenica 26 luglio") e sotto l'**orologio
  enorme** (circa 160 px, bianco con un leggero alone).
- In basso al centro: foto, nome e la stessa pillola della password dell'accesso.

### 4.6 Finestre e app

- Hyprland: angoli 18 px, niente bordo colorato, ombra morbida.
- Barre del titolo (hyprbars): chiare `#f6f8fb`, alte 34 px, titolo al centro scuro
  (DM Sans), – ■ ✕ scuri a destra senza cerchi.
- App GTK 3 e 4: tema chiaro, accento `#1a8cff`, voci scelte nei lati come pillole
  blu, carattere DM Sans 11.

### 4.7 Sfondi e puntatore

- Sfondi nuovi, disegnati qui e messi nello script come immagini (JPG, 2560×1440):
  **sfera** (predefinito: azzurro con una grande sfera blu e linee bianche sottili),
  **nuvole** (accesso), **cielo** (blocco), **onde** (scuro, nastri di vetro blu),
  **magenta** (scuro, forme di vetro rosa), **argento** (grigio e blu notte).
  Lo sfondo della modalità fantasma resta quello di oggi.
- Puntatore: freccia bianca con bordo nero spesso e angoli arrotondati.

## 5. Anteprime

Uno strumento solo per lo sviluppo (non va nello script) disegna qui i pezzi
principali in immagine: barra, menu, riquadro musica, accesso, blocco, impostazioni.
Le immagini si confrontano con il video e si mandano all'utente prima della prova
nella macchina virtuale.

## 6. Leggerezza

Niente servizi nuovi. In più ci sono solo il carattere (240 KB) e gli sfondi
(circa 1–2 MB nello script). La barra unica sostituisce due pannelli: la RAM usata
non cresce.

## 7. Come si controlla

1. Le prove automatiche passano (sintassi QML, contenuti, passi dello script).
2. Le anteprime somigliano ai fotogrammi del video (sezione 2).
3. Nella macchina virtuale: accesso con la pillola e l'occhio; barra unica con le
   pillole; menu delle app; riquadro musica; centro di controllo in basso a destra;
   blocco con l'orologio grande; finestre chiare con – ■ ✕; Thunar chiaro con la
   voce scelta blu.
