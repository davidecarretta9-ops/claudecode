pragma Singleton
// Il meteo (creato da lfs.sh, Fase 10): lo chiede a wttr.in ogni 30 minuti.
// Si spegne o si sceglie la citta' da Impostazioni -> Cruscotto.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: meteo

    property bool pronto: false
    property string temperatura: "--"
    property string percepita: ""
    property string descrizione: ""
    property string luogo: ""
    property string icona: "cloud"
    property string umidita: ""
    property string vento: ""
    property var giorni: []       // [{ giorno, min, max, icona }]

    function iconaPer(codice) {
        const c = Number(codice);
        if (c === 113) return "sunny";
        if (c === 116) return "partly_cloudy_day";
        if (c === 119 || c === 122) return "cloud";
        if ([143, 248, 260].indexOf(c) >= 0) return "foggy";
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return "thunderstorm";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(c) >= 0) return "weather_snowy";
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) >= 0) return "weather_mix";
        return "rainy";
    }

    function aggiorna() {
        if (!Opzioni.meteo) return;
        if (!richiesta.running) richiesta.running = true;
    }

    Process {
        id: richiesta
        command: ["curl", "-sf", "--max-time", "15",
                  "https://wttr.in/" + encodeURIComponent(Opzioni.citta) + "?format=j1&lang=it"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    const ora = d.current_condition[0];
                    meteo.temperatura = ora.temp_C;
                    meteo.percepita = ora.FeelsLikeC;
                    meteo.umidita = ora.humidity;
                    meteo.vento = ora.windspeedKmph;
                    meteo.descrizione = (ora.lang_it && ora.lang_it.length > 0)
                        ? ora.lang_it[0].value : ora.weatherDesc[0].value;
                    meteo.icona = meteo.iconaPer(ora.weatherCode);
                    const area = d.nearest_area && d.nearest_area[0];
                    meteo.luogo = area ? area.areaName[0].value : Opzioni.citta;
                    const nomi = ["dom", "lun", "mar", "mer", "gio", "ven", "sab"];
                    const g = [];
                    for (let i = 0; i < d.weather.length; i++) {
                        const w = d.weather[i];
                        const data = new Date(w.date + "T12:00:00");
                        const mezzo = w.hourly && w.hourly.length > 4 ? w.hourly[4] : null;
                        g.push({
                            giorno: i === 0 ? "oggi" : nomi[data.getDay()],
                            min: w.mintempC, max: w.maxtempC,
                            icona: mezzo ? meteo.iconaPer(mezzo.weatherCode) : "cloud"
                        });
                    }
                    meteo.giorni = g;
                    meteo.pronto = true;
                } catch (e) {
                    console.log("meteo: risposta non valida");
                }
            }
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: Opzioni.meteo
        repeat: true
        triggeredOnStart: true
        onTriggered: meteo.aggiorna()
    }

    Connections {
        target: Opzioni
        function onCittaChanged() { meteo.aggiorna(); }
        function onMeteoChanged() { meteo.aggiorna(); }
    }
}
