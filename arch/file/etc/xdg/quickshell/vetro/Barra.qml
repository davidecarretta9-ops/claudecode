// La barra unica in basso (creato da vetro-arch.sh), una per schermo: prende il posto
// della barra in alto e del dock. La grafica e' in BarraVista.qml; qui i dati veri:
// app preferite e aperte (con le finestre ridotte), musica, rete, volume, batteria,
// modalita' fantasma, ora. Clic: logo = menu delle app, pillola di sistema = centro di
// controllo, ora = cruscotto, musica = riquadro della musica.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: barra
    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    implicitHeight: vista.implicitHeight
    // le finestre si fermano sopra la barra (piu' lo spazio di Hyprland)
    exclusiveZone: Tema.altezzaBarra + Tema.staccoBarra
    color: "transparent"
    WlrLayershell.namespace: "vetro-barra"
    WlrLayershell.layer: WlrLayer.Top

    SystemClock {
        id: orologio
        precision: Opzioni.secondi ? SystemClock.Seconds : SystemClock.Minutes
    }

    // "Resta sveglio" (centro di controllo): lo schermo non si spegne
    IdleInhibitor {
        window: barra
        enabled: Stato.restaSveglio
    }

    // con un pannello aperto Hyprland manda i clic solo alle finestre della sua lista:
    // la barra ci entra, cosi' i suoi tasti rispondono al primo clic
    Component.onCompleted: Stato.barre = Stato.barre.concat([barra])
    Component.onDestruction: Stato.barre = Stato.barre.filter(b => b !== barra)

    // --- le app: prima le preferite, poi le altre aperte (era il dock) --------------
    function fissate() {
        const r = [];
        const lista = Opzioni.preferite;
        let browser = false;
        for (let i = 0; i < lista.length; i++) {
            const e = DesktopEntries.byId(lista[i]);
            if (!e || r.indexOf(e) >= 0) continue;
            if (e.id === "tor-browser" || e.id === "firefox") {
                if (browser) continue;
                browser = true;
            }
            r.push(e);
        }
        return r;
    }

    readonly property var voci: {
        // Quickshell legge le app in sottofondo: leggere qui l'elenco fa ricalcolare
        // la barra quando arriva
        const pronte = Applicazioni.tutte;
        const l = [];
        const fisse = fissate();
        for (let i = 0; i < fisse.length; i++)
            l.push({ chiave: fisse[i].id, entry: fisse[i], icona: fisse[i].icon, nome: fisse[i].name, finestre: [] });
        const finestre = Finestre.tutte;
        for (let i = 0; i < finestre.length; i++) {
            const t = finestre[i];
            const app = Finestre.appDi(t);
            if (app === "" || app.startsWith("org.quickshell")) continue;
            const e = DesktopEntries.heuristicLookup(app);
            let v = null;
            for (let j = 0; j < l.length; j++)
                if ((e && l[j].entry === e) || l[j].chiave === app) { v = l[j]; break; }
            if (v === null) {
                v = { chiave: e ? e.id : app, entry: e, icona: e ? e.icon : app, nome: e ? e.name : app, finestre: [] };
                l.push(v);
            }
            v.finestre.push(t);
        }
        return l;
    }

    // clic su un'app: la apre; se e' aperta porta davanti la finestra (o la riduce se
    // e' gia' davanti); una ridotta torna
    function clic(v) {
        if (!v) return;
        if (v.finestre.length === 0) {
            if (v.entry) v.entry.execute();
            return;
        }
        for (let i = 0; i < v.finestre.length; i++)
            if (Finestre.ridotta(v.finestre[i])) { Finestre.riporta(v.finestre[i]); return; }
        let attiva = -1;
        for (let i = 0; i < v.finestre.length; i++)
            if (v.finestre[i].activated) attiva = i;
        if (attiva >= 0 && v.finestre.length === 1) {
            Finestre.riduci("0x" + v.finestre[0].address.replace(/^0x/, ""));
            return;
        }
        Finestre.riporta(v.finestre[(attiva + 1) % v.finestre.length]);
    }

    function iconaRete() {
        if (Sistema.reteTipo === "cavo") return "lan";
        if (Sistema.reteTipo === "wifi")
            return ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar",
                    "network_wifi_3_bar", "signal_wifi_4_bar"][Math.max(0, Math.min(4, Sistema.reteSegnale))];
        return "signal_wifi_off";
    }

    BarraVista {
        id: vista
        anchors.fill: parent

        app: barra.voci.map(v => ({
            nome: v.nome,
            icona: Applicazioni.icona(v.icona),
            aperta: v.finestre.length > 0,
            attiva: v.finestre.some(t => t.activated)
        }))
        nonDisturbare: Opzioni.nonDisturbare
        musica: Musica.attivo !== null && Musica.titolo !== ""
        musicaTitolo: Musica.titolo
        musicaCopertina: Musica.copertina
        iconaRete: barra.iconaRete()
        iconaVolume: Audio.icona
        batteria: Sistema.batteria
        inCarica: Sistema.inCarica
        fantasma: Sistema.fantasma
        ora: orologio.date.toLocaleString(Qt.locale("it_IT"), "ddd d") + "  "
             + orologio.date.toLocaleString(Qt.locale("it_IT"), Opzioni.secondi ? "HH:mm:ss" : "HH:mm")
        menuAperto: Stato.avvio
        pannelloAperto: Stato.pannello
        musicaAperta: Stato.musica

        onLogoCliccato: Stato.alterna("avvio")
        onAppCliccata: i => barra.clic(barra.voci[i])
        onNonDisturbareCliccato: Opzioni.nonDisturbare = false
        onMusicaCliccata: Stato.alterna("musica")
        onSistemaCliccato: Stato.alterna("pannello")
        onOraCliccata: Stato.alterna("cruscotto")
    }
}
