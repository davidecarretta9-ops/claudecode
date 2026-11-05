pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// oversicaOS: Impostazioni > Data e ora. Fuso orario e ora automatica passano
// dall'aiutante /usr/local/sbin/oversica-data (sudo senza password solo per lui, accetta
// solo fusi orari che esistono); il formato a 24 ore e' una scelta di Caelestia.
PageBase {
    id: root

    property string fuso
    property bool automatica: true

    readonly property list<MenuItem> fusi: [
        MenuItem {
            text: "Italia (Roma)"
            value: "Europe/Rome"
        },
        MenuItem {
            text: "Regno Unito (Londra)"
            value: "Europe/London"
        },
        MenuItem {
            text: "Francia (Parigi)"
            value: "Europe/Paris"
        },
        MenuItem {
            text: "Germania (Berlino)"
            value: "Europe/Berlin"
        },
        MenuItem {
            text: "Spagna (Madrid)"
            value: "Europe/Madrid"
        },
        MenuItem {
            text: "Svizzera (Zurigo)"
            value: "Europe/Zurich"
        },
        MenuItem {
            text: "Portogallo (Lisbona)"
            value: "Europe/Lisbon"
        },
        MenuItem {
            text: "Stati Uniti (New York)"
            value: "America/New_York"
        },
        MenuItem {
            text: "Stati Uniti (Los Angeles)"
            value: "America/Los_Angeles"
        },
        MenuItem {
            text: "Brasile (San Paolo)"
            value: "America/Sao_Paulo"
        },
        MenuItem {
            text: "Giappone (Tokyo)"
            value: "Asia/Tokyo"
        },
        MenuItem {
            text: "Cina (Shanghai)"
            value: "Asia/Shanghai"
        },
        MenuItem {
            text: "Australia (Sydney)"
            value: "Australia/Sydney"
        },
        MenuItem {
            text: "Tempo universale (UTC)"
            value: "UTC"
        }
    ]

    readonly property list<MenuItem> formati: [
        MenuItem {
            text: "24 ore (14:30)"
            value: ClockFormat.TwentyFourHour
        },
        MenuItem {
            text: "12 ore (2:30 PM)"
            value: ClockFormat.TwelveHour
        },
        MenuItem {
            text: "Come la lingua del sistema"
            value: ClockFormat.Auto
        }
    ]

    function aiutante(argomenti: list<string>): void {
        cambia.command = ["sudo", "-n", ...argomenti];
        cambia.running = true;
    }

    readonly property Process leggi: Process {
        running: true
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const riga of text.split("\n")) {
                    if (riga.startsWith("Timezone="))
                        root.fuso = riga.slice(9);
                    else if (riga.startsWith("NTP="))
                        root.automatica = riga.slice(4) === "yes";
                }
            }
        }
    }

    readonly property Process cambia: Process {
        onExited: root.leggi.running = true
    }

    title: "Data e ora"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Data e ora"
        }

        InfoRow {
            first: true
            icon: "schedule"
            label: "Adesso"
            value: Qt.formatDateTime(Time.date, GlobalConfig.services.clockFormat === ClockFormat.TwelveHour ? "dddd d MMMM yyyy, h:mm AP" : "dddd d MMMM yyyy, HH:mm")
        }

        ToggleRow {
            text: "Ora automatica"
            subtext: "Prende l'ora esatta da internet"
            checked: root.automatica
            onToggled: root.aiutante(["/usr/local/sbin/oversica-data", "automatica", checked ? "si" : "no"])
        }

        SelectRow {
            last: true
            label: "Fuso orario"
            subtext: root.fuso
            menuItems: root.fusi
            active: root.fusi.find(i => i.value === root.fuso) ?? null
            fallbackText: root.fuso
            onSelected: item => root.aiutante(["/usr/local/sbin/oversica-data", "fuso", item.value])
        }

        SectionHeader {
            text: "Formato"
        }

        SelectRow {
            first: true
            last: true
            label: "Formato dell'ora"
            subtext: "Come si vede l'ora nella barra e nel blocco"
            menuItems: root.formati
            active: root.formati.find(i => i.value === GlobalConfig.services.clockFormat) ?? root.formati[0]
            onSelected: item => GlobalConfig.services.clockFormat = item.value
        }
    }
}
