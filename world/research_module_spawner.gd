extends Node2D
## Спавнит затонувшие исследовательские модули (world/research_module.gd)
## вокруг игрока, строго за пределами видимой камерой области — та же логика
## закадрового спавна, что и у seaweed_spawner.gd (см. его комментарий).
##
## ВРЕМЕННО НЕ ИСПОЛЬЗУЕТСЯ: узел убран из node_2d.tscn — давление корпус
## пока не разрушает (дренаж прочности отключён вместе с волнами), чинить
## нечего. Скрипт жив и переведён на новую систему забега (run_started/
## run_completed, тир глубины вместо номера волны), чтобы механику можно было
## вернуть простой вставкой узла в сцену.
##
## Появляются не с первого тира: чинить прочность есть смысл только там, где
## она расходуется давлением (min_tier). До этого тира таймер тикает вхолостую.

@export var research_module_scene: PackedScene
@export var spawn_interval: float = 10.0
@export var off_screen_margin: float = 150.0
@export var min_tier: int = 2

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	DepthManager.run_started.connect(_on_run_started)
	DepthManager.run_completed.connect(_on_run_completed)


func _on_run_started() -> void:
	spawn_timer.start()


func _on_run_completed() -> void:
	spawn_timer.stop()


func _on_spawn_timer_timeout() -> void:
	_spawn_research_module()


func _spawn_research_module() -> void:
	if research_module_scene == null or DepthManager.get_depth_tier() < min_tier:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var view_size: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	var spawn_distance := view_size.length() * 0.5 + off_screen_margin
	var angle := randf() * TAU
	var spawn_pos := camera.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
	# Выше уровня воды модули не появляются — тот же кламп, что и у
	# сундуков/врагов/водорослей (см. DepthManager.get_floor_y()).
	spawn_pos.y = maxf(spawn_pos.y, DepthManager.get_floor_y())

	var research_module: Node2D = research_module_scene.instantiate()
	research_module.global_position = spawn_pos
	get_tree().current_scene.add_child(research_module)
