"""Prove delle regole di Hyprland per piu' schermi (Schermi.js), con il motore JS di Qt (Task 6)."""
import json
import pathlib
import unittest

try:
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtQml import QJSEngine
    APP = QCoreApplication.instance() or QCoreApplication([])
except ImportError:          # serve PySide6: vedi arch/test/test-importati.sh
    QJSEngine = None

JS = pathlib.Path(__file__).resolve().parents[2] / "file/etc/xdg/quickshell/vetro/Schermi.js"
UNO = {"name": "Virtual-1", "width": 1920, "height": 1080}
DUE = {"name": "Virtual-2", "width": 1920, "height": 1080}


def regole(schermi, scelte):
    if QJSEngine is None:
        raise AssertionError("manca PySide6 (python3 -m venv ~/.vetro-qt && ~/.vetro-qt/bin/pip install PySide6-Essentials)")
    motore = QJSEngine()
    testo = JS.read_text().replace(".pragma library", "")
    motore.evaluate(testo)
    risultato = motore.evaluate("regole(%s, %s)" % (json.dumps(schermi), json.dumps(scelte)))
    if risultato.isError():
        raise AssertionError(risultato.toString())
    return risultato.toString()


class ProvaSchermi(unittest.TestCase):
    def test_due_schermi_destra(self):
        t = regole([UNO, DUE], {"Virtual-1": {"principale": True, "risoluzione": "1920x1080", "scala": 1},
                                "Virtual-2": {"posizione": "destra", "risoluzione": "1920x1080", "scala": 1}})
        self.assertIn("monitor = Virtual-1, 1920x1080, 0x0, 1\n", t)
        self.assertIn("monitor = Virtual-2, 1920x1080, 1920x0, 1\n", t)

    def test_duplica(self):
        t = regole([UNO, DUE], {"Virtual-1": {"principale": True}, "Virtual-2": {"posizione": "duplica"}})
        self.assertIn("monitor = Virtual-2, preferred, auto, 1, mirror, Virtual-1\n", t)

    def test_regole_schermi_spariti(self):
        t = regole([UNO], {"Virtual-1": {"principale": True}, "Virtual-2": {"posizione": "destra"}})
        self.assertNotIn("Virtual-2", t)
        self.assertIn("monitor = Virtual-1, 1920x1080, 0x0, 1\n", t)

    def test_nessuna_scelta(self):
        self.assertEqual("", regole([UNO, DUE], {}))

    def test_sinistra_con_scala(self):
        t = regole([UNO, DUE], {"Virtual-1": {"principale": True},
                                "Virtual-2": {"posizione": "sinistra", "risoluzione": "2560x1440", "scala": 2}})
        self.assertIn("monitor = Virtual-2, 2560x1440, -1280x0, 2\n", t)


if __name__ == "__main__":
    unittest.main()
