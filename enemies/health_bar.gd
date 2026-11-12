extends Node2D
## Полоска здоровья над врагом. Обновляется вызовом set_fraction() из enemy.gd.

@export var width: float = 40.0
@export var height: float = 5.0
@export var bg_color: Color = Color(0, 0, 0, 0.6)
@export var fill_color: Color = Color(0.2, 0.9, 0.3, 1.0)

var _fraction: float = 1.0


func set_fraction(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var half_w := width * 0.5
	draw_rect(Rect2(-half_w, 0.0, width, height), bg_color)
	draw_rect(Rect2(-half_w, 0.0, width * _fraction, height), fill_color)
