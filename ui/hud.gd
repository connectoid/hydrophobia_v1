extends CanvasLayer
## HUD: здоровье/кислород/прочность/глубина/опыт игрока (левый верхний угол;
## глубина в формате "xxx/yyy" — текущая/цель конца волны) и номер
## волны/список открытого оружия (правый верхний угол).
## Экран конца игры (текст + кнопки Начать заново/Главное меню/Выход) — в
## ui/pause_menu.gd (тот узел PROCESS_MODE_ALWAYS и без игровых потомков,
## поэтому кнопки остаются кликабельными на паузе, см. его комментарий).

@onready var health_label: Label = $HealthLabel
@onready var oxygen_label: Label = $OxygenLabel
@onready var durability_label: Label = $DurabilityLabel
@onready var depth_label: Label = $DepthLabel
@onready var xp_label: Label = $XPLabel
@onready var wave_label: Label = $WaveLabel
@onready var weapons_list: VBoxContainer = $WeaponsList

var _player: Node


func _ready() -> void:
	DepthManager.wave_started.connect(_on_wave_started)
	DepthManager.depth_changed.connect(_on_depth_changed)
	_update_depth_label(DepthManager.current_depth)

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.experience_changed.connect(_on_experience_changed)
		_player.oxygen_changed.connect(_on_oxygen_changed)
		_player.durability_changed.connect(_on_durability_changed)
		_player.weapon_unlocked.connect(func(_weapon: WeaponData) -> void: _rebuild_weapons_list())
		_player.weapon_sold.connect(func(_weapon: WeaponData) -> void: _rebuild_weapons_list())
		_update_health_label(_player.current_health, _player.max_health)
		_update_xp_label(_player.current_xp)
		_update_oxygen_label(_player.current_oxygen)
		_update_durability_label(_player.current_durability, _player.max_durability)
		# Стартовое оружие добавляется в player._ready(), которое отрабатывает
		# раньше HUD (Player стоит выше по дереву сцены) — сигнал weapon_unlocked
		# на него мы уже пропустили, добираем его тут напрямую.
		_rebuild_weapons_list()


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Волна %d из %d" % [wave_number, DepthManager.max_waves]
	# Цель по глубине (wave_start_depth + wave_depth_goal) меняется при старте
	# волны, даже если сама текущая глубина в этот момент не изменилась.
	_update_depth_label(DepthManager.current_depth)


func _on_health_changed(current: float, max_health: float) -> void:
	_update_health_label(current, max_health)


func _update_health_label(current: float, max_health: float) -> void:
	health_label.text = "HP: %d/%d" % [roundi(current), roundi(max_health)]


func _on_experience_changed(current_xp: int) -> void:
	_update_xp_label(current_xp)


func _update_xp_label(current_xp: int) -> void:
	xp_label.text = "XP: %d" % current_xp


func _on_oxygen_changed(current: float, _max_oxygen: float) -> void:
	_update_oxygen_label(current)


func _update_oxygen_label(current_oxygen: float) -> void:
	oxygen_label.text = "Кислород: %d" % roundi(current_oxygen)


func _on_durability_changed(current: float, max_durability: float) -> void:
	_update_durability_label(current, max_durability)


func _update_durability_label(current: float, max_durability: float) -> void:
	durability_label.text = "Прочность: %d/%d" % [roundi(current), roundi(max_durability)]


func _on_depth_changed(new_depth: float) -> void:
	_update_depth_label(new_depth)


## yyy — абсолютная глубина, на которой закончится текущая волна
## (wave_start_depth + wave_depth_goal), а не сам wave_depth_goal (это
## только "сколько ещё метров").
func _update_depth_label(depth: float) -> void:
	var goal_depth := DepthManager.wave_start_depth + DepthManager.wave_depth_goal
	depth_label.text = "Глубина: %d/%d" % [roundi(depth), roundi(goal_depth)]


## Полная перестройка списка при любом изменении инвентаря (покупка/продажа
## в магазине) — проще и надёжнее точечных add/remove, а список маленький (до 6).
## TODO: заменить текстовые названия на иконки оружия.
func _rebuild_weapons_list() -> void:
	for child in weapons_list.get_children():
		child.queue_free()
	for weapon in _player.unlocked_weapons:
		var label := Label.new()
		label.text = weapon.weapon_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 20)
		weapons_list.add_child(label)
