// Grafico a linea (rete, processore) (creato da lfs.sh, Fase 10)
import QtQuick

Canvas {
    id: grafico
    property var valori: []
    property var valori2: []
    property color colore: Tema.accento
    property color colore2: Tema.testo3
    property real massimo: 0           // 0 = automatico

    implicitHeight: 80
    implicitWidth: 240
    renderStrategy: Canvas.Cooperative

    onValoriChanged: requestPaint()
    onValori2Changed: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function linea(ctx, v, colore, max, riempi) {
        if (!v || v.length < 2) return;
        const passo = width / (v.length - 1);
        ctx.beginPath();
        for (let i = 0; i < v.length; i++) {
            const x = i * passo;
            const y = height - 2 - (height - 6) * Math.min(1, v[i] / max);
            if (i === 0) ctx.moveTo(x, y);
            else {
                const xp = (i - 1) * passo;
                const yp = height - 2 - (height - 6) * Math.min(1, v[i - 1] / max);
                ctx.bezierCurveTo(xp + passo / 2, yp, x - passo / 2, y, x, y);
            }
        }
        ctx.strokeStyle = colore;
        ctx.lineWidth = 2;
        ctx.stroke();
        if (riempi) {
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.rgba(colore.r, colore.g, colore.b, 0.35));
            g.addColorStop(1, Qt.rgba(colore.r, colore.g, colore.b, 0.0));
            ctx.fillStyle = g;
            ctx.fill();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        let max = massimo;
        if (max <= 0) {
            max = 1;
            for (let i = 0; i < valori.length; i++) max = Math.max(max, valori[i]);
            for (let i = 0; i < valori2.length; i++) max = Math.max(max, valori2[i]);
            max *= 1.15;
        }
        linea(ctx, valori2, colore2, max, false);
        linea(ctx, valori, colore, max, true);
    }
}
