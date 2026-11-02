// Il dock in basso (creato da lfs.sh, Fase 10): le app preferite, quelle aperte e
// le finestre ridotte. Passandoci sopra le icone si ingrandiscono come su macOS.
// Clic: apre l'app, o porta davanti la sua finestra. Si spegne da Impostazioni.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: dock
    required property var modelData
    screen: modelData

    anchors { bottom: true }
    implicitWidth: pillola.width + 40
    implicitHeight: 132
    exclusiveZone: 80
    color: "transparent"
    WlrLayershell.namespace: "vetro-dock"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region { item: pillola }

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

    function voceDi(e) {
        for (let i = 0; i < voci.length; i++) if (voci[i].entry === e) return voci[i];
        return null;
    }

    // l'elenco: prima le preferite, poi le altre app aperte
    readonly property var voci: {
        // Quickshell legge le app in sottofondo: finche' non ha finito, byId() non trova
        // niente. Leggere qui l'elenco fa ricalcolare il dock quando arriva.
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

    function clic(v) {
        if (v.finestre.length === 0) {
            if (v.entry) v.entry.execute();
            return;
        }
        // una ridotta: torna; altrimenti la prossima finestra di quell'app
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

    property real mouseX: -1000

    Rectangle {
        id: pillola
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 66
        width: fila.width + 20
        radius: 22
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo
        Behavior on width { NumberAnimation { duration: Tema.media; easing.type: Easing.OutCubic } }

        MouseArea {
            id: sopra
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: e => dock.mouseX = e.x
            onExited: dock.mouseX = -1000
        }

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: ScriptModel { values: dock.voci }
                delegate: Item {
                    id: casella
                    required property var modelData
                    width: 52
                    height: 52

                    readonly property real centro: x + width / 2 + 10
                    readonly property real vicinanza: Math.max(0, 1 - Math.abs(centro - dock.mouseX) / 130)
                    readonly property bool aperta: modelData.finestre.length > 0

                    Item {
                        id: icona
                        anchors.fill: parent
                        transformOrigin: Item.Bottom
                        scale: Opzioni.animazioni ? 1 + 0.42 * casella.vicinanza : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 46
                            asynchronous: true
                            mipmap: true
                            source: Applicazioni.icona(casella.modelData.icona)
                            scale: areaC.pressed ? 0.88 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.veloce } }
                        }
                    }

                    // pallino: l'app e' aperta
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 1
                        width: casella.aperta ? 5 : 0
                        height: 5
                        radius: 2.5
                        color: Tema.testo2
                        Behavior on width { NumberAnimation { duration: Tema.media } }
                    }

                    // il nome sopra l'icona
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -56
                        width: nomeApp.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: Tema.fondoPieno
                        border.width: 1
                        border.color: Tema.bordo
                        opacity: casella.vicinanza > 0.9 ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Tema.veloce } }
                        Text {
                            id: nomeApp
                            anchors.centerIn: parent
                            text: casella.modelData.nome
                            font.family: Tema.carattere
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Tema.testo
                        }
                    }

                    MouseArea {
                        id: areaC
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.clic(casella.modelData)
                    }
                }
            }
        }
    }
}
