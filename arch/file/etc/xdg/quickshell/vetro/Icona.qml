// Un'icona dal carattere Material Symbols (creato da lfs.sh, Fase 10). Se il
// carattere non c'e' mostra un simbolo semplice al suo posto.
import QtQuick

Text {
    id: icona

    property string nome: "circle"
    property real dimensione: 20
    property bool piena: false

    readonly property var riserva: ({
        "search": "⌕", "close": "✕", "check": "✓", "add": "+", "remove": "−",
        "chevron_left": "‹", "chevron_right": "›", "expand_more": "⌄",
        "play_arrow": "▶", "pause": "⏸", "skip_next": "⏭", "skip_previous": "⏮",
        "power_settings_new": "⏻", "lock": "🔒", "settings": "⚙", "notifications": "🔔",
        "sunny": "☀", "cloud": "☁", "rainy": "☂", "weather_snowy": "❄", "thunderstorm": "⚡",
        "volume_up": "🔊", "volume_off": "🔇", "apps": "▦", "dark_mode": "☾", "light_mode": "☼"
    })

    font.family: Tema.iconeOk ? Tema.fontIcone : Tema.carattere
    font.pixelSize: dimensione
    font.variableAxes: Tema.iconeOk ? { "FILL": piena ? 1 : 0, "wght": 400, "opsz": 24 } : {}
    text: Tema.iconeOk ? nome : (riserva[nome] || "•")
    color: Tema.testo
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering

    Behavior on color { ColorAnimation { duration: Tema.veloce } }
}
