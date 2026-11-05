pragma Singleton

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps
import qs.modules.nexus.pages.audio
import qs.modules.nexus.pages.bluetooth
import qs.modules.nexus.pages.network
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.services
import qs.modules.nexus.pages.wallandstyle
import qs.modules.nexus.pages.panels.taskbar

// oversicaOS: le pagine delle Impostazioni, prese da Caelestia con le pagine di oversicaOS in
// piu', nell'ordine di Windows e macOS. Va tenuto allineato a PageRegistry.qml (stessa
// posizione = stessa pagina).
QtObject {
    id: root

    readonly property list<Component> pageComps: [
        // Account
        Component {
            // Account (oversicaOS)
            StackPage {
                Component {
                    AccountPage {}
                }
            }
        },

        // Appearance
        Component {
                    WallpaperAndStyle {}
                },
        Component {
            // Schermo (oversicaOS)
            StackPage {
                Component {
                    SchermoPage {}
                }
            }
        },

        // Connectivity
        Component {
                    NetworkPage {}
                },
        Component {
                    BluetoothPage {}
                },
        Component {
                    AudioPage {}
                },

        // System
        Component {
            // Privacy e sicurezza (oversicaOS)
            StackPage {
                Component {
                    PrivacyPage {}
                }
            }
        },
        Component {
            // Energia e blocco (oversicaOS)
            StackPage {
                Component {
                    EnergiaPage {}
                }
            }
        },
        Component {
            // Notifiche (oversicaOS)
            StackPage {
                Component {
                    NotifichePage {}
                }
            }
        },
        Component {
            // Tastiera, mouse e touchpad (oversicaOS)
            StackPage {
                Component {
                    TastieraPage {}
                }
            }
        },
        Component {
            // Data e ora (oversicaOS)
            StackPage {
                Component {
                    DataOraPage {}
                }
            }
        },
        Component {
            // Archiviazione (oversicaOS)
            StackPage {
                Component {
                    ArchiviazionePage {}
                }
            }
        },
        Component {
            // Accessibilita' (oversicaOS)
            StackPage {
                Component {
                    AccessibilitaPage {}
                }
            }
        },
        Component {
            // Aggiornamenti: in Caelestia era in costruzione (oversicaOS)
            StackPage {
                Component {
                    AggiornamentiPage {}
                }
            }
        },

        // Shell
        Component {
                    PanelsPage {}
                },
        Component {
                    AppsPage {}
                },
        Component {
                    ServicesPage {}
                },
        Component {
                    LanguageAndRegion {}
                },

        // About
        Component {
                    AboutPage {}
                }
    ]

    readonly property Component placeholderComp: Component {
        PlaceholderComp {}
    }

    component PlaceholderComp: Item {
        property NexusState nState // To avoid the warning from non-existent property

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.padding.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "handyman"
                color: Colours.palette.m3outlineVariant
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("Page under construction")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.title.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("This page will be available in a future update.")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.body.large
            }
        }
    }
}
