extends Node2D
## Пятно водорослей — пассивный источник кислорода (DESIGN.md п.3): пока
## батискаф находится внутри radius, медленно восполняет кислород. В отличие
## от пузырька (pickups/oxygen_bubble.gd) — не летит к игроку, а действует,
## пока сам не отдаст total_oxygen целиком: после этого плавно растворяется
## (см. _start_despawn) — одноразовый ресурс, а не бесконечный источник.
## Также исчезает (мгновенно, без анимации — она всё равно не видна за
## кадром), если игрок уходит от него дальше despawn_distance: спавнятся
## пятна часто (см. seaweed_spawner.gd) и без этого копились бы бесконечно.
##
## Визуализация временная и полностью процедурная (_draw, несколько
## колышущихся стеблей) — в будущем заменится на анимированный спрайт,
## параметры экспортов при этом не изменятся.

@export var radius: float = 110.0
@export var oxygen_per_second: float = 6.0
@export var total_oxygen: float = 60.0 # сколько всего кислорода отдаст пятно, прежде чем исчезнуть
@export var despawn_distance: float = 2000.0 # больше дистанции закадрового спавна (см. seaweed_spawner.gd) — не должно исчезать в кадре
@export var fade_out_duration: float = 1.2

const STALK_COUNT_MIN := 8
const STALK_COUNT_MAX := 13
const COLORS := [
	Color(0.18, 0.55, 0.28, 0.85),
	Color(0.22, 0.62, 0.35, 0.85),
	Color(0.15, 0.45, 0.30, 0.85),
]

class Stalk:
	var base_x: float
	var height: float
	var width: float
	var sway_amplitude: float
	var sway_freq: float
	var sway_phase: float
	var color: Color

var _stalks: Array[Stalk] = []
var _time: float = 0.0
var _player: Node2D
var _oxygen_remaining: float
var _despawning: bool = false


func _ready() -> void:
	add_to_group("seaweed")
	_player = get_tree().get_first_node_in_group("player")
	oxygen_per_second = Balance.get_value("items:seaweed:regen_per_second")
	_oxygen_remaining = total_oxygen

	var stalk_count := randi_range(STALK_COUNT_MIN, STALK_COUNT_MAX)
	for i in stalk_count:
		var stalk := Stalk.new()
		stalk.base_x = randf_range(-radius * 0.6, radius * 0.6)
		stalk.height = randf_range(radius * 0.7, radius * 1.3)
		stalk.width = randf_range(3.0, 6.0)
		stalk.sway_amplitude = randf_range(8.0, 18.0)
		stalk.sway_freq = randf_range(0.6, 1.3)
		stalk.sway_phase = randf() * TAU
		stalk.color = COLORS[randi() % COLORS.size()]
		_stalks.append(stalk)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _despawning:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var distance := global_position.distance_to(_player.global_position)

	# Далеко за кадром (пятна спавнятся часто, см. seaweed_spawner.gd) — само
	# исчезновение всё равно не видно, поэтому без плавного затухания.
	if distance > despawn_distance:
		queue_free()
		return

	if distance <= radius and _player.has_method("regenerate_oxygen") and _oxygen_remaining > 0.0:
		var amount := minf(oxygen_per_second * delta, _oxygen_remaining)
		_player.regenerate_oxygen(amount)
		_oxygen_remaining -= amount
		if _oxygen_remaining <= 0.0:
			_start_despawn()


## Пятно отдало весь total_oxygen — плавно растворяется и удаляется. В
## отличие от возврата по despawn_distance это происходит на глазах у
## игрока (он же только что стоял внутри radius), поэтому мгновенный
## queue_free() выглядел бы как резкое исчезновение.
func _start_despawn() -> void:
	if _despawning:
		return
	_despawning = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# Лёгкая мутная подсветка зоны эффекта — заодно временно помогает видеть
	# фактический radius при плейтесте, до замены на настоящий арт.
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.5, 0.3, 0.08))

	const SEGMENTS := 6
	for stalk in _stalks:
		var points := PackedVector2Array()
		for i in range(SEGMENTS + 1):
			var t := float(i) / SEGMENTS
			var y := -stalk.height * t
			var sway := sin(_time * stalk.sway_freq + stalk.sway_phase) * stalk.sway_amplitude * pow(t, 1.6)
			points.append(Vector2(stalk.base_x + sway, y))
		draw_polyline(points, stalk.color, stalk.width, true)
