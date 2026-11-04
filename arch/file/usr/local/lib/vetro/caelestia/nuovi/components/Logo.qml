// Logo di oversicaOS, "Orbita" (creato da lfs.sh, al posto del logo di Caelestia):
// anello aperto in alto a destra con il puntino arancione nell'apertura.
// topColour = il puntino, bottomColour = l'anello (stessi nomi del logo di Caelestia).
// Geometria uguale a strumenti/disegna-logo.py (versione senza tessera).
import QtQuick
import QtQuick.Shapes
import qs.services

Item {
    id: root

    readonly property real designWidth: 128
    readonly property real designHeight: 128

    property color topColour: "#d9704a"
    property color bottomColour: Colours.palette.m3onSurface

    implicitWidth: designWidth
    implicitHeight: designHeight

    Shape {
        id: forma
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.Center
        preferredRendererType: Shape.CurveRenderer

        // raggio esterno 0.40 del lato, spessore 0.30 del raggio
        readonly property real esterno: 128 * 0.40
        readonly property real spessore: esterno * 0.30
        readonly property real linea: esterno - spessore / 2

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.bottomColour
            strokeWidth: forma.spessore
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: 64
                centerY: 64
                radiusX: forma.linea
                radiusY: forma.linea
                startAngle: -10
                sweepAngle: 300
            }
        }

        ShapePath {
            fillColor: root.topColour
            strokeColor: "transparent"

            PathAngleArc {
                centerX: 64 + forma.linea * Math.cos(-40 * Math.PI / 180)
                centerY: 64 + forma.linea * Math.sin(-40 * Math.PI / 180)
                radiusX: forma.spessore * 0.62
                radiusY: forma.spessore * 0.62
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
