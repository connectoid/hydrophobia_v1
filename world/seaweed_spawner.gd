extends Node2D
## Спавнит пятна водорослей (world/seaweed.gd) вокруг игрока, но, в отличие
## от chest_spawner.gd, строго за пределами видимой камере области — иначе
## крупное пятно материализовалось бы прямо на глазах у игрока. Дистанция
## спавна считается от половины диагонали текущего вида камеры (с учётом
## zoom) плюс off_screen_margin, поэтому гарантированно вне кадра на любом
## разрешении и при любом угле, а не только по осям экрана.

@export var seaweed_scene: PackedScene
@export var spawn_interval: float = 2.4
@export var off_screen_margin: float = 150.0

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	DepthManager.run_started.connect(_on_run_started)
	DepthManager.run_completed.connect(_on_run_completed)


func _on_run_started() -> void:
	_refresh_interval()
	spawn_timer.start()


func _on_run_completed() -> void:
	spawn_timer.stop()


func _on_spawn_timer_timeout() -> void:
	_spawn_seaweed()
	_refresh_interval()


## Интервал живёт в Balance (Отладка → Баланс → Предметы → Водоросли);
## выставленный после тика, он применится к следующему циклу таймера.
func _refresh_interval() -> void:
	spawn_timer.wait_time = Balance.get_value("items:seaweed:spawn_interval")


func _spawn_seaweed() -> void:
	if seaweed_scene == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	# Половина диагонали вида (не половина ширины/высоты) — гарантия "вне
	# кадра" даже для угла, целящего точно в угол экрана, а не только по
	# горизонтали/вертикали.
	var view_size: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	var spawn_distance := view_size.length() * 0.5 + off_screen_margin
	var angle := randf() * TAU
	var spawn_pos := camera.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
	# Выше уровня воды водоросли не появляются — тот же кламп, что и у
	# сундуков/врагов (см. DepthManager.get_floor_y()).
	spawn_pos.y = maxf(spawn_pos.y, DepthManager.get_floor_y())

	var seaweed: Node2D = seaweed_scene.instantiate()
	seaweed.global_position = spawn_pos
	get_tree().current_scene.add_child(seaweed)
