extends Node2D
## Фонарик удильщика: желтоватое свечение с центром в его природном фонарике
## (эске на усике) плюс "дыра" в оверлее темноты глубины (world/lighting.gd) —
## удильщик подсвечивает небольшую область вокруг себя, выдавая себя в
## темноте, как и положено глубоководному хищнику с биолюминесценцией.
##
## Вешается на Node2D-якорь ПОД спрайтом (angler.tscn): позиция якоря —
## координаты эски в пикселях кадра (спрайт масштабирует детей сам). Якорь
## вращается вместе со спрайтом (курс рыбы), а при зеркальном отражении
## (flip_h, см. enemy.gd::_face_direction) скрипт зеркалит и свой X — flip_h
## на дочерние узлы не влияет, без компенсации свечение оставалось бы со
## старой стороны отражённой рыбы.
##
## Свечение видно и на мелководье (additive-спрайт), а "дыра" в темноте
## работает на глубине: lighting.gd собирает группу darkness_light каждый кадр.

## Радиус "дыры" в оверлее темноты (px экрана) и её сила (0..1 — насколько
## полностью темнота вырезается в центре).
@export var light_radius: float = 83.0
@export var light_strength: float = 0.9
## Диаметр видимого аддитивного свечения (px).
@export var glow_size: float = 50.0

const GLOW_TEXTURE_SIZE := 128

var _base_x: float = 0.0
var _glow: Sprite2D


func _ready() -> void:
	_base_x = position.x
	add_to_group("darkness_light")

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.6, 0.9),
		Color(1.0, 0.85, 0.4, 0.35),
		Color(1.0, 0.8, 0.3, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = GLOW_TEXTURE_SIZE
	texture.height = GLOW_TEXTURE_SIZE

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_glow = Sprite2D.new()
	_glow.texture = texture
	_glow.material = material
	_glow.scale = Vector2(glow_size, glow_size) / GLOW_TEXTURE_SIZE
	add_child(_glow)


func _process(_delta: float) -> void:
	# ВАЖНО: каст к Sprite2D давал null (AnimatedSprite2D ему не наследник —
	# в этой сборке его родитель напрямую Node2D), из-за чего зеркаление не
	# применялось и у развёрнутых рыб свечение оставалось "за спиной".
	var sprite := get_parent() as AnimatedSprite2D
	if sprite:
		position.x = -_base_x if sprite.flip_h else _base_x
