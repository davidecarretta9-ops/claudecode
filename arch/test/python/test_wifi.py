"""Prove di vetro-wifi: come legge l'elenco delle reti di iwctl (Task 7)."""
import importlib.machinery
import importlib.util
import pathlib
import unittest

FILE = pathlib.Path(__file__).resolve().parents[2] / "file/usr/local/bin/vetro-wifi"


def carica():
    caricatore = importlib.machinery.SourceFileLoader("vetro_wifi", str(FILE))
    spec = importlib.util.spec_from_loader("vetro_wifi", caricatore)
    modulo = importlib.util.module_from_spec(spec)
    caricatore.exec_module(modulo)
    return modulo


GRIGIO = "\x1b[1;90m"
SPENTO = "\x1b[0m"

# come lo scrive "iwctl station wlan0 get-networks": le stelline spente sono grigie
CON_STELLE = (
    "                               Available networks                             \n"
    "--------------------------------------------------------------------------------\n"
    "      Network name                      Security            Signal\n"
    "--------------------------------------------------------------------------------\n"
    "      Bar Sport                         open                **" + GRIGIO + "**" + SPENTO + "    \n"
    "  " + GRIGIO + "> " + SPENTO + "  Casa Rossi                        psk                 ****    \n"
    "      Vicino                            psk                 *" + GRIGIO + "***" + SPENTO + "    \n"
    "\n"
)

# con "get-networks rssi-dbms": il segnale in dBm (a volte per 100)
CON_DBM = (
    "                               Available networks\n"
    "--------------------------------------------------------------------------------\n"
    "      Network name                      Security            Signal\n"
    "--------------------------------------------------------------------------------\n"
    "  > Casa Rossi                          psk                 -58\n"
    "      Bar Sport                         open                -7400\n"
)

VUOTO = "No networks available\n"


class ProvaWifi(unittest.TestCase):
    def setUp(self):
        self.w = carica()

    def test_elenco(self):
        reti = self.w.leggi_elenco(CON_STELLE)
        self.assertEqual(len(reti), 3)
        self.assertEqual(reti[0], {"nome": "Casa Rossi", "segnale": 4, "protetta": True, "collegata": True})
        self.assertEqual(reti[1], {"nome": "Bar Sport", "segnale": 2, "protetta": False, "collegata": False})
        self.assertEqual(reti[2]["nome"], "Vicino")
        self.assertEqual(reti[2]["segnale"], 1)

    def test_dbm(self):
        reti = self.w.leggi_elenco(CON_DBM)
        self.assertEqual([(r["nome"], r["segnale"], r["collegata"]) for r in reti],
                         [("Casa Rossi", 4, True), ("Bar Sport", 2, False)])

    def test_vuoto(self):
        self.assertEqual(self.w.leggi_elenco(VUOTO), [])
        self.assertEqual(self.w.leggi_elenco(""), [])


if __name__ == "__main__":
    unittest.main()
