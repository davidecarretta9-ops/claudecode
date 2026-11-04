"""Prove di oversica-config: le scelte di oversicaOS in ~/.config/caelestia/shell.json,
solo dove mancano (piano oversicaOS, Task 5)."""
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "file/usr/local/bin/oversica-config"


def lancia(casa):
    amb = dict(os.environ, HOME=str(casa), XDG_CONFIG_HOME=str(casa / ".config"))
    return subprocess.run(["python3", "-I", str(SCRIPT)], env=amb, capture_output=True, text=True)


class ProvaConfig(unittest.TestCase):
    def setUp(self):
        self.casa = pathlib.Path(tempfile.mkdtemp())
        self.file = self.casa / ".config/caelestia/shell.json"

    def leggi(self):
        return json.loads(self.file.read_text())

    def test_config_nuova(self):
        r = lancia(self.casa)
        self.assertEqual(r.returncode, 0, r.stderr)
        c = self.leggi()
        self.assertIs(c["bar"]["persistent"], False)
        self.assertEqual(c["general"]["language"], "it")
        self.assertEqual(c["general"]["logo"], "caelestia")
        self.assertEqual(c["paths"]["wallpaperDir"], "/usr/share/backgrounds")
        self.assertEqual(c["general"]["apps"]["terminal"], ["foot"])
        self.assertEqual(c["general"]["apps"]["explorer"], ["thunar"])

    def test_config_non_sovrascrive(self):
        self.file.parent.mkdir(parents=True)
        self.file.write_text(json.dumps({"bar": {"persistent": True, "tray": False},
                                         "general": {"language": "en"}}))
        self.assertEqual(lancia(self.casa).returncode, 0)
        c = self.leggi()
        self.assertIs(c["bar"]["persistent"], True)
        self.assertIs(c["bar"]["tray"], False)
        self.assertEqual(c["general"]["language"], "en")
        self.assertEqual(c["general"]["logo"], "caelestia")

    def test_config_rovinata(self):
        self.file.parent.mkdir(parents=True)
        self.file.write_text("{ non e' json")
        self.assertEqual(lancia(self.casa).returncode, 0)
        self.assertTrue((self.file.parent / "shell.json.rovinato").exists())
        self.assertIs(self.leggi()["bar"]["persistent"], False)


if __name__ == "__main__":
    unittest.main()
