"""Prove delle regole di Hyprland per piu' schermi (Hypr.js, funzione schermi), con il motore
JS di Qt; ogni risultato passa anche dall'Hyprland finto di test_lua.py (Lua di Hyprland 0.57)."""
import json
import pathlib
import shutil
import tempfile
import unittest

from test_lua import Hyprland, js, motore_js

UNO = {"name": "Virtual-1", "width": 1920, "height": 1080}
DUE = {"name": "Virtual-2", "width": 1920, "height": 1080}


def regole(schermi, scelte):
    return js(motore_js(), "schermi(%s, %s)" % (json.dumps(schermi), json.dumps(scelte)))


def in_hyprland(testo):
    """Le regole come le legge Hyprland: l'elenco degli hl.monitor."""
    cartella = pathlib.Path(tempfile.mkdtemp())
    try:
        f = cartella / "schermi.lua"
        f.write_text(testo)
        h = Hyprland().esegui_file(f)
    finally:
        shutil.rmtree(cartella)
    if h.errori:
        raise AssertionError(h.errori)
    return h.monitor


def schermo(nome, modo, posizione, scala, copia=None):
    d = {"output": nome, "mode": modo, "position": posizione, "scale": scala}
    if copia:
        d["mirror"] = copia
    return d


class ProvaSchermi(unittest.TestCase):
    def test_due_schermi_destra(self):
        t = regole([UNO, DUE], {"Virtual-1": {"principale": True, "risoluzione": "1920x1080", "scala": 1},
                                "Virtual-2": {"posizione": "destra", "risoluzione": "1920x1080", "scala": 1}})
        self.assertEqual(in_hyprland(t), [schermo("Virtual-1", "1920x1080", "0x0", "1"),
                                          schermo("Virtual-2", "1920x1080", "1920x0", "1")])

    def test_duplica(self):
        t = regole([UNO, DUE], {"Virtual-1": {"principale": True}, "Virtual-2": {"posizione": "duplica"}})
        self.assertIn(schermo("Virtual-2", "preferred", "auto", "1", "Virtual-1"), in_hyprland(t))

    def test_regole_schermi_spariti(self):
        t = regole([UNO], {"Virtual-1": {"principale": True}, "Virtual-2": {"posizione": "destra"}})
        self.assertEqual(in_hyprland(t), [schermo("Virtual-1", "1920x1080", "0x0", "1")])

    def test_nessuna_scelta(self):
        self.assertEqual("", regole([UNO, DUE], {}))

    def test_sinistra_con_scala(self):
        t = regole([UNO, DUE], {"Virtual-1": {"principale": True},
                                "Virtual-2": {"posizione": "sinistra", "risoluzione": "2560x1440", "scala": 2}})
        self.assertIn(schermo("Virtual-2", "2560x1440", "-1280x0", "2"), in_hyprland(t))

    def test_nome_strano_resta_un_testo(self):
        strano = {"name": 'HDMI"-1\\', "width": 1280, "height": 720}
        t = regole([strano], {'HDMI"-1\\': {"principale": True}})
        self.assertEqual(in_hyprland(t), [schermo('HDMI"-1\\', "1280x720", "0x0", "1")])


if __name__ == "__main__":
    unittest.main()
