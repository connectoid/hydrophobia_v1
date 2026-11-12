import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from items import ITEMS

OUTDIR = "/home/claude/out/items"
up = lambda im, k=2: im.resize((im.width * k, im.height * k), Image.NEAREST)


def tres(v, cell):
    subs, anims, idx = [], [], 0
    for row, (an, n, fps, loop) in enumerate(v.ANIMS):
        frames = []
        for c in range(n):
            sid = f"at_{idx}"; idx += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1_tex")\nregion = Rect2({c*cell}, {row*cell}, {cell}, {cell})\n')
            frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (", ".join(frames), "true" if loop else "false", an, fps))
    return (f'[gd_resource type="SpriteFrames" load_steps={idx+2} format=3]\n\n'
            f'[ext_resource type="Texture2D" path="res://items/{v.name}/{v.name}_sheet.png" id="1_tex"]\n\n'
            + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n")


def tscn(v):
    return (f'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="SpriteFrames" path="res://items/{v.name}/{v.name}_frames.tres" id="1_sf"]\n\n'
            f'[node name="{v.name.title().replace("_", "")}" type="AnimatedSprite2D"]\ntexture_filter = 1\nsprite_frames = ExtResource("1_sf")\nanimation = &"idle"\nautoplay = "idle"\n')


def bg(w, h):
    img = Image.new("RGBA", (w, h)); d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h; d.line((0, y, w, y), fill=(int(14 + 6*(1-t)), int(40 + 30*(1-t)), int(70 + 40*(1-t)), 255))
    return img


frames = {}
for v in ITEMS:
    cell = v.size * 2
    cols = max(n for _, n, _, _ in v.ANIMS)
    vd = os.path.join(OUTDIR, v.name); os.makedirs(vd, exist_ok=True)
    sheet = Image.new("RGBA", (cell * cols, cell * len(v.ANIMS)), (0, 0, 0, 0)); fr = {}
    for row, (an, n, fps, loop) in enumerate(v.ANIMS):
        fr[an] = [(up(v.frame(an, i)), int(1000 / fps)) for i in range(n)]
        for c, (f, _) in enumerate(fr[an]): sheet.paste(f, (c * cell, row * cell))
    frames[v.name] = fr
    sheet.save(f"{vd}/{v.name}_sheet.png")
    open(f"{vd}/{v.name}_frames.tres", "w").write(tres(v, cell))
    open(f"{vd}/{v.name}.tscn", "w").write(tscn(v))
    b = bg(sheet.width, sheet.height); b.alpha_composite(sheet); up(b, 1).save(f"/home/claude/out/icheck_{v.name}.png")

# preview: chest sequence (left, 2x) + orbs & oxygen (right, 2x) looping idle then collect
Z = 2
Wd, H = 128 * Z + 64 * Z * 4 + 60, 128 * Z + 40
chest_seq = []
for an, n, fps, loop in ITEMS[0].ANIMS:
    for _ in range(2 if loop else 1):
        chest_seq += [(an, i) for i in range(n)]
    if not loop: chest_seq += [(an, n - 1)] * 2
small_seq = []
for an, n, fps, loop in ITEMS[1].ANIMS:
    for _ in range(3 if loop else 1):
        small_seq += [(an, i) for i in range(n)]
    if not loop: small_seq += [(an, n - 1)] * 4
L = max(len(chest_seq), len(small_seq))
base = bg(Wd, H); gif = []
for t in range(L):
    im = base.copy(); d = ImageDraw.Draw(im)
    an, i = chest_seq[t % len(chest_seq)]
    im.alpha_composite(up(frames["health_chest"][an][i][0], Z), (10, 0))
    d.text((20, H - 30), f"health_chest: {an}", fill=(255, 230, 130, 255))
    an2, i2 = small_seq[t % len(small_seq)]
    for k, nm in enumerate(["xp_small", "xp_medium", "xp_large", "oxygen"]):
        x = 128 * Z + 30 + k * 64 * Z
        im.alpha_composite(up(frames[nm][an2][i2][0], Z), (x, 60))
        d.text((x + 10, H - 30), nm, fill=(220, 240, 255, 255))
    d.text((128 * Z + 40, 20), an2, fill=(255, 230, 130, 255))
    gif.append(im.convert("RGB"))
gif[0].save("/home/claude/out/items_preview.gif", save_all=True, append_images=gif[1:], duration=90, loop=0)
print("ok")
