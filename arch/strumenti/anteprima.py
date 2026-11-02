#!/usr/bin/env python3
"""Anteprime della grafica di Vetro (creato da vetro-arch.sh; solo per lo sviluppo,
non va nello script). Disegna in immagini PNG le "Viste" (i pezzi grafici che non
dipendono da Quickshell) usando PySide6, senza schermo:

    python anteprima.py CARTELLA_USCITA [--icone FILE.ttf] [--solo NOME] [--scene CARTELLA]

Ogni file scene/NOME.qml (la radice ha width e height) diventa CARTELLA_USCITA/NOME.png.
Le scene vedono gli sfondi veri con la proprieta' "sfondi" (cartella, come indirizzo
file://) e i file dello script con "radice" (arch/file). Ombre e sfocature (MultiEffect) qui non si vedono.
Esce con 1 se una scena ha errori QML (stampati con il nome del file).
"""
import argparse
import os
import pathlib
import shutil
import sys
import tempfile

QUI = pathlib.Path(__file__).resolve().parent
ARCH = QUI.parent
VETRO = ARCH / "file/etc/xdg/quickshell/vetro"
FINTI = QUI / "anteprima"
SFONDI = ARCH / "file/usr/share/backgrounds"
CARATTERE = ARCH / "file/usr/share/fonts/dm-sans/DMSans.ttf"
# i file "puri" (solo QtQuick + Tema/Icona) oltre a tutti i *Vista.qml
PURI = ["Tema.qml", "Icona.qml", "PasswordPillola.qml", "VoceLato.qml"]
SINGLETON = {"Tema", "Opzioni"}


def prepara(cartella: pathlib.Path) -> None:
    """Copia i pezzi grafici e i file finti in CARTELLA e scrive il suo qmldir."""
    nomi = [n for n in PURI if (VETRO / n).exists()]
    nomi += sorted(p.name for p in VETRO.glob("*Vista.qml"))
    for n in nomi:
        shutil.copy(VETRO / n, cartella / n)
    shutil.copy(FINTI / "Opzioni.qml", cartella / "Opzioni.qml")
    shutil.copytree(FINTI / "Quickshell", cartella / "Quickshell")
    righe = []
    for p in sorted(cartella.glob("*.qml")):
        tipo = "singleton " if p.stem in SINGLETON else ""
        righe.append(f"{tipo}{p.stem} 1.0 {p.name}")
    (cartella / "qmldir").write_text("\n".join(righe) + "\n")


def main() -> int:
    a = argparse.ArgumentParser(description="Anteprime della grafica di Vetro")
    a.add_argument("uscita")
    a.add_argument("--icone", help="file del carattere Material Symbols Rounded")
    a.add_argument("--solo", help="disegna solo questa scena")
    a.add_argument("--scene", default=str(FINTI / "scene"), help="cartella delle scene")
    arg = a.parse_args()

    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    try:
        from PySide6.QtCore import QUrl, QTimer, qInstallMessageHandler, QtMsgType
        from PySide6.QtGui import QGuiApplication, QFontDatabase
        from PySide6.QtQuick import QQuickView
    except ImportError:
        print("manca PySide6: python3 -m venv ~/.vetro-qt && ~/.vetro-qt/bin/pip install PySide6-Essentials",
              file=sys.stderr)
        return 2

    uscita = pathlib.Path(arg.uscita)
    uscita.mkdir(parents=True, exist_ok=True)
    scene = sorted(pathlib.Path(arg.scene).glob("*.qml"))
    if arg.solo:
        scene = [s for s in scene if s.stem == arg.solo]
    if not scene:
        print("nessuna scena da disegnare", file=sys.stderr)
        return 1

    errori = []

    def messaggi(tipo, contesto, testo):
        if tipo in (QtMsgType.QtWarningMsg, QtMsgType.QtCriticalMsg, QtMsgType.QtFatalMsg) \
                and ".qml" in testo:
            errori.append(testo)

    qInstallMessageHandler(messaggi)
    app = QGuiApplication(sys.argv[:1])
    for f in [CARATTERE] + ([pathlib.Path(arg.icone)] if arg.icone else []):
        if QFontDatabase.addApplicationFont(str(f)) < 0:
            print(f"non riesco a caricare il carattere {f}", file=sys.stderr)

    esito = 0
    with tempfile.TemporaryDirectory() as t:
        cartella = pathlib.Path(t)
        prepara(cartella)
        for s in scene:
            shutil.copy(s, cartella / ("scena-" + s.name))
            errori.clear()
            vista = QQuickView()
            vista.engine().addImportPath(str(cartella))
            vista.rootContext().setContextProperty("sfondi", QUrl.fromLocalFile(str(SFONDI)).toString())
            vista.rootContext().setContextProperty("radice", QUrl.fromLocalFile(str(ARCH / "file")).toString())
            vista.setResizeMode(QQuickView.ResizeMode.SizeViewToRootObject)
            vista.setSource(QUrl.fromLocalFile(str(cartella / ("scena-" + s.name))))
            for e in vista.errors():
                errori.append(e.toString())
            if vista.rootObject() is None or errori:
                print(f"errore nella scena {s.name}:", file=sys.stderr)
                for e in errori:
                    print("  " + e.replace("scena-", ""), file=sys.stderr)
                esito = 1
                continue
            vista.show()
            # le immagini si caricano in sottofondo: si aspetta un attimo
            QTimer.singleShot(400, app.quit)
            app.exec()
            if errori:
                print(f"errore nella scena {s.name}:", file=sys.stderr)
                for e in errori:
                    print("  " + e.replace("scena-", ""), file=sys.stderr)
                esito = 1
            vista.grabWindow().save(str(uscita / (s.stem + ".png")))
            vista.close()
            print(f"  {s.stem}.png")
    return esito


if __name__ == "__main__":
    sys.exit(main())
