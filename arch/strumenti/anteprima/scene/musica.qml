// Anteprima: il riquadro della musica su sfondo scuro (creato da vetro-arch.sh)
import QtQuick
Item {
    width: 460
    height: 260
    Image {
        anchors.fill: parent
        source: sfondi + "/vetro-magenta.jpg"
        fillMode: Image.PreserveAspectCrop
    }
    MusicaVista {
        anchors.centerIn: parent
        titolo: "Notte di vetro"
        artista: "Orchestra leggera"
        copertina: sfondi + "/vetro-magenta.jpg"
        posizione: 32
        durata: 219
        suona: false
    }
}
