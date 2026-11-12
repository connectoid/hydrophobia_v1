extends "res://pickups/pickup.gd"
## Хилка, которую роняет разбитый сундук. Притягивается к игроку в радиусе
## действия магнита (см. pickup.gd) и подбирается касанием. Количество
## восстанавливаемого здоровья — в Balance (Отладка → Баланс → Предметы).


func _collect(player_node: Node2D) -> void:
	if player_node.has_method("heal"):
		player_node.heal(Balance.get_value("items:chest:heal"))
