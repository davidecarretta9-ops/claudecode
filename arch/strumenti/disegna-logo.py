#!/usr/bin/env python3
"""Logo di oversicaOS, "Orbita" (creato da lfs.sh; solo per lo sviluppo: i file finiti
vanno nello script, in arch/file). Nasce dal segno di Oversica: anello aperto in alto a
destra con il puntino arancione nell'apertura, tratto spesso e punte tonde.

    python3 disegna-logo.py CARTELLA_FILE     (di solito arch/file)

Scrive in CARTELLA_FILE/usr/share/icons/hicolor:
  scalable/apps/oversicaos.svg         icona "tessera" (quadrato grafite, segno crema)
  scalable/apps/oversicaos-segno.svg   solo il segno crema (per fondi scuri)
  NxN/apps/oversicaos.png              la tessera a 16, 24, 32, 48, 64, 128, 256, 512 px
Servono Pillow. SVG e PNG usano la stessa geometria (funzione geometria)."""
import math
import pathlib
import sys

from PIL import Image, ImageDraw

CREMA = "#eeece4"
ARANCIO = "#d9704a"
GRAFITE = "#1f201c"
DA, A, PUNTO = -10.0, 290.0, -40.0     # gradi, in senso orario da destra (come lo schermo)
MISURE = (16, 24, 32, 48, 64, 128, 256, 512)


def geometria(lato, tessera):
    """centro, raggio della linea dell'anello, spessore, raggio del punto, punto (x, y)"""
    c = lato / 2
    r = lato * (0.30 if tessera else 0.40)        # raggio esterno
    w = r * 0.30                                  # spessore
    rc = r - w / 2                                # raggio della linea centrale
    t = math.radians(PUNTO)
    return c, rc, w, w * 0.62, (c + rc * math.cos(t), c + rc * math.sin(t))


def svg(tessera):
    lato = 512
    c, rc, w, rp, (px, py) = geometria(lato, tessera)
    x0, y0 = c + rc * math.cos(math.radians(DA)), c + rc * math.sin(math.radians(DA))
    x1, y1 = c + rc * math.cos(math.radians(A)), c + rc * math.sin(math.radians(A))
    fondo = (f'  <rect width="{lato}" height="{lato}" rx="{lato * 0.24:.1f}" fill="{GRAFITE}"/>\n'
             if tessera else "")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {lato} {lato}" '
            f'width="{lato}" height="{lato}">\n'
            f'  <!-- oversicaOS, logo "Orbita" (creato da lfs.sh) -->\n{fondo}'
            f'  <path d="M {x0:.2f} {y0:.2f} A {rc:.2f} {rc:.2f} 0 1 1 {x1:.2f} {y1:.2f}" '
            f'fill="none" stroke="{CREMA}" stroke-width="{w:.2f}" stroke-linecap="round"/>\n'
            f'  <circle cx="{px:.2f}" cy="{py:.2f}" r="{rp:.2f}" fill="{ARANCIO}"/>\n'
            f'</svg>\n')


def png(lato, tessera=True):
    k = 8                                         # disegno piu' grande e poi rimpicciolisco
    L = lato * k
    im = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if tessera:
        d.rounded_rectangle([0, 0, L - 1, L - 1], radius=L * 0.24, fill=GRAFITE)
    c, rc, w, rp, (px, py) = geometria(L, tessera)
    passi = 360
    for i in range(passi + 1):                    # anello: tanti dischi lungo la linea
        a = math.radians(DA + (A - DA) * i / passi)
        x, y = c + rc * math.cos(a), c + rc * math.sin(a)
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=CREMA)
    d.ellipse([px - rp, py - rp, px + rp, py + rp], fill=ARANCIO)
    return im.resize((lato, lato), Image.LANCZOS)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    icone = pathlib.Path(sys.argv[1]) / "usr/share/icons/hicolor"
    (icone / "scalable/apps").mkdir(parents=True, exist_ok=True)
    (icone / "scalable/apps/oversicaos.svg").write_text(svg(True))
    (icone / "scalable/apps/oversicaos-segno.svg").write_text(svg(False))
    for s in MISURE:
        cartella = icone / f"{s}x{s}/apps"
        cartella.mkdir(parents=True, exist_ok=True)
        png(s).save(cartella / "oversicaos.png", optimize=True)
    print("logo scritto in", icone)


if __name__ == "__main__":
    main()
