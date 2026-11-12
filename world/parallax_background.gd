extends Node2D
## Процедурный параллакс-фон (ПЛЕЙСХОЛДЕР): три слоя Parallax2D с бесшовными
## плитками, сгенерированными кодом при старте уровня (мягкие пятна-"взвесь"
## разного размера и контраста). Эффект параллакса работает во всех
## направлениях — и при вертикальном погружении, и при горизонтальных
## заплывах: Parallax2D сам бесконечно тайлит текстуру вокруг камеры,
## scroll_scale у слоёв разный (дальний медленный, ближний быстрый).
##
## Слои лежат поверх DepthBackground (z_index -10) и под геймплеем (z >= 0);
## затемнение по глубине выполняет общий CanvasModulate (world/lighting.gd),
## который вместе с фонарём игрока составляет систему света/темноты.
##
## ЗАМЕНИТЬ на пользовательские PNG (assets/backgrounds/parallax_{far,mid,
## near}.png, бесшовные плитки 1024×1024 с альфой): когда файлы появятся,
## достаточно грузить их вместо _make_blob_texture() — структура слоёв,
## scroll_scale и z-порядок остаются теми же.

## Конфиги слоёв: размер плитки, скорость параллакса, число пятен, их радиусы,
## цвет и z-порядок. Дальний — крупные, едва заметные пятна и минимальный
## scroll_scale; ближний — мелкая контрастная взвесь и почти 1:1 с камерой.
const LAYERS := [
	{
		"tile": 1024, "scroll": 0.2, "z": -9,
		"blobs": 8, "radius_min": 130.0, "radius_max": 250.0,
		"color": Color(0.45, 0.65, 0.85, 0.05),
	},
	{
		"tile": 768, "scroll": 0.5, "z": -8,
		"blobs": 26, "radius_min": 26.0, "radius_max": 60.0,
		"color": Color(0.6, 0.8, 1.0, 0.07),
	},
	{
		"tile": 512, "scroll": 0.8, "z": -7,
		"blobs": 70, "radius_min": 5.0, "radius_max": 14.0,
		"color": Color(0.85, 0.95, 1.0, 0.12),
	},
]

## Затемнение по глубине здесь больше не своё: его выполняет общий
## CanvasModulate (world/lighting.gd) вместе с фонарём игрока — собственный
## tint давал бы двойное потемнение слоёв.


func _ready() -> void:
	var view := get_viewport().get_visible_rect().size
	for cfg in LAYERS:
		var tile: int = cfg["tile"]
		# Parallax2D в Godot 4.5 сам ничего не рисует — он лишь смещает детей
		# относительно камеры (scroll_scale) и зацикливает своё положение
		# (repeat_size). Картинку держит дочерний Sprite2D с включённым
		# region-повтором. ВАЖНО: запас region_rect — view + 4 тайла (по 2 с
		# каждой стороны). Узел слоя при зацикливании смещается относительно
		# центра экрана вплоть до repeat_size, и при меньшем запасе (view +
		# 2 тайла) покрытие сходило впритык/внахлёст-впритык: у края экрана
		# слой периодически не дорисовывался (тусклая полоса), а после
		# переноса резко возвращался. Текстура бесшовная — стыки region-копий
		# неразличимы, лишние тайлы ничего не стоят (это UV-повтор, не память).
		var layer := Parallax2D.new()
		layer.scroll_scale = Vector2(cfg["scroll"], cfg["scroll"])
		layer.repeat_size = Vector2(tile, tile)
		layer.z_index = cfg["z"]
		var sprite := Sprite2D.new()
		sprite.texture = _make_blob_texture(cfg)
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, view + Vector2(tile, tile) * 4.0)
		layer.add_child(sprite)
		add_child(layer)


## Бесшовная плитка из мягких круглых пятен: каждое пятно рисуется с
## квадратичным затуханием к краю и дополнительно штампуется через границу
## плитки (wrap), чтобы стыки тайлов были неразличимы по всем четырём
## сторонам — Parallax2D повторяет текстуру бесконечно.
func _make_blob_texture(cfg: Dictionary) -> ImageTexture:
	var tile: int = cfg["tile"]
	var img := Image.create_empty(tile, tile, false, Image.FORMAT_RGBA8)
	var color: Color = cfg["color"]
	for i in int(cfg["blobs"]):
		var center := Vector2(randf() * tile, randf() * tile)
		var radius := randf_range(cfg["radius_min"], cfg["radius_max"])
		# Обычный штамп + wrap-копии, только если пятно пересекает границу.
		var xs := [center.x]
		if center.x - radius < 0.0:
			xs.append(center.x + tile)
		elif center.x + radius > float(tile):
			xs.append(center.x - tile)
		var ys := [center.y]
		if center.y - radius < 0.0:
			ys.append(center.y + tile)
		elif center.y + radius > float(tile):
			ys.append(center.y - tile)
		for x in xs:
			for y in ys:
				_stamp_blob(img, Vector2(x, y), radius, color)
	return ImageTexture.create_from_image(img)


## Рисует одно мягкое пятно в пределах его bounding box (не по всей плитке)
## с альфа-композитингом поверх уже нарисованного.
func _stamp_blob(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var tile := img.get_width()
	var min_x := maxi(int(center.x - radius), 0)
	var max_x := mini(int(center.x + radius) + 1, tile)
	var min_y := maxi(int(center.y - radius), 0)
	var max_y := mini(int(center.y + radius) + 1, tile)
	var r_sq := radius * radius
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			var dx := x - center.x
			var dy := y - center.y
			var d_sq := dx * dx + dy * dy
			if d_sq >= r_sq:
				continue
			var falloff := 1.0 - d_sq / r_sq
			var a := color.a * falloff * falloff
			if a <= 0.001:
				continue
			var existing := img.get_pixel(x, y)
			var new_a := minf(existing.a + a, 1.0)
			if new_a <= existing.a:
				continue
			var blend := (existing * existing.a + color * a) / new_a
			blend.a = new_a
			img.set_pixel(x, y, blend)
