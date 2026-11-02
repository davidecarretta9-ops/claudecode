pragma Singleton
// Quali pannelli sono aperti (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell

Singleton {
    id: stato

    property bool pannello: false        // centro di controllo (a destra)
    property bool cruscotto: false       // meteo, calendario, prestazioni
    property int schedaCruscotto: 0
    property bool avvio: false           // cerca le app
    property bool impostazioni: false    // finestra delle Impostazioni
    property string pagina: "generale"
    // blocco schermo. All'accesso (avvio senza la schermata a testo) si parte bloccati:
    // la password si scrive qui (lo decide avvia-pannelli con VETRO_BLOCCA_ALL_AVVIO)
    property bool bloccato: Quickshell.env("VETRO_BLOCCA_ALL_AVVIO") === "1"
    property bool restaSveglio: false    // lo schermo non si spegne e non si blocca
    // le barre in alto (una per schermo): restano cliccabili quando un pannello e' aperto
    property var barre: []

    function chiudiTutto() {
        pannello = false;
        cruscotto = false;
        avvio = false;
    }

    function alterna(nome) {
        let era = false;
        if (nome === "pannello") era = pannello;
        else if (nome === "cruscotto") era = cruscotto;
        else if (nome === "avvio") era = avvio;
        chiudiTutto();
        if (era) return;
        if (nome === "pannello") pannello = true;
        else if (nome === "cruscotto") cruscotto = true;
        else if (nome === "avvio") avvio = true;
    }

    function apriCruscotto(scheda) {
        chiudiTutto();
        schedaCruscotto = scheda;
        cruscotto = true;
    }

    function apriImpostazioni(p) {
        chiudiTutto();
        if (p) pagina = p;
        impostazioni = true;
    }

    function blocca() {
        chiudiTutto();
        bloccato = true;
    }
}
