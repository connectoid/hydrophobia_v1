
extends Node2D
## Плейсхолдер-фон "толщи воды" — ЧИСТО ВИЗУАЛЬНЫЙ слой, не влияет на физику
## сцены (игрок/враги двигаются по собственным координатам независимо от него).
## Забег теперь один и непрерывный (волн нет), поэтому фон упрощён: ровная
## заливка цветом воды + две информативные линии, когда они попадают в вид
## камеры:
## - СВЕРХУ — поверхность воды (DepthManager.get_floor_y() = SURFACE_Y),
##   над ней более светлая заливка ("воздух");
## - СНИЗУ — цель забега (DepthManager.get_goal_y(), run_depth метров):
##   финишная граница, видно заранее, сколько осталось нырнуть.
##
## Затемнение с глубиной здесь больше не рисуется: видимость по глубине —
## задача системы света (world/lighting.gd, оверлей темноты вокруг игрока),
## а цвет воды остаётся постоянным, чтобы внутри круга фонаря видимость была
## "обычной" на любой глубине.

@export var fill_color: Color = Color(0.05, 0.25, 0.45, 1.0)
## С запасом больше вьюпорта 1920×1080 (в т.ч. под stretch aspect=expand на
## широких окнах): заливка всегда центрирована на камере и должна покрывать
## экран целиком, иначе по краям виден чёрный clear-color.
@export var view_size: Vector2 = Vector2(2560, 1440)
@export var water_surface_color: Color = Color(0.75, 0.95, 1.0, 0.9)
@export var water_surface_tint: Color = Color(0.4, 0.75, 0.95, 0.35) # заливка над поверхностью — "воздух"
@export var goal_line_color: Color = Color(0.6, 1.0, 0.75, 0.9) # финишная линия цели забега


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		global_position = camera.global_position
	queue_redraw()


func _draw() -> void:
	var half_w := view_size.x * 0.5
	var half_h := view_size.y * 0.5
	draw_rect(Rect2(-half_w, -half_h, view_size.x, view_size.y), fill_color)

	# global_position уже равен позиции камеры (см. _process), поэтому мировая
	# Y в локальных координатах этого узла — просто разница координат.

	# Поверхность воды: над линией — более светлая заливка ("воздух").
	var surface_y := DepthManager.get_floor_y() - global_position.y
	if surface_y >= -half_h and surface_y <= half_h:
		draw_rect(Rect2(-half_w, -half_h, view_size.x, surface_y + half_h), water_surface_tint)
		draw_line(Vector2(-half_w, surface_y), Vector2(half_w, surface_y), water_surface_color, 3.0)

	# Цель забега (run_depth): финишная граница снизу.
	var goal_y := DepthManager.get_goal_y() - global_position.y
	if goal_y >= -half_h and goal_y <= half_h:
		draw_line(Vector2(-half_w, goal_y), Vector2(half_w, goal_y), goal_line_color, 3.0)
