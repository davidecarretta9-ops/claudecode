pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common
import "../../../utils/Avatar.js" as Avatar

// oversicaOS: Impostazioni > Account. Il tuo nome, la password e l'avatar a pixel in stile
// Oversica Lodge: l'anteprima usa Avatar.js con gli stessi dati di oversica-avatar
// (/usr/share/oversica/avatar/pixel.json), quindi quello che vedi e' quello che salvi.
// "Salva" scrive ~/.config/oversica/avatar.json e ~/.face e lo rende visibile anche
// alla schermata di accesso.
PageBase {
    id: root

    property var dati: null
    property var salvate: Avatar.normalizza({})
    property var scelte: Avatar.normalizza({})
    readonly property bool cambiate: JSON.stringify(scelte) !== JSON.stringify(salvate)
    readonly property var griglia: dati ? Avatar.griglia(dati, scelte) : []
    readonly property string utente: Quickshell.env("USER")
    property string nomeMostrato
    property string esito

    readonly property var stili: [
        { valore: "corti", testo: "Corti" },
        { valore: "folti", testo: "Folti" },
        { valore: "lunghi", testo: "Lunghi" },
        { valore: "raccolti", testo: "Raccolti" },
        { valore: "ricci", testo: "Ricci" },
        { valore: "rasati", testo: "Rasati" }
    ]

    function scegli(campo: string, valore: var): void {
        const s = Object.assign({}, scelte);
        s[campo] = valore;
        scelte = s;
        esito = "";
    }

    function terminale(comando: list<string>): void {
        Quickshell.execDetached([...GlobalConfig.general.apps.terminal, ...comando]);
    }

    readonly property FileView fileDati: FileView {
        path: "/usr/share/oversica/avatar/pixel.json"
        onLoaded: root.dati = JSON.parse(text())
    }

    readonly property FileView fileScelte: FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`}/oversica/avatar.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.salvate = Avatar.normalizza(JSON.parse(text()));
            } catch (e) {
                root.salvate = Avatar.normalizza({});
            }
            root.scelte = root.salvate;
        }
    }

    // il nome mostrato (il campo "nome completo" dell'utente)
    readonly property Process leggiNome: Process {
        running: true
        command: ["getent", "passwd", root.utente]
        stdout: StdioCollector {
            onStreamFinished: root.nomeMostrato = (text.split(":")[4] ?? "").split(",")[0]
        }
    }

    readonly property Process salva: Process {
        command: ["oversica-avatar", "salva", JSON.stringify(root.scelte)]
        stderr: StdioCollector {
            id: erroriSalva
        }
        onExited: code => {
            if (code === 0) {
                root.salvate = root.scelte;
                root.esito = erroriSalva.text.trim() || "Avatar salvato";
            } else {
                root.esito = "Non sono riuscito a salvare l'avatar";
            }
        }
    }

    title: "Account"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Il tuo account"
        }

        InfoRow {
            first: true
            icon: "person"
            label: "Nome utente"
            value: root.utente
        }

        InfoRow {
            icon: "badge"
            label: "Nome mostrato"
            value: root.nomeMostrato || root.utente
        }

        RowButton {
            icon: "edit"
            text: "Cambia il nome mostrato"
            subtext: "Si apre il terminale: scrivi la password e poi il nuovo nome"
            onClicked: root.terminale(["chfn"])
        }

        RowButton {
            last: true
            icon: "key"
            text: "Cambia la password"
            subtext: "Si apre il terminale: scrivi la password di adesso e poi quella nuova"
            onClicked: root.terminale(["passwd"])
        }

        SectionHeader {
            text: "Avatar"
        }

        // l'anteprima: un quadratino per ogni pixel
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            implicitHeight: anteprima.height + Tokens.padding.extraLarge * 2

            Grid {
                id: anteprima

                readonly property int pixel: 12

                anchors.centerIn: parent
                columns: 16

                Repeater {
                    model: 256

                    Rectangle {
                        required property int index
                        readonly property var colore: root.griglia.length ? root.griglia[Math.floor(index / 16)][index % 16] : null

                        width: anteprima.pixel
                        height: anteprima.pixel
                        color: colore ?? (root.dati ? root.dati.sfondo : "transparent")
                    }
                }
            }
        }

        Scelta {
            titolo: "Capelli"

            Repeater {
                model: root.stili

                Chip {
                    required property var modelData

                    testo: modelData.testo
                    scelto: root.scelte.capelli === modelData.valore
                    onScegli: root.scegli("capelli", modelData.valore)
                }
            }
        }

        Scelta {
            titolo: "Colore dei capelli"

            Repeater {
                model: root.dati ? root.dati.tavolozze.capelli : []

                Tinta {
                    campo: "coloreCapelli"
                }
            }
        }

        Scelta {
            titolo: "Pelle"

            Repeater {
                model: root.dati ? root.dati.tavolozze.pelle : []

                Tinta {
                    campo: "pelle"
                }
            }
        }

        Scelta {
            titolo: "Maglia"
            last: true

            Repeater {
                model: root.dati ? root.dati.tavolozze.maglia : []

                Tinta {
                    campo: "maglia"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.esito
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            TextButton {
                isRound: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                type: TextButton.Tonal
                text: "Annulla"
                disabled: !root.cambiate || root.salva.running
                onClicked: {
                    root.scelte = root.salvate;
                    root.esito = "";
                }
            }

            TextButton {
                isRound: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                text: "Salva"
                disabled: !root.cambiate || root.salva.running
                onClicked: root.salva.running = true
            }
        }
    }

    // una riga di scelte con il suo titolo
    component Scelta: ConnectedRect {
        id: scelta

        required property string titolo
        default property alias voci: voci.data

        Layout.fillWidth: true
        implicitHeight: colonna.implicitHeight + Tokens.padding.large * 2

        ColumnLayout {
            id: colonna

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            anchors.leftMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.small

            StyledText {
                text: scelta.titolo
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurface
            }

            Flow {
                id: voci

                Layout.fillWidth: true
                spacing: Tokens.spacing.small
            }
        }
    }

    // una capigliatura: pillola di testo, arancio se scelta
    component Chip: StyledRect {
        id: chip

        required property string testo
        required property bool scelto

        signal scegli

        implicitWidth: etichetta.implicitWidth + Tokens.padding.large * 2
        implicitHeight: etichetta.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: scelto ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        StyledText {
            id: etichetta

            anchors.centerIn: parent
            text: chip.testo
            font: Tokens.font.body.small
            color: chip.scelto ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.scegli()
        }
    }

    // un colore: tondo, con l'anello se scelto
    component Tinta: Rectangle {
        id: tinta

        required property var modelData
        required property int index
        required property string campo
        readonly property bool scelto: root.scelte[campo] === index

        implicitWidth: 32
        implicitHeight: 32
        radius: width / 2
        color: modelData.colore
        border.width: scelto ? 3 : 0
        border.color: Colours.palette.m3primary

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.scegli(tinta.campo, tinta.index)
        }
    }
}
