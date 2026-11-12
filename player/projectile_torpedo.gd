extends Area2D
## Снаряд торпеды — в отличие от projectile.gd не наводится и летит по прямой
## в сторону скопления врагов (см. player.gd::_find_cluster_target), заданной
## один раз при броске. Взрывается либо при контакте с первым встречным телом,
## либо пролетев max_distance (= attack_range оружия) без попадания — и
## наносит damage ВСЕМ целям в radius от точки взрыва, а не только той, во что
## попал (см. WeaponData.splash_radius). Тот же принцип удара по площади, что
## был у гранаты (player/projectile_grenade.gd) — переименована/перерисована
## в торпеду, старый файл оставлен на диске неиспользуемым на случай отката.

@export var speed: float = 420.0

var _direction: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _splash_radius: float = 0.0
var _max_distance: float = 0.0
var _traveled: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	# См. player/projectile.gd — та же маска и та же причина (сундуки на
	# отдельном LAYER_CHEST, физически никого не толкают, но детектся
	# снарядами через body_entered).
	collision_mask = 1 | 4 | 8 # LAYER_WORLD | LAYER_ENEMY | LAYER_CHEST
	body_entered.connect(_on_body_entered)


func launch(direction: Vector2, damage: float, splash_radius: float, max_distance: float) -> void:
	_direction = direction.normalized()
	_damage = damage
	_splash_radius = splash_radius
	_max_distance = max_distance
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	var step := _direction * speed * delta
	global_position += step
	_traveled += step.length()
	if _traveled >= _max_distance:
		_explode()


func _on_body_entered(_body: Node2D) -> void:
	_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	for body in get_tree().get_nodes_in_group("attackable"):
		if not body.has_method("take_damage"):
			continue
		if global_position.distance_to(body.global_position) <= _splash_radius:
			body.take_damage(_damage)
	_spawn_blast_visual()
	queue_free()


func _spawn_blast_visual() -> void:
	var blast_scene: PackedScene = load("res://player/explosion_effect.tscn")
	var blast: Node2D = blast_scene.instantiate()
	get_tree().current_scene.add_child(blast)
	blast.global_position = global_position
	blast.radius = _splash_radius
