extends "res://pickups/pickup.gd"
## Пузырёк кислорода — роняют особые рыбы (см. EnemyData.oxygen_reward).
## Притягивается к игроку и пополняет его кислород.

@export var oxygen_amount: float = 25.0


func _collect(player_node: Node2D) -> void:
	if player_node.has_method("add_oxygen"):
		player_node.add_oxygen(oxygen_amount)
		SFX.play(SFX.OXYGEN)
