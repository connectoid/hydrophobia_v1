extends Area2D
## Снаряд дальнобойного оружия игрока — летит к назначенной цели и наносит
## урон при попадании. Наводится (пересчитывает направление к цели каждый
## кадр), поэтому не промахивается мимо мелких/быстрых врагов.

@export var speed: float = 500.0
@export var max_lifetime: float = 3.0

var _target: Node2D
var _direction: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _lifetime: float = 0.0


func _ready() -> void:
	# Маска включает слой "мир", слой врагов и слой сундуков — сундуки живут
	# на отдельном LAYER_CHEST (8) и физически никого не толкают (см.
	# chest.tscn), но снаряд обязан их находить через body_entered.
	collision_mask = 1 | 4 | 8 # LAYER_WORLD | LAYER_ENEMY | LAYER_CHEST
	body_entered.connect(_on_body_entered)


func launch(target: Node2D, initial_direction: Vector2, damage: float) -> void:
	_target = target
	_direction = initial_direction.normalized()
	_damage = damage
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime > max_lifetime:
		queue_free()
		return

	if _target != null and is_instance_valid(_target):
		_direction = (_target.global_position - global_position).normalized()
		rotation = _direction.angle()

	global_position += _direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body == _target and body.has_method("take_damage"):
		body.take_damage(_damage)
		queue_free()
