pragma Singleton

import QtQuick
import Caelestia.I18n

// oversicaOS: l'elenco delle pagine delle Impostazioni, preso da Caelestia con le pagine di
// oversicaOS in piu' e nell'ordine di Windows e macOS. Va tenuto allineato a
// PageCompRegistry.qml (stessa posizione = stessa pagina). "chiave": il nome fisso della
// pagina (la barra apre alcune pagine per nome). Tolta "Plugins" (in costruzione).
QtObject {
    id: root

    readonly property list<var> pages: [
        // Account
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
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance",
            chiave: "appearance"
        },
        {
            label: "Schermo",
            icon: "monitor",
            description: "Luminosita', luce notturna, risoluzione, piu' schermi",
            category: "appearance",
            chiave: "schermo"
        },

        // Connectivity
        {
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity",
            chiave: "network"
        },
        {
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true,
            chiave: "bluetooth"
        },
        {
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity",
            chiave: "audio"
        },

        // System
        {
            label: "Privacy e sicurezza",
            icon: "shield",
            description: "Modalita' fantasma, VPN, firewall, cassaforte",
            category: "system",
            chiave: "privacy"
        },
        {
            label: "Energia e blocco",
            icon: "battery_charging_full",
            description: "Blocco, schermo spento, profilo energetico",
            category: "system",
            chiave: "energia"
        },
        {
            label: Tr.tr("Notifications"),
            icon: "notifications",
            description: "Non disturbare, come compaiono",
            category: "system",
            chiave: "notifiche"
        },
        {
            label: "Tastiera, mouse e touchpad",
            icon: "keyboard",
            description: "Disposizione dei tasti, velocita', tocco per clic",
            category: "system",
            chiave: "tastiera"
        },
        {
            label: "Data e ora",
            icon: "schedule",
            description: "Fuso orario, ora automatica, formato 24 ore",
            category: "system",
            chiave: "dataora"
        },
        {
            label: "Archiviazione",
            icon: "hard_drive",
            description: "Spazio sul disco, cestino, file temporanei",
            category: "system",
            chiave: "archiviazione"
        },
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
            category: "system",
            chiave: "aggiornamenti"
        },

        // Shell
        {
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell",
            chiave: "panels"
        },
        {
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell",
            chiave: "apps"
        },
        {
            label: Tr.tr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics backend"),
            category: "shell",
            chiave: "services"
        },
        {
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell",
            chiave: "language"
        },

        // About
        {
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about",
            chiave: "about"
        },
    ]
}
