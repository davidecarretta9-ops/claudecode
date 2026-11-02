"""Prove dello strumento che copia i file di Vetro da lfs.sh (Task 4)."""
import importlib.util
import pathlib
import tempfile
import unittest

QUI = pathlib.Path(__file__).resolve().parent
STRUMENTO = QUI.parent.parent / "strumenti" / "importa-da-lfs.py"


def carica():
    spec = importlib.util.spec_from_file_location("importa_da_lfs", STRUMENTO)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


FINTO_LFS = '''#!/bin/bash
f7_fantasma() {
cat > /usr/local/bin/x << "EOF"
prima
EOF
cat > /usr/local/bin/x << "EOF"
seconda
f_dentro() {
EOF
cat > /etc/systemd/system/casa.mount << EOF
uid=$uid
EOF
}

f10_shell() {
local d=/etc/xdg/quickshell/vetro
cat > "$d/A.qml" << "EOF"
import QtQuick
EOF
}

f8_altro() {
cat > /usr/local/bin/da-non-prendere << "EOF"
no
EOF
}
'''


class ProvaImporta(unittest.TestCase):
    def setUp(self):
        self.m = carica()
        self.uscita = pathlib.Path(tempfile.mkdtemp())

    def test_qml_nella_cartella_dei_pannelli(self):
        self.m.importa(FINTO_LFS, self.uscita)
        self.assertEqual((self.uscita / "etc/xdg/quickshell/vetro/A.qml").read_text(), "import QtQuick\n")

    def test_vince_l_ultima_definizione(self):
        self.m.importa(FINTO_LFS, self.uscita)
        x = self.uscita / "usr/local/bin/x"
        self.assertEqual(x.read_text(), "seconda\nf_dentro() {\n")
        self.assertEqual(oct(x.stat().st_mode & 0o777), "0o755")

    def test_heredoc_senza_virgolette_saltato(self):
        _scritti, saltati = self.m.importa(FINTO_LFS, self.uscita)
        self.assertIn("/etc/systemd/system/casa.mount", saltati)
        self.assertFalse((self.uscita / "etc/systemd/system/casa.mount").exists())

    def test_solo_le_funzioni_scelte(self):
        self.m.importa(FINTO_LFS, self.uscita)
        self.assertFalse((self.uscita / "usr/local/bin/da-non-prendere").exists())


if __name__ == "__main__":
    unittest.main()
