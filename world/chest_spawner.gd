extends Node2D
## Изредка спавнит сундуки в пределах видимой на экране области вокруг игрока
## (в отличие от врагов, которые появляются за кадром и подходят).

@export var chest_scene: PackedScene
@export var spawn_interval: float = 10.0
@export var spawn_margin: float = 80.0

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	DepthManager.wave_started.connect(_on_wave_started)
	DepthManager.wave_ended.connect(_on_wave_ended)


func _on_wave_started(_wave_number: int) -> void:
	_refresh_interval()
	spawn_timer.start()


func _on_wave_ended(_wave_number: int) -> void:
	spawn_timer.stop()


func _on_spawn_timer_timeout() -> void:
	_spawn_chest()
	_refresh_interval()


## Интервал живёт в Balance (Отладка → Баланс → Предметы → Сундуки);
## выставленный после тика, он применится к следующему циклу таймера.
func _refresh_interval() -> void:
	spawn_timer.wait_time = Balance.get_value("items:chest:spawn_interval")


func _spawn_chest() -> void:
	if chest_scene == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var half_w := maxf(viewport_size.x * 0.5 - spawn_margin, 0.0)
	var half_h := maxf(viewport_size.y * 0.5 - spawn_margin, 0.0)
	var offset := Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h))

	var chest: Node2D = chest_scene.instantiate()
	chest.global_position = camera.global_position + offset
	# Выше дна уже пройденной зоны сундуки не появляются — прижимаем точку
	# спавна к границе текущей волны (см. DepthManager.get_wave_floor_y()).
	chest.global_position.y = maxf(chest.global_position.y, DepthManager.get_wave_floor_y())
	get_tree().current_scene.add_child(chest)
