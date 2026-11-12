import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from sprites import G
from creatures import CREATURES as FISH, ANIMS

OUTDIR = "/home/claude/out/creatures"
S, CELL = 2, 128
COLS = max(n for _, n, _, _ in ANIMS)
up = lambda im, k=S: im.resize((im.width * k, im.height * k), Image.NEAREST)

def tres(v):
    subs, anims, idx = [], [], 0
    for row, (an, n, fps, loop) in enumerate(ANIMS):
        frames = []
        for c in range(n):
            sid = f"at_{idx}"; idx += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1_tex")\nregion = Rect2({c*CELL}, {row*CELL}, {CELL}, {CELL})\n')
            frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (", ".join(frames), "true" if loop else "false", an, fps))
    return (f'[gd_resource type="SpriteFrames" load_steps={idx+2} format=3]\n\n'
            f'[ext_resource type="Texture2D" path="res://creatures/{v.name}/{v.name}_sheet.png" id="1_tex"]\n\n'
            + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n")

def tscn(v):
    return (f'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="SpriteFrames" path="res://creatures/{v.name}/{v.name}_frames.tres" id="1_sf"]\n\n'
            f'[node name="{v.name.capitalize()}" type="AnimatedSprite2D"]\ntexture_filter = 1\nsprite_frames = ExtResource("1_sf")\nanimation = &"swim"\nautoplay = "swim"\n')

def bg(w, h):
    img = Image.new("RGBA", (w, h)); d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h; d.line((0, y, w, y), fill=(int(14 + 6*(1-t)), int(40 + 30*(1-t)), int(70 + 40*(1-t)), 255))
    return img

allf = {}
for v in FISH:
    vd = os.path.join(OUTDIR, v.name); os.makedirs(vd, exist_ok=True)
    sheet = Image.new("RGBA", (CELL*COLS, CELL*len(ANIMS)), (0,0,0,0)); fr = {}
    for row, (an, n, fps, loop) in enumerate(ANIMS):
        fr[an] = [up(v.frame(an, i)) for i in range(n)]
        for c, f in enumerate(fr[an]): sheet.paste(f, (c*CELL, row*CELL))
    allf[v.name] = fr
    sheet.save(f"{vd}/{v.name}_sheet.png")
    open(f"{vd}/{v.name}_frames.tres", "w").write(tres(v))
    open(f"{vd}/{v.name}.tscn", "w").write(tscn(v))
    b = bg(sheet.width, sheet.height); b.alpha_composite(sheet); b.save(f"/home/claude/out/ccheck_{v.name}.png")

Z = 2; Wd, H = CELL*Z*3 + 40, CELL*Z + 50
seq = []
for an, n, fps, loop in ANIMS:
    for _ in range(3 if loop else 1):
        for i in range(n): seq.append((an, i, int(1000/fps)))
    if not loop: seq.append((an, n-1, 500 if an == "death" else 250))
base = bg(Wd, H); gif = []
for an, i, dur in seq:
    im = base.copy(); d = ImageDraw.Draw(im)
    for k, v in enumerate(FISH):
        im.alpha_composite(up(allf[v.name][an][i], Z), (20 + k*CELL*Z, 10))
        d.text((20 + k*CELL*Z + 8, H - 34), f"{k+1}. {v.name}", fill=(220, 240, 255, 255))
    d.text((Wd - 90, H - 34), an.upper(), fill=(255, 230, 130, 255))
    gif.append((im.convert("RGB"), dur))
gif[0][0].save("/home/claude/out/creatures_preview.gif", save_all=True, append_images=[g for g,_ in gif[1:]], duration=[x for _,x in gif], loop=0)
print("ok")
