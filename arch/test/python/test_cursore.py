"""Prove del puntatore (disegna-cursori): freccia bianca con il bordo nero spesso."""
import importlib.machinery
import importlib.util
import pathlib
import unittest

FILE = pathlib.Path(__file__).resolve().parents[2] / "file/usr/local/lib/vetro/disegna-cursori"


def carica():
    caricatore = importlib.machinery.SourceFileLoader("disegna_cursori", str(FILE))
    spec = importlib.util.spec_from_loader("disegna_cursori", caricatore)
    modulo = importlib.util.module_from_spec(spec)
    caricatore.exec_module(modulo)
    return modulo


def pixel(immagine, taglia, x, y):
    """(r, g, b, a) da 0 a 255 dal pixel ARGB (colori moltiplicati per l'alfa)."""
    v = immagine[y * taglia + x]
    return (v >> 16) & 255, (v >> 8) & 255, v & 255, (v >> 24) & 255


class ProvaCursore(unittest.TestCase):
    def setUp(self):
        self.c = carica()
        self.img = self.c.immagine(self.c.freccia(), 24)

    def test_bordo_spesso(self):
        # colonna 1 (subito dentro il bordo sinistro): con il bordo spesso e' scura
        for y in range(4, 13):
            r, g, b, a = pixel(self.img, 24, 1, y)
            self.assertEqual(a, 255, f"riga {y}")
            self.assertLess(r, 140, f"riga {y}: il bordo e' troppo sottile")

    def test_dentro_bianco(self):
        r, g, b, a = pixel(self.img, 24, 4, 10)
        self.assertEqual(a, 255)
        self.assertGreater(r, 245)


if __name__ == "__main__":
    unittest.main()
