#!/usr/bin/env python3
"""Scena „Las nad jeziorkiem" – pixel art 480x270, warstwy paralaksy.

Uruchom:  python3 grafika/narzedzia/scena_las.py
Wynik:    grafika/sceny/las_jeziorko/  (scena.png + warstwy/*.png)
          grafika/postacie/            (szkice sylwetek)
          grafika/podglady/            (powiększenia, siatka kompozycji, warstwy)

Zasady: tylko kolory z palety, bez wygładzania, miękkie przejścia wyłącznie ditheringiem.
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H = 480, 270
PALETA = ["#07080c", "#0d0f15", "#121926", "#1d2738", "#3b475a", "#6a7f99", "#d3dfea", "#ff8a3d"]
NOC, ZIE, TAF, BRZ, MGL, POS, KSI, AKC = range(8)
PUSTE = -1

_B = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
BY = (np.tile(_B, (H // 4 + 1, W // 4 + 1))[:H, :W] + 0.5) / 16
YY, XX = np.mgrid[0:H, 0:W]

KS_X, KS_Y, KS_R = 238, 42, 11          # księżyc: nad areną, między przeciwnikami
HORYZONT = 131                           # linia dalekiego brzegu jeziorka
# strona, z której przychodzi światło księżyca (dla obrysu): +1 z prawej, -1 z lewej
STRONA = np.where(np.abs(KS_X - XX) > 12, np.sign(KS_X - XX), 0)

KORZEN = Path(__file__).resolve().parents[1]


# ---------------------------------------------------------------- narzędzia
def warstwa():
    return np.full((H, W), PUSTE, np.int16)


def poloz(dst, src):
    m = src >= 0
    dst[m] = src[m]


def sasiad(m, dx, dy):
    """out[y, x] = m[y+dy, x+dx]; poza obrazem = False."""
    out = np.zeros_like(m)
    ys_d, ye_d = max(0, -dy), H - max(0, dy)
    xs_d, xe_d = max(0, -dx), W - max(0, dx)
    out[ys_d:ye_d, xs_d:xe_d] = m[ys_d + dy:ye_d + dy, xs_d + dx:xe_d + dx]
    return out


def kwantyzuj(I, tony, sila=0.55):
    n = len(tony)
    v = np.floor(I * (n - 0.6) + (BY - 0.5) * sila).astype(int)
    return np.array(tony)[np.clip(v, 0, n - 1)]


def szum(skala, ziarno):
    rng = np.random.default_rng(ziarno)
    gw, gh = W // skala + 3, H // skala + 3
    mal = Image.fromarray(rng.random((gh, gw)).astype(np.float32), "F")
    duz = mal.resize((gw * skala, gh * skala), Image.BILINEAR)
    return np.asarray(duz)[skala:skala + H, skala:skala + W]


def szum2(sx, sy, ziarno):
    rng = np.random.default_rng(ziarno)
    gw, gh = W // sx + 3, H // sy + 3
    mal = Image.fromarray(rng.random((gh, gw)).astype(np.float32), "F")
    duz = mal.resize((gw * sx, gh * sy), Image.BICUBIC)
    return np.clip(np.asarray(duz)[sy:sy + H, sx:sx + W], 0, 1)


SZUM_D = szum(14, 3)
SMUGI = szum2(40, 6, 5)
SMUGI2 = szum2(26, 4, 6)
SZUM_M = szum(5, 4)


def swiatlo(x):
    lx = max(-0.85, min(0.85, (KS_X - x) / 140))
    v = np.array([lx, -0.8, 0.5])
    return v / np.linalg.norm(v)


def obrys(m, I=None, prog=(0.0, 0.5)):
    """Krawędzie zwrócone do księżyca: (słabsze, mocniejsze)."""
    gora = m & ~sasiad(m, 0, -1)
    bok = m & (((STRONA > 0) & ~sasiad(m, 1, 0)) | ((STRONA < 0) & ~sasiad(m, -1, 0)))
    kr = gora | bok
    if I is None:
        return kr, kr & gora & bok
    return kr & (I > prog[0]), kr & (I > prog[1])


def maluj(buf, I, tony, obr=None, prog=(0.33, 0.6), sila=0.55):
    m = I >= 0
    out = np.where(m, kwantyzuj(np.clip(I, 0, 1), tony, sila), PUSTE)
    if obr:
        r1, r2 = obrys(m, I, prog)
        r1 &= SZUM_M > 0.3
        r2 &= (SZUM_M > 0.5) & (BY < 0.75)
        out[r1] = obr[0]
        out[r2] = obr[1]
    poloz(buf, out)


def stempel(I, x, y, r, val):
    if r < 0.8:
        xi, yi = int(x), int(y)
        if 0 <= xi < W and 0 <= yi < H and I[yi, xi] < 0:
            I[yi, xi] = val
        return
    x0, x1 = max(0, int(x - r) - 1), min(W, int(x + r) + 2)
    y0, y1 = max(0, int(y - r) - 1), min(H, int(y + r) + 2)
    if x0 >= x1 or y0 >= y1:
        return
    d2 = (XX[y0:y1, x0:x1] + 0.5 - x) ** 2 + (YY[y0:y1, x0:x1] + 0.5 - y) ** 2
    sub = I[y0:y1, x0:x1]
    sub[(d2 < r * r) & (sub < 0)] = val


# ---------------------------------------------------------------- korony z kępek liści
def _wpisz(Z, N, cx, cy, r, bias):
    x0, x1 = max(0, int(cx - r) - 1), min(W, int(cx + r) + 2)
    y0, y1 = max(0, int(cy - r) - 1), min(H, int(cy + r) + 2)
    if x0 >= x1 or y0 >= y1:
        return
    dx = XX[y0:y1, x0:x1] + 0.5 - cx
    dy = YY[y0:y1, x0:x1] + 0.5 - cy
    d2 = dx * dx + dy * dy
    zz = np.sqrt(np.maximum(r * r - d2, 0))
    z = zz + cy * bias
    upd = (d2 < r * r) & (z > Z[y0:y1, x0:x1])
    Z[y0:y1, x0:x1][upd] = z[upd]
    N[y0:y1, x0:x1][upd] = np.stack([dx / r, dy / r, zz / r], -1)[upd]


def korona(bloby, L, rnd, r_listka=(1.8, 3.4), dziury=()):
    Zg = np.full((H, W), -1e9); G = np.zeros((H, W, 3))
    Zl = np.full((H, W), -1e9); Lo = np.zeros((H, W, 3))
    for cx, cy, r in bloby:
        _wpisz(Zg, G, cx, cy, r * 1.35, 0.15)
    pole = sum(math.pi * r * r for _, _, r in bloby)
    n = int(pole / (math.pi * 2.6 ** 2) * 1.8) + 4
    wagi = [r * r for _, _, r in bloby]
    for _ in range(n):
        cx, cy, r = rnd.choices(bloby, wagi)[0]
        a = rnd.uniform(0, 2 * math.pi)
        d = math.sqrt(rnd.random()) * r * 1.1
        _wpisz(Zl, Lo, cx + math.cos(a) * d, cy + math.sin(a) * d, rnd.uniform(*r_listka), 0.05)
    m = Zl > -1e8
    for hx, hy, hr in dziury:
        m &= (XX + 0.5 - hx) ** 2 + (YY + 0.5 - hy) ** 2 >= hr * hr
    ig = np.clip(G @ L, 0, 1)
    il = np.clip(Lo @ L, 0, 1)
    i = ig * (0.45 + 0.75 * il) * (0.8 + 0.4 * SZUM_M)
    gora = min(cy - r for _, cy, r in bloby)
    dol = max(cy + r for _, cy, r in bloby)
    ao = np.clip((dol - YY) / max(1, dol - gora) * 1.4, 0.3, 1.0)
    return m, i * ao, dol


# ---------------------------------------------------------------- drzewa
def drzewo(x0, podstawa, wys, grub, pochyl=0.0, seed=0, liscie=True, r_korony=20,
           galezie=None, n_galezi=5, poziomy=2, rozpiecie=1.0, korzenie=True, jasnosc=1.0):
    """Drzewo liściaste albo martwe. Zwraca mapę jasności (-1 = puste)."""
    rnd = random.Random(seed)
    L = swiatlo(x0)
    I = np.full((H, W), -1.0)
    U = np.full((H, W), 9.0)
    Pw = np.ones((H, W))
    N = int(wys * 2) + 1
    pkt = []
    for i in range(N + 1):
        t = i / N
        y = podstawa - t * wys
        x = x0 + pochyl * wys * t ** 1.5 + math.sin(t * 5 + seed) * grub * 0.12
        w = grub * (1 - 0.5 * t) * (1 + 1.2 * (1 - t) ** 10)
        pkt.append((x, y, w))
        r = int(math.floor(y))
        if 0 <= r < H:
            for px in range(int(x - w / 2) - 1, int(x + w / 2) + 2):
                if 0 <= px < W:
                    u = (px + 0.5 - x) / (w / 2)
                    if abs(u) <= 1 and abs(u) < abs(U[r, px]):
                        U[r, px] = u
                        Pw[r, px] = w / 2
    tm = U <= 1
    u = U[tm]
    nz = np.sqrt(1 - u * u)
    it = np.clip(u * L[0] * 1.1 + nz * L[2] * 0.6 + 0.05, 0, 1)
    if grub >= 6:  # bruzdy kory – pasma jak na szkicu
        yv = YY[tm]
        pw = Pw[tm]
        for c in (-0.5, 0.02, 0.48):
            g = c + 0.12 * np.sin(yv * 0.11 + c * 7 + seed)
            it = np.where(np.abs(u - g) < 0.6 / pw, it * 0.3, it)
    I[tm] = it * 0.8

    konce = []

    def galaz(x, y, kat, dl, gr, poz):
        kroki = max(2, int(dl * 1.5))
        for s in range(kroki):
            x += math.sin(kat) * 0.67
            y -= math.cos(kat) * 0.67
            kat += rnd.uniform(-0.09, 0.09)
            if not liscie:
                kat += 0.012 * (1 if kat > 0 else -1)
            stempel(I, x, y, max(0.5, gr * (1 - 0.55 * s / kroki)), 0.32)
        konce.append((x, y))
        if poz > 0:
            for zn in (-1, 1):
                galaz(x, y, kat + zn * rnd.uniform(0.25, 0.65), dl * rnd.uniform(0.5, 0.72),
                      gr * 0.6, poz - 1)

    if galezie is None:
        galezie = []
        for k in range(n_galezi):
            st = 1 if k % 2 else -1
            galezie.append((rnd.uniform(0.6, 0.97), st * rnd.uniform(0.35, 1.0) * rozpiecie,
                            r_korony * rnd.uniform(0.7, 1.3), poziomy))
        galezie.append((1.0, pochyl * 2, r_korony * 0.6, poziomy))
    for t, kat, dl, poz in galezie:
        x, y, w = pkt[min(N, int(t * N))]
        galaz(x, y, kat, dl, max(0.6, w * 0.38), poz)

    if korzenie:
        for k in range(rnd.randint(2, 4)):
            st = -1 if k % 2 == 0 else 1
            sx, sy = x0 + st * grub * 0.2, podstawa - 3
            ex = x0 + st * grub * rnd.uniform(0.9, 1.7)
            for s in range(20):
                t = s / 19
                stempel(I, sx + (ex - sx) * t, sy + 4 * t * t, grub * 0.2 * (1 - t) + 0.5, 0.28)

    if liscie and konce:
        bloby = [(ex, ey, r_korony * rnd.uniform(0.42, 0.68)) for ex, ey in konce]
        tx, ty, _ = pkt[-1]
        bloby.append((tx, ty, r_korony * 0.75))
        dz = [(rnd.choice(bloby)[0] + rnd.uniform(-6, 6), max(b[1] for b in bloby) + rnd.uniform(-2, 4),
               rnd.uniform(1.6, 2.8)) for b in range(2)]
        m, ik, dol = korona(bloby, L, rnd, dziury=dz)
        I[m] = ik[m]
        # pod koroną pień w cieniu
        cien = tm & ~m & (YY < dol + 28)
        I[cien] *= np.clip((YY[cien] - dol) / 28, 0.25, 1.0)
    I[I >= 0] = np.clip(I[I >= 0] * jasnosc, 0, 1)
    return I


def swierk(x0, podstawa, wys, szer, seed=0, jasnosc=1.0):
    rnd = random.Random(seed)
    L = swiatlo(x0)
    I = np.full((H, W), -1.0)
    gora = podstawa - wys
    pietra = max(3, int(wys / 9))
    for y in range(max(0, int(gora)), min(H, int(podstawa))):
        t = (y - gora) / wys
        p = (t * pietra) % 1
        half = szer / 2 * (0.08 + 0.92 * t) * (0.5 + 0.5 * p ** 0.7) + rnd.uniform(-0.9, 0.9)
        if t > 0.94:
            half = max(1.0, szer * 0.06)
        for x in range(int(x0 - half), int(x0 + half) + 1):
            if 0 <= x < W:
                u = (x + 0.5 - x0) / max(half, 1)
                i = 0.3 + 0.5 * u * np.sign(L[0]) * min(1, abs(L[0]) * 2) + (0.25 if p < 0.3 else 0)
                I[y, x] = max(0.0, min(1.0, i * jasnosc))
    return I


def krzak(x, y, r, seed, jasnosc=1.0):
    rnd = random.Random(seed)
    bloby = [(x + rnd.uniform(-r, r), y - rnd.uniform(0, r * 0.6), r * rnd.uniform(0.5, 0.8))
             for _ in range(3)]
    m, i, _ = korona(bloby, swiatlo(x), rnd, r_listka=(1.4, 2.6))
    I = np.full((H, W), -1.0)
    I[m] = np.clip(i[m] * jasnosc, 0, 1)
    return I


def pnacze(buf, x, y, dl, kolor, seed):
    rnd = random.Random(seed)
    for s in range(int(dl)):
        xx = int(x + math.sin(s * 0.25 + seed) * 1.2)
        yy = int(y + s)
        if 0 <= xx < W and 0 <= yy < H:
            buf[yy, xx] = kolor
            if rnd.random() < 0.25 and 0 <= xx + 1 < W:
                buf[yy, xx + rnd.choice((-1, 1))] = kolor


# ---------------------------------------------------------------- teren
def ziemia_gry(x):
    """Wysokość ziemi, po której chodzą postacie."""
    if x < 156:
        return 188
    if x > 246:
        return 205
    t = (x - 156) / 90
    return 188 + 17 * t * t * (3 - 2 * t)


def brzeg_bliski(x):
    return 186 + 1.5 * math.sin(x * 0.05) + 1.0 * math.sin(x * 0.17)


def w_jeziorku():
    cx, cy, rx, ry = 325, 158.5, 134, 28
    m = (np.abs((XX + 0.5 - cx) / rx) ** 5 + np.abs((YY + 0.5 - cy) / ry) ** 5) <= 1
    m &= YY > HORYZONT
    bl = np.array([brzeg_bliski(x) for x in range(W)])
    m &= YY < bl[None, :]
    return m


# ---------------------------------------------------------------- warstwy
def niebo():
    b = warstwa()
    d = np.hypot(XX - KS_X, (YY - KS_Y) * 1.25)
    v = np.clip(YY / 135, 0, 1) * 1.7 + 2.4 * np.exp(-d / 34) + 1.0 * np.exp(-d / 110)
    v = np.floor(v + (BY - 0.5) * 0.9)
    b[:] = np.array([NOC, ZIE, TAF, BRZ, MGL])[np.clip(v, 0, 4).astype(int)]
    # smuga chmur przecinająca dolną część tarczy
    pas = np.exp(-((YY - (KS_Y + 8 + 0.05 * (XX - KS_X))) / 5.0) ** 2) * np.exp(-((XX - KS_X) / 120) ** 2)
    chm = SMUGI * pas
    b[(chm > 0.32) & (BY < (chm - 0.32) * 4)] = BRZ
    # księżyc
    tarcza = (XX + 0.5 - KS_X) ** 2 + (YY + 0.5 - KS_Y) ** 2 < KS_R ** 2
    b[tarcza] = KSI
    for mx, my, mr in ((-3, -3, 3.2), (4, 2, 2.4), (-1, 5, 1.6)):
        b[tarcza & ((XX + 0.5 - KS_X - mx) ** 2 + (YY + 0.5 - KS_Y - my) ** 2 < mr * mr) & (BY < 0.6)] = POS
    b[tarcza & (chm > 0.4) & (BY < 0.5)] = POS
    # gwiazdy z dala od księżyca
    rnd = random.Random(11)
    for _ in range(38):
        x, y = rnd.randrange(W), rnd.randrange(0, 95)
        if math.hypot(x - KS_X, y - KS_Y) > 70 and b[y, x] <= ZIE:
            b[y, x] = rnd.choice((BRZ, BRZ, MGL, MGL, POS))
    return b


def las_daleki():
    b = warstwa()
    rnd = random.Random(21)
    x = -6
    while x < W + 6:
        if rnd.random() < 0.7:
            I = swierk(x, HORYZONT + 1, rnd.uniform(22, 58), rnd.uniform(11, 20), seed=int(x) + 100)
        else:
            I = krzak(x, HORYZONT - 6, rnd.uniform(7, 12), int(x) + 200)
        maluj(b, I, [TAF, BRZ], obr=(BRZ, MGL), prog=(0.2, 0.55))
        x += rnd.uniform(7, 17)
    b[HORYZONT - 2:HORYZONT + 1, :][b[HORYZONT - 2:HORYZONT + 1, :] < 0] = TAF
    return b


def mgla_daleka():
    b = warstwa()
    gest = 0.55 * np.exp(-((YY - 127) / 8.0) ** 2) * np.clip((SMUGI - 0.2) * 2.2, 0, 1.4)
    gest = np.select([gest > 0.4, gest > 0.22, gest > 0.1], [0.5, 0.25, 0.125], 0)
    b[(BY < gest) & (YY < HORYZONT + 3)] = MGL
    return b


def plan_daleki():
    """Drzewa za jeziorkiem i łąka, która odchodzi w głąb."""
    b = warstwa()
    # łąka / dalsze dno lasu: im dalej, tym jaśniej (mgła)
    I = np.full((H, W), -1.0)
    teren = YY >= HORYZONT
    I[teren] = np.clip(0.85 - (YY[teren] - HORYZONT) / 85, 0.1, 0.8) * (0.85 + 0.3 * SZUM_M[teren])
    maluj(b, I, [ZIE, TAF, BRZ], sila=0.8)
    obiekty = [
        drzewo(290, HORYZONT + 1, 114, 5, pochyl=0.03, seed=31, r_korony=16, poziomy=2),
        swierk(318, HORYZONT + 2, 48, 18, seed=32),
        drzewo(352, HORYZONT + 2, 118, 7, pochyl=-0.03, seed=33, r_korony=22, poziomy=2),
        swierk(408, HORYZONT + 2, 92, 30, seed=34),
        swierk(190, HORYZONT + 2, 66, 24, seed=35),
        drzewo(222, HORYZONT + 1, 70, 3, pochyl=0.05, seed=36, liscie=False, n_galezi=4, poziomy=2,
               r_korony=12, korzenie=False),
    ]
    for I in obiekty:
        maluj(b, I, [ZIE, TAF, BRZ], obr=(BRZ, MGL), prog=(0.25, 0.6))
    for x, s in ((246, 1), (288, 2), (330, 3), (380, 4), (440, 5), (160, 6)):
        maluj(b, krzak(x, HORYZONT + 1, 6, s), [ZIE, TAF, BRZ], obr=(BRZ, MGL), prog=(0.3, 0.6))
    return b


def jezioro(tlo):
    """Woda odbija to, co jest za nią (o ton ciemniej) + ścieżka księżyca."""
    b = warstwa()
    m = w_jeziorku()
    rnd = random.Random(41)
    for y in range(HORYZONT + 1, H):
        rz = m[y]
        if not rz.any():
            continue
        sy = 2 * HORYZONT - y
        fala = int(round(1.4 * math.sin(y * 0.9))) if y % 2 else 0
        for x in np.nonzero(rz)[0]:
            sx = min(W - 1, max(0, x + fala))
            c = tlo[sy, sx] if 0 <= sy < H else NOC
            c = POS if c == AKC else c
            b[y, x] = max(ZIE, c - 1)
        # zmarszczki na wodzie
        for _ in range(3):
            x = rnd.randrange(190, 460)
            dl = rnd.randint(2, 7)
            for xx in range(x, x + dl):
                if 0 <= xx < W and rz[xx] and rnd.random() < 0.8:
                    b[y, xx] = BRZ if b[y, xx] < BRZ else MGL
    # jasna linia styku wody z dalekim brzegiem
    for x in range(W):
        if m[HORYZONT + 1, x] and BY[HORYZONT + 1, x] < 0.6:
            b[HORYZONT + 1, x] = MGL
    # ścieżka księżyca – w grze: puls tempa
    for y in range(HORYZONT + 2, H):
        k = y - HORYZONT
        if y % 2 and rnd.random() < 0.6:
            continue
        pol = 3 + k * 0.42
        for x in range(int(KS_X - pol), int(KS_X + pol) + 1):
            if not (0 <= x < W and m[y, x]):
                continue
            d = abs(x + 0.5 - KS_X) / pol
            szansa = 0.95 - d * 0.6 - k / 140
            if ((x // 2 + y * 3) % 5 == 0) or rnd.random() > szansa:
                continue
            b[y, x] = KSI if (d < 0.18 and k < 26 and y % 2 == 0) else (POS if d < 0.55 else MGL)
    return b


def snopy():
    b = warstwa()
    cele = [(140, 200, 5), (196, 210, 7), (286, 210, 6), (338, 200, 4)]
    for tx, ty, sz in cele:
        dx, dy = tx - KS_X, ty - KS_Y
        dl = math.hypot(dx, dy)
        ux, uy = dx / dl, dy / dl
        px, py = XX + 0.5 - KS_X, YY + 0.5 - KS_Y
        t = (px * ux + py * uy) / dl
        prost = np.abs(px * -uy + py * ux)
        w = 1.5 + sz * t
        gest = 0.13 * np.clip(1 - t, 0, 1) * np.clip((t - 0.12) * 6, 0, 1)
        b[(t > 0) & (t < 1) & (prost < w) & (BY < gest)] = MGL
    return b


def las_sredni():
    b = warstwa()
    T = [NOC, ZIE, TAF, BRZ]
    obiekty = [
        drzewo(64, 176, 150, 18, pochyl=0.02, seed=51, r_korony=34, n_galezi=6, poziomy=2, jasnosc=1.25),
        drzewo(26, 170, 124, 8, pochyl=0.05, seed=52, r_korony=19, n_galezi=5, poziomy=2, jasnosc=1.2),
        drzewo(458, 197, 168, 20, pochyl=-0.03, seed=53, r_korony=34, n_galezi=6, poziomy=2, jasnosc=1.25),
    ]
    for I in obiekty:
        maluj(b, I, T, obr=(MGL, POS), prog=(0.33, 0.62))
    for x, y, r, s in ((196, 176, 6, 62), (40, 178, 9, 63), (436, 192, 8, 64)):
        maluj(b, krzak(x, y, r, s), T, obr=(MGL, POS), prog=(0.33, 0.62))
    for x, y, dl, s in ((52, 22, 34, 1), (80, 30, 22, 2), (444, 26, 40, 3), (474, 34, 26, 4), (30, 34, 18, 5)):
        pnacze(b, x, y, dl, ZIE, s)
    return b


def mgla_niska():
    b = warstwa()
    gest = 0.3 * np.exp(-((YY - 181) / 7.0) ** 2) * np.clip((SMUGI2 - 0.35) * 2.5, 0, 1.3)
    gest = np.select([gest > 0.2, gest > 0.09], [0.25, 0.125], 0)
    b[(BY < gest * 0.45)] = MGL
    b[(BY >= gest * 0.45) & (BY < gest)] = BRZ
    return b


def ziemia():
    b = warstwa()
    rnd = random.Random(71)
    jez = w_jeziorku()
    # trzciny na bliskim brzegu jeziorka
    for x in range(196, 458, 2):
        if rnd.random() < 0.55:
            y0 = int(brzeg_bliski(x)) + rnd.randint(0, 3)
            h = rnd.randint(4, 15)
            pochyl = rnd.uniform(-0.25, 0.25)
            for s in range(h):
                xx, yy = int(x + pochyl * s), y0 - s
                if 0 <= xx < W and 0 <= yy < H:
                    b[yy, xx] = (MGL if STRONA[yy, xx] else BRZ) if s == h - 1 else ZIE
            if rnd.random() < 0.15:
                xx = int(x + pochyl * (h - 2))
                for yy in range(y0 - h - 2, y0 - h + 3):
                    for dx in (0, 1):
                        if 0 <= yy < H and 0 <= xx + dx < W:
                            b[yy, xx + dx] = NOC
    # ziemia, po której walczą postacie
    gy = np.array([ziemia_gry(x) for x in range(W)])
    gr = YY >= gy[None, :]
    b[gr] = NOC
    b[gr & (YY < gy[None, :] + 2) & (BY < 0.5)] = ZIE
    # kępki trawy wzdłuż krawędzi
    for x in range(W):
        if rnd.random() < 0.6:
            h = rnd.choice((1, 2, 2, 3, 4, 5))
            nach = rnd.choice((-1, 0, 0, 1))
            for s in range(h):
                xx, yy = x + (nach if s > h // 2 else 0), int(gy[x]) - 1 - s
                if 0 <= xx < W and 0 <= yy < H:
                    blisko = abs(xx - KS_X) < 150
                    b[yy, xx] = (MGL if blisko and rnd.random() < 0.5 else TAF) if s == h - 1 else NOC
    # kamienie i korzenie w ziemi
    gl = YY - gy[None, :]
    b[gr & (gl >= 2) & (BY < 0.4 * np.exp(-gl / 9.0) * (0.5 + SZUM_M))] = ZIE
    return b


# ---------------------------------------------------------------- postacie (szkice sylwetek)
def cieniuj_sylwetke(m, b):
    b[m] = NOC
    # odbite światło w głąb sylwetki (dithering)
    gl2 = m & (~sasiad(m, 0, -2) | ((STRONA > 0) & ~sasiad(m, 2, 0)) | ((STRONA < 0) & ~sasiad(m, -2, 0)))
    b[gl2 & (BY < 0.5)] = ZIE
    r1, r2 = obrys(m)
    b[r1] = MGL
    b[r2] = POS


def przyjaciel():
    """Przyjaciel bohatera: kaptur, płaszcz, ostrze uniesione do ciosu. Wys. ok. 50 px."""
    im = Image.new("1", (W, H), 0)
    d = ImageDraw.Draw(im)
    gy = 187
    d.line([(132, 168), (142, 177), (146, gy)], fill=1, width=5)     # noga przednia
    d.line([(145, gy), (151, gy)], fill=1, width=2)
    d.line([(127, 168), (119, 178), (110, gy)], fill=1, width=5)     # noga zakroczna
    d.line([(105, gy), (111, gy)], fill=1, width=2)
    d.polygon([(123, 169), (138, 169), (143, 153), (126, 149)], fill=1)  # tułów
    d.polygon([(127, 151), (120, 156), (109, 163), (100, 172), (106, 170), (103, 177), (110, 172),
               (113, 179), (117, 172), (123, 174), (128, 166)], fill=1)  # płaszcz
    d.ellipse((131, 139, 141, 150), fill=1)                              # głowa
    d.polygon([(132, 141), (126, 137), (121, 134), (124, 140), (128, 145)], fill=1)  # szpic kaptura
    d.line([(131, 151), (121, 149), (113, 152), (104, 149)], fill=1, width=2)  # szal
    d.line([(139, 154), (146, 159), (152, 156)], fill=1, width=3)        # ręka z ostrzem
    d.line([(128, 154), (120, 160), (114, 158)], fill=1, width=2)        # druga ręka
    m = np.array(im, bool)
    b = warstwa()
    cieniuj_sylwetke(m, b)
    # ostrze: jasna stal + pomarańczowy błysk przed ciosem (akcent)
    pts = []
    x0, y0, x1, y1 = 153, 155, 171, 137
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        pts.append((round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)))
    for i, (x, y) in enumerate(pts):
        b[y, x] = POS if i > 2 else MGL
        if i > 2:
            b[y + 1, x] = NOC
    tx, ty = pts[-1]
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (0, -2), (-2, 0), (0, 2)):
        b[ty + dy, tx + dx] = AKC
    b[ty, tx] = KSI
    b[pts[-2][1], pts[-2][0]] = AKC
    return b, m


def bestia():
    """Przeciwnik: ogromny dzik-bestia ze szczeciną na grzbiecie, zwrócony w lewo."""
    rnd = random.Random(81)
    im = Image.new("1", (W, H), 0)
    d = ImageDraw.Draw(im)
    cialo = [(282, 174), (283, 181), (290, 184), (300, 184), (310, 183), (325, 185), (345, 186),
             (370, 186), (400, 185), (420, 183), (429, 178), (433, 170), (433, 160), (429, 152),
             (421, 145), (410, 140), (395, 137), (378, 135), (362, 132), (348, 131), (334, 134),
             (322, 140), (312, 147), (304, 153), (297, 160), (290, 166), (285, 170)]
    d.polygon(cialo, fill=1)
    d.polygon([(309, 151), (314, 139), (320, 147)], fill=1)                 # ucho
    for (a, bb, c, w1, w2) in (((316, 183), (312, 195), (314, 203), 7, 5),
                               ((331, 183), (334, 195), (330, 203), 6, 4),
                               ((404, 180), (413, 193), (409, 203), 9, 5),
                               ((420, 178), (427, 192), (424, 203), 7, 4)):
        d.line([a, bb], fill=1, width=w1)
        d.line([bb, c], fill=1, width=w2)
        d.rectangle((c[0] - 2, c[1], c[0] + 2, 205), fill=1)              # racice
    d.line([(432, 156), (438, 160), (437, 167)], fill=1, width=1)        # ogon
    m = np.array(im, bool)
    # szczecina na grzbiecie – najgęstsza na karku
    for x in range(300, 428, 2):
        kol = m[:, x]
        if not kol.any():
            continue
        top = int(np.argmax(kol))
        garb = math.exp(-((x - 340) / 32) ** 2)
        h = 2 + 7 * garb * rnd.uniform(0.5, 1.0) + rnd.uniform(0, 2)
        d.line([(x, top + 1), (x + rnd.uniform(1, 4), top - h)], fill=1, width=1)
    for x in range(296, 428, 3):
        kol = m[:, x]
        if not kol.any():
            continue
        dol = int(H - 1 - np.argmax(kol[::-1]))
        if dol > 190:
            continue
        d.line([(x, dol - 1), (x - rnd.uniform(0, 2), dol + rnd.uniform(1, 4))], fill=1, width=1)
    m = np.array(im, bool)
    b = warstwa()
    cieniuj_sylwetke(m, b)
    # kły w świetle księżyca
    for i, (x, y) in enumerate([(289, 181), (288, 180), (287, 179), (286, 178), (285, 176),
                                (284, 175), (284, 174), (284, 173)]):
        b[y, x] = KSI if i >= 6 else POS
        if i < 6:
            b[y, x + 1] = MGL
    b[163, 300] = KSI                                                     # oko
    b[163, 301] = POS
    # para z pyska
    para = ((XX - 274) ** 2 / 90 + (YY - 177) ** 2 / 20 < 1) & (BY < 0.22 * np.clip((XX - 262) / 18, 0, 1))
    b[para & (b < 0)] = MGL
    return b, m


# ---------------------------------------------------------------- pierwszy plan
def kepa_trawy(buf, x, y, n, wys, rozrzut, seed):
    """Kępa wysokich, wygiętych źdźbeł na pierwszym planie."""
    rnd = random.Random(seed)
    kr = np.zeros((H, W), bool)
    for _ in range(n):
        h = rnd.uniform(*wys)
        x0 = x + rnd.uniform(-rozrzut, rozrzut)
        zgiecie = rnd.uniform(-0.9, 0.9) * h * 0.45
        kroki = int(h * 1.5)
        for i in range(kroki):
            t = i / kroki
            px = x0 + zgiecie * t * t
            py = y - h * t + abs(zgiecie) * 0.25 * t ** 3
            gr = 2 if t < 0.45 else 1
            for g in range(gr):
                xi, yi = int(px) + g, int(py)
                if 0 <= xi < W and 0 <= yi < H:
                    kr[yi, xi] = True
    buf[kr] = NOC
    r1, _ = obrys(kr)
    buf[r1 & (BY < 0.7)] = TAF
    buf[r1 & (SZUM_M > 0.6)] = BRZ
    return kr


def pierwszy_plan():
    b = warstwa()
    # ogromny pień przy lewej krawędzi – rama kadru
    I = drzewo(4, 280, 300, 34, pochyl=0.0, seed=91, liscie=False, galezie=[], korzenie=True)
    maluj(b, I, [NOC], obr=(TAF, BRZ), prog=(0.3, 0.75))
    # martwe drzewo z prawej: gałąź nad kadrem
    I = drzewo(492, 280, 280, 26, seed=92, liscie=False, korzenie=False, poziomy=3,
               galezie=[(0.78, -1.15, 70, 3), (0.62, -1.35, 40, 2), (0.9, -0.8, 50, 3)])
    maluj(b, I, [NOC], obr=(TAF, BRZ), prog=(0.2, 0.7))
    # trawa na dole
    # zwalony pień przy dolnej krawędzi
    pn = ((XX - 262) / 96.0) ** 2 + ((YY - 276) / 26.0) ** 2 < 1
    pn |= ((XX - 330) ** 2 / 12 + (YY - 252) ** 2 / 60 < 1)                 # złamany konar
    pn &= ~(((XX - 172) ** 2 + (YY - 268) ** 2) < 70)
    b[pn] = NOC
    r1, r2 = obrys(pn)
    b[r1] = TAF
    b[r1 & (SZUM_M > 0.45)] = BRZ
    b[pn & sasiad(r1, 0, -1) & (BY < 0.5)] = ZIE
    # korzenie olbrzymiego pnia pełzną po ziemi
    for y0, y1, x1, gr, s in ((236, 214, 150, 3.2, 1), (250, 236, 120, 2.6, 2), (226, 210, 70, 2.0, 3)):
        I = np.full((H, W), -1.0)
        for i in range(160):
            t = i / 159
            stempel(I, 14 + (x1 - 14) * t, y0 + (y1 - y0) * t + 2.5 * math.sin(t * 9 + s),
                    gr * (1 - 0.6 * t) + 0.4, 0.5)
        maluj(b, I, [NOC], obr=(TAF, BRZ), prog=(0.2, 0.9))
    for x, y, n, wys, rz, s in ((10, 272, 26, (16, 52), 14, 1), (64, 272, 14, (10, 30), 10, 2),
                                (462, 272, 24, (16, 56), 16, 3), (404, 274, 12, (8, 26), 8, 4),
                                (200, 274, 8, (6, 16), 10, 5)):
        kepa_trawy(b, x, y, n, wys, rz, s)
    rnd = random.Random(93)
    for x in list(range(0, 110)) + list(range(400, 480)):
        if rnd.random() < 0.35:
            h = rnd.randint(4, 20)
            nach = rnd.uniform(-0.4, 0.4)
            for s in range(h):
                xi, yi = int(x + nach * s), H - 1 - s
                if 0 <= xi < W:
                    b[yi, xi] = TAF if s == h - 1 and rnd.random() < 0.5 else NOC
    return b


# ---------------------------------------------------------------- zapis
RGB = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in PALETA], np.uint8)


def na_obraz(b):
    out = np.zeros((H, W, 4), np.uint8)
    m = b >= 0
    out[m, :3] = RGB[b[m]]
    out[m, 3] = 255
    return Image.fromarray(out, "RGBA")


def main():
    cel = KORZEN / "sceny" / "las_jeziorko"
    (cel / "warstwy").mkdir(parents=True, exist_ok=True)
    (KORZEN / "postacie").mkdir(exist_ok=True)
    (KORZEN / "podglady").mkdir(exist_ok=True)

    warstwy = [("0_niebo", niebo()), ("1_las_daleki", las_daleki()), ("2_mgla_daleka", mgla_daleka()),
               ("3_plan_daleki", plan_daleki())]
    tlo = warstwa()
    for _, w in warstwy:
        poloz(tlo, w)
    warstwy += [("4_jeziorko", jezioro(tlo)), ("5_snopy_swiatla", snopy()), ("6_las_sredni", las_sredni()),
                ("7_mgla_niska", mgla_niska()), ("8_ziemia", ziemia())]
    przyj, _ = przyjaciel()
    best, _ = bestia()
    postacie = warstwa()
    poloz(postacie, best)
    poloz(postacie, przyj)
    warstwy += [("9_postacie", postacie), ("10_pierwszy_plan", pierwszy_plan())]

    scena = warstwa()
    for nazwa, w in warstwy:
        poloz(scena, w)
        na_obraz(w).save(cel / "warstwy" / f"{nazwa}.png")
    obraz = na_obraz(scena)
    obraz.save(cel / "scena.png")
    obraz.resize((W * 3, H * 3), Image.NEAREST).save(KORZEN / "podglady" / "las_scena_x3.png")
    for nazwa, b in (("przyjaciel_szkic", przyj), ("bestia_szkic", best)):
        im = na_obraz(b)
        im.crop(im.getbbox()).save(KORZEN / "postacie" / f"{nazwa}.png")

    # --- siatka kompozycji
    S = 2
    pod = obraz.resize((W * S, H * S), Image.NEAREST).convert("RGBA")
    nak = Image.new("RGBA", pod.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(nak)
    try:
        f = ImageFont.truetype("DejaVuSans.ttf", 15)
        fm = ImageFont.truetype("DejaVuSans.ttf", 13)
    except OSError:
        f = fm = ImageFont.load_default()
    bialy = (255, 255, 255, 150)
    for k in (1, 2):
        for xx in range(0, W * S, 12):
            d.line([(xx, H * S * k // 3), (xx + 6, H * S * k // 3)], fill=bialy, width=1)
        for yy in range(0, H * S, 12):
            d.line([(W * S * k // 3, yy), (W * S * k // 3, yy + 6)], fill=bialy, width=1)
    pasy = [(0, 60, "TŁO: niebo, księżyc"), (95, HORYZONT, "PLAN DALEKI: las w mgle"),
            (HORYZONT, 186, "JEZIORKO + plan średni"), (186, 206, "PLAN GRY: tu walczą postacie"),
            (206, H, "PIERWSZY PLAN: ciemne ramy")]
    for y0, y1, tekst in pasy:
        d.line([(W * S - 10, y0 * S + 3), (W * S - 10, y1 * S - 3)], fill=(255, 138, 61, 230), width=3)
        tw = d.textlength(tekst, font=fm)
        ty = (y0 + y1) * S // 2 - 8
        d.rectangle((W * S - 22 - tw - 8, ty - 3, W * S - 18, ty + 17), fill=(0, 0, 0, 170))
        d.text((W * S - 22 - tw - 4, ty), tekst, font=fm, fill=(255, 255, 255, 255))
    for (cx, cy, r, tekst) in ((171, 137, 9, "1. błysk ostrza"), (KS_X, KS_Y, 17, "2. księżyc"),
                               (300, 163, 9, "3. oko bestii")):
        d.ellipse(((cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S), outline=(255, 138, 61, 255), width=2)
        d.rectangle(((cx + r) * S + 4, cy * S - 10, (cx + r) * S + 10 + d.textlength(tekst, font=f), cy * S + 10),
                    fill=(0, 0, 0, 170))
        d.text(((cx + r) * S + 7, cy * S - 9), tekst, font=f, fill=(255, 255, 255, 255))
    pod.alpha_composite(nak)
    pod.save(KORZEN / "podglady" / "las_kompozycja.png")

    # --- wszystkie warstwy obok siebie
    kol, sk = 4, 1
    rz = math.ceil(len(warstwy) / kol)
    arkusz = Image.new("RGBA", (kol * (W + 10) + 10, rz * (H + 34) + 10), (40, 40, 48, 255))
    d = ImageDraw.Draw(arkusz)
    for i, (nazwa, w) in enumerate(warstwy):
        x, y = 10 + (i % kol) * (W + 10), 10 + (i // kol) * (H + 34)
        sz = Image.new("RGBA", (W, H), (70, 70, 80, 255))
        szach = ((XX // 8 + YY // 8) % 2 == 0)
        a = np.asarray(sz).copy()
        a[szach] = (90, 90, 100, 255)
        sz = Image.fromarray(a, "RGBA")
        sz.alpha_composite(na_obraz(w))
        arkusz.paste(sz, (x, y + 24))
        d.text((x, y + 2), nazwa, font=f, fill=(255, 255, 255, 255))
    arkusz.save(KORZEN / "podglady" / "las_warstwy.png")
    print("gotowe:", cel)


if __name__ == "__main__":
    main()
