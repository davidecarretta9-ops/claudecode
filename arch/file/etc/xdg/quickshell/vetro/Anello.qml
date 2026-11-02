// Anello di avanzamento (processore, memoria, disco...) (creato da lfs.sh, Fase 10)
import QtQuick
import QtQuick.Shapes

Item {
    id: anello
    property real valore: 0            // 0..1
    property real spessore: 8
    property color colore: Tema.accento
    property color fondo: Tema.cartaForte
    property real mostrato: Math.max(0, Math.min(1, valore))

    implicitWidth: 96
    implicitHeight: 96

    Behavior on mostrato { NumberAnimation { duration: Tema.lenta; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: anello.fondo
            strokeWidth: anello.spessore
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: anello.width / 2
                centerY: anello.height / 2
                radiusX: (Math.min(anello.width, anello.height) - anello.spessore) / 2
                radiusY: radiusX
                startAngle: 135
                sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: anello.colore
            strokeWidth: anello.spessore
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: anello.width / 2
                centerY: anello.height / 2
                radiusX: (Math.min(anello.width, anello.height) - anello.spessore) / 2
                radiusY: radiusX
                startAngle: 135
                sweepAngle: Math.max(0.5, 270 * anello.mostrato)
            }
        }
    }
}
