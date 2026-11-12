extends Node2D
## Точка входа игрового цикла: запускает волну 1, по её окончании открывает
## магазин оружия (ui/weapon_shop.gd) и переходит на следующую волну — так до
## смерти игрока или прохождения последней волны (DepthManager.max_waves),
## после которой вместо магазина объявляется победа. Сложность волн пока не
## меняется (DESIGN.md, открытый вопрос). На конце игры (смерть или победа)
## ставит дерево сцены на паузу (враги/спавнер/таймер реально останавливаются).
## Сам узел НЕ в PROCESS_MODE_ALWAYS — почти все игровые объекты (враги,
## сундуки, снаряды, пикапы) создаются в рантайме как дети get_tree().current_scene,
## т.е. этого же узла, и наследуют его process_mode. Если бы корень был ALWAYS,
## все они игнорировали бы паузу. Рестарт по Enter после конца игры
## обрабатывается в pause_menu.gd — он изолирован (без игровых потомков) и там
## ALWAYS безопасен.

signal game_lost
signal game_won

@export var wave_number: int = 1

var game_ended: bool = false # читается pause_menu.gd — true после смерти ИЛИ победы

var _player: Node
var _shop: Node


func _ready() -> void:
	add_to_group("level")

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.died.connect(_on_player_died)

	# WeaponShop — сиблинг этого узла под тем же корнем; его _ready() уже
	# отработал к этому моменту (дети сцены готовятся раньше корня), поэтому
	# группа "weapon_shop" здесь уже заполнена — call_deferred не нужен.
	_shop = get_tree().get_first_node_in_group("weapon_shop")
	if _shop:
		_shop.continued.connect(_on_shop_continued)

	DepthManager.wave_ended.connect(_on_wave_ended)
	DepthManager.start_wave(wave_number)
	print("Волна %d начата" % wave_number)


func _on_player_died() -> void:
	if game_ended:
		return
	game_ended = true
	DepthManager.end_wave()
	_clear_enemies()
	print("Игрок погиб. Игра окончена. Нажмите Enter, чтобы начать заново.")
	game_lost.emit()
	get_tree().paused = true


func _on_wave_ended(_wave_number: int) -> void:
	if game_ended:
		return
	_clear_enemies()
	print("Волна %d пройдена" % wave_number)
	if wave_number >= DepthManager.max_waves:
		_on_victory()
		return
	if _shop and _player:
		_shop.open_for(_player)
	else:
		_start_next_wave()


func _on_victory() -> void:
	game_ended = true
	print("Все волны пройдены! Победа. Нажмите Enter, чтобы начать заново.")
	game_won.emit()
	get_tree().paused = true


func _on_shop_continued() -> void:
	_start_next_wave()


func _start_next_wave() -> void:
	wave_number += 1
	DepthManager.start_wave(wave_number)
	print("Волна %d начата" % wave_number)


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
