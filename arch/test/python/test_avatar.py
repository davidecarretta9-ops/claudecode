"""Prove dell'avatar a pixel di oversicaOS (stile Lodge, piano oversicaOS, Task 12):
lo stesso disegno in Python (oversica-avatar, che scrive il PNG) e in JS (Avatar.js, che
lo mostra nelle Impostazioni)."""
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

try:
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtGui import QImage
    from PySide6.QtQml import QJSEngine
    APP = QCoreApplication.instance() or QCoreApplication([])
except ImportError:          # serve PySide6: vedi arch/test/test-importati.sh
    QJSEngine = None

FILE = pathlib.Path(__file__).resolve().parents[2] / "file"
SCRIPT = FILE / "usr/local/bin/oversica-avatar"
DATI = FILE / "usr/share/oversica/avatar/pixel.json"
JS = FILE / "usr/local/lib/vetro/caelestia/nuovi/utils/Avatar.js"
PREDEFINITE = {"capelli": "corti", "coloreCapelli": 2, "pelle": 1, "maglia": 2}
STILI = ["corti", "folti", "lunghi", "raccolti", "ricci", "rasati"]


def modulo():
    caricatore = importlib.machinery.SourceFileLoader("oversica_avatar", str(SCRIPT))
    spec = importlib.util.spec_from_loader("oversica_avatar", caricatore)
    m = importlib.util.module_from_spec(spec)
    caricatore.exec_module(m)
    return m


def disegna(scelte, lato=None):
    d = pathlib.Path(tempfile.mkdtemp())
    (d / "scelte.json").write_text(json.dumps(scelte))
    cmd = ["python3", "-I", str(SCRIPT), "disegna", str(d / "scelte.json"), str(d / "a.png")]
    if lato:
        cmd += ["--lato", str(lato)]
    r = subprocess.run(cmd, capture_output=True, text=True,
                       env=dict(os.environ, OVERSICA_AVATAR_DATI=str(DATI)))
    if r.returncode != 0:
        raise AssertionError(r.stderr)
    return (d / "a.png").read_bytes()


def griglia_js(scelte):
    if QJSEngine is None:
        raise AssertionError("manca PySide6")
    m = QJSEngine()
    r = m.evaluate(JS.read_text().replace(".pragma library", ""))
    if r.isError():
        raise AssertionError(r.toString())
    r = m.evaluate("JSON.stringify(griglia(%s, %s))" % (DATI.read_text(), json.dumps(scelte)))
    if r.isError():
        raise AssertionError(r.toString())
    return json.loads(r.toString())


class ProvaAvatar(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = modulo()
        cls.dati = json.loads(DATI.read_text())

    def griglia(self, scelte):
        return self.m.griglia(self.dati, scelte)

    def test_dati(self):
        d = self.dati
        self.assertEqual(d["lato"], 16)
        self.assertEqual(sorted(d["capelli"]), sorted(STILI))
        self.assertEqual(len(d["tavolozze"]["capelli"]), 8)
        self.assertEqual(len(d["tavolozze"]["pelle"]), 6)
        self.assertEqual(len(d["tavolozze"]["maglia"]), 8)
        for strato in [d["corpo"]] + list(d["capelli"].values()):
            self.assertEqual(len(strato), 16)
            for riga in strato:
                self.assertEqual(len(riga), 16, riga)

    def test_predefinite(self):
        self.assertEqual(self.m.normalizza({}), PREDEFINITE)

    def test_stessa_immagine(self):
        self.assertEqual(disegna(PREDEFINITE), disegna(PREDEFINITE))

    def test_ogni_scelta_cambia(self):
        base = self.griglia(PREDEFINITE)

        def cambiati(scelte):
            g = self.griglia(scelte)
            return {(x, y) for y in range(16) for x in range(16) if g[y][x] != base[y][x]}

        def zona(strato, lettere):
            return {(x, y) for y, riga in enumerate(strato) for x, c in enumerate(riga) if c in lettere}

        capelli = zona(self.dati["capelli"]["corti"], "hH")
        for stile in STILI[1:]:
            c = cambiati(dict(PREDEFINITE, capelli=stile))
            self.assertTrue(c, stile)
            self.assertLessEqual(c, capelli | zona(self.dati["capelli"][stile], "hH"), stile)
        c = cambiati(dict(PREDEFINITE, coloreCapelli=5))
        self.assertTrue(c)
        self.assertLessEqual(c, capelli)
        c = cambiati(dict(PREDEFINITE, pelle=4))
        self.assertTrue(c)
        self.assertLessEqual(c, zona(self.dati["corpo"], "sS") - capelli)
        c = cambiati(dict(PREDEFINITE, maglia=6))
        self.assertTrue(c)
        self.assertLessEqual(c, zona(self.dati["corpo"], "mM") - capelli)

    def test_js_uguale_python(self):
        for scelte in [PREDEFINITE, {"capelli": "lunghi", "coloreCapelli": 7, "pelle": 5, "maglia": 0},
                       {"capelli": "ricci", "coloreCapelli": 0, "pelle": 0, "maglia": 7},
                       {"capelli": "blu", "pelle": 99}]:
            self.assertEqual(griglia_js(scelte), self.griglia(scelte), scelte)

    def test_scelte_strane(self):
        self.assertEqual(self.m.normalizza({"capelli": "blu", "pelle": 99, "maglia": "x", "coloreCapelli": -1}),
                         PREDEFINITE)
        self.assertEqual(self.m.normalizza({"capelli": "ricci", "pelle": 3}),
                         dict(PREDEFINITE, capelli="ricci", pelle=3))
        self.assertEqual(self.m.normalizza("non un oggetto"), PREDEFINITE)
        self.assertTrue(disegna({"capelli": "blu", "pelle": 99}).startswith(b"\x89PNG\r\n\x1a\n"))

    def test_png_pixel_netti(self):
        d = pathlib.Path(tempfile.mkdtemp())
        (d / "a.png").write_bytes(disegna(PREDEFINITE))
        img = QImage(str(d / "a.png"))
        self.assertEqual((img.width(), img.height()), (256, 256))
        g = self.griglia(PREDEFINITE)
        for by in range(16):
            for bx in range(16):
                colori = {img.pixel(bx * 16 + x, by * 16 + y) for y in range(16) for x in range(16)}
                self.assertEqual(len(colori), 1, (bx, by))
                atteso = g[by][bx] or self.dati["sfondo"]
                self.assertEqual("#%06x" % (colori.pop() & 0xFFFFFF), atteso.lower(), (bx, by))

    def test_lato(self):
        d = pathlib.Path(tempfile.mkdtemp())
        (d / "a.png").write_bytes(disegna(PREDEFINITE, lato=64))
        self.assertEqual(QImage(str(d / "a.png")).width(), 64)


if __name__ == "__main__":
    unittest.main()
