import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from sprites import VARIANTS, ANIMS, G, new, draw_harpoon, outline

OUTDIR = "/home/claude/out/bathyscaphes"
S = 2  # 64 -> 128
CELL = G * S
COLS = max(n for _, n, _, _ in ANIMS)


def up(img, k=S):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def tres(v, sheet_rel):
    subs, anims, idx = [], [], 0
    for row, (an, n, fps, loop) in enumerate(ANIMS):
        frames = []
        for c in range(n):
            sid = f"at_{idx}"; idx += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1_tex")\n'
                        f'region = Rect2({c*CELL}, {row*CELL}, {CELL}, {CELL})\n')
            frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                     % (", ".join(frames), "true" if loop else "false", an, fps))
    head = f'[gd_resource type="SpriteFrames" load_steps={idx+2} format=3]\n\n' \
           f'[ext_resource type="Texture2D" path="res://bathyscaphes/{v.name}/{sheet_rel}" id="1_tex"]\n\n'
    return head + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n"


def tscn(v):
    return (f'[gd_scene load_steps=2 format=3]\n\n'
            f'[ext_resource type="SpriteFrames" path="res://bathyscaphes/{v.name}/{v.name}_frames.tres" id="1_sf"]\n\n'
            f'[node name="{v.name.capitalize()}" type="AnimatedSprite2D"]\n'
            f'texture_filter = 1\nsprite_frames = ExtResource("1_sf")\nanimation = &"idle"\nautoplay = "idle"\n')


def bg(w, h):
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        d.line((0, y, w, y), fill=(int(14 + 6 * (1 - t)), int(40 + 30 * (1 - t)), int(70 + 40 * (1 - t)), 255))
    return img


all_frames = {}
for v in VARIANTS:
    vd = os.path.join(OUTDIR, v.name); os.makedirs(vd, exist_ok=True)
    sheet = Image.new("RGBA", (CELL * COLS, CELL * len(ANIMS)), (0, 0, 0, 0))
    fr = {}
    for row, (an, n, fps, loop) in enumerate(ANIMS):
        fr[an] = [up(v.frame(an, i)) for i in range(n)]
        for c, f in enumerate(fr[an]):
            sheet.paste(f, (c * CELL, row * CELL))
    all_frames[v.name] = fr
    sheet.save(os.path.join(vd, f"{v.name}_sheet.png"))
    open(os.path.join(vd, f"{v.name}_frames.tres"), "w").write(tres(v, f"{v.name}_sheet.png"))
    open(os.path.join(vd, f"{v.name}.tscn"), "w").write(tscn(v))

# harpoon projectile
p = Image.new("RGBA", (16, 8), (0, 0, 0, 0))
from PIL import ImageDraw as _D
draw_harpoon(_D.Draw(p), 13, 4)
up(p).save(os.path.join(OUTDIR, "harpoon", "harpoon_projectile.png"))

# combined preview GIF: 3 variants side by side, sequence idle x2, move x2, attack, hurt
Z = 2
W, H = CELL * Z * 3 + 40, CELL * Z + 50
seq = []
for an, n, fps, loop in ANIMS:
    reps = 2 if loop else 1
    for _ in range(reps):
        for i in range(n):
            seq.append((an, i, int(1000 / fps)))
    if not loop:
        seq.append((an, n - 1, 300))
labels = {"idle": "IDLE", "move": "MOVE", "attack": "ATTACK", "hurt": "HURT"}
gif = []
base = bg(W, H)
for an, i, dur in seq:
    im = base.copy(); d = ImageDraw.Draw(im)
    for k, v in enumerate(VARIANTS):
        f = all_frames[v.name][an][min(i, len(all_frames[v.name][an]) - 1)]
        im.alpha_composite(up(f, Z), (20 + k * CELL * Z, 10))
        d.text((20 + k * CELL * Z + 8, H - 34), f"{k+1}. {v.name}", fill=(220, 240, 255, 255))
    d.text((W - 90, H - 34), labels[an], fill=(255, 230, 130, 255))
    gif.append((im.convert("RGB"), dur))
gif[0][0].save("/home/claude/out/preview.gif", save_all=True, append_images=[g for g, _ in gif[1:]],
               duration=[dd for _, dd in gif], loop=0, disposal=2)
# static contact sheet for checking
for v in VARIANTS:
    s = Image.open(os.path.join(OUTDIR, v.name, f"{v.name}_sheet.png"))
    b = bg(s.width, s.height); b.alpha_composite(s); b.save(f"/home/claude/out/check_{v.name}.png")
print("done")
