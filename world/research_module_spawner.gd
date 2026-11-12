extends Node2D
## Спавнит затонувшие исследовательские модули (world/research_module.gd)
## вокруг игрока, строго за пределами видимой камерой области — та же логика
## закадрового спавна, что и у seaweed_spawner.gd (см. его комментарий).
##
## В отличие от водорослей, появляются не с первой волны: чинить прочность
## корпуса есть смысл только там, где она вообще расходуется давлением (см.
## player.gd::_process_durability_drain — драйн начинается с current_wave >=
## min_wave). До этой волны таймер тикает вхолостую, ничего не спавня.

@export var research_module_scene: PackedScene
@export var spawn_interval: float = 10.0
@export var off_screen_margin: float = 150.0
@export var min_wave: int = 2

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	DepthManager.wave_started.connect(_on_wave_started)
	DepthManager.wave_ended.connect(_on_wave_ended)


func _on_wave_started(_wave_number: int) -> void:
	spawn_timer.start()


func _on_wave_ended(_wave_number: int) -> void:
	spawn_timer.stop()


func _on_spawn_timer_timeout() -> void:
	_spawn_research_module()


func _spawn_research_module() -> void:
	if research_module_scene == null or DepthManager.current_wave < min_wave:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var view_size: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	var spawn_distance := view_size.length() * 0.5 + off_screen_margin
	var angle := randf() * TAU
	var spawn_pos := camera.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
	# Выше дна уже пройденной зоны модули не появляются — тот же кламп, что и
	# у сундуков/врагов/водорослей (см. DepthManager.get_wave_floor_y()).
	spawn_pos.y = maxf(spawn_pos.y, DepthManager.get_wave_floor_y())

	var research_module: Node2D = research_module_scene.instantiate()
	research_module.global_position = spawn_pos
	get_tree().current_scene.add_child(research_module)
