"""Prova del "motore" della schermata di accesso (AccessoGreetd.qml) con Quickshell e greetd
finti: si scrive la password con la tastiera (tasti veri, in una finestra senza schermo),
si preme Invio, greetd chiede e riceve la password, poi si sblocca e parte il desktop."""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

NUOVI = (pathlib.Path(__file__).resolve().parents[2]
         / "file/usr/local/lib/vetro/caelestia/nuovi")

FINTI = {
    "Quickshell/qmldir": "module Quickshell\nScope 1.0 Scope.qml\n",
    "Quickshell/Scope.qml": "import QtQml\nQtObject { default property list<QtObject> dati }\n",
    "Quickshell/Io/qmldir": "module Quickshell.Io\nFileView 1.0 FileView.qml\nsingleton FileFinti 1.0 FileFinti.qml\n",
    "Quickshell/Io/FileFinti.qml": "pragma Singleton\nimport QtQml\nQtObject { property var file: ({}) }\n",
    "Quickshell/Io/FileView.qml": textwrap.dedent("""\
        import QtQml
        QtObject {
            id: f
            property string path
            property bool printErrors
            property bool watchChanges
            property bool blockLoading
            property string contenuto
            signal loaded()
            signal loadFailed(var error)
            signal fileChanged()
            function text() { return contenuto }
            function reload() {}
            Component.onCompleted: Qt.callLater(function() {
                const c = FileFinti.file[f.path];
                if (c === undefined) f.loadFailed(1); else { f.contenuto = c; f.loaded(); }
            })
        }
        """),
    "Quickshell/Services/Greetd/qmldir": "module Quickshell.Services.Greetd\nsingleton Greetd 1.0 Greetd.qml\n",
    "Quickshell/Services/Greetd/Greetd.qml": textwrap.dedent("""\
        pragma Singleton
        import QtQml
        QtObject {
            property var chiamate: []
            property bool available: true
            signal authMessage(string message, bool error, bool responseRequired, bool echoResponse)
            signal authFailure(string message)
            signal readyToLaunch()
            signal error(string error)
            function registra(s) { chiamate = chiamate.concat([s]) }
            function createSession(u) { registra("createSession " + u) }
            function respond(r) { registra("respond " + r) }
            function launch(c) { registra("launch " + JSON.stringify(c)) }
            function cancelSession() { registra("cancelSession") }
        }
        """),
    "modules/lock/Pam.qml": "import QtQml\nQtObject { enum PamState { None, Error, MaxTries, Failed } }\n",
    "prova.qml": textwrap.dedent("""\
        import QtQuick
        import Quickshell.Io
        import Quickshell.Services.Greetd
        import Quickshell.Wayland
        import "modules/lock"
        Window {
            id: finestra
            width: 200; height: 100; visible: true
            property int sblocchi: 0
            property alias motore: motore
            property alias blocco: blocco
            function chiamate() { return Greetd.chiamate.join("\\n") }
            function chiediPassword() { Greetd.authMessage("Password:", false, true, false) }
            function passwordGiusta() { Greetd.readyToLaunch() }
            function passwordSbagliata() { Greetd.authFailure("Authentication failure") }
            function file(f) { FileFinti.file = f }
            function rileggi(tuo) { motore.tuo = tuo; motore.leggiUtenti() }
            function stato() { return motore.state }
            function utente() { return motore.utente }
            function avviso() { return motore.lockMessage }
            function apriBlocco() { blocco.locked = false }
            function attese(g, a) { motore.attesaGreetd = g; motore.attesaAvvio = a }
            function greetdAssente() { Greetd.available = false }
            WlSessionLock {
                id: blocco
                signal unlock
                locked: true
                onUnlock: finestra.sblocchi++
            }
            Item {
                id: campo
                focus: true
                Keys.onPressed: event => motore.handleKey(event)
            }
            AccessoGreetd {
                id: motore
                lock: blocco
            }
        }
        """),
}

PASSWD = "root:x:0:0::/root:/bin/bash\ndavide:x:1000:1000::/home/davide:/bin/bash\n" \
         "fantasma:x:1001:1001::/home/fantasma:/bin/bash\n"


class ProvaMotoreAccesso(unittest.TestCase):
    """Le prove vere girano in un processo a parte: serve un'applicazione Qt con la
    grafica (finestra senza schermo), e le altre prove ne creano una senza."""

    def test_in_un_processo_a_parte(self):
        r = subprocess.run([sys.executable, "-I", "-B", __file__, "--dentro"], capture_output=True,
                           text=True, timeout=180, env=dict(os.environ, QT_QPA_PLATFORM="offscreen"))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("OK", r.stderr)


def prove_dentro():
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    try:
        from PySide6.QtCore import QObject, Property, QUrl, Qt, Signal
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
        from PySide6.QtTest import QTest
        APP = QGuiApplication.instance() or QGuiApplication([])

        class BloccoFinto(QObject):
            """WlSessionLock di Quickshell: la proprieta' locked avvisa con lockStateChanged
            (non con lockedChanged, come farebbe una proprieta' scritta in QML)."""
            lockStateChanged = Signal()

            def __init__(self, genitore=None):
                super().__init__(genitore)
                self._chiuso = False

            def _leggi(self):
                return self._chiuso

            def _scrivi(self, valore):
                if valore != self._chiuso:
                    self._chiuso = valore
                    self.lockStateChanged.emit()

            locked = Property(bool, _leggi, _scrivi, notify=lockStateChanged)

        qmlRegisterType(BloccoFinto, "Quickshell.Wayland", 1, 0, "WlSessionLock")
    except ImportError:          # serve PySide6: vedi arch/test/test-importati.sh
        return None

    class ProvaMotoreAccessoDentro(unittest.TestCase):
        def setUp(self):
            self.dir = pathlib.Path(tempfile.mkdtemp())
            self.addCleanup(shutil.rmtree, self.dir)
            for nome, testo in FINTI.items():
                (self.dir / nome).parent.mkdir(parents=True, exist_ok=True)
                (self.dir / nome).write_text(testo)
            (self.dir / "utils").mkdir()
            shutil.copy(NUOVI / "utils/Accesso.js", self.dir / "utils/Accesso.js")
            shutil.copy(NUOVI / "modules/lock/AccessoGreetd.qml", self.dir / "modules/lock/AccessoGreetd.qml")
            self.errori = []
            self.motore_qml = QQmlApplicationEngine()
            self.motore_qml.warnings.connect(lambda w: self.errori.extend(x.toString() for x in w))
            self.motore_qml.addImportPath(str(self.dir))
            # i file letti dal motore: prima di caricare (li legge appena nato)
            self.motore_qml.rootContext()
            self.motore_qml.load(QUrl.fromLocalFile(str(self.dir / "prova.qml")))
            self.assertTrue(self.motore_qml.rootObjects(), "\n".join(self.errori))
            self.f = self.motore_qml.rootObjects()[0]

        def tearDown(self):
            for o in self.motore_qml.rootObjects():
                o.deleteLater()
            self.motore_qml.deleteLater()

        def prepara(self, utente="davide\n"):
            f = {"/etc/passwd": PASSWD}
            if utente is not None:
                f["/etc/vetro/utente"] = utente
            self.f.file(f)
            # i FileView leggono appena possono (Qt.callLater): si rilancia la lettura
            self.f.rileggi((utente or "").strip())
            QTest.qWait(50)

        def chiamate(self):
            return self.f.chiamate().split("\n") if self.f.chiamate() else []

        def scrivi(self, testo):
            self.f.requestActivate()
            QTest.qWait(20)
            for c in testo:
                QTest.keyClick(self.f, c)
            QTest.keyClick(self.f, Qt.Key_Return)
            QTest.qWait(50)

        def test_password_giusta_parte_il_desktop(self):
            self.prepara()
            self.scrivi("segreto")
            self.assertEqual(self.chiamate(), ["createSession davide"], self.errori)
            self.f.chiediPassword()
            QTest.qWait(20)
            self.assertIn("respond segreto", self.chiamate())
            self.f.passwordGiusta()
            QTest.qWait(20)
            self.assertEqual(self.f.property("sblocchi"), 1, "il blocco riceve unlock (animazione)")
            # fine dell'animazione di Caelestia: il blocco si apre, e allora parte il desktop
            self.f.apriBlocco()
            QTest.qWait(20)
            self.assertIn('launch ["/usr/local/bin/avvia-desktop"]', self.chiamate())
            self.assertEqual([e for e in self.errori if "AccessoGreetd" in e], [])

        def test_password_sbagliata_si_riprova(self):
            self.prepara()
            self.scrivi("sbagliata")
            self.f.chiediPassword()
            self.f.passwordSbagliata()
            QTest.qWait(20)
            self.assertEqual(self.f.stato(), 3, "stato Failed: compare 'password sbagliata'")
            self.scrivi("segreto")
            self.assertEqual(self.chiamate().count("createSession davide"), 2)

        def test_tab_passa_al_fantasma(self):
            self.prepara()
            self.f.requestActivate()
            QTest.keyClick(self.f, Qt.Key_Tab)
            QTest.qWait(20)
            self.assertEqual(self.f.utente(), "fantasma")
            self.assertEqual(self.f.avviso(), "Accesso come fantasma (Tab per cambiare)")
            self.scrivi("segreto")
            self.assertEqual(self.chiamate(), ["createSession fantasma"])

        def test_greetd_non_risponde(self):
            # dopo la password greetd tace: dopo un po' si annulla e si puo' riprovare
            self.prepara()
            self.f.attese(200, 200)
            self.scrivi("segreto")
            QTest.qWait(400)
            self.assertIn("cancelSession", self.chiamate())
            self.assertEqual(self.f.stato(), 1, "stato Error: compare il messaggio")
            self.scrivi("segreto")
            self.assertEqual(self.chiamate().count("createSession davide"), 2)

        def test_sblocco_che_si_inceppa(self):
            # password giusta ma l'animazione non apre il blocco: il desktop parte lo stesso
            self.prepara()
            self.f.attese(200, 200)
            self.scrivi("segreto")
            self.f.chiediPassword()
            self.f.passwordGiusta()
            QTest.qWait(400)
            self.assertIn('launch ["/usr/local/bin/avvia-desktop"]', self.chiamate())
            self.assertEqual(self.chiamate().count('launch ["/usr/local/bin/avvia-desktop"]'), 1)

        def test_avvio_una_volta_sola(self):
            self.prepara()
            self.f.attese(200, 200)
            self.scrivi("segreto")
            self.f.chiediPassword()
            self.f.passwordGiusta()
            self.f.apriBlocco()
            QTest.qWait(400)
            self.assertEqual(self.chiamate().count('launch ["/usr/local/bin/avvia-desktop"]'), 1)

        def test_greetd_assente(self):
            self.prepara()
            self.f.greetdAssente()
            self.scrivi("segreto")
            self.assertEqual(self.chiamate(), [])
            self.assertEqual(self.f.stato(), 1, "stato Error: compare il messaggio")

        def test_senza_file_dell_utente(self):
            self.prepara(utente=None)
            self.scrivi("segreto")
            self.assertEqual(self.chiamate(), ["createSession davide"])
    return ProvaMotoreAccessoDentro


if __name__ == "__main__":
    if "--dentro" in sys.argv:
        sys.argv.remove("--dentro")
        classe = prove_dentro()
        if classe is None:
            sys.exit("manca PySide6")
        unittest.main(defaultTest="classe")
    else:
        unittest.main()
