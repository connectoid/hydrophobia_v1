extends Node2D
## Затонувший исследовательский модуль — пассивный источник восстановления
## прочности корпуса (см. player.gd::regenerate_durability): пока батискаф
## внутри radius, медленно её восполняет. Спавн/деспаун/одноразовость — по
## аналогии с водорослями (world/seaweed.gd, см. также
## research_module_spawner.gd): отдаёт total_durability целиком и плавно
## растворяется, либо мгновенно исчезает, если игрок уходит дальше
## despawn_distance.
##
## Появляются только в волнах, где корпус вообще получает урон от давления
## (см. player.gd::_process_durability_drain, current_wave >= 2) — иначе
## чинить было бы нечего; сам гейт по волне — в спавнере, не здесь.
##
## Визуализация временная и полностью процедурная (_draw) — голубоватая сфера
## с мигающим оранжевым маячком; в будущем заменится на текстуру/анимацию,
## параметры экспортов при этом не изменятся.

@export var radius: float = 200.0
@export var durability_per_second: float = 8.0
@export var total_durability: float = 40.0 # сколько всего прочности отдаст модуль, прежде чем исчезнуть
@export var despawn_distance: float = 2000.0 # больше дистанции закадрового спавна (см. research_module_spawner.gd) — не должно исчезать в кадре
@export var fade_out_duration: float = 1.2

const BODY_RADIUS := 84.0
const BLINK_PERIOD := 1.4 # сек, полный цикл маячка
const BLINK_ON_DURATION := 0.25 # сек, сколько из периода лампочка ярко горит

var _time: float = 0.0
var _player: Node2D
var _durability_remaining: float
var _despawning: bool = false


func _ready() -> void:
	add_to_group("research_module")
	_player = get_tree().get_first_node_in_group("player")
	durability_per_second = Balance.get_value("items:module:regen_per_second")
	total_durability = Balance.get_value("items:module:total")
	_durability_remaining = total_durability


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

	# Далеко за кадром (модуль всё равно не виден) — без плавного затухания.
	if distance > despawn_distance:
		queue_free()
		return

	if distance <= radius and _player.has_method("regenerate_durability") and _durability_remaining > 0.0:
		var amount := minf(durability_per_second * delta, _durability_remaining)
		_player.regenerate_durability(amount)
		_durability_remaining -= amount
		if _durability_remaining <= 0.0:
			_start_despawn()


## Модуль отдал весь total_durability — плавно растворяется и удаляется (в
## отличие от возврата по despawn_distance это происходит на глазах у
## игрока, поэтому мгновенный queue_free() выглядел бы как резкий обрыв).
func _start_despawn() -> void:
	if _despawning:
		return
	_despawning = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# Лёгкая мутная подсветка зоны эффекта — временно помогает видеть
	# фактический radius при плейтесте, до замены на настоящий арт.
	draw_circle(Vector2.ZERO, radius, Color(0.15, 0.35, 0.5, 0.06))

	# Корпус модуля — голубоватая сфера в несколько слоёв для объёма, плюс блик.
	draw_circle(Vector2.ZERO, BODY_RADIUS, Color(0.22, 0.42, 0.58, 0.95))
	draw_circle(Vector2.ZERO, BODY_RADIUS * 0.78, Color(0.32, 0.55, 0.7, 0.9))
	draw_circle(Vector2(-BODY_RADIUS * 0.32, -BODY_RADIUS * 0.32), BODY_RADIUS * 0.3, Color(0.75, 0.9, 1.0, 0.45))

	# Иллюминатор в центре — сама лампочка в нём и мигает (резкий цикл
	# вспышка/затухание, а не плавное дыхание, чтобы читалось именно как
	# "мигает", а не "пульсирует").
	var phase := fmod(_time, BLINK_PERIOD)
	var lit := phase < BLINK_ON_DURATION
	var light_color := Color(1.0, 0.55, 0.1, 1.0) if lit else Color(0.4, 0.22, 0.06, 0.5)
	draw_circle(Vector2.ZERO, BODY_RADIUS * 0.38, light_color)
	draw_arc(Vector2.ZERO, BODY_RADIUS * 0.38, 0.0, TAU, 24, Color(0.6, 0.82, 0.92, 0.55), 2.0)
