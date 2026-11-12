"""Mutant sea creatures. Logical 64x64 -> 128x128. Facing right."""
import math, random
from PIL import Image, ImageDraw
from sprites import G, OUT, new, outline, flash, bubble, E, R
from fish import eye

ANIMS = [("swim", 6, 10.0, True), ("attack", 8, 12.0, False), ("hurt", 3, 10.0, False), ("death", 8, 10.0, False)]
W = (255, 255, 255, 255)


def fade(img, a):
    if a < 1:
        img.putalpha(img.getchannel("A").point(lambda v: int(v * a)))
    return img


def desat(img, k):
    px = img.load()
    for y in range(G):
        for x in range(G):
            r, g, b, a = px[x, y]
            if a and (r, g, b, a) != OUT:
                m = (r + g + b) // 3
                px[x, y] = (int(r + (m - r) * k), int(g + (m - g) * k), int(b + (m - b) * k), a)
    return img


def star(d, x, y, s, c=(255, 245, 160, 255)):
    for a in range(0, 360, 45):
        ln = s if a % 90 == 0 else s - 1
        d.line((x, y, x + round(math.cos(math.radians(a)) * ln), y + round(math.sin(math.radians(a)) * ln)), fill=c)


def bolt(d, x0, y0, x1, y1, seed, c=(190, 255, 255, 255)):
    rnd = random.Random(seed); pts = [(x0, y0)]
    n = max(3, abs(x1 - x0) // 4)
    for k in range(1, n):
        pts.append((x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n + rnd.randint(-3, 3)))
    pts.append((x1, y1))
    d.line(pts, fill=c)
    d.line([(x, y + 1) for x, y in pts], fill=(90, 200, 255, 255))


# ------------------------------------------------------------------ squid
class Squid:
    name, title = "squid", "Спрут-мутант"
    B, BS, BH = (195, 65, 125, 255), (140, 40, 95, 255), (240, 130, 175, 255)
    SPOT = (120, 35, 85, 255)
    SUCK = (250, 190, 210, 255)
    EYE = (255, 220, 70, 255)

    def tentacle(self, d, x, y, length, ang, wave, t, thick=2):
        px, py = x, y
        for k in range(length):
            f = k / length
            a = ang + wave * math.sin(t + k * 0.5) * f
            nx, ny = px + math.cos(a) * 1.6, py + math.sin(a) * 1.6
            r = max(0, round(thick * (1 - f) + 0.4))
            E(d, round(nx) - r, round(ny) - r, round(nx) + r, round(ny) + r, self.B if k % 3 else self.BS)
            px, py = nx, ny
        return round(px), round(py)

    def frame(self, anim, i):
        img = new(); d = ImageDraw.Draw(img)
        cx, cy = 30, 26
        t = i / 6 * 2 * math.pi
        spread, wave, em, lash, droop, ink = 0.0, 0.5, "open", 0, 0.0, 0
        fl, alpha, gray = False, 1.0, 0
        if anim == "swim":
            spread = 0.35 * math.sin(t); cy += round(-1.5 * math.sin(t))
        elif anim == "attack":
            t = i / 8 * 2 * math.pi
            cx += [0, -2, -3, 0, 3, 3, 1, 0][i]
            lash = [0, 0, 4, 14, 22, 22, 12, 4][i]
            em = "angry"; spread = 0.2
        elif anim == "hurt":
            cx += [-3, 1, 0][i]; em = "hurt"; fl = i == 0; spread = 0.4
        elif anim == "death":
            em = ["hurt", "hurt", "dead", "dead", "dead", "dead", "dead", "dead"][i]
            fl = i == 0; cx += [-3, 2, 0, 0, 0, 0, 0, 0][i]
            droop = min(1, i / 4); wave = 0.5 * (1 - droop)
            cy += [0, 0, 1, 2, 4, 7, 10, 13][i]
            ink = [0, 6, 9, 11, 0, 0, 0, 0][i]
            gray = min(0.85, i * 0.15)
            alpha = [1, 1, 1, 1, 1, 0.8, 0.5, 0.2][i]
        # back tentacles (trail left-down)
        for n in range(4):
            base_ang = math.radians(150 - n * 22) + spread * (1 if n < 2 else -1)
            base_ang = base_ang * (1 - droop) + math.radians(95 + n * 4) * droop
            self.tentacle(d, cx - 4 + n * 3, cy + 2, 14, base_ang, wave, t + n, 2)
        # lashing front tentacles
        tips = []
        for n, off in enumerate((0, 3)):
            if lash:
                ang = math.radians(10 + n * 12)
                tips.append(self.tentacle(d, cx + 6, cy + 1 + off, 4 + lash // 2 + n * 2, ang, 0.15, t, 2))
            else:
                a = math.radians(70 + n * 15) * (1 - droop) + math.radians(90) * droop
                tips.append(self.tentacle(d, cx + 6, cy + 1 + off, 12, a, wave, t + 2 + n, 2))
        # mantle
        E(d, cx - 12, cy - 18, cx + 12, cy + 4, self.BS)
        E(d, cx - 12, cy - 18, cx + 11, cy + 2, self.B)
        E(d, cx - 8, cy - 15, cx - 2, cy - 11, self.BH)
        for sx, sy in ((cx - 6, cy - 5), (cx - 9, cy - 1), (cx + 1, cy - 15), (cx - 3, cy - 2)):
            R(d, sx, sy, sx + 1, sy + 1, self.SPOT)
        # three mutant eyes
        if em in ("open", "angry"):
            E(d, cx + 1, cy - 9, cx + 9, cy - 1, self.EYE)
            R(d, cx + 5, cy - 8, cx + 6, cy - 2, OUT)
            d.point((cx + 3, cy - 7), fill=W)
            if em == "angry":
                d.line((cx + 1, cy - 11, cx + 9, cy - 8), fill=OUT); d.line((cx + 1, cy - 10, cx + 8, cy - 8), fill=OUT)
            eye(d, cx - 3, cy - 6, em, r=2, brow=False)
            eye(d, cx + 5, cy - 14, em, r=2, brow=False)
        else:
            eye(d, cx + 5, cy - 5, em, r=3)
            eye(d, cx - 3, cy - 6, em, r=2, brow=False); eye(d, cx + 5, cy - 14, em, r=2, brow=False)
        # beak
        d.polygon([(cx + 7, cy), (cx + 11, cy + 1), (cx + 7, cy + 3)], fill=(240, 220, 150, 255))
        img = outline(img); d = ImageDraw.Draw(img)
        if lash >= 22:
            for tx, ty in tips: star(d, min(tx + 3, G - 5), ty, 4 if i == 4 else 2)
        if gray: img = desat(img, gray); d = ImageDraw.Draw(img)
        if ink:
            for k, (ox, oy) in enumerate(((-14, 6), (-18, 0), (-10, 12), (-20, 10))):
                r = max(1, ink // 2 - k)
                E(d, cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r, (30, 20, 45, 200))
        if anim == "swim" and i in (2, 3, 4):
            bubble(d, cx - 16, cy + 18 - (i - 2) * 3, (i % 2))
        if anim == "death" and i >= 3:
            for k in range(2): bubble(d, cx - 2 + k * 6, cy - 22 - (i - 3) * 2 - k * 4, (i + k) % 2)
        if fl: img = flash(img)
        return fade(img, alpha)


# ------------------------------------------------------------------ eel
class Eel:
    name, title = "eel", "Электромурена"
    B, BS, BEL = (45, 100, 80, 255), (25, 60, 55, 255), (150, 190, 80, 255)
    SP_OFF, SP_ON = (60, 140, 160, 255), (150, 250, 255, 255)
    EYE = (255, 70, 60, 255)

    def frame(self, anim, i):
        img = new(); d = ImageDraw.Draw(img)
        cx, cy = 30, 32
        t = i / 6 * 2 * math.pi
        amp, open_, glow, em, zap, fl, alpha, flip = 5.0, 0, i % 2 == 0, "open", 0, False, 1.0, False
        if anim == "swim":
            pass
        elif anim == "attack":
            t = i / 8 * 2 * math.pi
            amp = [5, 4, 3, 2, 1, 2, 3, 4][i]
            cx += [0, -2, -3, 3, 6, 5, 2, 0][i]
            open_ = [0, 1, 2, 3, 3, 2, 1, 0][i]
            glow = i < 6; zap = i in (3, 4, 5); em = "angry"
        elif anim == "hurt":
            cx += [-3, 1, 0][i]; em = "hurt"; fl = i == 0; amp = 6
        elif anim == "death":
            em = ["hurt", "hurt", "dead", "dead", "dead", "dead", "dead", "dead"][i]
            fl = i == 0; cx += [-3, 2, 0, 0, 0, 0, 0, 0][i]
            amp = [6, 6, 3, 2, 1, 1, 1, 1][i]; glow = i == 1; flip = i >= 3; open_ = 1 if i >= 2 else 0
            cy += [0, 0, 0, 0, 2, 4, 6, 8][i]; alpha = [1, 1, 1, 1, 1, .8, .5, .2][i]
        tail, head = cx - 26, cx + 12
        path = []
        for x in range(tail, head + 1):
            f = (x - tail) / (head - tail)
            y = cy + amp * math.sin(t * (1 if anim != "death" else 0) - x * 0.22) * (1 - f) ** 1.3
            path.append((x, y, 1.2 + 3.8 * f ** 0.7))
        # tail fin
        tx, ty, _ = path[0]
        d.polygon([(tx + 3, ty - 1), (tx - 3, ty - 5), (tx - 2, ty + 1), (tx - 3, ty + 5), (tx + 3, ty + 2)], fill=self.BS)
        for x, y, r in path:
            E(d, x - r, y - r, x + r, y + r, self.B)
        for x, y, r in path:
            if r > 2: E(d, x - r + 1, y, x + r - 1, y + r, self.BEL)
        # spines
        for k in range(4, len(path) - 6, 5):
            x, y, r = path[k]
            d.polygon([(x - 1, y - r), (x + 2, y - r), (x - 2, y - r - 3 - (k % 2))], fill=self.SP_ON if glow else self.SP_OFF)
        # head
        hx, hy, _ = path[-1]; hx, hy = round(hx), round(hy)
        E(d, hx - 6, hy - 6, hx + 7, hy + 5, self.B)
        if open_:
            d.polygon([(hx + 1, hy + 1), (hx + 10, hy - 3 - open_), (hx + 10, hy + 5 + open_)], fill=(90, 20, 40, 255))
            for x in range(hx + 4, hx + 10, 2):
                d.line((x, hy - 1 - open_ + (hx + 10 - x) // 3, x, hy - open_ + (hx + 10 - x) // 3), fill=W)
                d.line((x, hy + 3 + open_ - (hx + 10 - x) // 3, x, hy + 2 + open_ - (hx + 10 - x) // 3), fill=W)
        else:
            d.polygon([(hx + 4, hy - 3), (hx + 11, hy), (hx + 4, hy + 3)], fill=self.B)
            d.line((hx + 3, hy + 1, hx + 10, hy + 1), fill=OUT)
            d.line((hx + 9, hy + 1, hx + 9, hy + 3), fill=W)
        if em in ("open", "angry"):
            E(d, hx, hy - 5, hx + 3, hy - 2, self.EYE); d.point((hx + 2, hy - 4), fill=W)
            d.line((hx - 1, hy - 7, hx + 4, hy - 4), fill=OUT)
        else:
            eye(d, hx + 2, hy - 4, em, r=1)
        img = outline(img)
        if flip:
            img = img.transpose(Image.FLIP_TOP_BOTTOM)
            sh = new(); sh.paste(img, (0, 2 * cy - (G - 1)), img); img = sh
        d = ImageDraw.Draw(img)
        if glow and anim == "attack" and i in (1, 2):
            for k in range(6, len(path) - 6, 9):
                x, y, r = path[k]; star(d, round(x), round(y - r - 5), 2, self.SP_ON)
        if zap:
            mx, my = hx + 11, hy + 1
            bolt(d, mx, my, G - 2, my + (i - 4) * 3, i)
            if i == 4: bolt(d, mx, my, G - 6, my - 8, i + 9); star(d, mx, my, 3, W)
        if anim == "swim" and i in (1, 4):
            bubble(d, tail - 2 + (i // 4) * 4, cy - 6, i % 2)
        if anim == "death" and i >= 3:
            for k in range(2): bubble(d, cx - 6 + k * 10, cy - 10 - (i - 3) * 3, (i + k) % 2)
        if fl: img = flash(img)
        return fade(img, alpha)


# ------------------------------------------------------------------ puffer mine
class Mine:
    name, title = "puffermine", "Иглобомба"
    B, BS, BH = (150, 140, 75, 255), (105, 95, 50, 255), (200, 190, 120, 255)
    BEL = (225, 210, 160, 255)
    HORN, HORNT = (120, 125, 140, 255), (220, 60, 50, 255)
    FIN = (200, 120, 60, 255)

    def body(self, d, cx, cy, r, horn, em, blink, tw, mouth):
        # tail & fins
        d.polygon([(cx - r + 1, cy - 1), (cx - r - 6, cy - 5 + tw), (cx - r - 6, cy + 5 + tw), (cx - r + 1, cy + 2)], fill=self.FIN)
        d.polygon([(cx - 2, cy + r - 2), (cx + 3, cy + r - 2), (cx - 3, cy + r + 3 + tw // 2)], fill=self.FIN)
        # horns (mine contacts)
        for a in range(-90, 270, 45):
            if a == 0: continue  # face side
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            bx, by = cx + ca * r, cy + sa * r
            ex, ey = cx + ca * (r + horn), cy + sa * (r + horn)
            d.line((bx, by, ex, ey), fill=self.HORN, width=3)
            tc = self.HORNT if (a != -90 or blink) else (110, 40, 40, 255)
            E(d, ex - 1.5, ey - 1.5, ex + 1.5, ey + 1.5, tc if a != -90 else ((255, 80, 60, 255) if blink else (110, 40, 40, 255)))
        E(d, cx - r, cy - r, cx + r, cy + r, self.BS)
        E(d, cx - r, cy - r, cx + r - 1, cy + r - 2, self.B)
        E(d, cx - r + 3, cy, cx + r - 2, cy + r - 2, self.BEL)
        E(d, cx - r + 3, cy - r + 3, cx - r // 3, cy - r // 3, self.BH)
        # weld seam with rivets
        d.line((cx - r + 1, cy - 1, cx + r - 1, cy - 1), fill=self.BS)
        for x in range(cx - r + 3, cx + r - 2, 4): d.point((x, cy - 2), fill=self.BH)
        # face
        ex = cx + r // 3
        eye(d, ex, cy - r // 3 - 1, em, r=2)
        eye(d, ex + 6, cy - r // 3, em, r=2)
        mx = cx + r - 4
        if mouth:
            E(d, mx - 2, cy + 3, mx + 2, cy + 7, (90, 20, 40, 255)); d.point((mx, cy + 3), fill=W)
        else:
            d.line((mx - 3, cy + 5, mx + 2, cy + 4), fill=OUT)
            d.point((mx - 1, cy + 6), fill=W); d.point((mx + 1, cy + 5), fill=W)

    def frame(self, anim, i):
        img = new(); d = ImageDraw.Draw(img)
        cx, cy = 30, 32
        t = i / 6 * 2 * math.pi
        r, horn, em, mouth, fl, alpha = 10, 3, "angry", 0, False, 1.0
        tw = round(math.sin(t * 2) * 2); blink = i % 3 == 0
        spikes, boom = 0, 0
        if anim == "swim":
            cy += round(math.sin(t) * 1.5); em = "open"
        elif anim == "attack":
            r = [10, 12, 14, 15, 13, 11, 10, 10][i]; horn = [3, 4, 5, 6, 3, 2, 3, 3][i]
            mouth = i in (1, 2, 3); spikes = [0, 0, 0, 0, 18, 25, 0, 0][i]; blink = i < 4
        elif anim == "hurt":
            cx += [-3, 1, 0][i]; em = "hurt"; fl = i == 0
        elif anim == "death":
            em = "hurt"; fl = i in (0, 2); blink = i in (0, 2)
            r = [11, 13, 15, 16, 0, 0, 0, 0][i]; horn = [3, 4, 5, 6, 0, 0, 0, 0][i]; mouth = i in (1, 2, 3)
            cx += [-2, 2, -1, 1, 0, 0, 0, 0][i]
            boom = [0, 0, 0, 0, 1, 2, 3, 4][i]
        if r:
            self.body(d, cx, cy, r, horn, em, blink, tw, mouth)
            img = outline(img); d = ImageDraw.Draw(img)
        if spikes:
            for a in range(-90, 270, 45):
                if a == 0: continue
                ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
                x0, y0 = cx + ca * spikes, cy + sa * spikes
                d.line((x0, y0, x0 + ca * 4, y0 + sa * 4), fill=(235, 235, 245, 255), width=1)
                d.point((round(x0 + ca * 4), round(y0 + sa * 4)), fill=self.HORNT)
        if boom:
            rnd = random.Random(7)
            if boom == 1:
                E(d, cx - 14, cy - 14, cx + 14, cy + 14, (255, 240, 170, 255))
                E(d, cx - 9, cy - 9, cx + 9, cy + 9, W)
                star(d, cx, cy, 20 if 20 < cx else 18, (255, 250, 220, 255))
            elif boom == 2:
                E(d, cx - 18, cy - 18, cx + 18, cy + 18, (250, 140, 50, 255))
                E(d, cx - 12, cy - 12, cx + 12, cy + 12, (255, 220, 110, 255))
                for k in range(8):
                    a = rnd.random() * 6.28; dd = 20 + rnd.random() * 6
                    R(d, cx + math.cos(a) * dd, cy + math.sin(a) * dd, cx + math.cos(a) * dd + 1, cy + math.sin(a) * dd + 1, self.BS)
            else:
                k = boom - 3
                col = (120, 115, 120, 255) if k == 0 else (90, 90, 100, 255)
                for n in range(7):
                    a = n / 7 * 6.28 + 0.4; dd = 9 + k * 6
                    pr = 6 - k * 2
                    x, y = cx + math.cos(a) * dd, cy + math.sin(a) * dd - k * 3
                    E(d, x - pr, y - pr, x + pr, y + pr, col)
                for n in range(3):
                    bubble(d, cx - 8 + n * 8, cy - 10 - k * 8 - n * 2, 1)
                alpha = 1 if k == 0 else 0.5
        if anim == "swim" and i in (2, 5):
            bubble(d, cx - 20, cy + 2 - (i // 5) * 4, i % 2)
        if fl: img = flash(img)
        return fade(img, alpha)


CREATURES = [Squid(), Eel(), Mine()]
