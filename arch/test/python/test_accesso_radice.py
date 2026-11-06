"""Prova di accesso.qml (la radice della schermata di accesso) con Quickshell finto: la
superficie del blocco (LockSurface, creata dal blocco per ogni schermo) deve ricevere il
blocco vero, se no non sente "unlock", non fa l'animazione e il desktop non parte.
(Successo davvero: "lock: lock" dentro il blocco puntava a se stesso -> null.)"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

FILE = pathlib.Path(__file__).resolve().parents[2] / "file/usr/local/lib/vetro/caelestia/nuovi"

FINTI = {
    "Quickshell/qmldir": "module Quickshell\nScope 1.0 Scope.qml\nShellRoot 1.0 Scope.qml\n"
                         "singleton Quickshell 1.0 Quickshell.qml\n",
    "Quickshell/Scope.qml": "import QtQml\nQtObject { default property list<QtObject> dati }\n",
    "Quickshell/Quickshell.qml": "pragma Singleton\nimport QtQml\n"
                                 "QtObject { function shellPath(p) { return \"\" } }\n",
    "Quickshell/Io/qmldir": "module Quickshell.Io\nFileView 1.0 FileView.qml\n",
    "Quickshell/Io/FileView.qml": textwrap.dedent("""\
        import QtQml
        QtObject {
            property string path
            signal loaded()
            signal loadFailed(var error)
            function text() { return path === "/etc/passwd" ? "davide:x:1000:1000::/home/davide:/bin/bash\\n" : "davide\\n" }
            Component.onCompleted: Qt.callLater(loaded)
        }
        """),
    "Quickshell/Services/Greetd/qmldir": "module Quickshell.Services.Greetd\nsingleton Greetd 1.0 Greetd.qml\n",
    "Quickshell/Services/Greetd/Greetd.qml": textwrap.dedent("""\
        pragma Singleton
        import QtQml
        QtObject {
            property bool available: true
            signal authMessage(string message, bool error, bool responseRequired, bool echoResponse)
            signal authFailure(string message)
            signal readyToLaunch()
            signal error(string error)
            function createSession(u) {}
            function respond(r) {}
            function launch(c) { Registro.lanciato = JSON.stringify(c) }
            function cancelSession() {}
        }
        """),
    "Quickshell/Services/Greetd/Registro.qml": "pragma Singleton\nimport QtQml\n"
                                               "QtObject { property var superficie; property int sblocchi; property string lanciato }\n",
    "qs/modules/lock/qmldir": "module qs.modules.lock\nLockSurface 1.0 LockSurface.qml\n"
                              "AccessoGreetd 1.0 AccessoGreetd.qml\nPam 1.0 Pam.qml\n",
    "qs/modules/lock/Pam.qml": "import QtQml\nQtObject { enum PamState { None, Error, MaxTries, Failed } }\n",
    # la superficie finta: ricorda il blocco che riceve e conta gli "unlock" che sente
    "qs/modules/lock/LockSurface.qml": textwrap.dedent("""\
        import QtQml
        import Quickshell.Services.Greetd
        QtObject {
            id: s
            required property var lock
            required property var pam
            property Connections ascolta: Connections {
                target: s.lock
                function onUnlock() { Registro.sblocchi++ }
            }
            Component.onCompleted: Registro.superficie = String(lock)
        }
        """),
}


class ProvaRadiceAccesso(unittest.TestCase):
    """Le prove vere girano in un processo a parte (serve un'applicazione Qt tutta sua)."""

    def test_in_un_processo_a_parte(self):
        r = subprocess.run([sys.executable, "-I", "-B", __file__, "--dentro"], capture_output=True,
                           text=True, timeout=180, env=dict(os.environ, QT_QPA_PLATFORM="offscreen"))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("OK", r.stderr)


def prove_dentro():
    try:
        from PySide6.QtCore import ClassInfo, Property, QObject, QTimer, QUrl, Signal
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent, qmlRegisterType
        from PySide6.QtTest import QTest
    except ImportError:          # serve PySide6: vedi arch/test/test-importati.sh
        return None
    app = QGuiApplication.instance() or QGuiApplication([])

    @ClassInfo(DefaultProperty="surface")
    class BloccoFinto(QObject):
        """WlSessionLock di Quickshell: la superficie e' un modello (default property
        "surface") che il blocco crea per ogni schermo; locked avvisa con lockStateChanged."""
        lockStateChanged = Signal()
        surfaceChanged = Signal()

        def __init__(self, genitore=None):
            super().__init__(genitore)
            self._chiuso = False
            self._modello = None
            self._fatte = []

        def _leggi(self):
            return self._chiuso

        def _scrivi(self, valore):
            if valore != self._chiuso:
                self._chiuso = valore
                self.lockStateChanged.emit()

        def _modello_leggi(self):
            return self._modello

        def _modello_scrivi(self, modello):
            self._modello = modello
            QTimer.singleShot(0, self._crea)

        def _crea(self):
            o = self._modello.create(self._modello.creationContext())
            if o is not None:
                o.setParent(self)
                self._fatte.append(o)

        locked = Property(bool, _leggi, _scrivi, notify=lockStateChanged)
        surface = Property(QQmlComponent, _modello_leggi, _modello_scrivi, notify=surfaceChanged)

    qmlRegisterType(BloccoFinto, "Quickshell.Wayland", 1, 0, "WlSessionLock")

    class ProvaRadiceAccessoDentro(unittest.TestCase):
        def setUp(self):
            self.dir = pathlib.Path(tempfile.mkdtemp())
            self.addCleanup(shutil.rmtree, self.dir)
            for nome, testo in FINTI.items():
                (self.dir / nome).parent.mkdir(parents=True, exist_ok=True)
                (self.dir / nome).write_text(testo)
            # il registro e' nel modulo di greetd finto (cosi' lo vedono tutti i file)
            q = self.dir / "Quickshell/Services/Greetd/qmldir"
            q.write_text(q.read_text() + "singleton Registro 1.0 Registro.qml\n")
            (self.dir / "qs/utils").mkdir(parents=True)
            shutil.copy(FILE / "utils/Accesso.js", self.dir / "qs/utils/Accesso.js")
            shutil.copy(FILE / "modules/lock/AccessoGreetd.qml", self.dir / "qs/modules/lock/AccessoGreetd.qml")
            shutil.copy(FILE / "accesso.qml", self.dir / "qs/accesso.qml")
            # FontLoader vuole un file vero: qui non serve
            t = (self.dir / "qs/accesso.qml").read_text()
            self.errori = []
            self.e = QQmlApplicationEngine()
            self.e.warnings.connect(lambda w: self.errori.extend(x.toString() for x in w))
            self.e.addImportPath(str(self.dir))
            self.e.load(QUrl.fromLocalFile(str(self.dir / "qs/accesso.qml")))
            self.assertTrue(self.e.rootObjects(), "\n".join(self.errori))
            QTest.qWait(100)
            self.registro = self.e.singletonInstance("Quickshell.Services.Greetd", "Registro")
            self.greetd = self.e.singletonInstance("Quickshell.Services.Greetd", "Greetd")

        def test_superficie_riceve_il_blocco(self):
            loop = [e for e in self.errori if "Binding loop" in e]
            self.assertEqual(loop, [])
            self.assertNotEqual(self.registro.property("superficie"), "null")
            self.assertIn("BloccoFinto", self.registro.property("superficie"))

        def test_password_giusta_sblocca_e_avvia(self):
            self.greetd.readyToLaunch.emit()
            QTest.qWait(50)
            self.assertEqual(self.registro.property("sblocchi"), 1, "la superficie sente unlock")

    return ProvaRadiceAccessoDentro


if __name__ == "__main__":
    if "--dentro" in sys.argv:
        sys.argv.remove("--dentro")
        classe = prove_dentro()
        if classe is None:
            sys.exit("manca PySide6")
        unittest.main(defaultTest="classe")
    else:
        unittest.main()
