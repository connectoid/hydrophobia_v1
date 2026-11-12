extends "res://pickups/pickup.gd"
## Сфера опыта, которую роняет враг при смерти. Визуально — один из трёх
## заранее нарисованных размеров (small/medium/large, см. pickups/items/) —
## выбирается по xp_amount один раз при спавне (_ready): крупная награда
## получает заметно более крупную/яркую сферу. Притягивается к игроку в
## радиусе действия магнита (см. pickup.gd) и подбирается касанием.

const SMALL_FRAMES := preload("res://pickups/items/xp_small/xp_small_frames.tres")
const MEDIUM_FRAMES := preload("res://pickups/items/xp_medium/xp_medium_frames.tres")
const LARGE_FRAMES := preload("res://pickups/items/xp_large/xp_large_frames.tres")

## Пороги подобраны под разброс xp_reward среди текущих врагов (3..20, см.
## enemies/data/*.tres): пиранья/акулёнок (3-5) → small, спрут-мутант/
## электромурена (8-9) → medium, удильщик/иглобомба (18-20) → large.
const MEDIUM_THRESHOLD := 6
const LARGE_THRESHOLD := 16

@export var xp_amount: int = 10

@onready var sprite: AnimatedSprite2D = $Sprite2D


func _ready() -> void:
	super._ready()
	if xp_amount >= LARGE_THRESHOLD:
		sprite.sprite_frames = LARGE_FRAMES
	elif xp_amount >= MEDIUM_THRESHOLD:
		sprite.sprite_frames = MEDIUM_FRAMES
	else:
		sprite.sprite_frames = SMALL_FRAMES
	sprite.play(&"idle")


func _collect(player_node: Node2D) -> void:
	if player_node.has_method("add_experience"):
		player_node.add_experience(xp_amount)
		SFX.play(SFX.XP_ORB)
