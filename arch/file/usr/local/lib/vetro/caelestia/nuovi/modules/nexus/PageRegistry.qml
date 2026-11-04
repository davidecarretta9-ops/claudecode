pragma Singleton

import QtQuick
import Caelestia.I18n

// oversicaOS: l'elenco delle pagine delle Impostazioni, preso intero da Caelestia con le
// pagine di oversicaOS in piu'. Va tenuto allineato a PageCompRegistry.qml (stessa
// posizione = stessa pagina). "chiave": la barra apre alcune pagine per nome.
QtObject {
    id: root

    readonly property list<var> pages: [
        // oversicaOS: il tuo account (nome, password, avatar in stile Lodge)
        {
            label: "Account",
            icon: "account_circle",
            description: "Nome, password, avatar",
            category: "account",
            chiave: "account"
        },

        // Appearance
        {
            label: Tr.tr("Wallpaper & style"),
            chiave: "appearance",
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance"
        },
        // oversicaOS
        {
            label: "Schermo",
            icon: "monitor",
            description: "Luminosita', luce notturna, risoluzione, piu' schermi",
            category: "appearance",
            chiave: "schermo"
        },

        // Connectivity
        // TODO
        // {
        //     label: Tr.tr("Display"),
        //     icon: "monitor",
        //     description: Tr.tr("Output configuration"),
        //     category: "connectivity"
        // },
        {
            label: Tr.tr("Network"),
            chiave: "network",
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity"
        },
        {
            label: Tr.tr("Connected devices"),
            chiave: "bluetooth",
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },
        {
            label: Tr.tr("Audio"),
            chiave: "audio",
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity"
        },
        // oversicaOS
        {
            label: "Tastiera, mouse e touchpad",
            icon: "keyboard",
            description: "Disposizione dei tasti, velocita', tocco per clic",
            category: "connectivity",
            chiave: "tastiera"
        },

        // System
        // oversicaOS
        {
            label: "Accessibilita'",
            icon: "accessibility_new",
            description: "Testo piu' grande, meno animazioni",
            category: "system",
            chiave: "accessibilita"
        },
        {
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            category: "system"
        },
        {
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Manage plugins"),
            category: "system"
        },

        // Shell
        {
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            label: Tr.tr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics backend"),
            category: "shell"
        },
        {
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell"
        },

        // About
        {
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about"
        },
    ]
}
