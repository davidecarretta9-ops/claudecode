// Calendario del mese, con le frecce per gli altri mesi (creato da lfs.sh, Fase 10)
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: calendario
    property date oggi: new Date()
    property int spostamento: 0       // mesi avanti/indietro rispetto a oggi
    readonly property date mese: new Date(oggi.getFullYear(), oggi.getMonth() + spostamento, 1)

    readonly property var giorni: {
        const anno = mese.getFullYear(), m = mese.getMonth();
        const primo = (new Date(anno, m, 1).getDay() + 6) % 7;      // lunedi' = 0
        const quanti = new Date(anno, m + 1, 0).getDate();
        const prima = new Date(anno, m, 0).getDate();
        const l = [];
        for (let i = 0; i < 42; i++) {
            const n = i - primo + 1;
            if (n < 1) l.push({ n: prima + n, fuori: true, oggi: false });
            else if (n > quanti) l.push({ n: n - quanti, fuori: true, oggi: false });
            else l.push({
                n: n, fuori: false,
                oggi: n === oggi.getDate() && m === oggi.getMonth() && anno === oggi.getFullYear()
            });
        }
        return l;
    }

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        PulsanteIcona {
            implicitWidth: 28; implicitHeight: 28
            icona: "chevron_left"; dimensioneIcona: 18
            color: "transparent"
            onCliccato: calendario.spostamento--
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: {
                const t = calendario.mese.toLocaleString(Qt.locale("it_IT"), "MMMM yyyy");
                return t.charAt(0).toUpperCase() + t.slice(1);
            }
            font.family: Tema.carattere
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Tema.testo
            MouseArea { anchors.fill: parent; onClicked: calendario.spostamento = 0 }
        }
        PulsanteIcona {
            implicitWidth: 28; implicitHeight: 28
            icona: "chevron_right"; dimensioneIcona: 18
            color: "transparent"
            onCliccato: calendario.spostamento++
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["lu", "ma", "me", "gi", "ve", "sa", "do"]
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1          // colonne tutte larghe uguali
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: Tema.carattere
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Tema.testo3
            }
        }
        Repeater {
            model: calendario.giorni
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height, 30)
                    height: width
                    radius: width / 2
                    color: modelData.oggi ? Tema.accento : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.n
                    font.family: Tema.carattere
                    font.pixelSize: 12
                    font.weight: modelData.oggi ? Font.Bold : Font.Normal
                    color: modelData.oggi ? Tema.suAccento : (modelData.fuori ? Tema.testo3 : Tema.testo)
                    opacity: modelData.fuori ? 0.6 : 1
                }
            }
        }
    }
}
