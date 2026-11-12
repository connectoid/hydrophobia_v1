"""Procedural pixel-art bathyscaphes. Logical grid 64x64, exported at 2x = 128x128."""
import math, random
from PIL import Image, ImageDraw

G = 64
OUT = (28, 20, 44, 255)

ANIMS = [("idle", 6, 8.0, True), ("move", 6, 10.0, True), ("attack", 8, 12.0, False), ("hurt", 3, 10.0, False)]


def new():
    return Image.new("RGBA", (G, G), (0, 0, 0, 0))


def outline(img, col=OUT):
    px = img.load()
    res = img.copy()
    rp = res.load()
    for y in range(G):
        for x in range(G):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < G and 0 <= ny < G and px[nx, ny][3] > 0 and px[nx, ny] != col:
                        rp[x, y] = col
                        break
    return res


def flash(img):
    px = img.load()
    for y in range(G):
        for x in range(G):
            p = px[x, y]
            if p[3] > 0 and p != OUT:
                px[x, y] = (255, 250, 245, 255)
    return img


def E(d, x0, y0, x1, y1, c):
    d.ellipse((x0, y0, x1, y1), fill=c)


def R(d, x0, y0, x1, y1, c):
    d.rectangle((x0, y0, x1, y1), fill=c)


def bubble(d, x, y, r=1):
    if r <= 0:
        d.point((x, y), fill=(170, 225, 255, 255))
        return
    d.ellipse((x - r, y - r, x + r, y + r), outline=(170, 225, 255, 255))
    d.point((x - r + 1, y - r + 1), fill=(255, 255, 255, 255))


def eyes(d, x, y, mode, gap=4, look=1):
    """two small eyes; mode: open/blink/angry/hurt"""
    W, P = (255, 255, 255, 255), OUT
    for ex in (x, x + gap):
        if mode == "blink":
            R(d, ex, y + 2, ex + 2, y + 2, P)
        elif mode == "hurt":
            d.point((ex, y), fill=P); d.point((ex + 2, y), fill=P)
            d.point((ex + 1, y + 1), fill=P)
            d.point((ex, y + 2), fill=P); d.point((ex + 2, y + 2), fill=P)
        else:
            R(d, ex, y, ex + 2, y + 3, W)
            R(d, ex + look, y + 1, ex + look + 1, y + 2, P)
            if mode == "angry":
                d.line((ex - 1, y - 2, ex + 3, y), fill=P) if True else None


def propeller(d, x, y, phase, h=6, col=(150, 160, 185, 255), dark=(95, 100, 130, 255)):
    p = phase % 3
    if p == 0:
        R(d, x - 1, y - h, x, y + h, col); R(d, x - 1, y - h, x - 1, y - h + 2, dark)
    elif p == 1:
        R(d, x - 1, y - h // 2, x, y + h // 2, col)
        R(d, x - 2, y - 1, x + 1, y + 1, dark)
    else:
        R(d, x - 1, y - 1, x, y + 1, dark)
        R(d, x - 1, y - h, x - 1, y - h + 1, col); R(d, x, y + h - 1, x, y + h, col)


def spark(d, x, y, s=2, c=(160, 250, 255, 255)):
    d.line((x - s, y, x + s, y), fill=c); d.line((x, y - s, x, y + s), fill=c)
    d.point((x, y), fill=(255, 255, 255, 255))


# ---------------------------------------------------------------- variant A
class Bulb:
    name, title = "bulb", "Пузырь"
    Y, YS, YH = (244, 196, 48, 255), (205, 140, 30, 255), (255, 232, 140, 255)
    MET, METD = (150, 160, 185, 255), (95, 100, 130, 255)
    GL, GLH = (70, 160, 220, 255), (170, 225, 255, 255)

    def frame(self, anim, i):
        img = new(); d = ImageDraw.Draw(img)
        cx, cy = 29, 32
        prop, eyem, ext, opn, bulb_on = i // 2, "open", 0, 0, i % 3 != 2
        bubbles = []
        if anim == "idle":
            cy += [0, -1, -1, 0, 1, 1][i]
            if i == 4: eyem = "blink"
            bubbles = [(cx - 4, cy - 22 - i * 2, 1 if i < 3 else 0)]
        elif anim == "move":
            cy += [0, -1, 0, 1, 0, -1][i]; cx += [0, 1, 1, 0, 0, 0][i]
            prop = i
            bubbles = [(cx - 23 - ((i * 3 + k * 5) % 9), cy - 2 + (k * 3) % 7 - 3, (k + i) % 2) for k in range(3)]
        elif anim == "attack":
            ext = [0, -2, -2, 6, 14, 14, 9, 3][i]
            opn = [1, 2, 3, 3, 0, 0, 1, 0][i]
            cx += [0, -1, -2, 1, 2, 2, 1, 0][i]
            eyem = "angry" if i > 0 else "open"
            prop = i
        elif anim == "hurt":
            cx += [-2, 1, 0][i]; eyem = "hurt"

        # propeller & shaft
        R(d, cx - 19, cy - 1, cx - 14, cy + 1, self.METD)
        propeller(d, cx - 20, cy, prop)
        # skids
        d.line((cx - 7, cy + 13, cx - 10, cy + 18), fill=self.METD)
        d.line((cx + 5, cy + 13, cx + 8, cy + 18), fill=self.METD)
        R(d, cx - 14, cy + 18, cx + 12, cy + 19, self.MET)
        # arm
        ax = cx + 10
        tx = ax + 3 + max(ext, 0)
        R(d, ax, cy + 9, tx, cy + 11, self.METD); R(d, ax, cy + 9, tx, cy + 9, self.MET)
        # claw
        R(d, tx, cy + 7 - opn, tx + 4, cy + 8 - opn, self.MET); d.point((tx + 4, cy + 9 - opn), fill=self.MET)
        R(d, tx, cy + 12 + opn, tx + 4, cy + 13 + opn, self.MET); d.point((tx + 4, cy + 11 + opn), fill=self.MET)
        R(d, tx - 1, cy + 8, tx + 1, cy + 12, self.METD)
        # body
        E(d, cx - 16, cy - 15, cx + 16, cy + 15, self.YS)
        E(d, cx - 16, cy - 15, cx + 14, cy + 12, self.Y)
        E(d, cx - 11, cy - 12, cx - 3, cy - 6, self.YH)
        d.point((cx - 12, cy - 4), fill=self.YH)
        # belt with rivets
        R(d, cx - 16, cy + 4, cx + 15, cy + 5, self.YS)
        for rx in range(cx - 13, cx + 14, 4):
            d.point((rx, cy + 4), fill=self.YH)
        # hatch & antenna light
        R(d, cx - 6, cy - 19, cx + 2, cy - 15, self.MET); R(d, cx - 6, cy - 16, cx + 2, cy - 15, self.METD)
        d.line((cx - 2, cy - 20, cx - 2, cy - 24), fill=self.METD)
        d.line((cx - 2, cy - 24, cx + 2, cy - 26), fill=self.METD)
        bc = (255, 250, 190, 255) if bulb_on else (210, 180, 90, 255)
        E(d, cx + 2, cy - 28, cx + 5, cy - 25, bc)
        # porthole
        E(d, cx + 1, cy - 9, cx + 15, cy + 5, self.METD)
        E(d, cx + 2, cy - 8, cx + 14, cy + 4, self.MET)
        E(d, cx + 4, cy - 6, cx + 12, cy + 2, self.GL)
        d.point((cx + 5, cy - 5), fill=self.GLH); d.point((cx + 6, cy - 5), fill=self.GLH)
        eyes(d, cx + 5, cy - 4, eyem, gap=4, look=1)
        if eyem == "angry":
            d.line((cx + 4, cy - 7, cx + 7, cy - 5), fill=OUT); d.line((cx + 9, cy - 5, cx + 12, cy - 7), fill=OUT)
        img = outline(img)
        d = ImageDraw.Draw(img)
        for bx, by, r in bubbles:
            bubble(d, bx, by, r)
        if anim == "attack" and i in (4, 5):
            sx = min(tx + 6, G - 5)
            s = 4 if i == 4 else 2
            for a in range(0, 360, 45):
                ln = s if a % 90 == 0 else s - 1
                d.line((sx, cy + 10, sx + round(math.cos(math.radians(a)) * ln), cy + 10 + round(math.sin(math.radians(a)) * ln)), fill=(255, 245, 160, 255))
        if anim == "hurt" and i == 0:
            img = flash(img)
        return img


# ---------------------------------------------------------------- variant B
class Harpoon:
    name, title = "harpoon", "Гарпунёр"
    RD, RDS, RDH = (214, 70, 60, 255), (150, 40, 45, 255), (245, 130, 110, 255)
    WH = (236, 236, 228, 255)
    MET, METD = (150, 160, 185, 255), (80, 86, 112, 255)
    VIS, VISH = (60, 205, 195, 255), (190, 255, 245, 255)

    def body(self, d, cx, cy, prop, eyem, loaded, glow):
        # twin propellers
        R(d, cx - 23, cy - 5, cx - 19, cy - 4, self.METD); R(d, cx - 23, cy + 3, cx - 19, cy + 4, self.METD)
        propeller(d, cx - 24, cy - 4, prop, h=4)
        propeller(d, cx - 24, cy + 4, prop + 1, h=4)
        # fins
        d.polygon([(cx - 19, cy - 8), (cx - 14, cy - 8), (cx - 18, cy - 14), (cx - 21, cy - 14)], fill=self.RDS)
        d.polygon([(cx - 19, cy + 8), (cx - 13, cy + 8), (cx - 18, cy + 13), (cx - 21, cy + 13)], fill=self.RDS)
        # periscope
        R(d, cx - 12, cy - 17, cx - 10, cy - 8, self.MET)
        R(d, cx - 12, cy - 19, cx - 6, cy - 17, self.MET); d.point((cx - 6, cy - 18), fill=self.VISH)
        # gun
        R(d, cx - 1, cy - 12, cx + 5, cy - 9, self.METD)
        R(d, cx + 1, cy - 15, cx + 15, cy - 13, self.METD); R(d, cx + 1, cy - 15, cx + 15, cy - 15, self.MET)
        R(d, cx - 2, cy - 15, cx + 1, cy - 12, self.MET)
        if loaded:
            d.polygon([(cx + 16, cy - 16), (cx + 19, cy - 14), (cx + 16, cy - 12)], fill=(220, 225, 235, 255))
        if glow:
            R(d, cx + 14, cy - 15, cx + 15, cy - 13, (255, 230, 120, 255))
        # hull
        d.rounded_rectangle((cx - 20, cy - 9, cx + 18, cy + 9), radius=8, fill=self.RDS)
        d.rounded_rectangle((cx - 20, cy - 9, cx + 18, cy + 6), radius=7, fill=self.RD)
        R(d, cx - 14, cy - 7, cx + 4, cy - 6, self.RDH)
        R(d, cx - 7, cy - 9, cx - 4, cy + 9, self.WH)
        R(d, cx - 7, cy + 6, cx - 4, cy + 8, (190, 190, 182, 255))
        # visor
        d.rounded_rectangle((cx + 5, cy - 7, cx + 18, cy + 3), radius=3, fill=self.METD)
        d.rounded_rectangle((cx + 6, cy - 6, cx + 17, cy + 2), radius=2, fill=self.VIS)
        d.point((cx + 7, cy - 5), fill=self.VISH); d.point((cx + 8, cy - 5), fill=self.VISH)
        eyes(d, cx + 9, cy - 4, eyem, gap=4, look=1)
        # determined brows always
        if eyem in ("open", "angry"):
            d.line((cx + 8, cy - 7, cx + 12, cy - 6), fill=OUT); d.line((cx + 13, cy - 6, cx + 16, cy - 7), fill=OUT)
        # headlamp + rivets
        E(d, cx + 14, cy + 4, cx + 17, cy + 7, (255, 230, 120, 255))
        for rx in range(cx - 17, cx + 4, 5):
            d.point((rx, cy + 3), fill=self.RDS)

    def frame(self, anim, i):
        img = new(); d = ImageDraw.Draw(img)
        cx, cy = 28, 34
        prop, eyem, loaded, glow = i // 2, "open", True, False
        bubbles, proj = [], None
        if anim == "idle":
            cy += [0, 0, -1, -1, 0, 1][i]
            if i == 3: eyem = "blink"
            bubbles = [(cx - 9, cy - 22 - i * 2, 0)]
        elif anim == "move":
            cy += [0, -1, 0, 1, 0, -1][i]; prop = i
            bubbles = [(cx - 27 - ((i * 3 + k * 5) % 12), cy + (k * 5) % 9 - 4, (k + i) % 2) for k in range(3)]
        elif anim == "attack":
            cx += [0, 0, -3, -2, -1, 0, 0, 0][i]
            glow = i == 1
            loaded = i in (0, 1, 7)
            eyem = "angry"
            prop = i
            if i in (2, 3, 4):
                proj = cx + 18 + [0, 8, 18][i - 2]
        elif anim == "hurt":
            cx += [-2, 1, 0][i]; eyem = "hurt"
        self.body(d, cx, cy, prop, eyem, loaded, glow)
        img = outline(img)
        d = ImageDraw.Draw(img)
        if proj is not None:
            gy = cy - 14
            if proj - 2 > cx + 16:
                d.line((cx + 16, gy, proj - 6, gy), fill=(200, 190, 160, 255))
            draw_harpoon(d, proj, gy)
        if anim == "attack" and i == 2:
            mx = cx + 17
            for a in (-40, 0, 40):
                d.line((mx, cy - 14, mx + round(4 * math.cos(math.radians(a))), cy - 14 + round(4 * math.sin(math.radians(a)))), fill=(255, 240, 150, 255))
        for bx, by, r in bubbles:
            bubble(d, bx, by, r)
        if anim == "hurt" and i == 0:
            img = flash(img)
        return img


def draw_harpoon(d, tip_x, y):
    R(d, tip_x - 10, y, tip_x - 3, y, (190, 195, 210, 255))
    d.polygon([(tip_x - 3, y - 2), (tip_x + 1, y), (tip_x - 3, y + 2)], fill=(230, 235, 245, 255))
    d.point((tip_x - 10, y - 1), fill=(214, 70, 60, 255)); d.point((tip_x - 10, y + 1), fill=(214, 70, 60, 255))


# ---------------------------------------------------------------- variant C
class Bell:
    name, title = "bell", "Колокол"
    T, TS, TH = (58, 180, 168, 255), (34, 120, 125, 255), (140, 230, 210, 255)
    PU, PUS = (112, 82, 165, 255), (72, 52, 115, 255)
    GL = (150, 250, 255, 255)
    ARM, ARMD = (175, 165, 205, 255), (115, 100, 155, 255)

    def frame(self, anim, i):
        img = new(); d = ImageDraw.Draw(img)
        cx, cy = 32, 24
        t = i / 6 * 2 * math.pi
        amp, spread, lift, eyem, look = 2.0, 0.0, 0, "open", 1
        lights = i % 2 == 0
        tipspark, ring = 0, 0
        bubbles = []
        if anim == "idle":
            cy += [0, -1, -1, 0, 1, 1][i]
            if i == 4: eyem = "blink"
        elif anim == "move":
            cy += [1, 0, -1, -2, -1, 0][i]
            spread = [3, 2, 0, -1, 0, 2][i]; amp = 1.0
            bubbles = [(cx - 6 + k * 6, cy + 26 + ((i * 2 + k * 3) % 8), (k + i) % 2) for k in range(3)]
        elif anim == "attack":
            t = i / 8 * 2 * math.pi
            spread = [1, 3, 4, 4, 2, 1, 0, 0][i]; lift = [0, 2, 4, 4, 1, 0, 0, 0][i]
            tipspark = [0, 1, 2, 3, 0, 0, 0, 0][i]
            ring = [0, 0, 0, 0, 20, 25, 29, 0][i]
            eyem = "angry" if 0 < i < 7 else "open"; look = 0
            lights = True
        elif anim == "hurt":
            cx += [-2, 1, 0][i]; eyem = "hurt"

        tips = []
        for n, bx in enumerate((-9, 0, 9)):
            side = (-1, 0, 1)[n]
            px_, py_ = cx + bx, cy + 4
            for k in range(6):
                ox = amp * math.sin(t + k * 0.9 + n * 1.7) * (k / 5) + side * spread * (k / 5)
                yy = cy + 6 + k * 3 - int(lift * k / 5)
                xx = round(cx + bx + ox)
                col = self.ARMD if k % 2 else self.ARM
                E(d, xx - 1, yy - 1, xx + 1, yy + 1, col)
                d.line((px_, py_, xx, yy), fill=self.ARMD)
                px_, py_ = xx, yy
            tips.append((px_, py_ + 2))
            E(d, px_ - 1, py_ + 1, px_ + 1, py_ + 3, self.GL if (lights or tipspark) else self.TS)
        # dome
        dome = new(); dd = ImageDraw.Draw(dome)
        E(dd, cx - 16, cy - 17, cx + 16, cy + 15, self.TS)
        E(dd, cx - 16, cy - 17, cx + 14, cy + 13, self.T)
        E(dd, cx - 12, cy - 14, cx - 5, cy - 9, self.TH)
        for yy in range(cy + 2, G):
            for xx in range(G):
                dome.putpixel((xx, yy), (0, 0, 0, 0))
        img.alpha_composite(dome)
        R(d, cx - 17, cy + 1, cx + 17, cy + 5, self.PU)
        R(d, cx - 17, cy + 4, cx + 17, cy + 5, self.PUS)
        for rx in range(cx - 15, cx + 16, 4):
            d.point((rx, cy + 2), fill=(180, 160, 220, 255))
        # top light
        R(d, cx - 1, cy - 19, cx + 1, cy - 17, self.PUS)
        E(d, cx - 3, cy - 23, cx + 3, cy - 18, self.GL if lights else self.TH)
        # side portholes
        for sx in (cx - 13, cx + 10):
            E(d, sx, cy - 6, sx + 4, cy - 2, self.PUS)
            E(d, sx + 1, cy - 5, sx + 3, cy - 3, self.GL if lights else self.TS)
        # big eye porthole
        E(d, cx - 7, cy - 12, cx + 7, cy + 1, self.PUS)
        E(d, cx - 6, cy - 11, cx + 6, cy, (40, 50, 80, 255))
        if eyem == "blink":
            R(d, cx - 4, cy - 5, cx + 4, cy - 5, (255, 255, 255, 255))
        elif eyem == "hurt":
            d.line((cx - 3, cy - 8, cx + 3, cy - 2), fill=(255, 255, 255, 255))
            d.line((cx - 3, cy - 2, cx + 3, cy - 8), fill=(255, 255, 255, 255))
        else:
            E(d, cx - 4, cy - 9, cx + 4, cy - 2, (255, 255, 255, 255))
            R(d, cx - 1 + look, cy - 7, cx + 1 + look, cy - 4, OUT)
            d.point((cx + look, cy - 7), fill=(255, 255, 255, 255))
            if eyem == "angry":
                R(d, cx - 5, cy - 10, cx + 5, cy - 8, (40, 50, 80, 255))
                d.line((cx - 4, cy - 9, cx + 4, cy - 8), fill=self.PUS)
        img = outline(img)
        d = ImageDraw.Draw(img)
        if tipspark:
            for tx, ty in tips:
                spark(d, tx, ty + 1, tipspark)
        if ring:
            rnd = random.Random(i)
            c = (190, 255, 255, 255) if ring < 29 else (110, 200, 230, 255)
            pts = []
            for a in range(0, 361, 15):
                rr = ring + rnd.choice((-1, 0, 1))
                pts.append((cx + rr * math.cos(math.radians(a)), cy + 6 + rr * math.sin(math.radians(a))))
            for k in range(len(pts) - 1):
                if ring == 29 and k % 2: continue
                d.line((*pts[k], *pts[k + 1]), fill=c)
            if ring == 20:
                for tx, ty in tips:
                    d.line((tx, ty, tx + (tx - cx) // 2, ty + 5), fill=(255, 255, 255, 255))
        for bx, by, r in bubbles:
            bubble(d, bx, by, r)
        if anim == "hurt" and i == 0:
            img = flash(img)
        return img


VARIANTS = [Bulb(), Harpoon(), Bell()]
