extends Node2D
## Кратковременная визуализация взрыва — расширяющийся угасающий круг
## заданного радиуса, переиспользуется и торпедой (см.
## projectile_torpedo.gd::_spawn_blast_visual), и взрывом иглобомбы при
## смерти (см. enemies/enemy.gd::_trigger_death_explosion) — чисто
## декоративная, на урон не влияет (тот уже применён к моменту вызова).

@export var radius: float = 100.0
@export var color: Color = Color(1.0, 0.55, 0.15, 0.55)

const EXPAND_TIME := 0.18
const FADE_TIME := 0.2


func _ready() -> void:
	scale = Vector2(0.3, 0.3)
	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, EXPAND_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
