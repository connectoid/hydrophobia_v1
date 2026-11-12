"""Oxygen fish: peaceful creature carrying an air bladder. 64 logical -> 128px, facing right."""
import math
from PIL import Image, ImageDraw
from sprites import G, OUT, new, outline, flash, bubble, E, R
from fish import eye
from items import Oxygen

ANIMS = [("swim", 6, 10.0, True), ("flee", 6, 14.0, True), ("hurt", 3, 10.0, False), ("death", 8, 10.0, False)]
W = (255, 255, 255, 255)
O2 = Oxygen()


def o2_bubble(d, x, y, r):
    d.ellipse((x - r, y - r, x + r, y + r), fill=(90, 190, 240, 110), outline=(180, 240, 255, 255))
    d.arc((x - r, y - r, x + r, y + r), 20, 160, fill=(70, 150, 200, 255))
    d.point((x - r + 2, y - r + 2), fill=W)
    if r >= 6:
        O2.o2(d, x - 5, y - 3)


class OxyFish:
    name, title = "oxyfish", "Кислородная рыба"
    B, BS, BH = (110, 210, 230, 255), (55, 145, 185, 255), (190, 245, 250, 255)
    BEL = (235, 250, 245, 255)
    FIN = (255, 170, 90, 255)

    def body(self, d, cx, cy, tw, em, mouth):
        d.polygon([(cx - 11, cy - 1), (cx - 19, cy - 8 + tw), (cx - 16, cy + tw), (cx - 19, cy + 8 + tw), (cx - 11, cy + 3)], fill=self.FIN)
        d.polygon([(cx - 1, cy + 7), (cx + 4, cy + 7), (cx - 2, cy + 12 + abs(tw) // 2)], fill=self.FIN)
        E(d, cx - 13, cy - 9, cx + 11, cy + 10, self.BS)
        E(d, cx - 13, cy - 9, cx + 10, cy + 8, self.B)
        E(d, cx - 9, cy + 1, cx + 9, cy + 9, self.BEL)
        R(d, cx - 8, cy - 7, cx - 3, cy - 6, self.BH)
        # gill slits
        d.line((cx - 1, cy - 3, cx - 2, cy + 1), fill=self.BS); d.line((cx + 1, cy - 3, cx, cy + 1), fill=self.BS)
        # side fin
        d.polygon([(cx - 4, cy), (cx + 1, cy + 2), (cx - 5, cy + 4 + tw // 2)], fill=self.FIN)
        # face
        if em == "scared":
            E(d, cx + 2, cy - 7, cx + 8, cy - 1, W); R(d, cx + 6, cy - 5, cx + 6, cy - 4, OUT)
        elif em == "open":
            E(d, cx + 2, cy - 7, cx + 8, cy - 1, W); R(d, cx + 5, cy - 6, cx + 7, cy - 3, OUT); d.point((cx + 5, cy - 6), fill=W)
        else:
            eye(d, cx + 5, cy - 4, em, r=2, brow=False)
        if mouth:
            E(d, cx + 8, cy + 1, cx + 11, cy + 4, (200, 80, 100, 255))
        else:
            d.line((cx + 8, cy + 3, cx + 10, cy + 2), fill=OUT)
        # blush
        d.point((cx + 4, cy + 1), fill=(255, 150, 170, 255)); d.point((cx + 5, cy + 1), fill=(255, 150, 170, 255))

    def frame(self, anim, i):
        img = new(); d = ImageDraw.Draw(img)
        cx, cy = 32, 36
        t = i / 6 * 2 * math.pi
        tw, em, mouth = round(math.sin(t) * 3), "open", 0
        br, flip, alpha, fl, sweat, pop = 7, False, 1.0, False, False, 0
        bubbles, rising = [], []
        if anim == "swim":
            cy += round(math.sin(t + 1)); br = 7 + (1 if i in (1, 2) else 0)
            mouth = i in (3, 4)
            if i >= 3: bubbles = [(cx + 13 + (i - 3), cy + 1 - (i - 3) * 3, (i % 2))]
        elif anim == "flee":
            tw = round(math.sin(t * 2) * 5); em = "scared"; mouth = 1
            cy += [0, -1, 0, 1, 0, -1][i]; cx += [0, 1, 0, -1, 0, 1][i]; sweat = True
            bubbles = [(cx - 22 - (i * 3 + k * 5) % 9, cy - 3 + k * 4, (i + k) % 2) for k in range(2)]
        elif anim == "hurt":
            cx += [-3, 1, 0][i]; em = "hurt"; fl = i == 0; br = 6
        elif anim == "death":
            em = ["hurt", "hurt", "hurt", "dead", "dead", "dead", "dead", "dead"][i]
            fl = i == 0; cx += [-3, 2, 0, 0, 0, 0, 0, 0][i]
            br = [7, 8, 9, 0, 0, 0, 0, 0][i]; pop = 1 if i == 3 else 0
            flip = i >= 4; cy += [0, 0, 0, 0, 1, 3, 5, 7][i]
            alpha = [1, 1, 1, 1, 1, .8, .5, .25][i]; tw = [2, -2, 1, 0, 0, 0, 0, 0][i]
            if i >= 3:
                k = i - 3
                rising = [(cx - 4, 22 - k * 4, 6), (cx - 13, 26 - k * 5, 3), (cx + 6, 27 - k * 6, 3)]
        self.body(d, cx, cy, tw, em, mouth)
        img = outline(img)
        if flip:
            img = img.transpose(Image.FLIP_TOP_BOTTOM)
            sh = new(); sh.paste(img, (0, 2 * cy - (G - 1)), img); img = sh
        img = img if alpha == 1 else _fade(img, alpha)
        d = ImageDraw.Draw(img)
        if br:  # translucent air bladder on the back
            bx, by = cx - 4, cy - 9 - br + 2
            d.line((bx, by + br, bx, cy - 8), fill=self.BS)
            o2_bubble(d, bx, by, br)
        if pop:
            bx, by = cx - 4, cy - 16
            for a in range(0, 360, 45):
                x, y = bx + math.cos(math.radians(a)) * 11, by + math.sin(math.radians(a)) * 11
                d.line((x, y, bx + math.cos(math.radians(a)) * 14, by + math.sin(math.radians(a)) * 14), fill=(180, 240, 255, 255))
        for x, y, r in rising:
            if y - r > 0: o2_bubble(d, x, y, r)
        if sweat:
            d.point((cx + 10, cy - 10), fill=(180, 240, 255, 255))
            R(d, cx + 10, cy - 9, cx + 11, cy - 8, (180, 240, 255, 255))
        for bx, by, r in bubbles:
            if 1 < bx < G - 2: bubble(d, bx, by, r)
        if fl: img = flash(img)
        return img


def _fade(img, a):
    img.putalpha(img.getchannel("A").point(lambda v: int(v * a)))
    return img


CREATURES = [OxyFish()]
