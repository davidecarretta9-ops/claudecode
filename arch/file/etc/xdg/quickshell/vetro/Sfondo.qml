// Lo sfondo del desktop su uno schermo, con la dissolvenza quando cambia (lfs.sh)
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: finestra
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "vetro-sfondo"
    color: "#101012"

    property bool primoSopra: true
    property string mostrato: ""

    function cambia(file) {
        const sorgente = "file://" + file;
        if (sorgente === mostrato) return;
        mostrato = sorgente;
        if (primoSopra) secondo.source = sorgente;
        else primo.source = sorgente;
    }

    Component.onCompleted: cambia(Sfondi.attuale)
    Connections {
        target: Sfondi
        function onAttualeChanged() { finestra.cambia(Sfondi.attuale); }
    }

    Image {
        id: primo
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: finestra.width
        sourceSize.height: finestra.height
        opacity: finestra.primoSopra ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.lenta * 2; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && source.toString() === finestra.mostrato) finestra.primoSopra = true
    }
    Image {
        id: secondo
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: finestra.width
        sourceSize.height: finestra.height
        opacity: finestra.primoSopra ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tema.lenta * 2; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && source.toString() === finestra.mostrato) finestra.primoSopra = false
    }
}
