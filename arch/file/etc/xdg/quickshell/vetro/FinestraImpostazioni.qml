// Impostazioni del desktop Vetro (creato da lfs.sh, Fase 10): a sinistra le voci,
// a destra le scelte. Tutto vale subito e resta salvato. Si apre con Windows+I,
// dal centro di controllo o dall'icona delle Impostazioni.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets

FloatingWindow {
    id: finestra
    title: "Impostazioni di sistema"
    implicitWidth: 1040
    implicitHeight: 700
    minimumSize: Qt.size(880, 580)
    color: "transparent"

    onClosed: Stato.impostazioni = false

    readonly property var voci: [
        { id: "generale",   nome: "Generale",         icona: "home" },
        { id: "aspetto",    nome: "Aspetto",          icona: "palette" },
        { id: "finestre",   nome: "Finestre",         icona: "select_window" },
        { id: "barra",      nome: "Barra",            icona: "dock_to_bottom" },
        { id: "cruscotto",  nome: "Cruscotto e meteo", icona: "partly_cloudy_day" },
        { id: "notifiche",  nome: "Notifiche",        icona: "notifications" },
        { id: "blocco",     nome: "Blocco schermo",   icona: "lock" },
        { id: "schermo",    nome: "Schermo",          icona: "desktop_windows" },
        { id: "sistema",    nome: "Sistema",          icona: "info" }
    ]
    function nomeDi(id) {
        for (let i = 0; i < voci.length; i++) if (voci[i].id === id) return voci[i].nome;
        return "";
    }

    Rectangle {
        id: corpo
        anchors.fill: parent
        radius: Tema.raggio
        color: Tema.fondoPieno
        border.width: 1
        border.color: Tema.bordoForte
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------------------------------------------------- menu a sinistra
            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: Tema.carta

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    // (i tre pulsanti tondi e lo spostamento: li ha la barra del titolo
                    // delle finestre, quella del plugin hyprbars)

                    // chi sei
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        spacing: 10
                        Avatar { Layout.preferredWidth: 44; Layout.preferredHeight: 44 }
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Opzioni.nomeUtente() || Sistema.utente
                                font.family: Tema.carattere; font.pixelSize: 15; font.weight: Font.DemiBold
                                color: Tema.testo
                            }
                            Text {
                                text: Sistema.nomeComputer
                                font.family: Tema.carattere; font.pixelSize: 11
                                color: Tema.testo2
                            }
                        }
                    }

                    ListView {
                        id: menu
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: finestra.voci
                        currentIndex: {
                            for (let i = 0; i < finestra.voci.length; i++)
                                if (finestra.voci[i].id === Stato.pagina) return i;
                            return 0;
                        }
                        highlightMoveDuration: Tema.media
                        highlight: Rectangle { radius: Tema.raggioPiccolo; color: Tema.accento }
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: menu.width
                            height: 40
                            readonly property bool scelta: Stato.pagina === modelData.id
                            Rectangle {
                                anchors.fill: parent
                                radius: Tema.raggioPiccolo
                                color: areaVoce.containsMouse && !parent.scelta ? Tema.cartaForte : "transparent"
                            }
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Icona {
                                    nome: modelData.icona
                                    dimensione: 19
                                    piena: parent.parent.scelta
                                    color: parent.parent.scelta ? Tema.suAccento : Tema.testo2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.nome
                                    font.family: Tema.carattere; font.pixelSize: 13
                                    font.weight: parent.parent.scelta ? Font.DemiBold : Font.Normal
                                    color: parent.parent.scelta ? Tema.suAccento : Tema.testo
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                id: areaVoce
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Stato.pagina = modelData.id
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------------- pagina a destra
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    MouseArea { anchors.fill: parent; onPressed: finestra.startSystemMove() }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: finestra.nomeDi(Stato.pagina)
                        font.family: Tema.carattere; font.pixelSize: 22; font.weight: Font.Bold
                        color: Tema.testo
                    }
                }

                Flickable {
                    id: scorri
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: pagina.height + 40
                    boundsBehavior: Flickable.StopAtBounds

                    Loader {
                        id: pagina
                        x: 28
                        width: scorri.width - 56
                        opacity: 0
                        sourceComponent: {
                            switch (Stato.pagina) {
                            case "aspetto": return pAspetto;
                            case "finestre": return pFinestre;
                            case "barra": return pBarra;
                            case "cruscotto": return pCruscotto;
                            case "notifiche": return pNotifiche;
                            case "blocco": return pBlocco;
                            case "schermo": return pSchermo;
                            case "sistema": return pSistema;
                            default: return pGenerale;
                            }
                        }
                        onLoaded: { scorri.contentY = 0; entra.restart(); }
                        ParallelAnimation {
                            id: entra
                            NumberAnimation { target: pagina; property: "opacity"; from: 0; to: 1; duration: Tema.media }
                            NumberAnimation { target: pagina; property: "x"; from: 52; to: 28; duration: Tema.media; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }

    // =================================================================== le pagine
    Component {
        id: pGenerale
        ColumnLayout {
            spacing: 16
            Carta {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                SystemClock { id: oraG; precision: SystemClock.Minutes }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 20
                    Avatar { Layout.preferredWidth: 84; Layout.preferredHeight: 84 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: Saluto.frase(oraG.date) + (Opzioni.nomeUtente() !== "" ? ", " + Opzioni.nomeUtente() : "")
                            font.family: Tema.carattere; font.pixelSize: 24; font.weight: Font.Bold
                            color: Tema.testo
                        }
                        Text {
                            text: oraG.date.toLocaleString(Qt.locale("it_IT"), "dddd d MMMM  ·  HH:mm")
                            font.family: Tema.carattere; font.pixelSize: 13
                            color: Tema.testo2
                        }
                        Text {
                            text: "Tema " + Tema.attuale.nome + "  ·  acceso da " + Sistema.testoAcceso()
                            font.family: Tema.carattere; font.pixelSize: 12
                            color: Tema.testo3
                        }
                    }
                }
            }
            Text {
                text: "Cosa vuoi cambiare?"
                font.family: Tema.carattere; font.pixelSize: 14; font.weight: Font.DemiBold
                color: Tema.testo2
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: finestra.voci.slice(1)
                    delegate: Carta {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        cliccabile: true
                        onCliccata: Stato.pagina = modelData.id
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14
                            Rectangle {
                                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                                radius: 13
                                color: Tema.cartaForte
                                Icona { anchors.centerIn: parent; nome: modelData.icona; dimensione: 22 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.nome
                                font.family: Tema.carattere; font.pixelSize: 14; font.weight: Font.DemiBold
                                color: Tema.testo
                            }
                            Icona { nome: "chevron_right"; dimensione: 20; color: Tema.testo3 }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pAspetto
        ColumnLayout {
            spacing: 16
            Titolo { testo: "Tema" }
            Row {
                spacing: 14
                Repeater {
                    model: Tema.temi
                    delegate: Column {
                        required property var modelData
                        spacing: 8
                        Rectangle {
                            width: 128; height: 84
                            radius: Tema.raggioMedio
                            color: modelData.fondo
                            border.width: Opzioni.tema === modelData.id ? 3 : 1
                            border.color: Opzioni.tema === modelData.id ? Tema.accento : Tema.bordoForte
                            scale: areaT.containsMouse ? 1.04 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.veloce } }
                            Rectangle {
                                x: 12; y: 14; width: 64; height: 10; radius: 5
                                color: modelData.accento
                            }
                            Rectangle {
                                x: 12; y: 32; width: 96; height: 8; radius: 4
                                color: modelData.id === "carta" ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.18)
                            }
                            Rectangle {
                                x: 12; y: 46; width: 76; height: 8; radius: 4
                                color: modelData.id === "carta" ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(1, 1, 1, 0.12)
                            }
                            MouseArea {
                                id: areaT
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Opzioni.tema = modelData.id
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.nome
                            font.family: Tema.carattere; font.pixelSize: 12
                            font.weight: Opzioni.tema === modelData.id ? Font.DemiBold : Font.Normal
                            color: Tema.testo
                        }
                    }
                }
            }
            Titolo { testo: "Effetto vetro" }
            Gruppo {
                Riga {
                    titolo: "Trasparenza dei pannelli"
                    sottotitolo: "Più trasparente: si vede di più lo sfondo, sfocato"
                    Cursore {
                        Layout.preferredWidth: 220
                        valore: (0.95 - Opzioni.opacita) / 0.6
                        onSpostato: v => Opzioni.opacita = Math.round((0.95 - v * 0.6) * 100) / 100
                    }
                }
            }
            Titolo { testo: "Sfondo" }
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: Sfondi.elenco
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 0.6
                        radius: Tema.raggioPiccolo
                        color: Tema.carta
                        border.width: modelData === Sfondi.attuale ? 3 : 1
                        border.color: modelData === Sfondi.attuale ? Tema.accento : Tema.bordo
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 320
                            sourceSize.height: 200
                            source: "file://" + modelData
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Sfondi.scegli(modelData)
                        }
                    }
                }
            }
            Pulsante {
                testo: "Usa una tua immagine..."
                icona: "add_photo_alternate"
                onCliccato: Quickshell.execDetached(["/usr/local/bin/impostazioni-aspetto"])
            }
        }
    }

    Component {
        id: pFinestre
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Animazioni"
                    sottotitolo: "Finestre e pannelli si muovono in modo fluido"
                    Interruttore { acceso: Opzioni.animazioni; onCambiato: v => Opzioni.animazioni = v }
                }
                Riga {
                    titolo: "Sfocatura"
                    sottotitolo: "Lo sfondo dietro i pannelli si vede sfocato (effetto vetro)"
                    Interruttore { acceso: Opzioni.sfocatura; onCambiato: v => Opzioni.sfocatura = v }
                }
                Riga {
                    titolo: "Affianca le finestre"
                    sottotitolo: "Le finestre nuove si dividono lo schermo da sole (per le finestre già aperte: Windows+V)"
                    Interruttore { acceso: Opzioni.affianca; onCambiato: v => Opzioni.affianca = v }
                }
            }
            Gruppo {
                Riga {
                    titolo: "Spazio tra le finestre"
                    sottotitolo: Opzioni.spazi + " pixel"
                    Cursore {
                        Layout.preferredWidth: 220
                        valore: Opzioni.spazi / 32
                        onSpostato: v => Opzioni.spazi = Math.round(v * 32)
                    }
                }
                Riga {
                    titolo: "Angoli arrotondati"
                    sottotitolo: Opzioni.angoli + " pixel"
                    Cursore {
                        Layout.preferredWidth: 220
                        valore: Opzioni.angoli / 28
                        onSpostato: v => Opzioni.angoli = Math.round(v * 28)
                    }
                }
            }
            Gruppo {
                Riga {
                    titolo: "Tasti utili"
                    sottotitolo: "Windows: cerca le app  ·  Windows+A: centro di controllo  ·  Windows+D: cruscotto\n"
                                 + "Alt+Tab: cambia finestra  ·  Windows+↑: ingrandisci  ·  Windows+↓: riduci  ·  Alt+F4: chiudi\n"
                                 + "Windows+1...5: scrivanie  ·  Windows+L: blocca  ·  Stamp: schermata"
                }
            }
        }
    }

    Component {
        id: pBarra
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Secondi nell'orologio"
                    sottotitolo: "Nella barra in basso"
                    Interruttore { acceso: Opzioni.secondi; onCambiato: v => Opzioni.secondi = v }
                }
            }
            Titolo { testo: "App nella barra" }
            Gruppo {
                Repeater {
                    model: Opzioni.preferite
                    delegate: Riga {
                        required property var modelData
                        required property int index
                        readonly property var app: DesktopEntries.byId(modelData)
                        visible: app !== null
                        titolo: app ? app.name : modelData
                        sottotitolo: app ? (app.genericName || app.comment || "") : ""
                        Pulsante {
                            testo: "Togli"
                            icona: "remove"
                            onCliccato: {
                                const l = Opzioni.preferite.slice();
                                l.splice(index, 1);
                                Opzioni.preferite = l;
                            }
                        }
                    }
                }
            }
            Titolo { testo: "Aggiungi un'app alla barra" }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 20
                color: Tema.cartaForte
                TextInput {
                    id: cercaApp
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tema.carattere; font.pixelSize: 13
                    color: Tema.testo
                    clip: true
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: cercaApp.text === ""
                        text: "Scrivi il nome dell'app..."
                        font: cercaApp.font
                        color: Tema.testo3
                    }
                }
            }
            Gruppo {
                visible: cercaApp.text !== ""
                Repeater {
                    model: cercaApp.text !== "" ? Applicazioni.cerca(cercaApp.text, 6) : []
                    delegate: Riga {
                        required property var modelData
                        titolo: modelData.name
                        sottotitolo: modelData.genericName || modelData.comment || ""
                        Pulsante {
                            testo: Opzioni.preferite.indexOf(modelData.id) >= 0 ? "Già nella barra" : "Aggiungi"
                            icona: "add"
                            onCliccato: {
                                if (Opzioni.preferite.indexOf(modelData.id) >= 0) return;
                                const l = Opzioni.preferite.slice();
                                l.push(modelData.id);
                                Opzioni.preferite = l;
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pCruscotto
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Meteo"
                    sottotitolo: "Lo chiede a wttr.in ogni mezz'ora (in modalità fantasma passa da Tor)"
                    Interruttore { acceso: Opzioni.meteo; onCambiato: v => Opzioni.meteo = v }
                }
                Riga {
                    titolo: "Città"
                    sottotitolo: "Vuoto: la trova da sola dalla connessione"
                    Rectangle {
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Tema.cartaForte
                        TextInput {
                            id: citta
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            text: Opzioni.citta
                            font.family: Tema.carattere; font.pixelSize: 13
                            color: Tema.testo
                            clip: true
                            onEditingFinished: Opzioni.citta = text.trim()
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: citta.text === "" && !citta.activeFocus
                                text: "es. Roma"
                                font: citta.font
                                color: Tema.testo3
                            }
                        }
                    }
                }
            }
            Gruppo {
                Riga {
                    titolo: "Ora: " + (Meteo.pronto ? Meteo.temperatura + "°C, " + Meteo.descrizione : "non ancora disponibile")
                    sottotitolo: Meteo.luogo
                    Pulsante { testo: "Aggiorna"; icona: "refresh"; onCliccato: Meteo.aggiorna() }
                }
            }
        }
    }

    Component {
        id: pNotifiche
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Non disturbare"
                    sottotitolo: "Le notifiche arrivano lo stesso, ma senza comparire (tranne quelle urgenti)"
                    Interruttore { acceso: Opzioni.nonDisturbare; onCambiato: v => Opzioni.nonDisturbare = v }
                }
                Riga {
                    titolo: Avvisi.quante === 1 ? "1 notifica da leggere" : Avvisi.quante + " notifiche da leggere"
                    sottotitolo: "Le trovi nel centro di controllo (Windows+A)"
                    Pulsante { visible: Avvisi.quante > 0; testo: "Cancella tutte"; icona: "clear_all"; onCliccato: Avvisi.cancellaTutte() }
                }
                Riga {
                    titolo: "Prova"
                    sottotitolo: "Manda una notifica per vedere come appare"
                    Pulsante {
                        testo: "Manda"
                        icona: "send"
                        onCliccato: Quickshell.execDetached(["notify-send", "-a", "Impostazioni", "Ciao!", "Così appaiono le notifiche."])
                    }
                }
            }
        }
    }

    Component {
        id: pBlocco
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga {
                    titolo: "Blocca da solo dopo"
                    sottotitolo: "Se non tocchi mouse e tastiera (dal centro di controllo puoi dire \"Resta sveglio\")"
                    Row {
                        spacing: 4
                        Repeater {
                            model: [0, 5, 10, 15, 30, 60]
                            delegate: Rectangle {
                                required property var modelData
                                width: testoMin.implicitWidth + 22
                                height: 32
                                radius: 16
                                color: Opzioni.bloccoMinuti === modelData ? Tema.accento : (areaMin.containsMouse ? Tema.cartaSopra : Tema.cartaForte)
                                Text {
                                    id: testoMin
                                    anchors.centerIn: parent
                                    text: modelData === 0 ? "Mai" : modelData + " min"
                                    font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.Medium
                                    color: Opzioni.bloccoMinuti === modelData ? Tema.suAccento : Tema.testo
                                }
                                MouseArea {
                                    id: areaMin
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Opzioni.bloccoMinuti = modelData
                                }
                            }
                        }
                    }
                }
                Riga {
                    titolo: "Blocca adesso"
                    sottotitolo: "Anche con Windows+L"
                    Pulsante { testo: "Blocca"; icona: "lock"; onCliccato: { Stato.impostazioni = false; Stato.blocca(); } }
                }
            }
        }
    }

    Component {
        id: pSchermo
        ColumnLayout {
            id: paginaSchermo
            spacing: 16

            // uno per ogni schermo collegato (barra e sfondo ci sono su tutti)
            Repeater {
                model: Opzioni.schermi
                delegate: Gruppo {
                    id: gruppoSchermo
                    required property var modelData
                    readonly property string nome: modelData.name
                    readonly property var scelta: Opzioni.scelteSchermi[nome] || ({})
                    readonly property bool principale: scelta.principale === true
                        || (!Object.values(Opzioni.scelteSchermi).some(c => c.principale) && Opzioni.schermi[0].name === nome)
                    readonly property string risoluzione: modelData.width + "x" + modelData.height
                    readonly property var modi: {
                        const visti = {}, l = [];
                        for (const m of (modelData.availableModes || [])) {
                            const r = m.split("@")[0];
                            if (!visti[r]) { visti[r] = true; l.push(r); }
                        }
                        return l;
                    }
                    Riga {
                        titolo: gruppoSchermo.nome + (gruppoSchermo.principale ? "  (principale)" : "")
                        sottotitolo: "Ora: " + gruppoSchermo.risoluzione + ", grandezza " + Math.round(modelData.scale * 100) + "%"
                        Pulsante {
                            visible: Opzioni.schermi.length > 1 && !gruppoSchermo.principale
                            testo: "Rendi principale"
                            icona: "star"
                            onCliccato: Opzioni.sceltaSchermo(gruppoSchermo.nome, "principale", true)
                        }
                    }
                    Riga {
                        visible: Opzioni.schermi.length > 1 && !gruppoSchermo.principale
                        titolo: "Posizione"
                        sottotitolo: "Rispetto allo schermo principale"
                        Repeater {
                            model: [["destra", "A destra"], ["sinistra", "A sinistra"], ["sopra", "Sopra"], ["duplica", "Uguale"]]
                            delegate: Scelta {
                                required property var modelData
                                testo: modelData[1]
                                scelto: (gruppoSchermo.scelta.posizione || "destra") === modelData[0]
                                onCliccato: Opzioni.sceltaSchermo(gruppoSchermo.nome, "posizione", modelData[0])
                            }
                        }
                    }
                    Riga {
                        titolo: "Grandezza di testi e finestre"
                        Repeater {
                            model: [1, 1.25, 1.5, 2]
                            delegate: Scelta {
                                required property var modelData
                                testo: Math.round(modelData * 100) + "%"
                                scelto: Math.abs(modelData - gruppoSchermo.modelData.scale) < 0.01
                                onCliccato: Opzioni.sceltaSchermo(gruppoSchermo.nome, "scala", modelData)
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.margins: 14
                        spacing: 6
                        Repeater {
                            model: gruppoSchermo.modi
                            delegate: Scelta {
                                required property var modelData
                                testo: modelData
                                scelto: modelData === gruppoSchermo.risoluzione
                                onCliccato: Opzioni.sceltaSchermo(gruppoSchermo.nome, "risoluzione", modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pSistema
        ColumnLayout {
            spacing: 16
            Gruppo {
                Riga { titolo: "Computer"; sottotitolo: Sistema.nomeComputer }
                Riga { titolo: "Utente"; sottotitolo: Sistema.utente }
                Riga { titolo: "Processore"; sottotitolo: Sistema.processore }
                Riga { titolo: "Memoria"; sottotitolo: Sistema.memoriaTotale.toFixed(1) + " GB" }
                Riga { titolo: "Disco"; sottotitolo: Sistema.discoUsato.toFixed(1) + " GB usati su " + Sistema.discoTotale.toFixed(1) + " GB" }
                Riga { titolo: "Kernel Linux"; sottotitolo: Sistema.kernel }
                Riga { titolo: "Desktop"; sottotitolo: "Vetro (Hyprland + Quickshell)" }
            }
            Titolo { testo: "Altre impostazioni" }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: [
                        { id: "vpn", nome: "VPN", icona: "vpn_lock" },
                        { id: "fantasma", nome: "Modalità fantasma", icona: "visibility_off" },
                        { id: "guardiano-regole", nome: "Guardiano della rete", icona: "shield" },
                        { id: "cassaforte", nome: "Cassaforte", icona: "lock" },
                        { id: "wine-programmi", nome: "Programmi Windows", icona: "window" },
                        { id: "cups", nome: "Stampanti", icona: "print" },
                        { id: "xfce4-taskmanager", nome: "Gestione attività", icona: "monitoring" },
                        { id: "impostazioni", nome: "Impostazioni classiche", icona: "tune" }
                    ].filter(v => !!DesktopEntries.byId(v.id))
                    delegate: Carta {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        cliccabile: true
                        onCliccata: {
                            // le Impostazioni classiche (a finestre di yad), non queste
                            if (modelData.id === "impostazioni") {
                                Quickshell.execDetached(["/usr/local/bin/impostazioni", "--classiche"]);
                                return;
                            }
                            const e = DesktopEntries.byId(modelData.id);
                            if (e) e.execute();
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12
                            Icona { nome: modelData.icona; dimensione: 22 }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.nome
                                font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                                color: Tema.testo
                            }
                            Icona { nome: "open_in_new"; dimensione: 16; color: Tema.testo3 }
                        }
                    }
                }
            }
        }
    }

    // =================================================================== pezzi comuni
    component Titolo: Text {
        property string testo: ""
        text: testo
        Layout.topMargin: 4
        font.family: Tema.carattere
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: Tema.testo2
    }

    // un gruppo di righe dentro una carta
    component Gruppo: Rectangle {
        id: gruppo
        default property alias contenuto: colonnaG.data
        Layout.fillWidth: true
        implicitHeight: colonnaG.implicitHeight
        radius: Tema.raggioMedio
        color: Tema.carta
        border.width: 1
        border.color: Tema.bordo
        ColumnLayout {
            id: colonnaG
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
        }
    }

    // una riga: titolo e spiegazione a sinistra, il comando a destra
    component Riga: Item {
        id: riga
        property string titolo: ""
        property string sottotitolo: ""
        default property alias comando: postoComando.data
        Layout.fillWidth: true
        implicitHeight: Math.max(58, testi.implicitHeight + 24)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16
            ColumnLayout {
                id: testi
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: riga.titolo
                    wrapMode: Text.Wrap
                    font.family: Tema.carattere; font.pixelSize: 13; font.weight: Font.DemiBold
                    color: Tema.testo
                }
                Text {
                    Layout.fillWidth: true
                    visible: riga.sottotitolo !== ""
                    text: riga.sottotitolo
                    wrapMode: Text.Wrap
                    font.family: Tema.carattere; font.pixelSize: 11
                    color: Tema.testo2
                }
            }
            RowLayout { id: postoComando; spacing: 8 }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            height: 1
            color: Tema.bordo
        }
    }

    component Pulsante: Rectangle {
        id: puls
        property string testo: ""
        property string icona: ""
        signal cliccato()
        implicitHeight: 34
        implicitWidth: rigaPu.implicitWidth + 26
        radius: 17
        color: areaPu.containsMouse ? Tema.cartaSopra : Tema.cartaForte
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
        Row {
            id: rigaPu
            anchors.centerIn: parent
            spacing: 6
            Icona { visible: puls.icona !== ""; nome: puls.icona; dimensione: 16; anchors.verticalCenter: parent.verticalCenter }
            Text { text: puls.testo; font.family: Tema.carattere; font.pixelSize: 12; font.weight: Font.Medium; color: Tema.testo; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: areaPu; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: puls.cliccato() }
    }

    // una scelta tonda (risoluzione, posizione, grandezza): colorata quando e' quella attuale
    component Scelta: Rectangle {
        id: scelta
        property string testo: ""
        property bool scelto: false
        signal cliccato()
        implicitWidth: testoScelta.implicitWidth + 22
        implicitHeight: 32
        radius: 16
        color: scelto ? Tema.accento : (areaScelta.containsMouse ? Tema.cartaSopra : Tema.cartaForte)
        Text {
            id: testoScelta
            anchors.centerIn: parent
            text: scelta.testo
            font.family: Tema.carattere; font.pixelSize: 12
            color: scelta.scelto ? Tema.suAccento : Tema.testo
        }
        MouseArea { id: areaScelta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: scelta.cliccato() }
    }

    component Semaforo: Rectangle {
        id: sem
        property color colore: "red"
        property string segno: ""
        signal cliccato()
        width: 14
        height: 14
        radius: 7
        color: colore
        border.width: 1
        border.color: Qt.darker(colore, 1.2)
        Icona {
            anchors.centerIn: parent
            visible: areaSem.containsMouse
            nome: sem.segno
            dimensione: 11
            color: Qt.rgba(0, 0, 0, 0.6)
        }
        MouseArea { id: areaSem; anchors.fill: parent; hoverEnabled: true; onClicked: sem.cliccato() }
    }
}
