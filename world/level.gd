extends Node2D
## Точка входа игрового цикла: один непрерывный забег — старт с поверхности и
## спуск на DepthManager.run_depth метров (победа) либо смерть игрока
## (поражение). Волн больше нет: магазин оружия (ui/weapon_shop.gd) открывается
## по левел-апу игрока (сигнал level_up в player.gd) прямо посреди погружения,
## с паузой; если за один pickup накопилось несколько уровней — магазин
## переоткрывается нужное число раз подряд. На конце игры (смерть или победа)
## ставит дерево сцены на паузу (враги/спавнер/таймер реально останавливаются).
## Сам узел НЕ в PROCESS_MODE_ALWAYS — почти все игровые объекты (враги,
## сундуки, снаряды, пикапы) создаются в рантайме как дети get_tree().current_scene,
## т.е. этого же узла, и наследуют его process_mode. Если бы корень был ALWAYS,
## все они игнорировали бы паузу. Рестарт по Enter после конца игры
## обрабатывается в pause_menu.gd — он изолирован (без игровых потомков) и там
## ALWAYS безопасен.

signal game_lost
signal game_won

var game_ended: bool = false # читается pause_menu.gd — true после смерти ИЛИ победы

var _player: Node
var _shop: Node
## Левел-апы, полученные, но ещё не отоваренные в магазине (несколько уровней
## за один подбор опыта) — магазин переоткрывается, пока счётчик не обнулится.
var _pending_level_ups: int = 0


func _ready() -> void:
	add_to_group("level")

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.died.connect(_on_player_died)
		_player.level_up.connect(_on_player_level_up)

	# WeaponShop — сиблинг этого узла под тем же корнем; его _ready() уже
	# отработал к этому моменту (дети сцены готовятся раньше корня), поэтому
	# группа "weapon_shop" здесь уже заполнена — call_deferred не нужен.
	_shop = get_tree().get_first_node_in_group("weapon_shop")
	if _shop:
		_shop.continued.connect(_on_shop_continued)

	DepthManager.run_completed.connect(_on_run_completed)
	DepthManager.start_run()
	print("Забег начат: цель — %d м" % roundi(DepthManager.run_depth))


func _on_player_died() -> void:
	if game_ended:
		return
	game_ended = true
	DepthManager.run_active = false
	_clear_enemies()
	print("Игрок погиб. Игра окончена. Нажмите Enter, чтобы начать заново.")
	game_lost.emit()
	get_tree().paused = true


## Цель забега достигнута (DepthManager.run_depth) — победа.
func _on_run_completed() -> void:
	if game_ended:
		return
	game_ended = true
	_clear_enemies()
	print("Глубина %d м достигнута! Победа. Нажмите Enter, чтобы начать заново." % roundi(DepthManager.run_depth))
	game_won.emit()
	get_tree().paused = true


func _on_player_level_up(_new_level: int) -> void:
	if game_ended:
		return
	_pending_level_ups += 1
	_open_shop_if_possible()


func _on_shop_continued() -> void:
	_pending_level_ups = maxi(_pending_level_ups - 1, 0)
	# Следующий неотработанный левел-ап (если был мульти-уровень) открываем не
	# в тот же кадр: магазин снимает паузу в continued, а open_for ставит её
	# снова — через deferred порядок гарантирован.
	_open_shop_if_possible.call_deferred()


func _open_shop_if_possible() -> void:
	if game_ended or _pending_level_ups <= 0:
		return
	if _shop and _player:
		_shop.open_for(_player)
	else:
		_pending_level_ups = 0


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
