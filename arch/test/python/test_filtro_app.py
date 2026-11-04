"""Prove del filtro del menu di oversicaOS (FiltroApp.js): niente app di sistema e
strumenti di Wine, ma i programmi Windows installati restano (piano oversicaOS, Task 6)."""
import json
import pathlib
import unittest

try:
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtQml import QJSEngine
    APP = QCoreApplication.instance() or QCoreApplication([])
except ImportError:          # serve PySide6: vedi arch/test/test-importati.sh
    QJSEngine = None

JS = (pathlib.Path(__file__).resolve().parents[2]
      / "file/usr/local/lib/vetro/caelestia/nuovi/utils/FiltroApp.js")


def nascosta(app):
    if QJSEngine is None:
        raise AssertionError("manca PySide6")
    m = QJSEngine()
    r = m.evaluate(JS.read_text().replace(".pragma library", ""))
    if r.isError():
        raise AssertionError(r.toString())
    app = dict({"categories": [], "noDisplay": False}, **app)
    r = m.evaluate("nascosta(%s)" % json.dumps(app))
    if r.isError():
        raise AssertionError(r.toString())
    return r.toBool()


class ProvaFiltroApp(unittest.TestCase):
    def test_strumenti_wine_nascosti(self):
        for i in ["wine", "winecfg", "wine-notepad", "wine-regedit", "wine-uninstaller",
                  "wine-winecfg", "wine-mime-msi", "org.winehq.Wine"]:
            self.assertTrue(nascosta({"id": i}), i)

    def test_programmi_windows_restano(self):
        self.assertFalse(nascosta({"id": "wine-Programs-Notepad++", "categories": ["Wine"]}))
        self.assertFalse(nascosta({"id": "wine-Programs-7-Zip-7-Zip File Manager"}))

    def test_terminale_e_file_restano(self):
        self.assertFalse(nascosta({"id": "foot", "categories": ["System", "TerminalEmulator"]}))
        self.assertFalse(nascosta({"id": "thunar", "categories": ["System", "Utility", "Core", "GTK", "FileManager"]}))
        self.assertFalse(nascosta({"id": "xfce4-taskmanager", "categories": ["System", "Monitor", "GTK"]}))

    def test_impostazioni_nascoste(self):
        self.assertTrue(nascosta({"id": "qt6ct", "categories": ["Settings", "DesktopSettings"]}))
        self.assertTrue(nascosta({"id": "avahi-discover", "categories": ["System", "Network"]}))
        self.assertTrue(nascosta({"id": "thunar-settings", "categories": ["GTK", "Utility"]}))
        self.assertTrue(nascosta({"id": "foot-server"}))

    def test_nodisplay(self):
        self.assertTrue(nascosta({"id": "qualcosa", "noDisplay": True}))

    def test_app_normali(self):
        self.assertFalse(nascosta({"id": "firefox", "categories": ["Network", "WebBrowser"]}))
        self.assertFalse(nascosta({"id": "org.mozilla.Thunderbird", "categories": ["Office", "Network", "Email"]}))
        self.assertFalse(nascosta({"id": "libreoffice-writer", "categories": ["Office", "WordProcessor"]}))

    def test_app_senza_categorie(self):
        self.assertFalse(nascosta({"id": "tor-browser", "categories": None}))


if __name__ == "__main__":
    unittest.main()
