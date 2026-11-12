extends StaticBody2D
## Неподвижный разрушаемый сундук: здоровье и урон обрабатываются как у врага
## (группа "attackable" — цель ближней атаки игрока), но не двигается и не
## атакует. Также состоит в группе "chest" — по ней дальнобойное оружие
## игрока узнаёт сундук отдельно от врагов (см. player.gd::_find_nearest_target).
##
## Визуализация — AnimatedSprite2D с 4 анимациями (см.
## pickups/items/health_chest/): "idle" (зациклена, обычное состояние),
## "break" (одноразовая, на каждый непробивающий удар — аналог hurt у врагов),
## и при уничтожении — цепочка "open" → "release": хилка выпадает не сразу в
## момент смерти, а когда "open" доигрывает и начинается "release" (ровно
## тот момент, когда на кадрах анимации сердечки вылетают наружу), после чего
## "release" доигрывает до конца и сундук освобождается.

signal died

@export var max_health: float = 50.0
@export var heal_pickup_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var health_bar: Node2D = $HealthBar

var current_health: float
var _is_dying: bool = false


func _ready() -> void:
	add_to_group("attackable")
	add_to_group("chest")
	max_health = Balance.get_value("items:chest:health")
	current_health = max_health
	health_bar.set_fraction(1.0)
	sprite.animation_finished.connect(_on_animation_finished)


func take_damage(amount: float) -> void:
	if _is_dying:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_bar.set_fraction(current_health / max_health)
	SFX.play(SFX.HIT)
	if current_health <= 0.0:
		die()
	else:
		sprite.play(&"break")


## Цепочка одноразовых анимаций: "break" (не смертельный удар) просто
## возвращается в "idle"; "open" (первая стадия смерти) по завершении роняет
## хилку и запускает "release"; "release" по завершении — реально
## освобождает узел. "idle" зациклена и animation_finished не шлёт (как и у
## enemy.gd — см. его комментарий на этот счёт), отдельного case не нужно.
func _on_animation_finished() -> void:
	match sprite.animation:
		&"break":
			sprite.play(&"idle")
		&"open":
			_drop_pickup()
			sprite.play(&"release")
		&"release":
			queue_free()


func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	print("Сундук разбит")
	SFX.play(SFX.CHEST)
	$CollisionShape2D.set_deferred("disabled", true)
	died.emit()
	sprite.play(&"open")


func _drop_pickup() -> void:
	if not heal_pickup_scene:
		return
	var pickup: Node2D = heal_pickup_scene.instantiate()
	pickup.global_position = global_position
	# _on_animation_finished приходит из сигнала AnimatedSprite2D — не колбэк
	# физики, но держим ту же осторожность, что и enemy.gd::die() (call_deferred
	# на add_child), раз уж паттерн уже устоявшийся в проекте.
	get_tree().current_scene.call_deferred("add_child", pickup)
