"""Prove di fantasma-aiuto in una cartella finta (VETRO_RADICE) (Task 9)."""
import importlib.machinery
import importlib.util
import os
import pathlib
import tempfile
import unittest

FILE = pathlib.Path(__file__).resolve().parents[2] / "file/usr/local/sbin/fantasma-aiuto"


def carica(radice):
    vecchia = os.environ.get("VETRO_RADICE")
    vecchio_path = os.environ.get("PATH")
    os.environ["VETRO_RADICE"] = radice
    try:
        caricatore = importlib.machinery.SourceFileLoader("fantasma_aiuto", str(FILE))
        spec = importlib.util.spec_from_loader("fantasma_aiuto", caricatore)
        modulo = importlib.util.module_from_spec(spec)
        caricatore.exec_module(modulo)
    finally:
        if vecchia is None:
            os.environ.pop("VETRO_RADICE", None)
        else:
            os.environ["VETRO_RADICE"] = vecchia
        os.environ["PATH"] = vecchio_path or ""
    # sicurezza: se lo script non usa la cartella finta scriverebbe nel /etc vero
    if getattr(modulo, "RADICE", None) != radice:
        raise AssertionError("fantasma-aiuto non usa VETRO_RADICE: prova fermata")
    chiamate = []
    modulo.comando = lambda *c, muto=True: chiamate.append(" ".join(c)) or True
    return modulo, chiamate


class ProvaFantasma(unittest.TestCase):
    def setUp(self):
        self.cartella = tempfile.TemporaryDirectory()
        self.r = self.cartella.name
        os.makedirs(os.path.join(self.r, "etc/systemd/network"))
        with open(os.path.join(self.r, "etc/systemd/network/20-cavo.network"), "w") as f:
            f.write("[Match]\nName=en*\n")
        try:
            self.f, self.chiamate = carica(self.r)
        except AssertionError:
            self.cartella.cleanup()
            raise

    def tearDown(self):
        self.cartella.cleanup()

    def esiste(self, rel):
        return os.path.exists(os.path.join(self.r, rel))

    def test_prepara(self):
        self.assertTrue(self.f.prepara())
        for rel in ("etc/fantasma/attivo", "etc/tor/fantasma.torrc",
                    "etc/systemd/resolved.conf.d/99-fantasma.conf",
                    "etc/systemd/network/20-cavo.network.d/90-fantasma.conf"):
            self.assertTrue(self.esiste(rel), rel)
        self.assertEqual(self.chiamate, ["systemctl enable tor-fantasma.service"])
        torrc = open(os.path.join(self.r, "etc/tor/fantasma.torrc")).read()
        self.assertIn("SocksPort 127.0.0.1:9150", torrc)
        self.assertIn("vetro-arch.sh", torrc)

    def test_spegni(self):
        self.f.prepara()
        altro = os.path.join(self.r, "etc/systemd/resolved.conf.d/10-mio.conf")
        with open(altro, "w") as f:
            f.write("[Resolve]\nDNS=9.9.9.9\n")
        self.chiamate.clear()
        self.assertTrue(self.f.spegni())
        self.assertFalse(self.esiste("etc/fantasma/attivo"))
        self.assertFalse(self.esiste("etc/systemd/resolved.conf.d/99-fantasma.conf"))
        self.assertFalse(self.esiste("etc/systemd/network/20-cavo.network.d/90-fantasma.conf"))
        self.assertTrue(os.path.exists(altro))
        self.assertIn("systemctl disable --now tor-fantasma.service", self.chiamate)

    def test_stato(self):
        self.assertFalse(self.f.acceso())
        self.f.prepara()
        self.assertTrue(self.f.acceso())


if __name__ == "__main__":
    unittest.main()
