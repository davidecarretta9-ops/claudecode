pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// oversicaOS: Impostazioni > Accessibilita'. Testo piu' grande (Caelestia) e meno
// animazioni (Caelestia e Hyprland).
PageBase {
    id: root

    title: "Accessibilita'"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Vista"
        }

        ToggleRow {
            first: true
            last: true
            text: "Testo piu' grande"
            subtext: "Ingrandisce i testi di barra, menu e impostazioni"
            checked: GlobalConfig.appearance.font.scale > 1.01
            onToggled: GlobalConfig.appearance.font.scale = checked ? 1.2 : 1
        }

        SectionHeader {
            text: "Movimento"
        }

        ToggleRow {
            first: true
            last: true
            text: "Meno animazioni"
            subtext: "Finestre e pannelli si muovono meno"
            checked: !ImpostazioniOversica.animazioni
            onToggled: {
                ImpostazioniOversica.animazioni = !checked;
                GlobalConfig.appearance.anim.durations.scale = checked ? 0.3 : 1;
            }
        }
    }
}
