"""Prove di Letture.js: batteria e rete per la barra (piano nuova grafica, Task 4)."""
import json
import pathlib
import unittest

try:
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtQml import QJSEngine
    APP = QCoreApplication.instance() or QCoreApplication([])
except ImportError:          # serve PySide6: vedi arch/test/test-importati.sh
    QJSEngine = None

JS = pathlib.Path(__file__).resolve().parents[2] / "file/etc/xdg/quickshell/vetro/Letture.js"


def chiama(funzione, testo):
    if QJSEngine is None:
        raise AssertionError("manca PySide6 (python3 -m venv ~/.vetro-qt && ~/.vetro-qt/bin/pip install PySide6-Essentials)")
    motore = QJSEngine()
    motore.evaluate(JS.read_text().replace(".pragma library", ""))
    r = motore.evaluate("JSON.stringify(%s(%s))" % (funzione, json.dumps(testo)))
    if r.isError():
        raise AssertionError(r.toString())
    return json.loads(r.toString())


class ProvaLetture(unittest.TestCase):
    def test_batteria(self):
        self.assertEqual(chiama("batteria", "85 Discharging\n"), {"livello": 85, "carica": False})

    def test_in_carica(self):
        self.assertEqual(chiama("batteria", "40 Charging\n"), {"livello": 40, "carica": True})

    def test_piena_attaccata(self):
        self.assertEqual(chiama("batteria", "100 Full\n"), {"livello": 100, "carica": True})

    def test_senza_batteria(self):
        self.assertEqual(chiama("batteria", ""), {"livello": -1, "carica": False})

    def test_wifi(self):
        t = "enp1s0 cavo down\nwlan0 wireless up\nwlan0: 0000   56.  -54.  -256        0      0      0      0     21        0\n"
        self.assertEqual(chiama("rete", t), {"tipo": "wifi", "segnale": 4})

    def test_wifi_debole(self):
        t = "wlan0 wireless up\nwlan0: 0000   20.  -85.  -256        0      0      0      0     21        0\n"
        self.assertEqual(chiama("rete", t), {"tipo": "wifi", "segnale": 2})

    def test_solo_cavo(self):
        self.assertEqual(chiama("rete", "enp1s0 cavo up\n"), {"tipo": "cavo", "segnale": 0})

    def test_niente(self):
        self.assertEqual(chiama("rete", "enp1s0 cavo down\nwlan0 wireless dormant\n"), {"tipo": "nessuna", "segnale": 0})
        self.assertEqual(chiama("rete", ""), {"tipo": "nessuna", "segnale": 0})


if __name__ == "__main__":
    unittest.main()
