.pragma library
// Il filtro del menu di oversicaOS (creato da lfs.sh): nasconde le app di sistema e gli
// strumenti di Wine. I programmi Windows installati (voci "wine-Programs-...") restano.
// Le voci nascoste a mano da Impostazioni -> App le gestisce Caelestia (hiddenApps).

const WINE = /^(wine|winecfg|org\.winehq\.)/i;
const WINE_STRUMENTI = /^wine-(notepad|regedit|uninstaller|winecfg|wordpad|oleview|winemine|winhelp|mime-msi|winefile|cmd|taskmgr|control|iexplore|msiexec)/i;
const PROGRAMMI_WINDOWS = /^wine-Programs-/;
const SISTEMA = ["System", "Settings"];
const TENUTE = ["TerminalEmulator", "FileManager", "Monitor"];
const STRUMENTI = ["avahi-discover", "bssh", "bvnc", "qv4l2", "qvidcap", "lstopo",
    "nm-connection-editor", "foot-server", "footclient", "thunar-settings",
    "thunar-bulk-rename", "xfce4-about", "cmake-gui", "designer", "linguist", "assistant",
    "qdbusviewer", "electron", "jshell", "yad-icon-browser"];

// app: una voce del menu ({ id, categories, noDisplay })
function nascosta(app) {
    if (!app)
        return true;
    const id = String(app.id || "").replace(/\.desktop$/, "");
    const categorie = Array.from(app.categories || []);
    if (app.noDisplay)
        return true;
    if (PROGRAMMI_WINDOWS.test(id))
        return false;
    if (WINE_STRUMENTI.test(id) || (WINE.test(id) && !id.startsWith("wine-")))
        return true;
    if (STRUMENTI.indexOf(id) >= 0)
        return true;
    return categorie.some(c => SISTEMA.indexOf(c) >= 0) && !categorie.some(c => TENUTE.indexOf(c) >= 0);
}
