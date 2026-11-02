// Anteprima: la schermata di accesso dopo una password sbagliata (creato da vetro-arch.sh)
import QtQuick
AccessoVista {
    width: 1920
    height: 1080
    sfondo: sfondi + "/vetro-nuvole.jpg"
    utenti: ["un-nome-utente-lunghissimo-che-non-entra-nella-riga-del-nome"]
    errore: "Password sbagliata"
}
