#!/usr/bin/python3 -I
"""Copia una volta, da lfs.sh, i file del desktop Vetro e della sicurezza in arch/file/.

    python3 -I arch/strumenti/importa-da-lfs.py lfs.sh arch/file

Prende gli heredoc  cat > PERCORSO << "EOF"  (delimitatore tra virgolette, cioe' testo
copiato cosi' com'e') dentro le funzioni scelte. Se un percorso compare piu' volte vince
l'ultima definizione. Gli heredoc senza virgolette (con variabili) si riscrivono a mano.
"""
import pathlib
import re
import sys

FUNZIONI = {"f10_shell", "f10_aiutanti", "f10_config_hyprland", "f10_cursori", "f6_guardiano",
            "f6_cassaforte", "f6_vpn", "f6_recinto_wine", "f6_tor_browser", "f7_fantasma",
            "f7_utente_fantasma"}
# servivano solo con LFS (controllo del 3D, password senza PAM, desktop classico)
ESCLUSI = {"/usr/local/lib/vetro/vetro-password.c", "/usr/local/sbin/controlla-3d",
           "/etc/systemd/system/controlla-3d.service", "/usr/local/bin/scegli-desktop",
           "/usr/share/applications/scegli-desktop.desktop"}
CARTELLA_PANNELLI = "/etc/xdg/quickshell/vetro"

INIZIO_FUNZIONE = re.compile(r"^([a-z0-9_]+)\(\) \{$")
HEREDOC = re.compile(r"(?<!<)<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1\s*$")
CAT = re.compile(r"^cat > (\"[^\"]+\"|\S+) <<")


def percorso_di(destinazione):
    """Il percorso assoluto del file, oppure None se dipende da una variabile."""
    p = destinazione.strip('"')
    if p.startswith("$d/"):
        return CARTELLA_PANNELLI + p[2:]
    if p.startswith("/") and "$" not in p:
        return p
    return None


def permessi(p):
    if p.startswith("/etc/sudoers.d/"):
        return 0o440
    if p.startswith(("/usr/local/bin/", "/usr/local/sbin/", "/usr/local/lib/")):
        return 0o755
    return 0o644


def importa(testo, uscita):
    """Scrive i file in uscita; restituisce (scritti, saltati) come percorsi assoluti."""
    uscita = pathlib.Path(uscita)
    funzione = None
    dentro = None          # (delimitatore, percorso o None, righe)
    trovati = {}
    saltati = []
    for riga in testo.split("\n"):
        if dentro is not None:
            fine, p, righe = dentro
            if riga == fine:
                if p is not None:
                    trovati[p] = "".join(r + "\n" for r in righe)
                dentro = None
            else:
                righe.append(riga)
            continue
        m = INIZIO_FUNZIONE.match(riga)
        if m:
            funzione = m.group(1)
            continue
        h = HEREDOC.search(riga)
        if not h:
            continue
        p = None
        c = CAT.match(riga)
        if c and funzione in FUNZIONI:
            p = percorso_di(c.group(1))
            if p in ESCLUSI:
                p = None
            elif p is not None and not h.group(1):
                saltati.append(p)          # senza virgolette: ha delle variabili
                p = None
        dentro = (h.group(2), p, [])
    for p, contenuto in trovati.items():
        f = uscita / p.lstrip("/")
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(contenuto)
        f.chmod(permessi(p))
    return sorted(trovati), sorted(set(saltati) - set(trovati))


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    scritti, saltati = importa(pathlib.Path(sys.argv[1]).read_text(), sys.argv[2])
    print(f"Scritti {len(scritti)} file:")
    for p in scritti:
        print("  " + p)
    if saltati:
        print("Saltati (con variabili, da riscrivere a mano):")
        for p in saltati:
            print("  " + p)


if __name__ == "__main__":
    main()
