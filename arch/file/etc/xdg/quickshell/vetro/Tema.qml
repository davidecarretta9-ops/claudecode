pragma Singleton
// Colori, caratteri e misure del desktop "Vetro" (creato da vetro-arch.sh).
// Il tema si sceglie da Impostazioni -> Aspetto.
import QtQuick
import Quickshell

Singleton {
    id: tema

    readonly property string nome: Opzioni.tema
    readonly property bool chiaro: nome === "carta"
    readonly property real opacita: Math.max(0.25, Math.min(0.95, Opzioni.opacita))

    readonly property var temi: [
        { id: "vetro",      nome: "Vetro",      fondo: "#1f242c", accento: "#1a8cff" },
        { id: "adwaita",    nome: "Adwaita",    fondo: "#242424", accento: "#3584e4" },
        { id: "ombra",      nome: "Ombra",      fondo: "#17171a", accento: "#ececf0" },
        { id: "grafite",    nome: "Grafite",    fondo: "#1d2024", accento: "#a9b4c2" },
        { id: "mezzanotte", nome: "Mezzanotte", fondo: "#14162a", accento: "#8c96ff" },
        { id: "rosa",       nome: "Rosa",       fondo: "#21171c", accento: "#ff9ab6" },
        { id: "carta",      nome: "Carta",      fondo: "#f4f4f6", accento: "#2f6df6" }
    ]
    readonly property var attuale: {
        for (let i = 0; i < temi.length; i++)
            if (temi[i].id === nome) return temi[i];
        return temi[0];
    }

    // fondi "a vetro": semitrasparenti, Hyprland sfoca quello che c'e' dietro
    readonly property color base: attuale.fondo
    readonly property color fondo: Qt.rgba(base.r, base.g, base.b, opacita)
    readonly property color fondoPieno: Qt.rgba(base.r, base.g, base.b, Math.min(1, opacita + 0.25))
    readonly property color carta: chiaro ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
    readonly property color cartaForte: chiaro ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.11)
    readonly property color cartaSopra: chiaro ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.17)
    readonly property color bordo: chiaro ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.09)
    readonly property color bordoForte: chiaro ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.18)

    readonly property color accento: attuale.accento
    readonly property color suAccento: (nome === "ombra" || nome === "grafite") ? "#121214" : "#ffffff"
    readonly property color testo: chiaro ? "#1d1d1f" : (nome === "adwaita" ? "#ffffff" : "#f2f2f5")
    readonly property color testo2: chiaro ? "#55555c" : "#a6a6ae"
    readonly property color testo3: chiaro ? "#86868e" : "#6c6c75"
    readonly property color rosso: "#ff5f57"
    readonly property color giallo: "#febc2e"
    readonly property color verde: "#30d158"

    // le pillole della barra (bianco leggero) e "Non disturbare" acceso (rosso)
    readonly property color pillola: Qt.rgba(1, 1, 1, 0.06)
    readonly property color pillolaBordo: Qt.rgba(1, 1, 1, 0.14)
    readonly property color pillolaSopra: Qt.rgba(1, 1, 1, 0.12)
    readonly property color rossoFondo: Qt.rgba(0.753, 0.149, 0.176, 0.35)    // #c0262d
    readonly property color rossoBordo: Qt.rgba(1, 0.353, 0.373, 0.5)         // #ff5a5f

    // le finestre chiare (Impostazioni e le app, come nel video)
    readonly property color appFondo: "#f5f7fa"
    readonly property color appCarta: "#ffffff"
    readonly property color appTesto: "#15181d"
    readonly property color appTesto2: "#6b7280"
    readonly property color appTesto3: "#9aa1ab"
    readonly property color appBordo: Qt.rgba(0, 0, 0, 0.08)
    readonly property color appSopra: Qt.rgba(0, 0, 0, 0.05)

    readonly property int raggio: 24
    readonly property int raggioMedio: 18
    readonly property int raggioPiccolo: 12
    readonly property int spazio: 12
    readonly property int raggioFinestra: 18
    readonly property int raggioBarra: 14
    readonly property int raggioRiquadro: 16

    // la barra unica in basso: alta 48, staccata 8 dai bordi dello schermo
    readonly property int altezzaBarra: 48
    readonly property int staccoBarra: 8
    // quanto devono stare in alto i pannelli che si aprono sopra la barra
    readonly property int sopraBarra: altezzaBarra + 2 * staccoBarra + 6

    readonly property string carattere: "DM Sans"
    readonly property string mono: "Adwaita Mono"
    readonly property string fontIcone: "Material Symbols Rounded"
    readonly property bool iconeOk: Qt.fontFamilies().indexOf(fontIcone) >= 0

    // durata delle animazioni (0 se spente da Impostazioni)
    readonly property int veloce: Opzioni.animazioni ? 160 : 0
    readonly property int media: Opzioni.animazioni ? 280 : 0
    readonly property int lenta: Opzioni.animazioni ? 460 : 0
}
