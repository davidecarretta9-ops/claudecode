#!/usr/bin/env python3
"""Disegna gli sfondi della nuova grafica di Vetro (creato da vetro-arch.sh; solo per lo
sviluppo: le immagini finite vanno nello script, in usr/share/backgrounds).

    python3 disegna-sfondi.py CARTELLA [NOME...]

Disegni originali fatti di forme semplici (sfumature, cerchi, curve, sfocature):
sfera, nuvole, cielo, onde, magenta, argento. Servono PIL (Pillow) e numpy.
"""
import math
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

L, A = 2560, 1440


def sfumatura(colori, angolo=90.0):
    """colori: [(posizione 0..1, (r, g, b)), ...]; angolo 90 = dall'alto in basso."""
    y, x = np.mgrid[0:A, 0:L].astype(np.float32)
    rad = math.radians(angolo)
    t = (x / L) * math.cos(rad) + (y / A) * math.sin(rad)
    t = (t - t.min()) / (t.max() - t.min())
    out = np.zeros((A, L, 3), np.float32)
    pos = [c[0] for c in colori]
    for k in range(3):
        out[..., k] = np.interp(t, pos, [c[1][k] for c in colori])
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGB")


def strato():
    return Image.new("RGBA", (L, A), (0, 0, 0, 0))


def incolla(base, s, sfoca=0):
    if sfoca:
        s = s.filter(ImageFilter.GaussianBlur(sfoca))
    base.alpha_composite(s)


def grana(img, forza=3.0, seme=1):
    """un filo di grana: niente scalini nelle sfumature"""
    r = np.random.default_rng(seme)
    a = np.asarray(img.convert("RGB"), np.float32)
    a += r.normal(0, forza, a.shape[:2])[..., None]
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGB")


def arco(d, cx, cy, r, da, a, colore, spessore):
    d.arc([cx - r, cy - r, cx + r, cy + r], da, a, fill=colore, width=spessore)


def sfera():
    base = sfumatura([(0, (222, 238, 252)), (0.55, (178, 214, 246)), (1, (140, 196, 245))], 35).convert("RGBA")
    # alone chiaro dietro la sfera
    s = strato(); d = ImageDraw.Draw(s)
    d.ellipse([1300, -600, 2900, 1000], fill=(255, 255, 255, 90))
    incolla(base, s, 120)
    # la sfera: blu pieno, piu' chiara in alto a destra, bordo morbido
    cx, cy, r = 1950, 330, 560
    y, x = np.mgrid[0:A, 0:L].astype(np.float32)
    dist = np.hypot(x - cx, y - cy)
    alfa = np.clip((r - dist) / 22.0, 0, 1)
    luce = np.clip(((x - cx) * 0.6 - (y - cy) * 0.8) / r, -1, 1)
    col = np.zeros((A, L, 4), np.float32)
    col[..., 0] = 10 + 40 * (luce + 1) / 2
    col[..., 1] = 112 + 70 * (luce + 1) / 2
    col[..., 2] = 236 + 19 * (luce + 1) / 2
    col[..., 3] = alfa * 255
    incolla(base, Image.fromarray(col.astype(np.uint8), "RGBA"))
    # linee bianche sottili che attraversano lo schermo
    s = strato(); d = ImageDraw.Draw(s)
    arco(d, 3300, 2200, 2700, 180, 260, (255, 255, 255, 220), 4)
    arco(d, -300, 2600, 2900, 280, 330, (255, 255, 255, 170), 3)
    arco(d, 1250, 2000, 1900, 230, 300, (255, 255, 255, 140), 3)
    incolla(base, s, 1)
    return grana(base, 2.0, 1)


def nuvola(d, x, y, k, chiaro, scuro):
    """una nuvola a rilievo: prima l'ombra spostata, poi la parte chiara"""
    pezzi = [(-90, 10, 70), (-30, -35, 95), (60, -5, 80), (120, 25, 55)]
    for dx, dy, col in ((14 * k, 18 * k, scuro), (0, 0, chiaro)):
        for px, py, r in pezzi:
            r *= k
            d.ellipse([x + px * k - r + dx, y + py * k - r + dy, x + px * k + r + dx, y + py * k + r + dy], fill=col)
        d.rounded_rectangle([x - 150 * k + dx, y + 10 * k + dy, x + 175 * k + dx, y + 80 * k + dy],
                            radius=int(35 * k), fill=col)


def nuvole():
    base = sfumatura([(0, (9, 26, 52)), (0.6, (17, 52, 92)), (1, (28, 84, 128))], 100).convert("RGBA")
    caso = random.Random(7)
    # scie diagonali e puntini
    s = strato(); d = ImageDraw.Draw(s)
    for _ in range(26):
        x, y, n = caso.uniform(-400, L), caso.uniform(-200, A), caso.uniform(180, 520)
        d.line([x, y, x + n * 0.82, y - n * 0.57], fill=(160, 200, 240, caso.randint(25, 70)), width=caso.choice([2, 3]))
    for _ in range(140):
        x, y = caso.uniform(0, L), caso.uniform(0, A)
        r = caso.uniform(1, 2.4)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(220, 235, 255, caso.randint(60, 160)))
    incolla(base, s, 0.6)
    # nuvole morbide, ruotate come le scie
    for i in range(14):
        k = caso.uniform(0.7, 1.35)
        s = strato(); d = ImageDraw.Draw(s)
        x, y = caso.uniform(0, L), caso.uniform(0, A)
        nuvola(d, 600, 400, k, (150, 186, 226, 235), (92, 126, 178, 235))
        s = s.crop((0, 0, 1200, 800)).rotate(caso.uniform(-38, -28), resample=Image.BICUBIC)
        pezzo = strato()
        pezzo.paste(s, (int(x - 600), int(y - 400)), s)
        incolla(base, pezzo, 3)
    return grana(base, 2.0, 2)


def cielo():
    base = sfumatura([(0, (10, 52, 108)), (0.3, (30, 120, 205)), (0.65, (88, 186, 240)),
                      (1, (196, 233, 251))], 95).convert("RGBA")
    s = strato(); d = ImageDraw.Draw(s)
    d.ellipse([-500, 700, 1500, 1900], fill=(255, 255, 255, 60))
    d.ellipse([1500, 900, 3100, 2000], fill=(255, 255, 255, 45))
    incolla(base, s, 160)
    return grana(base, 2.0, 3)


def nastro(base, centro, spessore, colore, chiaro):
    """un nastro di vetro lungo una curva (poligono, niente tacche): alone, corpo con
    la parte alta piu' chiara e una riga di luce sul bordo"""
    def fascia(da, a):
        sopra = [(x, y + da) for x, y in centro]
        sotto = [(x, y + a) for x, y in reversed(centro)]
        return sopra + sotto
    r, g, b, _ = colore
    s = strato(); ImageDraw.Draw(s).polygon(fascia(-spessore / 2, spessore / 2), fill=(r, g, b, 150))
    incolla(base, s, spessore * 0.55)
    s = strato(); d = ImageDraw.Draw(s)
    d.polygon(fascia(-spessore / 2, spessore / 2), fill=(r, g, b, 255))
    d.polygon(fascia(-spessore / 2, -spessore / 10), fill=(min(255, r + 40), min(255, g + 50), min(255, b + 20), 255))
    incolla(base, s, 2)
    s = strato(); ImageDraw.Draw(s).polygon(fascia(-spessore / 2 + 3, -spessore / 2 + 3 + max(4, spessore / 16)), fill=chiaro)
    incolla(base, s, 2)


def curva(x0, y0, x1, y1, onda, n=80):
    return [(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + onda * math.sin(t * math.pi)) for t in [i / n for i in range(n + 1)]]


def onde():
    base = sfumatura([(0, (4, 9, 22)), (1, (8, 20, 46))], 100).convert("RGBA")
    for punti, sp, col, chi in [
        (curva(-400, 1180, 3000, 500, -260), 170, (16, 92, 214, 255), (150, 215, 255, 230)),
        (curva(-400, 1420, 3000, 820, -180), 120, (10, 64, 170, 255), (120, 195, 255, 200)),
        (curva(-400, 420, 3000, -120, 240), 210, (20, 110, 235, 255), (175, 228, 255, 230)),
    ]:
        nastro(base, punti, sp, col, chi)
    return grana(base, 2.5, 4)


def magenta():
    base = sfumatura([(0, (14, 2, 12)), (1, (4, 0, 6))], 100).convert("RGBA")
    for (x, y, w, h, ang) in [(1500, 260, 900, 520, -14), (300, 820, 1100, 420, -8), (1900, 980, 700, 360, -20)]:
        s = strato(); d = ImageDraw.Draw(s)
        d.rounded_rectangle([x, y, x + w, y + h], radius=h // 2, fill=(210, 29, 187, 255))
        s = s.rotate(ang, center=(x + w / 2, y + h / 2), resample=Image.BICUBIC)
        incolla(base, s.filter(ImageFilter.GaussianBlur(60)))
        c = strato(); dc = ImageDraw.Draw(c)
        dc.rounded_rectangle([x, y, x + w, y + h], radius=h // 2, fill=(120, 10, 110, 255))
        dc.rounded_rectangle([x + 18, y + 10, x + w - 18, y + h * 0.42], radius=h // 3, fill=(245, 90, 225, 200))
        c = c.rotate(ang, center=(x + w / 2, y + h / 2), resample=Image.BICUBIC)
        incolla(base, c, 6)
    return grana(base, 2.5, 5)


def argento():
    base = sfumatura([(0, (236, 239, 244)), (0.45, (166, 176, 192)), (0.7, (40, 52, 76)),
                      (1, (8, 14, 30))], 100).convert("RGBA")
    s = strato(); d = ImageDraw.Draw(s)
    d.ellipse([-900, 520, 2000, 2900], fill=(225, 230, 238, 200))
    incolla(base, s, 40)
    s = strato(); d = ImageDraw.Draw(s)
    d.ellipse([-900, 520, 2000, 2900], fill=(0, 0, 0, 0), outline=(255, 255, 255, 230), width=10)
    incolla(base, s, 6)
    # stella sottile a quattro punte (curve verso il centro)
    s = strato(); d = ImageDraw.Draw(s)
    cx, cy, r = 1720, 760, 520
    punti = []
    for k in range(4):
        a0 = math.radians(90 * k - 90)
        for t in [i / 40 for i in range(41)]:
            a = a0 + t * math.pi / 2
            rr = r * (1 - math.sin(t * math.pi) * 0.86)
            punti.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.line(punti + punti[:1], fill=(235, 240, 250, 210), width=3, joint="curve")
    incolla(base, s, 0.8)
    return grana(base, 2.0, 6)


SFONDI = {"sfera": sfera, "nuvole": nuvole, "cielo": cielo, "onde": onde, "magenta": magenta, "argento": argento}


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cartella = sys.argv[1]
    for nome in sys.argv[2:] or list(SFONDI):
        img = SFONDI[nome]().convert("RGB")
        img.save(f"{cartella}/vetro-{nome}.jpg", "JPEG", quality=88, optimize=True, progressive=True)
        print(f"  vetro-{nome}.jpg")


if __name__ == "__main__":
    main()
