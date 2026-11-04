pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// oversicaOS: Impostazioni > Tastiera, mouse e touchpad. Le scelte vanno nel file di
// Hyprland (ImpostazioniOversica -> HyprImpostazioni.js) e valgono subito.
PageBase {
    id: root

    readonly property list<MenuItem> disposizioni: [
        MenuItem {
            text: "Italiana"
            value: "it"
        },
        MenuItem {
            text: "Inglese (Stati Uniti)"
            value: "us"
        },
        MenuItem {
            text: "Inglese (Regno Unito)"
            value: "gb"
        },
        MenuItem {
            text: "Tedesca"
            value: "de"
        },
        MenuItem {
            text: "Francese"
            value: "fr"
        },
        MenuItem {
            text: "Spagnola"
            value: "es"
        },
        MenuItem {
            text: "Svizzera"
            value: "ch"
        },
        MenuItem {
            text: "Portoghese"
            value: "pt"
        }
    ]

    title: "Tastiera, mouse e touchpad"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Tastiera"
        }

        SelectRow {
            first: true
            last: true
            label: "Disposizione della tastiera"
            subtext: "Come sono messi i tasti (vale anche per la password)"
            menuItems: root.disposizioni
            active: root.disposizioni.find(i => i.value === ImpostazioniOversica.tastiera) ?? root.disposizioni[0]
            onSelected: item => ImpostazioniOversica.tastiera = item.value
        }

        SectionHeader {
            text: "Mouse e touchpad"
        }

        SliderRow {
            first: true
            icon: "speed"
            label: "Velocita' del puntatore"
            valueLabel: ImpostazioniOversica.velocita > 0.05 ? "Veloce" : ImpostazioniOversica.velocita < -0.05 ? "Lento" : "Normale"
            value: (ImpostazioniOversica.velocita + 1) / 2
            onMoved: v => ImpostazioniOversica.velocita = Math.round((v * 2 - 1) * 100) / 100
        }

        ToggleRow {
            text: "Scorrimento naturale"
            subtext: "Il contenuto segue le dita, come sul telefono"
            checked: ImpostazioniOversica.naturale
            onToggled: ImpostazioniOversica.naturale = checked
        }

        ToggleRow {
            last: true
            text: "Tocco per clic"
            subtext: "Un tocco sul touchpad vale come un clic"
            checked: ImpostazioniOversica.tocco
            onToggled: ImpostazioniOversica.tocco = checked
        }
    }
}
