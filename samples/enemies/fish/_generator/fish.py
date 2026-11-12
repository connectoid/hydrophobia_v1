"""Predatory cartoon pixel fish. Logical 64x64 -> 128x128. Facing right."""
import math
from PIL import Image, ImageDraw
from sprites import G, OUT, new, outline, flash, bubble, E, R

ANIMS = [("swim", 6, 10.0, True), ("attack", 8, 12.0, False), ("hurt", 3, 10.0, False), ("death", 8, 10.0, False)]
W = (255, 255, 255, 255)
MOUTH = (90, 20, 40, 255)


def eye(d, x, y, mode, r=2, brow=True):
    if mode == "dead":
        d.line((x - 2, y - 2, x + 2, y + 2), fill=OUT); d.line((x - 2, y + 2, x + 2, y - 2), fill=OUT)
        return
    if mode == "hurt":
        d.line((x - 2, y - 2, x + 1, y), fill=OUT); d.line((x - 2, y + 2, x + 1, y), fill=OUT)
        return
    E(d, x - r, y - r, x + r, y + r, W)
    R(d, x, y - 1, x + 1, y + 1, OUT)
    if brow:
        if mode == "angry":
            d.line((x - r - 1, y - r - 2, x + r + 1, y - r + 1), fill=OUT)
            d.line((x - r - 1, y - r - 1, x + r, y - r + 1), fill=OUT)
        else:
            d.line((x - r, y - r - 1, x + r + 1, y - r), fill=OUT)


def teeth_row(d, x0, x1, y, down=True, step=2, h=1):
    for x in range(x0, x1 + 1, step):
        if down:
            d.line((x, y, x, y + h), fill=W)
        else:
            d.line((x, y, x, y - h), fill=W)


class Fish:
    """Base: subclasses implement draw(d, cx, cy, tw, mouth, eye_mode, extra)."""
    cx0, cy0 = 30, 32

    def frame(self, anim, i):
        img = new(); d = ImageDraw.Draw(img)
        cx, cy = self.cx0, self.cy0
        t = i / 6 * 2 * math.pi
        tw, mouth, em, extra = round(math.sin(t) * 3), 0, "open", 0
        bubbles, chomp, flipped, alpha, flash_it = [], 0, False, 1.0, False
        if anim == "swim":
            cy += round(math.sin(t + 1))
            bubbles = [(cx - 26 - (i * 2 + k * 5) % 8, cy - 4 + k * 4, (i + k) % 2) for k in range(2)]
        elif anim == "attack":
            t = i / 8 * 2 * math.pi
            tw = round(math.sin(t * 2) * 4)
            cx += [0, -2, -4, 2, 7, 8, 5, 1][i]
            mouth = [0, 1, 1, 3, 3, 0, 0, 0][i]
            extra = [1, 2, 3, 2, 1, 0, 0, 0][i]
            em = "angry"
            chomp = i in (5, 6)
        elif anim == "hurt":
            cx += [-3, 1, 0][i]; em = "hurt"; flash_it = i == 0; tw = 2 * (-1) ** i
        elif anim == "death":
            em = ["hurt", "hurt", "dead", "dead", "dead", "dead", "dead", "dead"][i]
            flash_it = i == 0
            cx += [-3, 2, 0, 0, 0, 0, 0, 0][i]
            flipped = i >= 3
            cy += [0, 0, 1, 0, 2, 4, 6, 8][i]
            mouth = 1 if i >= 2 else 0
            tw = [2, -2, 1, 0, 0, 0, 0, 0][i]
            alpha = [1, 1, 1, 1, 1, 0.85, 0.55, 0.25][i]
        self.draw(d, cx, cy, tw, mouth, em, extra)
        img = outline(img)
        if flipped:
            # flip around the fish's own centre line, belly up
            img = img.transpose(Image.FLIP_TOP_BOTTOM)
            off = 2 * cy - (G - 1)
            sh = Image.new("RGBA", (G, G), (0, 0, 0, 0)); sh.paste(img, (0, off), img)
            img = sh
        d = ImageDraw.Draw(img)
        if chomp:
            sx, sy = min(cx + self.mouth_x + 4, G - 5), cy + self.mouth_y
            s = 4 if anim == "attack" and i == 5 else 2
            for a in range(0, 360, 45):
                ln = s if a % 90 == 0 else s - 1
                d.line((sx, sy, sx + round(math.cos(math.radians(a)) * ln), sy + round(math.sin(math.radians(a)) * ln)), fill=(255, 245, 160, 255))
        if anim == "death" and i >= 3:
            for k in range(3):
                by = cy - 10 - (i - 3) * 3 - k * 5
                if by > 1:
                    bubble(d, cx - 4 + k * 5, by, (k + i) % 2)
        for bx, by, r in bubbles:
            if bx > 1: bubble(d, bx, by, r)
        if flash_it:
            img = flash(img)
        if alpha < 1:
            a = img.getchannel("A").point(lambda v: int(v * alpha))
            img.putalpha(a)
        return img


class Piranha(Fish):
    name, title = "piranha", "Пиранья"
    BK, BKS, BKH = (75, 95, 130, 255), (50, 65, 95, 255), (120, 145, 180, 255)
    BL, BLS = (225, 75, 60, 255), (170, 45, 45, 255)
    FIN = (160, 60, 70, 255)
    mouth_x, mouth_y = 15, 2

    def draw(self, d, cx, cy, tw, m, em, extra):
        # tail
        d.polygon([(cx - 12, cy - 2), (cx - 22, cy - 9 + tw), (cx - 19, cy + tw), (cx - 22, cy + 9 + tw), (cx - 12, cy + 3)], fill=self.FIN)
        # fins
        d.polygon([(cx - 7, cy - 10), (cx + 3, cy - 11), (cx - 5, cy - 17 + abs(tw) // 2)], fill=self.FIN)
        d.polygon([(cx - 4, cy + 9), (cx + 3, cy + 10), (cx - 6, cy + 15)], fill=self.FIN)
        # body
        E(d, cx - 14, cy - 12, cx + 13, cy + 11, self.BKS)
        E(d, cx - 14, cy - 12, cx + 12, cy + 9, self.BK)
        E(d, cx - 12, cy - 1, cx + 13, cy + 11, self.BLS)
        E(d, cx - 12, cy - 1, cx + 12, cy + 9, self.BL)
        E(d, cx - 8, cy - 10, cx - 1, cy - 6, self.BKH)
        for sx in range(cx - 8, cx + 6, 4):  # scales
            d.point((sx, cy - 3), fill=self.BKS); d.point((sx + 2, cy + 3), fill=self.BLS)
        # jaw / mouth (underbite)
        if m:
            d.polygon([(cx + 5, cy + 2), (cx + 15, cy - 2 - m), (cx + 15, cy + 5 + m)], fill=MOUTH)
            teeth_row(d, cx + 9, cx + 14, cy - m, True, 2, 1)
            teeth_row(d, cx + 9, cx + 14, cy + 4 + m, False, 2, 1)
        else:
            d.line((cx + 6, cy + 2, cx + 13, cy + 1), fill=OUT)
            teeth_row(d, cx + 8, cx + 13, cy + 1, False, 2, 1)
            R(d, cx + 12, cy + 2, cx + 14, cy + 4, self.BL)
        eye(d, cx + 5, cy - 5, em, r=2)


class Shark(Fish):
    name, title = "shark", "Акулёнок"
    GR, GRS, GRH = (120, 138, 165, 255), (82, 95, 125, 255), (170, 185, 205, 255)
    BL = (225, 228, 232, 255)
    cx0 = 30
    mouth_x, mouth_y = 19, 3

    def draw(self, d, cx, cy, tw, m, em, extra):
        d.polygon([(cx - 16, cy - 3), (cx - 26, cy - 13 + tw), (cx - 22, cy + tw), (cx - 25, cy + 9 + tw), (cx - 16, cy + 3)], fill=self.GRS)
        d.polygon([(cx - 4, cy - 7), (cx + 5, cy - 7), (cx - 7, cy - 18)], fill=self.GRS)
        d.polygon([(cx - 15, cy - 4), (cx - 11, cy - 4), (cx - 15, cy - 8)], fill=self.GRS)
        # body
        E(d, cx - 19, cy - 8, cx + 17, cy + 8, self.GRS)
        E(d, cx - 19, cy - 8, cx + 16, cy + 6, self.GR)
        d.polygon([(cx + 13, cy - 6), (cx + 22, cy - 1), (cx + 20, cy + 3), (cx + 13, cy + 5)], fill=self.GR)
        E(d, cx - 14, cy, cx + 15, cy + 8, self.BL)
        d.polygon([(cx + 13, cy + 1), (cx + 21, cy + 1), (cx + 13, cy + 6)], fill=self.BL)
        R(d, cx - 10, cy - 6, cx + 6, cy - 5, self.GRH)
        # pectoral fin
        d.polygon([(cx + 1, cy + 5), (cx + 7, cy + 5), (cx - 1, cy + 12 + abs(tw) // 2)], fill=self.GRS)
        # gills
        for gx in (cx + 4, cx + 6, cx + 8):
            d.line((gx, cy - 2, gx - 1, cy + 2), fill=self.GRS)
        # mouth
        if m:
            d.polygon([(cx + 9, cy + 2), (cx + 21, cy - 1 + (0 if m < 2 else 0)), (cx + 21, cy + 6 + m)], fill=MOUTH)
            teeth_row(d, cx + 12, cx + 20, cy + 1, True, 3, 1)
            teeth_row(d, cx + 13, cx + 20, cy + 4 + m, False, 3, 1)
        else:
            d.line((cx + 10, cy + 3, cx + 20, cy + 1), fill=OUT)
            d.line((cx + 10, cy + 3, cx + 9, cy + 2), fill=OUT)
            teeth_row(d, cx + 12, cx + 19, cy + 3, True, 2, 0)
        eye(d, cx + 12, cy - 3, em, r=2)


class Angler(Fish):
    name, title = "angler", "Удильщик"
    BD, BDS, BDH = (70, 58, 110, 255), (45, 36, 75, 255), (115, 95, 160, 255)
    BL = (130, 100, 140, 255)
    FIN = (95, 70, 130, 255)
    LURE, HALO = (230, 255, 150, 255), (120, 210, 120, 255)
    cx0, cy0 = 28, 35
    mouth_x, mouth_y = 15, 3

    def draw(self, d, cx, cy, tw, m, em, extra):
        # tail
        d.polygon([(cx - 13, cy - 2), (cx - 21, cy - 8 + tw), (cx - 21, cy + 8 + tw), (cx - 13, cy + 3)], fill=self.FIN)
        for k in (-5, 0, 5):
            d.line((cx - 14, cy, cx - 20, cy + k + tw), fill=self.BDS)
        d.polygon([(cx - 4, cy + 10), (cx + 3, cy + 11), (cx - 5, cy + 16 - abs(tw) // 2)], fill=self.FIN)
        # lure stalk
        lx, ly = cx + 15, cy - 22 + (1 if tw > 0 else 0)
        d.line((cx - 1, cy - 12, cx + 3, cy - 20), fill=self.BDS)
        d.line((cx + 3, cy - 20, cx + 8, cy - 23), fill=self.BDS)
        d.line((cx + 8, cy - 23, lx - 2, ly), fill=self.BDS)
        # body
        E(d, cx - 15, cy - 13, cx + 15, cy + 13, self.BDS)
        E(d, cx - 15, cy - 13, cx + 14, cy + 11, self.BD)
        E(d, cx - 11, cy + 2, cx + 10, cy + 12, self.BL)
        E(d, cx - 10, cy - 11, cx - 3, cy - 6, self.BDH)
        for sx, sy in ((cx - 6, cy - 2), (cx - 2, cy + 6), (cx - 10, cy + 4), (cx + 2, cy - 9)):
            d.point((sx, sy), fill=self.BDH)
        # huge mouth
        if m:
            E(d, cx + 1, cy - 4 - m, cx + 17, cy + 10 + m, MOUTH)
            R(d, cx + 12, cy - 6 - m, cx + 18, cy + 12 + m, (0, 0, 0, 0))
            d.polygon([(cx + 2, cy + 3), (cx + 16, cy - 5 - m), (cx + 16, cy + 11 + m)], fill=MOUTH)
            for k, x in enumerate(range(cx + 6, cx + 16, 2)):
                d.line((x, cy - 3 - m + (4 - k) // 2, x, cy - 3 - m + (4 - k) // 2 + 2), fill=W)
                d.line((x, cy + 9 + m - (4 - k) // 2, x, cy + 9 + m - (4 - k) // 2 - 2), fill=W)
        else:
            pts = []
            for k, x in enumerate(range(cx + 3, cx + 16, 2)):
                pts += [(x, cy + 3), (x + 1, cy + 3 + (2 if k % 2 else -2))]
            d.line((cx + 3, cy + 3, cx + 15, cy + 2), fill=OUT)
            for k, x in enumerate(range(cx + 5, cx + 15, 2)):
                d.line((x, cy + 2, x, cy + (0 if k % 2 else 5)), fill=W)
        eye(d, cx + 6, cy - 6, em, r=2)
        # glow (drawn here, outlined too: keep small); halo added for attack
        self._lure = (lx, ly, extra)
        E(d, lx - 2, ly - 2, lx + 2, ly + 2, self.LURE)

    def frame(self, anim, i):
        img = super().frame(anim, i)
        lx, ly, extra = self._lure
        if anim in ("swim", "attack") and img.getpixel((lx, ly))[3] > 0:
            d = ImageDraw.Draw(img)
            r = 3 + extra + (i % 2 if anim == "swim" else 0)
            for a in range(0, 360, 30):
                x = lx + round(math.cos(math.radians(a)) * r); y = ly + round(math.sin(math.radians(a)) * r)
                if 0 <= x < G and 0 <= y < G and img.getpixel((x, y))[3] == 0:
                    img.putpixel((x, y), self.HALO)
            img.putpixel((lx - 1, ly - 1), W)
        return img


FISH = [Piranha(), Shark(), Angler()]
