//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded

// oversicaOS: la schermata di accesso. La apre greetd all'accensione, dentro un Hyprland
// tutto suo (/etc/vetro/accesso-hyprland.lua), come utente "greeter". E' il blocco di
// Caelestia (orologio, avatar, password, meteo e stato del sistema ai lati): cambia solo
// il motore, AccessoGreetd, che controlla la password con greetd e poi avvia il desktop.
// Sta nella cartella di Caelestia perche' i pezzi del blocco ("qs.*") si trovano da qui.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.lock

ShellRoot {
    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    WlSessionLock {
        id: lock

        signal unlock

        locked: true

        LockSurface {
            lock: lock
            pam: accesso
        }
    }

    AccessoGreetd {
        id: accesso

        lock: lock
    }
}
