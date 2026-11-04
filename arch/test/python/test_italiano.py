"""Prove della traduzione italiana di Caelestia (it.po, piano oversicaOS, Task 11).
caelestia-testi.pot sono tutte le frasi di Caelestia al commit fisso, estratte con lo
stesso comando del suo scripts/trs.fish ("raw"); it.po le traduce tutte."""
import pathlib
import re
import unittest

QUI = pathlib.Path(__file__).resolve().parents[1]
TESTI = QUI / "caelestia-testi.pot"
PO = (QUI.parent / "file/usr/local/lib/vetro/caelestia/nuovi"
      / "plugin/src/Caelestia/I18n/trs/it.po")
PATCH = QUI.parent / "file/usr/local/lib/vetro/caelestia/ritocchi/07-italiano.patch"


ESCAPE = {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}


def _testo(righe):
    """Il testo di una voce (le righe tra virgolette, unite, con \\n \\t \\" \\\\ sciolti)."""
    pezzi = (re.match(r'^(?:\S+ )?"(.*)"$', r).group(1) for r in righe)
    return re.sub(r'\\(.)', lambda m: ESCAPE.get(m.group(1), "\\" + m.group(1)), "".join(pezzi))


def leggi(percorso):
    """Le voci di un file .po/.pot: {(contesto, msgid): {"plurale": ..., "msgstr": [...], "flag": ...}}"""
    voci = {}
    for blocco in re.split(r"\n\s*\n", percorso.read_text(encoding="utf-8")):
        campi, chiave, flag = {}, None, ""
        for riga in blocco.splitlines():
            if riga.startswith("#,"):
                flag = riga
                continue
            if riga.startswith("#") or not riga.strip():
                continue
            m = re.match(r'^(msgctxt|msgid_plural|msgid|msgstr(?:\[\d\])?) ', riga)
            if m:
                chiave = m.group(1)
                campi[chiave] = [riga]
            elif riga.startswith('"') and chiave:
                campi[chiave].append(riga)
            else:
                raise AssertionError(f"riga strana in {percorso.name}: {riga!r}")
        if "msgid" not in campi:
            continue
        msgid = _testo(campi["msgid"])
        if msgid == "":
            continue          # l'intestazione
        msgstr = [_testo(v) for k, v in sorted(campi.items()) if k.startswith("msgstr")]
        voci[(_testo(campi.get("msgctxt", ['""'])), msgid)] = {
            "plurale": _testo(campi["msgid_plural"]) if "msgid_plural" in campi else None,
            "msgstr": msgstr, "flag": flag}
    return voci


def segnaposto(testo):
    return sorted(set(re.findall(r"%L?(?:[1-9]|n)", testo)))


class ProvaItaliano(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.testi = leggi(TESTI)
        cls.po = leggi(PO)

    def test_po_valido(self):
        self.assertGreater(len(self.testi), 500)
        testa = PO.read_text(encoding="utf-8")
        self.assertIn('"Language: it\\n"', testa)
        self.assertIn('"Plural-Forms: nplurals=2; plural=(n != 1);\\n"', testa)
        for chiave, v in self.po.items():
            self.assertTrue(v["msgstr"], chiave)
            if v["plurale"] is not None:
                self.assertEqual(len(v["msgstr"]), 2, chiave)

    def test_tutte_le_voci_tradotte(self):
        mancano = [k for k in self.testi if k not in self.po or not all(self.po[k]["msgstr"])]
        self.assertEqual(mancano, [])

    def test_segnaposto(self):
        sbagliati = []
        for k, v in self.po.items():
            originali = segnaposto(k[1] + " " + (v["plurale"] or ""))
            for s in v["msgstr"]:
                attesi = [x for x in originali if x != "%n"] if v["plurale"] is None else originali
                trovati = segnaposto(s)
                # nel singolare si puo' scrivere "un" al posto di %n (come in inglese "1 item")
                if v["plurale"] is not None and "%n" in attesi and "%n" not in trovati:
                    trovati = sorted(set(trovati) | {"%n"})
                if trovati != sorted(set(attesi)):
                    sbagliati.append((k, s))
        self.assertEqual(sbagliati, [])

    def test_voci_esistenti(self):
        self.assertEqual([k for k in self.po if k not in self.testi], [])

    def test_ritocco_compila_it(self):
        t = PATCH.read_text()
        self.assertIn("+    trs/it.po", t)


if __name__ == "__main__":
    unittest.main()
