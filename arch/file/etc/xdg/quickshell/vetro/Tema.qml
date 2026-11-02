pragma Singleton
// Colori, caratteri e misure del desktop "Vetro" (creato da lfs.sh, Fase 10).
// Il tema si sceglie da Impostazioni -> Aspetto.
import QtQuick
import Quickshell

Singleton {
    id: tema

    readonly property string nome: Opzioni.tema
    readonly property bool chiaro: nome === "carta"
    readonly property real opacita: Math.max(0.25, Math.min(0.95, Opzioni.opacita))

    readonly property var temi: [
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
    readonly property color testo: chiaro ? "#1d1d1f" : "#f2f2f5"
    readonly property color testo2: chiaro ? "#55555c" : "#a6a6ae"
    readonly property color testo3: chiaro ? "#86868e" : "#6c6c75"
    readonly property color rosso: "#ff5f57"
    readonly property color giallo: "#febc2e"
    readonly property color verde: "#30d158"

    readonly property int raggio: 24
    readonly property int raggioMedio: 18
    readonly property int raggioPiccolo: 12
    readonly property int spazio: 12

    readonly property string carattere: "Adwaita Sans"
    readonly property string mono: "Adwaita Mono"
    readonly property string fontIcone: "Material Symbols Rounded"
    readonly property bool iconeOk: Qt.fontFamilies().indexOf(fontIcone) >= 0

    // durata delle animazioni (0 se spente da Impostazioni)
    readonly property int veloce: Opzioni.animazioni ? 160 : 0
    readonly property int media: Opzioni.animazioni ? 280 : 0
    readonly property int lenta: Opzioni.animazioni ? 460 : 0
}
