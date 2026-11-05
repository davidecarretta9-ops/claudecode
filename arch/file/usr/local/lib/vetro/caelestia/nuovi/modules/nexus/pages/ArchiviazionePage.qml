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

// oversicaOS: Impostazioni > Archiviazione. Lo spazio sul disco (df), il cestino (gio) e i
// file temporanei della tua cartella (~/.cache: si tolgono quelli non usati da 7 giorni).
PageBase {
    id: root

    property real totale
    property real usato
    property real cestino
    property real temporanei
    property string esito

    function misura(byte: real): string {
        if (byte >= 1e9)
            return `${(byte / 1e9).toFixed(1).replace(".", ",")} GB`;
        if (byte >= 1e6)
            return `${Math.round(byte / 1e6)} MB`;
        return `${Math.round(byte / 1e3)} KB`;
    }

    readonly property Process leggi: Process {
        running: true
        command: ["sh", "-c", "df -B1 --output=size,used / | tail -n 1; "
            + "echo $(du -sb \"$HOME/.local/share/Trash\" 2>/dev/null | cut -f1); "
            + "echo $(du -sb \"$HOME/.cache\" 2>/dev/null | cut -f1)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.split("\n");
                const disco = (r[0] ?? "").trim().split(/\s+/);
                root.totale = Number(disco[0]) || 0;
                root.usato = Number(disco[1]) || 0;
                root.cestino = Number(r[1]) || 0;
                root.temporanei = Number(r[2]) || 0;
            }
        }
    }

    readonly property Process svuotaCestino: Process {
        command: ["gio", "trash", "--empty"]
        onExited: code => {
            root.esito = code === 0 ? "Cestino svuotato" : "Non sono riuscito a svuotare il cestino";
            root.leggi.running = true;
        }
    }

    readonly property Process pulisci: Process {
        command: ["find", `${Paths.home}/.cache`, "-type", "f", "-atime", "+7", "-delete"]
        onExited: {
            root.esito = "File temporanei vecchi eliminati";
            root.leggi.running = true;
        }
    }

    title: "Archiviazione"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Disco"
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: disco.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: disco

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    text: root.totale > 0 ? `${root.misura(root.usato)} usati su ${root.misura(root.totale)}` : "Calcolo..."
                    font: Tokens.font.body.small
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.padding.small
                    value: root.totale > 0 ? root.usato / root.totale : 0
                }

                StyledText {
                    visible: root.totale > 0
                    text: `Liberi: ${root.misura(root.totale - root.usato)}`
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        SectionHeader {
            text: "Fai spazio"
        }

        RowButton {
            first: true
            icon: "delete"
            text: `Svuota il cestino (${root.misura(root.cestino)})`
            subtext: "I file nel cestino si cancellano per sempre"
            disabled: root.svuotaCestino.running
            onClicked: root.svuotaCestino.running = true
        }

        RowButton {
            last: true
            icon: "cleaning_services"
            text: `Elimina i file temporanei (${root.misura(root.temporanei)})`
            subtext: "Solo quelli non usati da una settimana: i programmi li rifanno se servono"
            disabled: root.pulisci.running
            onClicked: root.pulisci.running = true
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.small
            visible: root.esito !== ""
            text: root.esito
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }
    }
}
