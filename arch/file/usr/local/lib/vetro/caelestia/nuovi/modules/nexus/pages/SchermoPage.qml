pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// oversicaOS: Impostazioni > Schermo. Luminosita' (Caelestia), luce notturna (hyprsunset),
// e per ogni schermo risoluzione, scala, posizione e schermo principale (le regole per
// Hyprland le scrive ImpostazioniOversica con HyprImpostazioni.js).
PageBase {
    id: root

    readonly property bool piuSchermi: ImpostazioniOversica.schermi.length > 1

    readonly property list<MenuItem> scale: [
        MenuItem {
            text: "100%"
            value: 1
        },
        MenuItem {
            text: "125%"
            value: 1.25
        },
        MenuItem {
            text: "150%"
            value: 1.5
        },
        MenuItem {
            text: "200%"
            value: 2
        }
    ]

    readonly property list<MenuItem> posizioni: [
        MenuItem {
            text: "A destra del principale"
            value: "destra"
        },
        MenuItem {
            text: "A sinistra del principale"
            value: "sinistra"
        },
        MenuItem {
            text: "Sopra il principale"
            value: "sopra"
        },
        MenuItem {
            text: "Uguale al principale (duplica)"
            value: "duplica"
        }
    ]

    title: "Schermo"

    Component.onCompleted: ImpostazioniOversica.avvia()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: "Luminosita' e colori"
        }

        Repeater {
            model: Brightness.monitors

            SliderRow {
                required property var modelData
                required property int index

                first: index === 0
                icon: "brightness_6"
                label: root.piuSchermi ? `Luminosita' (${modelData.modelData.name})` : "Luminosita'"
                valueLabel: `${Math.round(modelData.brightness * 100)}%`
                value: modelData.brightness
                onMoved: v => modelData.setBrightness(v)
            }
        }

        ToggleRow {
            first: Brightness.monitors.length === 0
            last: true
            text: "Luce notturna"
            subtext: "Colori piu' caldi, meno luce blu"
            checked: ImpostazioniOversica.luceNotturna
            onToggled: ImpostazioniOversica.luceNotturna = checked
        }

        Repeater {
            model: ImpostazioniOversica.schermi

            ColumnLayout {
                id: schermo

                required property var modelData
                readonly property var scelta: ImpostazioniOversica.scelteSchermi[modelData.name] ?? {}
                readonly property string risoluzione: scelta.risoluzione ?? `${modelData.width}x${modelData.height}`

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: `${schermo.modelData.name}${schermo.modelData.description ? " - " + schermo.modelData.description : ""}`
                }

                SelectRow {
                    first: true
                    label: "Risoluzione"
                    fallbackText: schermo.risoluzione
                    menuItems: risoluzioni.instances
                    active: menuItems.find(i => i.value === schermo.risoluzione) ?? null
                    onSelected: item => ImpostazioniOversica.sceltaSchermo(schermo.modelData.name, "risoluzione", item.value)

                    Variants {
                        id: risoluzioni

                        // "1920x1080@60.00Hz" -> "1920x1080", senza doppioni
                        model: [...new Set((schermo.modelData.availableModes ?? []).map(m => m.split("@")[0]))]

                        MenuItem {
                            required property string modelData

                            text: modelData
                            value: modelData
                        }
                    }
                }

                SelectRow {
                    last: !root.piuSchermi
                    label: "Scala"
                    subtext: "Ingrandisce tutto (utile sugli schermi molto fitti)"
                    menuItems: root.scale
                    active: root.scale.find(i => i.value === (Number(schermo.scelta.scala) || 1)) ?? root.scale[0]
                    onSelected: item => ImpostazioniOversica.sceltaSchermo(schermo.modelData.name, "scala", item.value)
                }

                SelectRow {
                    visible: root.piuSchermi
                    label: "Posizione"
                    menuItems: root.posizioni
                    active: root.posizioni.find(i => i.value === (schermo.scelta.posizione ?? "destra")) ?? root.posizioni[0]
                    onSelected: item => ImpostazioniOversica.sceltaSchermo(schermo.modelData.name, "posizione", item.value)
                }

                ToggleRow {
                    visible: root.piuSchermi
                    last: true
                    text: "Schermo principale"
                    subtext: "Qui compaiono la barra e le finestre nuove"
                    checked: schermo.scelta.principale === true
                    onToggled: ImpostazioniOversica.sceltaSchermo(schermo.modelData.name, "principale", checked)
                }
            }
        }
    }
}
