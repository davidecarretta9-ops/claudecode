// Il menu delle app, solo la grafica (creato da vetro-arch.sh): riquadro scuro con
// "Cerca" e "Tutte le app". Scrivendo compaiono i risultati; "Tutte le app" apre la
// griglia di tutte le app. I dati e le azioni li gestisce Avvio.qml.
import QtQuick

Item {
    id: vista

    property var risultati: []          // [{ nome, icona (indirizzo) }]
    property int scelta: 0
    property bool tutte: false          // griglia di tutte le app
    property real altezzaMassima: 540
    readonly property string testo: campo.text
    readonly property int colonne: 4

    signal cercato(string testo)
    signal aperta(int indice)
    signal tutteCliccato()
    signal chiudi()
    signal su()
    signal giu()

    function metti_a_fuoco() {
        campo.text = "";
        campo.forceActiveFocus();
    }
    // mette del testo nel campo (anteprime)
    function scrivi(t) { campo.text = t; }

    readonly property bool cerca: campo.text.trim() !== ""
    implicitWidth: 420
    implicitHeight: Math.min(altezzaMassima, colonna.implicitHeight + 24)

    Rectangle {
        anchors.fill: parent
        radius: Tema.raggioRiquadro
        color: Tema.fondo
        border.width: 1
        border.color: Tema.bordo

        Column {
            id: colonna
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // --- il campo "Cerca" ---------------------------------------------------
            Rectangle {
                width: parent.width
                height: 40
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: campo.activeFocus ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10)
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Icona { anchors.verticalCenter: parent.verticalCenter; nome: "search"; dimensione: 19; color: Qt.rgba(1, 1, 1, 0.7) }
                    TextInput {
                        id: campo
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 30
                        font.family: Tema.carattere
                        font.pixelSize: 14
                        color: "#ffffff"
                        selectionColor: Tema.accento
                        selectedTextColor: "#ffffff"
                        clip: true
                        onTextChanged: vista.cercato(text)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: campo.text === ""
                            text: "Cerca"
                            font: campo.font
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }
                        Keys.onEscapePressed: vista.chiudi()
                        Keys.onReturnPressed: vista.aperta(vista.scelta)
                        Keys.onEnterPressed: vista.aperta(vista.scelta)
                        Keys.onUpPressed: vista.su()
                        Keys.onDownPressed: vista.giu()
                        Keys.onTabPressed: vista.giu()
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.10) }

            // --- "Tutte le app" (senza ricerca e con la griglia chiusa) -------------------
            Riga {
                visible: !vista.cerca && !vista.tutte
                width: parent.width
                onCliccata: vista.tutteCliccato()
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    Icona { anchors.centerIn: parent; nome: "apps"; dimensione: 20; piena: true; color: "#ffffff" }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tutte le app"
                    font.family: Tema.carattere
                    font.pixelSize: 14
                    color: "#ffffff"
                }
            }

            // --- i risultati della ricerca ----------------------------------------------
            Repeater {
                model: vista.cerca ? vista.risultati : []
                delegate: Riga {
                    id: riga
                    required property var modelData
                    required property int index
                    width: colonna.width
                    scelta: index === vista.scelta
                    onCliccata: vista.aperta(index)
                    IconaApp {
                        anchors.verticalCenter: parent.verticalCenter
                        sorgente: riga.modelData.icona || ""
                        nome: riga.modelData.nome || ""
                        lato: 28
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: colonna.width - 70
                        elide: Text.ElideRight
                        text: riga.modelData.nome || ""
                        font.family: Tema.carattere
                        font.pixelSize: 14
                        color: "#ffffff"
                    }
                }
            }
            Text {
                visible: vista.cerca && vista.risultati.length === 0
                leftPadding: 8
                text: "Nessuna app trovata"
                font.family: Tema.carattere
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.55)
            }

            // --- la griglia di tutte le app ---------------------------------------------
            GridView {
                id: griglia
                visible: vista.tutte && !vista.cerca
                width: parent.width
                height: visible ? Math.min(contentHeight, vista.altezzaMassima - 100) : 0
                clip: true
                cellWidth: width / vista.colonne
                cellHeight: 92
                model: visible ? vista.risultati : []
                currentIndex: vista.scelta
                highlightFollowsCurrentItem: true
                highlight: Rectangle { radius: 12; color: Tema.pillolaSopra }
                delegate: Item {
                    id: cella
                    required property var modelData
                    required property int index
                    width: griglia.cellWidth
                    height: griglia.cellHeight
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        IconaApp {
                            anchors.horizontalCenter: parent.horizontalCenter
                            sorgente: cella.modelData.icona || ""
                            nome: cella.modelData.nome || ""
                            lato: 40
                        }
                        Text {
                            width: griglia.cellWidth - 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: cella.modelData.nome || ""
                            font.family: Tema.carattere
                            font.pixelSize: 11
                            color: "#ffffff"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: vista.scelta = cella.index
                        onClicked: vista.aperta(cella.index)
                    }
                }
            }
        }
    }

    // una riga cliccabile del menu (icona + testo)
    component Riga: Item {
        id: r
        property bool scelta: false
        default property alias contenuto: filaR.data
        signal cliccata()
        height: 40
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: areaR.containsMouse || r.scelta ? Tema.pillolaSopra : "transparent"
            Behavior on color { ColorAnimation { duration: Tema.veloce } }
        }
        Row {
            id: filaR
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
        }
        MouseArea {
            id: areaR
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: r.cliccata()
        }
    }
}
