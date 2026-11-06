"""Generator pixel-artowego drzewa (sylwetka w świetle księżyca).

Uruchom:  python3 grafika/narzedzia/drzewo.py
Wynik:    grafika/otoczenie/drzewo.png (128x128, tylko kolory z palety, przezroczyste tło)
"""
import math, random
from pathlib import Path
from PIL import Image

W, H = 128, 128
random.seed(7)

# Paleta gry (od najciemniejszego)
NOC, ZIEMIA, TAFLA, BRZEG, MGLA, POSWIATA, KSIEZYC = (
    "#07080c", "#0d0f15", "#121926", "#1d2738", "#3b475a", "#6a7f99", "#d3dfea")
POZIOMY = [NOC, ZIEMIA, TAFLA, BRZEG, MGLA]  # cieniowanie bryły; POSWIATA tylko na obrysie

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
def bayer(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0

# Księżyc z góry po prawej
L = (0.55, -0.65, 0.52)
n = math.sqrt(sum(c * c for c in L)); L = tuple(c / n for c in L)

# Szum wartościowy do faktury liści
def siatka_szumu(skala, ziarno):
    rnd = random.Random(ziarno)
    g = {}
    def v(ix, iy):
        if (ix, iy) not in g: g[(ix, iy)] = rnd.random()
        return g[(ix, iy)]
    def f(x, y):
        fx, fy = x / skala, y / skala
        ix, iy = math.floor(fx), math.floor(fy)
        tx, ty = fx - ix, fy - iy
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = v(ix, iy) * (1 - tx) + v(ix + 1, iy) * tx
        b = v(ix, iy + 1) * (1 - tx) + v(ix + 1, iy + 1) * tx
        return a * (1 - ty) + b * ty
    return f
szum_duzy = siatka_szumu(6, 1)
szum_maly = siatka_szumu(2.5, 2)

# ---------- KORONA: kępy liści jako kule (kształt z oryginalnego szkicu) ----------
kepy = [  # (x, y, promień)
    (33, 24, 14), (54, 15, 13), (75, 14, 12), (96, 21, 14), (108, 38, 12),
    (99, 51, 12), (24, 42, 13), (37, 54, 10), (58, 33, 21), (82, 35, 20),
    (48, 49, 13), (72, 52, 11), (86, 54, 9), (60, 56, 8),
]
kepy = [(x, y, r * 0.88) for x, y, r in kepy]
duze = list(kepy)
# drobne kępki liści: na brzegu tworzą postrzępiony obrys, w środku fakturę
listki = []
for _ in range(900):
    k = random.choice(duze)
    a = random.uniform(0, 2 * math.pi)
    d = math.sqrt(random.random()) * k[2] * 1.12
    listki.append((k[0] + math.cos(a) * d, k[1] + math.sin(a) * d, random.uniform(1.8, 3.6)))
# prześwity w dolnej części korony (widać przez nie gałęzie i niebo)
dziury = [(64, 61, 2.4), (88, 61, 2.0)]

def najwyzsza(x, y, zbior, waga):
    best = None
    for cx, cy, r in zbior:
        dx, dy = x + 0.5 - cx, y + 0.5 - cy
        d2 = dx * dx + dy * dy
        if d2 < r * r:
            z = math.sqrt(r * r - d2)
            h = z + cy * waga
            if best is None or h > best[0]:
                best = (h, (dx / r, dy / r, z / r))
    return best

def korona(x, y):
    """Zwraca (globalna normalna bryły, lokalna normalna listka) albo None."""
    for cx, cy, r in dziury:
        if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 < r * r:
            return None
    g = najwyzsza(x, y, kepy, 0.15)
    l = najwyzsza(x, y, listki, 0.05)
    if l is None:
        return None  # obrys korony wyznaczają listki
    if g is None:  # listek wystający poza bryłę: użyj normalnej najbliższej bryły
        cx, cy, r = min(duze, key=lambda k: math.hypot(x - k[0], y - k[1]) - k[2])
        dx, dy = x + 0.5 - cx, y + 0.5 - cy; d = math.hypot(dx, dy) or 1
        g = (0, (dx / d * 0.95, dy / d * 0.95, 0.3))
    return g[1], l[1]

# ---------- PIEŃ: kilka splecionych pasm (jak kreski na szkicu) ----------
def pasmo(x0, x1, fala, faza, grubosc):
    pts = []
    for i in range(0, 200):
        t = i / 199
        y = 56 + t * 71
        x = x0 + (x1 - x0) * (t ** 5) + math.sin(t * 4.5 + faza) * fala
        pts.append((x, y, grubosc * (1 + 0.7 * t ** 6)))
    return pts
pasma = [
    pasma_ for pasma_ in (
        pasma_ for pasma_ in [
            pasmo(55, 36, 1.0, 0.0, 2.6),
            pasmo(59, 52, 1.4, 1.7, 3.0),
            pasmo(64, 64, 1.3, 3.1, 3.2),
            pasmo(69, 77, 1.2, 4.4, 3.0),
            pasmo(73, 94, 0.9, 5.6, 2.6),
            # gałęzie znikające w koronie
            [(54 - t * 0.2 * 60, 62 - t * 16, 2.0 - t) for t in [i / 99 for i in range(100)]],
            [(72 + t * 0.3 * 60, 60 - t * 16, 2.0 - t) for t in [i / 99 for i in range(100)]],
            [(63 + t * 4, 60 - t * 18, 1.8 - t * 0.8) for t in [i / 99 for i in range(100)]],
        ])
]

pien = {}  # (x,y) -> (indeks pasma, normalna_x)
for i, ps in enumerate(pasma):
    for (px, py, g) in ps:
        for x in range(int(px - g - 1), int(px + g + 2)):
            for y in (int(py),):
                d = (x + 0.5 - px) / g
                if abs(d) <= 1:
                    poprz = pien.get((x, y))
                    # pasmo bliżej środka swojej szerokości jest "z przodu"
                    if poprz is None or abs(d) < abs(poprz[1]) * 0.8:
                        pien[(x, y)] = (i, d)

# ---------- MALOWANIE ----------
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()
def hexrgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

mapa = [[None] * W for _ in range(H)]  # indeks poziomu jasności, -1 = puste

for y in range(H):
    for x in range(W):
        k = korona(x, y)
        if k:
            (nx, ny, nz), (lx, ly, lz) = k
            # bryła korony daje ogólne światło, listek - drobną fakturę
            ig = max(0.0, nx * L[0] + ny * L[1] + nz * L[2])
            il = max(0.0, lx * L[0] + ly * L[1] + lz * L[2])
            i = ig * (0.45 + 0.75 * il)
            # cień własny: dół i lewa strona korony giną w ciemności
            ao = min(1.0, max(0.0, (60 - y) / 45))
            i = 1.25 * i * (0.3 + 0.7 * ao) * (0.8 + 0.4 * szum_duzy(x, y))
            mapa[y][x] = i
        elif (x, y) in pien:
            _, d = pien[(x, y)]
            i = max(0.0, d * 0.95 + 0.2)  # walec oświetlony z prawej
            # krawędź pasma = bruzda w korze
            if abs(d) > 0.78: i *= 0.25
            # pod koroną jest ciemno
            cien = min(1.0, max(0.0, (y - 58) / 40))
            i *= 0.25 + 0.75 * cien
            mapa[y][x] = i * 0.85
        else:
            mapa[y][x] = -1

def pelny(x, y):
    return 0 <= x < W and 0 <= y < H and mapa[y][x] >= 0

wynik = [[-1] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        i = mapa[y][x]
        if i < 0: continue
        # kwantyzacja z ditheringiem tylko na granicach pasm
        v = i * (len(POZIOMY) - 0.6) + (bayer(x, y) - 0.5) * 0.55
        wynik[y][x] = max(0, min(len(POZIOMY) - 1, int(v)))

# usuń samotne piksele (brud), żeby kępy były czytelne
for _ in range(2):
    nowy = [r[:] for r in wynik]
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            c = wynik[y][x]
            if c < 0: continue
            sas = [wynik[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if all(s != c for s in sas if s >= 0):
                pel = [s for s in sas if s >= 0]
                if pel: nowy[y][x] = sorted(pel, key=lambda s: abs(s - c))[0]
    wynik = nowy

# usuń pojedyncze piksele odstające od obrysu
for y in range(H):
    for x in range(W):
        if wynik[y][x] >= 0:
            s = sum(pelny(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if s <= 1 and y < 120: wynik[y][x] = -1; mapa[y][x] = -1

for y in range(H):
    for x in range(W):
        c = wynik[y][x]
        if c < 0: continue
        kolor = POZIOMY[c]
        # obrys od księżyca: piksel, nad którym lub na prawo od którego jest niebo
        if not pelny(x + 1, y) or not pelny(x, y - 1):
            if mapa[y][x] > 0.42:
                kolor = POSWIATA if mapa[y][x] > 0.62 else MGLA
            elif mapa[y][x] > 0.22:
                kolor = POZIOMY[min(len(POZIOMY) - 1, c + 1)]
        px[x, y] = hexrgb(kolor)

wyj = Path(__file__).resolve().parents[1] / "otoczenie" / "drzewo.png"
img.save(wyj)
print("zapisano", wyj)
