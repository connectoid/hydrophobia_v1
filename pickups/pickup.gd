extends Area2D
## Общая база для подбираемых предметов (сферы опыта, кислород, хилки): в
## радиусе притяжения плавно летят к игроку, при непосредственном касании —
## подбираются. Наследники переопределяют _collect() — применяют эффект, но
## САМИ queue_free() больше не вызывают: это теперь делает _begin_collect
## ниже, один раз на оба случая.
##
## Если узел несёт AnimatedSprite2D с анимацией "collect" (сферы опыта,
## кислород — см. pickups/items/), при подборе сначала доигрывается она и
## только потом узел освобождается; для хилки (пока обычный статичный
## Sprite2D, без такого набора) поведение не меняется — освобождается сразу,
## как и раньше.

@export var attract_radius: float = 150.0
@export var attract_speed: float = 400.0
@export var pickup_radius: float = 30.0

@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null("Sprite2D") as AnimatedSprite2D

var _player: Node2D
var _collected: bool = false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var to_player := _player.global_position - global_position
	var distance := to_player.length()

	if distance <= pickup_radius:
		_begin_collect(_player)
		return

	if distance <= attract_radius:
		global_position += to_player.normalized() * attract_speed * delta


## Применяет эффект наследника один раз (_collected не даёт повторного
## триггера, пока узел доигрывает "collect" и ещё не свободен), затем либо
## доигрывает её перед queue_free(), либо освобождает сразу.
func _begin_collect(player_node: Node2D) -> void:
	if _collected:
		return
	_collected = true
	_collect(player_node)
	if _animated_sprite and _animated_sprite.sprite_frames.has_animation(&"collect"):
		_animated_sprite.animation_finished.connect(queue_free)
		_animated_sprite.play(&"collect")
	else:
		queue_free()


## Переопределяется в наследниках: применить эффект подбора. queue_free()
## здесь не вызывать — им управляет _begin_collect.
func _collect(_player_node: Node2D) -> void:
	pass
