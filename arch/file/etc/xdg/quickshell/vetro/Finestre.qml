pragma Singleton
// Le finestre aperte (creato da lfs.sh, Fase 10). Hyprland non sa "ridurre a icona":
// quando un programma lo chiede (il pulsante giallo), la finestra va in una scrivania
// nascosta e compare nel dock; cliccandola torna dov'era.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: finestre

    readonly property string nascoste: "special:ridotte"
    readonly property var tutte: Hyprland.toplevels.values

    function appDi(t) {
        if (t && t.wayland && t.wayland.appId) return t.wayland.appId;
        if (t && t.lastIpcObject && t.lastIpcObject["class"]) return t.lastIpcObject["class"];
        return "";
    }
    function ridotta(t) {
        return !!(t && t.workspace && t.workspace.name === nascoste);
    }
    function riduci(indirizzo) {
        if (!indirizzo) return;
        Hyprland.dispatch("movetoworkspacesilent " + nascoste + ",address:" + indirizzo);
    }
    function riduciAttiva() {
        const t = Hyprland.activeToplevel;
        if (t && t.address) riduci("0x" + t.address.replace(/^0x/, ""));
    }
    function riporta(t) {
        if (!t || !t.address) return;
        const ind = "0x" + t.address.replace(/^0x/, "");
        if (ridotta(t)) {
            const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            Hyprland.dispatch("movetoworkspace " + ws + ",address:" + ind);
        }
        Hyprland.dispatch("focuswindow address:" + ind);
        Hyprland.dispatch("alterzorder top,address:" + ind);
    }
    function finestreDi(app) {
        const r = [];
        for (let i = 0; i < tutte.length; i++)
            if (appDi(tutte[i]).toLowerCase() === app.toLowerCase()) r.push(tutte[i]);
        return r;
    }

    Connections {
        target: Hyprland
        function onRawEvent(evento) {
            // "minimized>>INDIRIZZO,1": un programma chiede di ridursi a icona
            if (evento.name === "minimized") {
                const parti = String(evento.data).split(",");
                if (parti.length >= 2 && parti[1] === "1")
                    finestre.riduci("0x" + parti[0].replace(/^0x/, ""));
            }
            if (evento.name === "openwindow" || evento.name === "closewindow"
                    || evento.name === "movewindowv2" || evento.name === "movewindow")
                Hyprland.refreshToplevels();
        }
    }
}
