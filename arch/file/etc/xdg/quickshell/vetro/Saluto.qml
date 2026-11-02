pragma Singleton
// Il saluto secondo l'ora (creato da lfs.sh, Fase 10)
import QtQuick
import Quickshell

Singleton {
    function frase(data) {
        const h = data.getHours();
        if (h >= 5 && h < 13) return "Buongiorno";
        if (h >= 13 && h < 18) return "Buon pomeriggio";
        if (h >= 18 && h < 23) return "Buonasera";
        return "Buonanotte";
    }
}
