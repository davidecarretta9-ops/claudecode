"""Prove della scelta dell'utente nella schermata di accesso di oversicaOS (Accesso.js):
il tuo utente per primo, poi gli altri utenti veri (per esempio "fantasma"), che si
scelgono col tasto Tab (piano oversicaOS, Task 10)."""
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
      / "file/usr/local/lib/vetro/caelestia/nuovi/utils/Accesso.js")

PASSWD = """root:x:0:0::/root:/usr/bin/bash
bin:x:1:1::/:/usr/bin/nologin
greeter:x:964:964:greetd greeter user:/var/lib/greeter:/usr/bin/nologin
davide:x:1000:1000::/home/davide:/bin/bash
fantasma:x:1001:1001:Utente fantasma (tutto in memoria):/home/fantasma:/bin/bash
servizio:x:1002:1002::/:/usr/bin/false
nobody:x:65534:65534:Kernel Overflow User:/:/usr/bin/nologin
"""


def chiama(funzione, *argomenti):
    if QJSEngine is None:
        raise AssertionError("manca PySide6")
    m = QJSEngine()
    r = m.evaluate(JS.read_text().replace(".pragma library", ""))
    if r.isError():
        raise AssertionError(r.toString())
    r = m.evaluate("JSON.stringify(%s(%s))" % (funzione, ", ".join(json.dumps(a) for a in argomenti)))
    if r.isError():
        raise AssertionError(r.toString())
    return json.loads(r.toString())


class ProvaUtenti(unittest.TestCase):
    def test_il_tuo_utente_per_primo(self):
        self.assertEqual(chiama("utenti", PASSWD, "davide\n"), ["davide", "fantasma"])
        self.assertEqual(chiama("utenti", PASSWD, "fantasma"), ["fantasma", "davide"])

    def test_senza_file_dell_utente(self):
        self.assertEqual(chiama("utenti", PASSWD, ""), ["davide", "fantasma"])
        self.assertEqual(chiama("utenti", PASSWD, "nessuno"), ["davide", "fantasma"])

    def test_niente_utenti_di_sistema(self):
        for u in ("root", "greeter", "servizio", "nobody", "bin"):
            self.assertNotIn(u, chiama("utenti", PASSWD, ""))

    def test_passwd_vuoto(self):
        self.assertEqual(chiama("utenti", "", "davide"), [])


class ProvaAvviso(unittest.TestCase):
    def test_il_tuo_utente_niente_avviso(self):
        self.assertEqual(chiama("avviso", ["davide", "fantasma"], 0), "")

    def test_altro_utente(self):
        self.assertEqual(chiama("avviso", ["davide", "fantasma"], 1),
                         "Accesso come fantasma (Tab per cambiare)")


if __name__ == "__main__":
    unittest.main()
