pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// oversicaOS: Impostazioni > Aggiornamenti (in Caelestia era ancora "in costruzione").
// Controlla con checkupdates (pacman-contrib, senza toccare il sistema) e aggiorna nel
// terminale con "sudo pacman -Syu", che chiede la password.
PageBase {
    id: root

    property int quanti: -1          // -1: non ancora controllato
    property bool errore
    property string elenco

    readonly property Process controlla: Process {
        running: true
        command: ["checkupdates"]
        stdout: StdioCollector {
            id: uscita
        }
        onExited: code => {
            // checkupdates: 0 = ci sono aggiornamenti, 2 = nessuno, altro = errore
            root.errore = code !== 0 && code !== 2;
            const righe = uscita.text.split("\n").filter(r => r.trim() !== "");
            root.quanti = code === 0 ? righe.length : 0;
            root.elenco = righe.slice(0, 8).map(r => r.split(" ")[0]).join(", ") + (righe.length > 8 ? "..." : "");
        }
    }

    title: "Aggiornamenti"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Sistema"
        }

        InfoRow {
            first: true
            icon: "update"
            label: "Aggiornamenti disponibili"
            subtext: root.quanti > 0 ? root.elenco : ""
            value: {
                if (root.controlla.running || root.quanti < 0)
                    return "Controllo...";
                if (root.errore)
                    return "Non riesco a controllare";
                return root.quanti > 0 ? `${root.quanti}` : "Nessuno, e' tutto aggiornato";
            }
        }

        RowButton {
            icon: "refresh"
            text: "Controlla di nuovo"
            disabled: root.controlla.running
            onClicked: root.controlla.running = true
        }

        RowButton {
            last: true
            icon: "system_update_alt"
            text: "Aggiorna adesso"
            subtext: "Si apre il terminale: scrivi la tua password e conferma"
            onClicked: Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "sh", "-c", "sudo pacman -Syu; echo; read -r -p 'Fatto. Premi Invio per chiudere ' x"])
        }
    }
}
