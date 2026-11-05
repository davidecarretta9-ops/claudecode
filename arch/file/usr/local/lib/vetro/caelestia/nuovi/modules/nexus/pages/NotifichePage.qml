pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.State
import qs.components
import qs.services
import qs.modules.nexus.common

// oversicaOS: Impostazioni > Notifiche. Non disturbare e le scelte principali delle
// notifiche di Caelestia (le altre sono in Servizi > Notifiche).
PageBase {
    id: root

    title: "Notifiche"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Notifiche"
        }

        ToggleRow {
            first: true
            text: "Non disturbare"
            subtext: "Le notifiche non compaiono sullo schermo (restano nell'elenco)"
            checked: PersistentState.doNotDisturb
            onToggled: PersistentState.doNotDisturb = checked
        }

        ToggleRow {
            text: "Chiudi da sole"
            subtext: "Le notifiche spariscono dopo qualche secondo"
            checked: GlobalConfig.notifs.expire
            onToggled: GlobalConfig.notifs.expire = checked
        }

        ToggleRow {
            last: true
            text: "Aperte per intero"
            subtext: "Mostra subito tutto il testo delle notifiche"
            checked: GlobalConfig.notifs.openExpanded
            onToggled: GlobalConfig.notifs.openExpanded = checked
        }
    }
}
