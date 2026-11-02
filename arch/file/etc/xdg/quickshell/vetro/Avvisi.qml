pragma Singleton
// Le notifiche (creato da lfs.sh, Fase 10): prende il posto di mako. Quelle nuove
// compaiono in alto a destra per qualche secondo, poi restano nel centro di controllo.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: avvisi

    readonly property var tutte: server.trackedNotifications.values
    readonly property int quante: tutte.length
    property var visibili: []

    function mostra(n) {
        const l = visibili.filter(x => x !== n);
        l.unshift(n);
        visibili = l.slice(0, 4);
    }
    function nascondi(n) {
        visibili = visibili.filter(x => x !== n);
    }
    function cancellaTutte() {
        const l = tutte.slice();
        visibili = [];
        for (let i = 0; i < l.length; i++) l[i].dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => avvisi.nascondi(n));
            if (!Opzioni.nonDisturbare || n.urgency === NotificationUrgency.Critical)
                avvisi.mostra(n);
        }
    }
}
