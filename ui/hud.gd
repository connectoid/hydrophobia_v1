extends CanvasLayer
## HUD: здоровье/кислород/глубина/уровень+опыт игрока (левый верхний угол)
## и список открытого оружия (правый верхний угол). Забег один и непрерывный:
## глубина показывается как "текущая / цель забега" (DepthManager.run_depth),
## прежние номер волны и прочность корпуса убраны (давление корпус пока не
## разрушает, водоросли/станции временно выключены).
## Экран конца игры (текст + кнопки Начать заново/Главное меню/Выход) — в
## ui/pause_menu.gd (тот узел PROCESS_MODE_ALWAYS и без игровых потомков,
## поэтому кнопки остаются кликабельными на паузе, см. его комментарий).

@onready var health_label: Label = $HealthLabel
@onready var oxygen_label: Label = $OxygenLabel
@onready var depth_label: Label = $DepthLabel
@onready var xp_label: Label = $XPLabel
@onready var weapons_list: VBoxContainer = $WeaponsList

var _player: Node


func _ready() -> void:
	DepthManager.depth_changed.connect(_on_depth_changed)
	_update_depth_label(DepthManager.current_depth)

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.experience_changed.connect(func(_xp: int): _update_xp_label())
		_player.level_up.connect(func(_level: int): _update_xp_label())
		_player.oxygen_changed.connect(_on_oxygen_changed)
		_player.weapon_unlocked.connect(func(_weapon: WeaponData) -> void: _rebuild_weapons_list())
		_player.weapon_sold.connect(func(_weapon: WeaponData) -> void: _rebuild_weapons_list())
		_player.weapon_upgraded.connect(func(_w: WeaponData, _l: int) -> void: _rebuild_weapons_list())
		_update_health_label(_player.current_health, _player.max_health)
		_update_xp_label()
		_update_oxygen_label(_player.current_oxygen)
		# Стартовое оружие добавляется в player._ready(), которое отрабатывает
		# раньше HUD (Player стоит выше по дереву сцены) — сигнал weapon_unlocked
		# на него мы уже пропустили, добираем его тут напрямую.
		_rebuild_weapons_list()


func _on_health_changed(current: float, max_health: float) -> void:
	_update_health_label(current, max_health)


func _update_health_label(current: float, max_health: float) -> void:
	health_label.text = "HP: %d/%d" % [roundi(current), roundi(max_health)]


## Уровень и прогресс до следующего левел-апа + доступный баланс XP (валюта
## магазина). Прогресс уровня не уменьшается от трат XP — см. player.gd.
func _update_xp_label() -> void:
	if _player == null:
		return
	xp_label.text = "Ур. %d — опыт %d/%d (баланс %d)" % [
		_player.level, _player._level_xp_progress, _player.xp_to_next, _player.current_xp
	]


func _on_oxygen_changed(current: float, _max_oxygen: float) -> void:
	_update_oxygen_label(current)


func _update_oxygen_label(current_oxygen: float) -> void:
	oxygen_label.text = "Кислород: %d" % roundi(current_oxygen)


func _on_depth_changed(new_depth: float) -> void:
	_update_depth_label(new_depth)


## Глубина забега: "текущая / цель" (DepthManager.run_depth), обновляется по
## depth_changed.
func _update_depth_label(depth: float) -> void:
	depth_label.text = "Глубина: %d/%d м" % [roundi(depth), roundi(DepthManager.run_depth)]


## Полная перестройка списка при любом изменении инвентаря (покупка/продажа
## в магазине) — проще и надёжнее точечных add/remove, а список маленький (до 6).
## TODO: заменить текстовые названия на иконки оружия.
func _rebuild_weapons_list() -> void:
	for child in weapons_list.get_children():
		child.queue_free()
	for i in _player.unlocked_weapons.size():
		var weapon: WeaponData = _player.unlocked_weapons[i]
		var label := Label.new()
		label.text = "%s · ур. %d" % [weapon.weapon_name, _player.get_weapon_level_at(i)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 20)
		weapons_list.add_child(label)
