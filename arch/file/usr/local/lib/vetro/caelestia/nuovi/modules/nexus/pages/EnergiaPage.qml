pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// oversicaOS: Impostazioni > Energia e blocco. I tempi sono quelli di Caelestia
// (general.idle.timeouts: blocco, spegnimento dello schermo, sospensione), il profilo
// energetico e' quello di power-profiles-daemon.
PageBase {
    id: root

    readonly property list<MenuItem> tempi: [
        MenuItem {
            text: "1 minuto"
            value: 60
        },
        MenuItem {
            text: "3 minuti"
            value: 180
        },
        MenuItem {
            text: "5 minuti"
            value: 300
        },
        MenuItem {
            text: "10 minuti"
            value: 600
        },
        MenuItem {
            text: "15 minuti"
            value: 900
        },
        MenuItem {
            text: "30 minuti"
            value: 1800
        },
        MenuItem {
            text: "1 ora"
            value: 3600
        },
        MenuItem {
            text: "Mai"
            value: 0
        }
    ]

    readonly property list<MenuItem> profili: [
        MenuItem {
            text: "Risparmio energetico"
            value: PowerProfile.PowerSaver
        },
        MenuItem {
            text: "Bilanciato"
            value: PowerProfile.Balanced
        },
        MenuItem {
            text: "Prestazioni"
            value: PowerProfile.Performance
        }
    ]

    // la posizione nella lista di Caelestia del tempo che fa "azione" (-1 se non c'e')
    function indice(azione: string): int {
        const voci = GlobalConfig.general.idle.timeouts.values;
        for (let i = 0; i < voci.length; i++)
            if (JSON.stringify(voci[i].idleAction).includes(azione))
                return i;
        return -1;
    }

    function tempo(azione: string): int {
        const i = indice(azione);
        if (i < 0)
            return 0;
        const v = GlobalConfig.general.idle.timeouts.values[i];
        return v.enabled ? v.timeout : 0;
    }

    function cambia(azione: string, secondi: int): void {
        const i = indice(azione);
        if (i < 0)
            return;
        const v = GlobalConfig.general.idle.timeouts.at(i);
        if (secondi > 0) {
            v.timeout = secondi;
            v.enabled = true;
        } else {
            v.enabled = false;
        }
    }

    title: "Energia e blocco"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Quando non usi il computer"
        }

        SelectRow {
            first: true
            label: "Blocca lo schermo dopo"
            menuItems: root.tempi
            active: root.tempi.find(i => i.value === root.tempo("lock")) ?? null
            fallbackText: `${Math.round(root.tempo("lock") / 60)} minuti`
            onSelected: item => root.cambia("lock", item.value)
        }

        SelectRow {
            label: "Spegni lo schermo dopo"
            menuItems: root.tempi
            active: root.tempi.find(i => i.value === root.tempo("dpms off")) ?? null
            fallbackText: `${Math.round(root.tempo("dpms off") / 60)} minuti`
            onSelected: item => root.cambia("dpms off", item.value)
        }

        SelectRow {
            label: "Sospendi dopo"
            menuItems: root.tempi
            active: root.tempi.find(i => i.value === root.tempo("suspend")) ?? null
            fallbackText: `${Math.round(root.tempo("suspend") / 60)} minuti`
            onSelected: item => root.cambia("suspend", item.value)
        }

        ToggleRow {
            last: true
            text: "Blocca prima di sospendere"
            subtext: "Al risveglio serve la password"
            checked: GlobalConfig.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        SectionHeader {
            text: "Prestazioni"
        }

        SelectRow {
            first: true
            last: true
            label: "Profilo energetico"
            subtext: "Piu' prestazioni o batteria che dura di piu'"
            menuItems: PowerProfiles.hasPerformanceProfile ? root.profili : [root.profili[0], root.profili[1]]
            active: root.profili.find(i => i.value === PowerProfiles.profile) ?? root.profili[1]
            onSelected: item => PowerProfiles.profile = item.value
        }
    }
}
