
extends Node2D
## Плейсхолдер-фон "толщи воды" — ЧИСТО ВИЗУАЛЬНЫЙ слой, не влияет на физику
## сцены (игрок/враги двигаются по собственным координатам независимо от него).
## Рисует базовую заливку, темнеющую с каждой волной, и границы соседних зон,
## когда их мировая Y-координата попадает в текущий вид камеры:
## - Сверху — DepthManager.get_wave_floor_y() (дно уже пройденной зоны, для
##   волны 1 совпадает с уровнем воды SURFACE_Y) с более светлой заливкой над
##   линией (предыдущая зона).
## - Снизу — DepthManager.get_wave_goal_y() (глубина, на которой волна
##   завершится) с более тёмной заливкой под линией (следующая зона) — видно
##   заранее, где заканчивается текущая волна.
## Обе границы переезжают вниз с каждой новой волной, и основной цвет фона
## (fill_color) при этом темнеет — так пройденные и предстоящие зоны визуально
## отличаются от текущей и друг от друга.
##
## Ощущение движения даёт процедурный параллакс (world/parallax_background.gd):
## прежняя скроллящаяся сетка полос и рисок убрана как менее наглядная.

@export var fill_color: Color = Color(0.05, 0.25, 0.45, 1.0)
## С запасом больше вьюпорта 1920×1080 (в т.ч. под stretch aspect=expand на
## широких окнах): заливка всегда центрирована на камере и должна покрывать
## экран целиком, иначе по краям виден чёрный clear-color.
@export var view_size: Vector2 = Vector2(2560, 1440)
@export var water_surface_color: Color = Color(0.75, 0.95, 1.0, 0.9)
@export var water_surface_tint: Color = Color(0.4, 0.75, 0.95, 0.35) # заливка над линией — "воздух"/предыдущая зона

## Насколько темнее становится fill_color за каждую волну после первой
## (0.12 = -12% к яркости за волну, см. Color.darkened). Ограничено max_darken,
## чтобы совсем глубокие волны не уходили в чистый чёрный.
@export var darken_per_wave: float = 0.18
@export var max_darken: float = 0.85


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		global_position = camera.global_position
	queue_redraw()


func _draw() -> void:
	var half_w := view_size.x * 0.5
	var half_h := view_size.y * 0.5
	var current_fill := fill_color.darkened(_darken_amount(DepthManager.current_wave - 1))
	draw_rect(Rect2(-half_w, -half_h, view_size.x, view_size.y), current_fill)

	# global_position уже равен позиции камеры (см. _process), поэтому мировая
	# Y=get_wave_floor_y() в локальных координатах этого узла — просто разница координат.
	var boundary_y := DepthManager.get_wave_floor_y() - global_position.y
	if boundary_y >= -half_h and boundary_y <= half_h:
		# Волна 1 — граница с "воздухом" над поверхностью (полупрозрачная
		# подсветка). Волна 2+ — граница с предыдущей (более светлой) зоной.
		var above_boundary_color := water_surface_tint
		if DepthManager.current_wave > 1:
			above_boundary_color = fill_color.darkened(_darken_amount(DepthManager.current_wave - 2))
		draw_rect(Rect2(-half_w, -half_h, view_size.x, boundary_y + half_h), above_boundary_color)
		draw_line(Vector2(-half_w, boundary_y), Vector2(half_w, boundary_y), water_surface_color, 3.0)

	# Граница снизу — глубина окончания волны (следующая, более тёмная зона).
	var goal_y := DepthManager.get_wave_goal_y() - global_position.y
	if goal_y >= -half_h and goal_y <= half_h:
		var below_goal_color := fill_color.darkened(_darken_amount(DepthManager.current_wave))
		draw_rect(Rect2(-half_w, goal_y, view_size.x, half_h - goal_y), below_goal_color)
		draw_line(Vector2(-half_w, goal_y), Vector2(half_w, goal_y), water_surface_color, 3.0)


func _darken_amount(waves_passed: float) -> float:
	return clampf(darken_per_wave * maxf(waves_passed, 0.0), 0.0, max_darken)
