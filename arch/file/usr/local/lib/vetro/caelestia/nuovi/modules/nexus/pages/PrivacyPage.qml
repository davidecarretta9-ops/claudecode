pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// oversicaOS: Impostazioni > Privacy e sicurezza. Mostra lo stato delle protezioni di
// Vetro (modalita' fantasma, firewall, Guardiano della rete, DNS cifrato, VPN) e apre i
// loro comandi di sempre: fantasma, vpn, cassaforte, guardiano-regole (le finestre che
// chiedono conferma e usano gli aiutanti sudo).
PageBase {
    id: root

    property bool fantasma
    property bool firewall
    property bool guardiano
    property bool dnsCifrato
    property bool vpn

    function apri(comando: string): void {
        Quickshell.execDetached([comando]);
    }

    // lo stato si rilegge ogni 3 secondi mentre la pagina e' aperta
    readonly property Process stato: Process {
        command: ["sh", "-c", "[ -e /etc/fantasma/attivo ] && echo fantasma; "
            + "systemctl is-active -q firewall.service && echo firewall; "
            + "systemctl is-active -q guardiano-rete.service && echo guardiano; "
            + "grep -qs '^DNSOverTLS=yes' /etc/systemd/resolved.conf.d/*.conf && echo dns; "
            + "ip link show vpn >/dev/null 2>&1 && echo vpn; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const righe = text.split("\n");
                root.fantasma = righe.includes("fantasma");
                root.firewall = righe.includes("firewall");
                root.guardiano = righe.includes("guardiano");
                root.dnsCifrato = righe.includes("dns");
                root.vpn = righe.includes("vpn");
            }
        }
    }

    readonly property Timer aggiorna: Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: root.stato.running = true
    }

    title: "Privacy e sicurezza"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Navigazione"
        }

        RowButton {
            first: true
            icon: "visibility_off"
            text: root.fantasma ? "Modalita' fantasma: accesa" : "Modalita' fantasma: spenta"
            subtext: "Tutto passa da Tor, l'indirizzo IP non si vede, webcam e microfono spenti"
            onClicked: root.apri("fantasma")
        }

        RowButton {
            icon: "vpn_lock"
            text: root.vpn ? "VPN: accesa" : "VPN: spenta"
            subtext: "Accendi, spegni o scegli la tua VPN WireGuard"
            onClicked: root.apri("vpn")
        }

        InfoRow {
            last: true
            icon: "dns"
            label: "DNS cifrato (Quad9)"
            subtext: "I nomi dei siti viaggiano cifrati"
            value: root.dnsCifrato ? "Acceso" : "Spento"
        }

        SectionHeader {
            text: "Protezioni"
        }

        InfoRow {
            first: true
            icon: "local_fire_department"
            label: "Firewall"
            subtext: "Blocca le connessioni che arrivano da fuori"
            value: root.firewall ? "Attivo" : "Spento"
        }

        RowButton {
            icon: "shield"
            text: root.guardiano ? "Guardiano della rete: attivo" : "Guardiano della rete: spento"
            subtext: "Chiede prima che un programma vada su internet. Tocca per le regole"
            onClicked: root.apri("guardiano-regole")
        }

        RowButton {
            last: true
            icon: "lock"
            text: "Cassaforte"
            subtext: "Una cartella cifrata che si apre con una password"
            onClicked: root.apri("cassaforte")
        }
    }
}
