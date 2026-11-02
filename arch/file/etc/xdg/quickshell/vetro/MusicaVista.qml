// Il riquadro della musica, solo la grafica (creato da vetro-arch.sh): copertina,
// titolo, autore, tempi, barra di avanzamento con il pallino ad anello e i tasti.
// Prende il colore dalla copertina. I dati li passa MusicaRiquadro.qml.
import QtQuick
import Quickshell.Widgets

Item {
    id: vista

    property string titolo: ""
    property string artista: ""
    property string copertina: ""
    property real posizione: 0          // secondi
    property real durata: 0             // secondi
    property bool suona: false
    // il colore medio della copertina (lo calcola "campione")
    property color tinta: Qt.rgba(0.30, 0.32, 0.38, 1)

    signal indietro()
    signal alterna()
    signal avanti()
    signal sposta(real secondi)

    implicitWidth: 380
    implicitHeight: 176

    function tempo(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // la copertina ridotta a un punto: il suo colore medio
    Canvas {
        id: campione
        width: 2
        height: 2
        opacity: 0
        property string immagine: vista.copertina
        onImmagineChanged: if (immagine !== "") loadImage(immagine)
        onImageLoaded: requestPaint()
        Component.onCompleted: if (immagine !== "") loadImage(immagine)
        onPaint: {
            if (immagine === "" || !isImageLoaded(immagine)) return;
            const ctx = getContext("2d");
            ctx.drawImage(immagine, 0, 0, 1, 1);
            const d = ctx.getImageData(0, 0, 1, 1).data;
            vista.tinta = Qt.rgba(d[0] / 255, d[1] / 255, d[2] / 255, 1);
        }
    }

    Rectangle {
        id: fondo
        anchors.fill: parent
        radius: Tema.raggioRiquadro
        color: Qt.rgba(vista.tinta.r * 0.42, vista.tinta.g * 0.42, vista.tinta.b * 0.42, 0.96)
        border.width: 1
        border.color: Qt.rgba(Math.min(1, vista.tinta.r * 1.3), Math.min(1, vista.tinta.g * 1.3),
                              Math.min(1, vista.tinta.b * 1.3), 0.55)
        Behavior on color { ColorAnimation { duration: Tema.media } }

        ClippingRectangle {
            id: quadro
            x: 16
            y: 16
            width: 64
            height: 64
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.12)
            Image {
                anchors.fill: parent
                source: vista.copertina
                sourceSize.width: 128
                sourceSize.height: 128
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors.left: quadro.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: quadro.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: vista.titolo || "Niente in riproduzione"
                font.family: Tema.carattere
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "#ffffff"
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: vista.artista
                font.family: Tema.carattere
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.65)
            }
        }

        // tempi e barra di avanzamento
        Item {
            id: avanzamento
            x: 16
            y: 92
            width: parent.width - 32
            height: 28
            readonly property real frazione: vista.durata > 0 ? Math.min(1, vista.posizione / vista.durata) : 0
            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                text: vista.tempo(vista.posizione)
                font.family: Tema.carattere; font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, 0.75)
            }
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                text: vista.tempo(vista.durata)
                font.family: Tema.carattere; font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, 0.75)
            }
            Rectangle {
                id: binario
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.22)
                Rectangle {
                    width: parent.width * avanzamento.frazione
                    height: parent.height
                    radius: 2
                    color: Qt.rgba(Math.min(1, vista.tinta.r * 1.6 + 0.2), Math.min(1, vista.tinta.g * 1.6 + 0.2),
                                   Math.min(1, vista.tinta.b * 1.6 + 0.2), 1)
                }
                // il pallino ad anello
                Rectangle {
                    x: parent.width * avanzamento.frazione - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: fondo.color
                    border.width: 2
                    border.color: "#ffffff"
                }
            }
            MouseArea {
                anchors.fill: binario
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: e => vista.sposta(Math.max(0, Math.min(1, e.x / width)) * vista.durata)
            }
        }

        // i tasti
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            spacing: 26
            Tasto { nome: "skip_previous"; onCliccato: vista.indietro() }
            Tasto { nome: vista.suona ? "pause" : "play_arrow"; grande: true; onCliccato: vista.alterna() }
            Tasto { nome: "skip_next"; onCliccato: vista.avanti() }
        }
    }

    component Tasto: Item {
        id: t
        property string nome: ""
        property bool grande: false
        signal cliccato()
        width: grande ? 40 : 34
        height: width
        Icona {
            anchors.centerIn: parent
            nome: t.nome
            dimensione: t.grande ? 34 : 28
            piena: true
            color: "#ffffff"
            scale: areaT.pressed ? 0.88 : (areaT.containsMouse ? 1.08 : 1)
            Behavior on scale { NumberAnimation { duration: Tema.veloce } }
        }
        MouseArea {
            id: areaT
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: t.cliccato()
        }
    }
}
