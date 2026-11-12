"""Collectible items. Chest: 64 logical -> 128px. Orbs / oxygen: 32 logical -> 64px."""
import math, random
from PIL import Image, ImageDraw

OUT = (28, 20, 44, 255)
W = (255, 255, 255, 255)


def new(n): return Image.new("RGBA", (n, n), (0, 0, 0, 0))


def outline(img, col=OUT):
    n = img.width; px = img.load(); res = img.copy(); rp = res.load()
    for y in range(n):
        for x in range(n):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < n and 0 <= ny < n and px[nx, ny][3] > 200 and px[nx, ny] != col:
                        rp[x, y] = col; break
    return res


def fade(img, a):
    if a < 1: img.putalpha(img.getchannel("A").point(lambda v: int(v * a)))
    return img


def whiten(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] and p != OUT: px[x, y] = (255, 250, 245, p[3])
    return img


def E(d, x0, y0, x1, y1, c): d.ellipse((x0, y0, x1, y1), fill=c)
def R(d, x0, y0, x1, y1, c): d.rectangle((x0, y0, x1, y1), fill=c)


def star(d, x, y, s, c=(255, 245, 170, 255)):
    for a in range(0, 360, 45):
        ln = s if a % 90 == 0 else max(0, s - 1)
        d.line((x, y, x + round(math.cos(math.radians(a)) * ln), y + round(math.sin(math.radians(a)) * ln)), fill=c)
    d.point((x, y), fill=W)


def heart(d, x, y, s, c, hl=True):
    """pixel heart centred at x,y, s = half-width (>=2)"""
    r = max(1, s // 2)
    E(d, x - s, y - s + 1, x - s + 2 * r, y - s + 1 + 2 * r, c)
    E(d, x + s - 2 * r, y - s + 1, x + s, y - s + 1 + 2 * r, c)
    d.polygon([(x - s, y - s + 1 + r), (x + s, y - s + 1 + r), (x, y + s + 1)], fill=c)
    if hl and s >= 3:
        d.point((x - s + 1, y - s + 2), fill=W)


def bub(d, x, y, r, c=(180, 235, 255, 255)):
    if r <= 0: d.point((x, y), fill=c); return
    d.ellipse((x - r, y - r, x + r, y + r), outline=c)
    d.point((x - r + 1, y - r + 1), fill=W)


# ======================================================================= CHEST
class Chest:
    name, size = "health_chest", 64
    ANIMS = [("idle", 6, 8.0, True), ("break", 6, 12.0, False), ("open", 6, 12.0, False), ("release", 8, 12.0, False)]
    WD, WDS, WDH = (165, 98, 52, 255), (112, 62, 36, 255), (205, 135, 75, 255)
    MET, METD = (160, 170, 195, 255), (95, 100, 130, 255)
    RED, REDD, REDH = (232, 58, 80, 255), (160, 30, 55, 255), (255, 150, 165, 255)
    GLOW = (255, 140, 160, 255)
    CRACKS = [[(26, 37), (28, 40), (27, 43), (29, 46)],
              [(40, 36), (38, 39), (40, 42)],
              [(21, 27), (24, 29), (23, 31)],
              [(35, 41), (37, 44), (35, 47), (36, 49)],
              [(43, 27), (41, 30)]]

    def base(self, d, dx, dy, ncracks, band_broken, pulse):
        x0, x1, y0, y1 = 17 + dx, 47 + dx, 34 + dy, 51 + dy
        # shadow
        R(d, x0 + 2, 53, x1 - 2, 54, (20, 30, 50, 120))
        # box
        R(d, x0, y0, x1, y1, self.WDS)
        R(d, x0, y0, x1, y1 - 2, self.WD)
        for py in (y0 + 5, y0 + 11):
            d.line((x0 + 1, py, x1 - 1, py), fill=self.WDS)
        R(d, x0 + 1, y0, x1 - 1, y0, self.WDH)
        # metal corners / bands
        for bx in (x0 + 4, x1 - 6):
            if band_broken and bx > x0 + 10:
                R(d, bx, y0, bx + 2, y0 + 7, self.MET); R(d, bx + 1, y0 + 10, bx + 3, y1, self.METD)
            else:
                R(d, bx, y0, bx + 2, y1, self.MET); R(d, bx + 2, y0, bx + 2, y1, self.METD)
        return x0, x1, y0, y1

    def lid(self, d, x0, x1, y0, lift=0, open_=0):
        if open_:  # lid flipped back, inner face visible
            R(d, x0 + 1, y0 - 9 - open_, x1 - 1, y0 - 2, self.WDS)
            R(d, x0 + 3, y0 - 7 - open_, x1 - 3, y0 - 3, (80, 45, 30, 255))
            return
        ly = y0 - lift
        d.rounded_rectangle((x0 - 1, ly - 10, x1 + 1, ly), radius=5, fill=self.WD)
        R(d, x0 - 1, ly - 3, x1 + 1, ly, self.WDS)
        R(d, x0 + 3, ly - 9, x1 - 6, ly - 8, self.WDH)
        for bx in (x0 + 4, x1 - 6):
            R(d, bx, ly - 10, bx + 2, ly, self.MET)
        # lock plate with heart
        cx = (x0 + x1) // 2
        R(d, cx - 5, ly - 4, cx + 5, ly + 6, self.MET); R(d, cx - 5, ly + 5, cx + 5, ly + 6, self.METD)

    def emblem(self, d, x0, x1, ly, pulse):
        cx = (x0 + x1) // 2
        heart(d, cx, ly + 1, 3, self.REDH if pulse else self.RED)

    def cracks(self, d, dx, dy, n):
        for k in range(n):
            pts = [(x + dx, y + dy) for x, y in self.CRACKS[k]]
            d.line(pts, fill=OUT)
            d.line([(x + 1, y) for x, y in pts], fill=self.GLOW)

    def frame(self, anim, i):
        img = new(64); d = ImageDraw.Draw(img)
        dx, dy, pulse, nc, band, lift, open_, glint = 0, 0, False, 0, False, 0, 0, -1
        rays, heart_y, heart_s, burst, alpha, flash = 0, None, 0, 0, 1.0, False
        splinters = []
        if anim == "idle":
            dy = [0, 0, -1, -1, 0, 0][i]; pulse = i in (2, 3); glint = i
        elif anim == "break":
            dx = [-2, 2, -1, 2, -1, 0][i]; nc = [1, 2, 3, 3, 4, 5][i]; band = i >= 4; flash = i == 0
            pulse = i % 2 == 1
            if i in (1, 3, 4):
                rnd = random.Random(i)
                splinters = [(32 + rnd.randint(-16, 16), 30 + rnd.randint(-6, 14)) for _ in range(4)]
        elif anim == "open":
            nc, band, pulse = 5, True, True
            lift = [0, 1, 4, 0, 0, 0][i]; open_ = [0, 0, 0, 1, 2, 2][i]; dx = [0, 1, 0, 0, 0, 0][i]
            rays = [0, 1, 2, 3, 4, 3][i]
        elif anim == "release":
            nc, band, open_ = 5, True, 2
            heart_y = [30, 24, 18, 14, 12, None, None, None][i]
            heart_s = [3, 4, 5, 6, 7, 0, 0, 0][i]
            burst = [0, 0, 0, 0, 0, 1, 2, 3][i]
            rays = [3, 2, 2, 1, 0, 0, 0, 0][i]
            alpha = [1, 1, 1, 1, 1, .8, .5, .25][i]
        x0, x1, y0, y1 = self.base(d, dx, dy, nc, band, pulse)
        if open_:
            self.lid(d, x0, x1, y0, open_=open_)
            R(d, x0 + 2, y0, x1 - 2, y0 + 3, (70, 30, 40, 255))
            R(d, x0 + 4, y0, x1 - 4, y0 + 1, self.GLOW)
        else:
            self.lid(d, x0, x1, y0, lift=lift)
        self.cracks(d, dx, dy, nc)
        if not open_:
            self.emblem(d, x0, x1, y0 - lift, pulse)
        img = outline(img); d = ImageDraw.Draw(img)
        cx = (x0 + x1) // 2
        if glint >= 0 and glint < 4:
            gx = x0 + 3 + glint * 8
            star(d, gx, y0 - 9 + dy, 2 if glint in (1, 2) else 1)
        for sx, sy in splinters:
            R(d, sx, sy, sx + 1, sy, self.WDH)
        if rays:
            for k in range(-2, 3):
                ln = 3 + rays * 3
                ex = cx + k * (3 + rays)
                d.line((cx + k * 2, y0 - 2, ex, y0 - 2 - ln), fill=(255, 200, 210, 170))
        # alpha fade on chest only, then hearts on top at full opacity
        img = fade(img, alpha); d = ImageDraw.Draw(img)
        if heart_y is not None:
            hl = new(64); hd = ImageDraw.Draw(hl)
            heart(hd, cx, heart_y, heart_s, self.RED)
            heart(hd, cx - 1, heart_y - 1, max(2, heart_s - 2), self.REDH, hl=True)
            hl = outline(hl); img.alpha_composite(hl); d = ImageDraw.Draw(img)
            if i >= 2: star(d, cx + heart_s + 3, heart_y - heart_s, 2); star(d, cx - heart_s - 3, heart_y + 2, 1)
        if burst:
            r = 6 + burst * 7
            for k in range(8):
                a = k / 8 * 2 * math.pi - math.pi / 2
                x, y = cx + math.cos(a) * r, 12 + math.sin(a) * r * 0.8
                if k % 2 == 0:
                    small = new(64); sd = ImageDraw.Draw(small)
                    heart(sd, round(x), round(y), 3 if burst < 3 else 2, self.RED if burst < 3 else self.REDH)
                    img.alpha_composite(outline(small))
                else:
                    d.line((x - 1, y, x + 1, y), fill=W); d.line((x, y - 1, x, y + 1), fill=W)
            if burst == 1:
                star(d, cx, 12, 6, W)
        if flash: img = whiten(img)
        return img


# ======================================================================= XP ORBS
class Orb:
    size = 32
    ANIMS = [("idle", 8, 10.0, True), ("collect", 6, 14.0, False)]

    def __init__(self, name, r, core, mid, dark):
        self.name, self.r, self.core, self.mid, self.dark = name, r, core, mid, dark

    def frame(self, anim, i):
        img = new(32); d = ImageDraw.Draw(img)
        c = 16
        if anim == "idle":
            r = self.r + (1 if i in (2, 3) else 0)
            yo = [0, -1, -1, -1, 0, 0, 1, 0][i]
            cy = c + yo
            # halo
            E(d, c - r - 2, cy - r - 2, c + r + 2, cy + r + 2, self.dark[:3] + (90,))
            E(d, c - r, cy - r, c + r, cy + r, self.dark)
            E(d, c - r, cy - r, c + r - 1, cy + r - 1, self.mid)
            E(d, c - r // 2 - 1, cy - r // 2 - 1, c + r // 2, cy + r // 2, self.core)
            # rotating highlight
            a = i / 8 * 2 * math.pi
            hx, hy = c + round(math.cos(a) * (r - 2)), cy + round(math.sin(a) * (r - 2) * 0.5) - r // 3
            d.point((hx, hy), fill=W); d.point((c - r // 2, cy - r // 2), fill=W)
            img = outline(img); d = ImageDraw.Draw(img)
            # orbiting sparkle
            oa = -i / 8 * 2 * math.pi
            ox, oy = c + round(math.cos(oa) * (r + 4)), cy + round(math.sin(oa) * (r + 4) * 0.45)
            if 0 < ox < 31: star(d, ox, oy, 1, self.core)
        else:
            if i == 0:
                r = self.r + 2
                E(d, c - r, c - r, c + r, c + r, W); E(d, c - r + 2, c - r + 2, c + r - 2, c + r - 2, self.core)
                img = outline(img)
            elif i == 1:
                E(d, c - self.r // 2 - 1, c - self.r - 2, c + self.r // 2 + 1, c + self.r + 2, self.core)
                d.line((c, c - self.r - 2, c, c + self.r + 2), fill=W)
                img = outline(img)
            else:
                k = i - 2
                rr = 4 + k * 3 + self.r // 2
                col = self.core if k < 2 else self.mid
                for n in range(8):
                    a = n / 8 * 2 * math.pi + k * 0.3
                    x, y = c + round(math.cos(a) * rr), c + round(math.sin(a) * rr)
                    if k < 3:
                        d.line((x - 1, y, x + 1, y), fill=col); d.line((x, y - 1, x, y + 1), fill=col)
                    else:
                        d.point((x, y), fill=col)
                if k == 0: star(d, c, c, 3, W)
        return img


# ======================================================================= OXYGEN
class Oxygen:
    name, size = "oxygen", 32
    ANIMS = [("idle", 8, 8.0, True), ("collect", 6, 14.0, False)]
    RIM, RIMD = (170, 235, 255, 255), (70, 150, 200, 255)
    FILL = (90, 190, 240, 90)
    TXT = (255, 255, 255, 255)

    def o2(self, d, x, y):
        # "O" 5x6
        d.rectangle((x + 1, y, x + 3, y), fill=self.TXT); d.rectangle((x + 1, y + 5, x + 3, y + 5), fill=self.TXT)
        d.rectangle((x, y + 1, x, y + 4), fill=self.TXT); d.rectangle((x + 4, y + 1, x + 4, y + 4), fill=self.TXT)
        # "2" 3x4 subscript
        sx, sy = x + 6, y + 3
        for p in ((sx, sy), (sx + 1, sy), (sx + 2, sy + 1), (sx + 1, sy + 2), (sx, sy + 3), (sx + 1, sy + 3), (sx + 2, sy + 3)):
            d.point(p, fill=self.TXT)

    def frame(self, anim, i):
        img = new(32); d = ImageDraw.Draw(img)
        c = 16
        if anim == "idle":
            rx = 10 + [0, 1, 1, 0, 0, -1, -1, 0][i]
            ry = 10 - [0, 1, 1, 0, 0, -1, -1, 0][i]
            cy = c + [0, 0, -1, -1, -1, 0, 0, 0][i]
            d.ellipse((c - rx, cy - ry, c + rx, cy + ry), fill=self.FILL, outline=self.RIM)
            d.arc((c - rx, cy - ry, c + rx, cy + ry), 20, 160, fill=self.RIMD)
            d.arc((c - rx + 2, cy - ry + 2, c + rx - 2, cy + ry - 2), 200, 250, fill=W)
            d.point((c - rx + 4, cy - ry + 3), fill=W)
            self.o2(d, c - 5, cy - 3)
            # tiny satellite bubbles
            bub(d, c + 11, cy + 6 - (i % 4), 0 if i % 2 else 1)
            if i >= 4: bub(d, c - 12, cy - 4 - (i - 4) * 2, 0)
            img2 = new(32); img2.alpha_composite(img); img = img2
        else:
            if i == 0:
                d.ellipse((c - 12, c - 9, c + 12, c + 9), fill=self.FILL, outline=W)
                self.o2(d, c - 5, c - 3)
            elif i == 1:
                for a0 in range(0, 360, 60):
                    d.arc((c - 12, c - 12, c + 12, c + 12), a0, a0 + 30, fill=self.RIM)
                self.o2(d, c - 5, c - 4)
            else:
                k = i - 2
                rr = 12 + k * 3
                for n in range(6):
                    a = n / 6 * 2 * math.pi + 0.5
                    x, y = c + round(math.cos(a) * rr), c + round(math.sin(a) * rr) - k * 2
                    if 0 < x < 31 and 0 < y < 31: bub(d, x, y, 1 if k < 2 else 0)
                # "+O2" rising
                if k < 3:
                    ty = c - 6 - k * 3
                    d.line((c - 9, ty + 3, c - 7, ty + 3), fill=(140, 255, 200, 255)); d.line((c - 8, ty + 2, c - 8, ty + 4), fill=(140, 255, 200, 255))
                    self.o2(d, c - 5, ty)
        return img


ITEMS = [Chest(),
         Orb("xp_small", 3, (190, 255, 160, 255), (90, 210, 90, 255), (40, 130, 60, 255)),
         Orb("xp_medium", 5, (170, 240, 255, 255), (70, 160, 240, 255), (35, 80, 170, 255)),
         Orb("xp_large", 7, (255, 220, 255, 255), (190, 100, 240, 255), (100, 45, 160, 255)),
         Oxygen()]
