// La barra in basso, solo la grafica (creato da vetro-arch.sh). I dati veri li passa
// Barra.qml; qui niente Quickshell, cosi' si puo' disegnare nelle anteprime.
//   a sinistra: logo (menu delle app), lineetta, app fissate e aperte
//   a destra: pillole "Non disturbare" (se acceso), musica (se suona), sistema
//   (fantasma, rete, volume, batteria) e l'ora
import QtQuick

Item {
    id: vista

    // --- i dati -----------------------------------------------------------------
    property var app: []                 // [{ nome, icona (indirizzo), aperta, attiva }]
    property bool nonDisturbare: false
    property bool musica: false
    property string musicaTitolo: ""
    property string musicaCopertina: ""
    property string iconaRete: "signal_wifi_4_bar"
    property string iconaVolume: "volume_up"
    property int batteria: -1            // -1 = non c'e'
    property bool inCarica: false
    property bool fantasma: false
    property string ora: ""
    property bool menuAperto: false
    property bool pannelloAperto: false
    property bool musicaAperta: false
    property string logo: "file:///usr/share/icons/hicolor/scalable/apps/vetro.svg"

    signal logoCliccato()
    signal appCliccata(int indice)
    signal nonDisturbareCliccato()
    signal musicaCliccata()
    signal sistemaCliccato()
    signal oraCliccata()

    implicitHeight: Tema.altezzaBarra + 2 * Tema.staccoBarra

    function iconaBatteria() {
        if (inCarica) return "battery_charging_full";
        if (batteria >= 90) return "battery_full";
        if (batteria >= 60) return "battery_5_bar";
        if (batteria >= 30) return "battery_3_bar";
        return "battery_1_bar";
    }

    Rectangle {
        id: fondo
        anchors.fill: parent
        anchors.margins: Tema.staccoBarra
        radius: Tema.raggioBarra
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo

        // ------------------------------------------------------------ a sinistra
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Casella {
                acceso: vista.menuAperto
                onCliccata: vista.logoCliccato()
                Image {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    source: vista.logo
                    sourceSize.width: 52
                    sourceSize.height: 52
                    smooth: true
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 20
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.35)
            }
            Item { width: 2; height: 1 }

            Repeater {
                model: vista.app
                delegate: Casella {
                    id: casella
                    required property var modelData
                    required property int index
                    acceso: modelData.attiva === true
                    onCliccata: vista.appCliccata(index)

                    Image {
                        id: immagine
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        source: casella.modelData.icona || ""
                        sourceSize.width: 60
                        sourceSize.height: 60
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }
                    // senza icona: un quadratino colorato con l'iniziale
                    Rectangle {
                        visible: immagine.status !== Image.Ready
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 8
                        color: Qt.hsla(((casella.modelData.nome || "?").charCodeAt(0) * 37 % 360) / 360, 0.65, 0.55, 1)
                        Text {
                            anchors.centerIn: parent
                            text: (casella.modelData.nome || "?").charAt(0).toUpperCase()
                            font.family: Tema.carattere
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }
                    // l'app e' aperta: un trattino sotto (piu' lungo e blu se e' davanti)
                    Rectangle {
                        visible: casella.modelData.aperta === true
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: casella.modelData.attiva ? 14 : 5
                        height: 3
                        radius: 1.5
                        color: casella.modelData.attiva ? Tema.accento : Qt.rgba(1, 1, 1, 0.6)
                        Behavior on width { NumberAnimation { duration: Tema.veloce } }
                    }
                }
            }
        }

        // ------------------------------------------------------------- a destra
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Pillola {
                rossa: true
                visible: vista.nonDisturbare
                onCliccata: vista.nonDisturbareCliccato()
                Icona { anchors.verticalCenter: parent.verticalCenter; nome: "do_not_disturb_on"; dimensione: 17; piena: true; color: "#ffffff" }
                Testo { text: "Non disturbare" }
            }

            Pillola {
                visible: vista.musica
                acceso: vista.musicaAperta
                onCliccata: vista.musicaCliccata()
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.15)
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: vista.musicaCopertina
                        sourceSize.width: 40
                        sourceSize.height: 40
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Testo {
                    width: Math.min(implicitWidth, 200)
                    elide: Text.ElideRight
                    text: vista.musicaTitolo
                }
            }

            Pillola {
                acceso: vista.pannelloAperto
                onCliccata: vista.sistemaCliccato()
                Icona { anchors.verticalCenter: parent.verticalCenter; visible: vista.fantasma; nome: "visibility_off"; dimensione: 17; color: "#ffffff" }
                Icona { anchors.verticalCenter: parent.verticalCenter; nome: vista.iconaRete; dimensione: 17; piena: true; color: "#ffffff" }
                Icona { anchors.verticalCenter: parent.verticalCenter; nome: vista.iconaVolume; dimensione: 17; piena: true; color: "#ffffff" }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: vista.batteria >= 0
                    spacing: 1
                    Icona { anchors.verticalCenter: parent.verticalCenter; nome: vista.iconaBatteria(); dimensione: 17; piena: true; color: "#ffffff" }
                    Testo { text: vista.batteria + "%" }
                }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: testoOra.implicitWidth + 12
                height: 32
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: areaOra.containsMouse ? Tema.pillolaSopra : "transparent"
                    Behavior on color { ColorAnimation { duration: Tema.veloce } }
                }
                Testo {
                    id: testoOra
                    anchors.centerIn: parent
                    text: vista.ora
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: areaOra
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: vista.oraCliccata()
                }
            }
        }
    }

    // --- pezzi -----------------------------------------------------------------
    // un'icona della barra (logo e app): al passaggio del mouse un riquadro chiaro
    component Casella: Item {
        id: c
        property bool acceso: false
        signal cliccata()
        width: 40
        height: 40
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: areaC.containsMouse ? Tema.pillolaSopra : (c.acceso ? Tema.pillola : "transparent")
            Behavior on color { ColorAnimation { duration: Tema.veloce } }
        }
        MouseArea {
            id: areaC
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: c.cliccata()
        }
    }

    // una pillola della barra: tonda, bianco leggero (rossa per "Non disturbare")
    component Pillola: Rectangle {
        id: p
        property bool rossa: false
        property bool acceso: false
        default property alias contenuto: filaP.data
        signal cliccata()
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        height: 32
        width: filaP.implicitWidth + 24
        radius: height / 2
        color: rossa ? Tema.rossoFondo : (areaP.containsMouse || acceso ? Tema.pillolaSopra : Tema.pillola)
        border.width: 1
        border.color: rossa ? Tema.rossoBordo : Tema.pillolaBordo
        Behavior on color { ColorAnimation { duration: Tema.veloce } }
        Row {
            id: filaP
            anchors.centerIn: parent
            spacing: 6
        }
        MouseArea {
            id: areaP
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: p.cliccata()
        }
    }

    component Testo: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: Tema.carattere
        font.pixelSize: 13
        font.weight: Font.Medium
        color: "#ffffff"
    }
}
