extends CanvasLayer
## Темнота глубины (Light/Vision System, DESIGN.md п.6): полноэкранный
## оверлей, затемняющий всё ВОНЕ светового круга фонаря вокруг игрока.
## Внутри круга видимость обычная (как на мелководье первой волны), снаружи
## вода темнеет с глубиной — дальних рыб становится всё хуже видно.
##
## Подход — именно затемнение неосвещённой области, а не высвечивание
## освещённой (PointLight2D + CanvasModulate убраны): круг фонаря вырезан
## в тёмном оверлее шейдером (радиус — Баланс → Игрок → Фонарь, применяется
## на лету). Оверлей живёт на CanvasLayer выше мира, но ниже UI (HUD/магазин/
## меню идут позже в дереве и рисуются поверх), мышь сквозь него проходит.
##
## На мелководье (до shallow_depth) затемнения нет вовсе — оверлей скрыт.

## До этой глубины (м) вода полностью прозрачная — затемнения нет.
@export var shallow_depth: float = 120.0
## За сколько метров после shallow_depth темнота нарастает до максимума.
@export var darkness_ramp: float = 700.0
## Потолок затемнения за пределами круга фонаря (0..1).
@export var max_darkness: float = 0.88
## Цвет глубоководной темноты (холодный сине-чёрный, не чистый чёрный,
## чтобы силуэты врагов угадывались).
@export var dark_color: Color = Color(0.02, 0.05, 0.10)
## Ширина мягкой кромки круга фонаря (px) — темнота нарастает плавно,
## без жёсткой границы света.
@export var falloff: float = 160.0

const SHADER_CODE := "
shader_type canvas_item;

uniform vec2 resolution = vec2(1920.0, 1080.0);
uniform vec2 center = vec2(960.0, 540.0);
uniform float radius = 260.0;
uniform float falloff = 160.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint = vec3(0.02, 0.05, 0.1);

void fragment() {
	vec2 px = UV * resolution;
	float d = distance(px, center);
	float k = smoothstep(radius, radius + falloff, d);
	COLOR = vec4(tint, k * darkness);
}
"

var _material: ShaderMaterial
var _rect: ColorRect


func _ready() -> void:
	layer = 1

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader

	_rect = ColorRect.new()
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func _process(_delta: float) -> void:
	var depth := DepthManager.current_depth
	var darkness := clampf((depth - shallow_depth) / darkness_ramp, 0.0, 1.0) * max_darkness
	# На мелководье оверлей полностью прозрачный — не тратим фрагменты зря.
	_rect.visible = darkness > 0.001
	if not _rect.visible:
		return

	var view := get_viewport().get_visible_rect().size
	var center := view * 0.5
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		# Экранная позиция игрока через canvas transform — круг остаётся на
		# игроке даже при сглаживании/ограничениях камеры.
		center = get_viewport().get_canvas_transform() * (player as Node2D).global_position

	_material.set_shader_parameter("resolution", view)
	_material.set_shader_parameter("center", center)
	_material.set_shader_parameter("radius", Balance.get_value("player:flashlight:radius"))
	_material.set_shader_parameter("falloff", falloff)
	_material.set_shader_parameter("darkness", darkness)
	_material.set_shader_parameter("tint", Vector3(dark_color.r, dark_color.g, dark_color.b))
