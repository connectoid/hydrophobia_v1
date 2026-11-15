extends CanvasLayer
## Экран прокачки по левел-апу: 3 случайные карточки оружия за XP (до
## MAX_WEAPONS единиц оружия суммарно; пока есть свободный слот, купленное
## оружие можно повторить ещё одной копией — см. player.gd::add_weapon).
## Когда слоты ЗАПОЛНЕНЫ, торговля превращается в прокачку: на карточках
## уже имеющегося оружия кнопка «Улучшить» (тип оружия получает +1 уровень,
## характеристики растут по кривым WeaponData.damage_at/range_at/interval_at),
## а на карточках чужого оружия кнопка покупки неактивна — сначала освободи
## слот продажей. Уровень оружия показан во всех карточках, в списке
## купленного и в HUD. Кнопка "Заменить" за REROLL_COST XP полностью
## перекатывает весь ряд карточек (в т.ч. уже опустевшие купленные слоты).
## Список купленного оружия — с продажей за половину цены (округление вниз).
## Открывается level.gd по сигналу player.level_up (забег непрерывный,
## магазин ставит игру на паузу), закрывается по кнопке "Дальше" (сигнал
## continued), после чего level.gd открывает следующий неотработанный
## левел-ап, если он есть. Траты XP НЕ откатывают прогрессию уровня —
## см. player.gd::_check_level_up. Сам узел и его дети — PROCESS_MODE_ALWAYS,
## как в pause_menu.gd, чтобы кнопки работали при поставленном на паузу дереве.

signal continued

const CARD_COUNT := 3
const MAX_WEAPONS := 6
const SELL_REFUND_RATIO := 0.5
const REROLL_COST := 20

## Пул оружия, из которого рандомятся карточки (weapons/*.tres) — назначается в node_2d.tscn.
@export var weapon_pool: Array[WeaponData] = []

@onready var title_label: Label = $Panel/TitleLabel
@onready var status_label: Label = $Panel/StatusLabel
@onready var owned_container: HBoxContainer = $Panel/OwnedContainer
@onready var cards_container: HBoxContainer = $Panel/CardsContainer
@onready var reroll_button: Button = $Panel/RerollButton
@onready var continue_button: Button = $Panel/ContinueButton

var _player: Node
var _cards: Array[Dictionary] = [] # [{weapon: WeaponData, button: Button, panel: PanelContainer, bought: bool}]


func _ready() -> void:
	add_to_group("weapon_shop")
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	continue_button.pressed.connect(_on_continue_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	reroll_button.text = "Заменить (%d XP)" % REROLL_COST


func open_for(player: Node) -> void:
	_player = player
	title_label.text = "НОВЫЙ УРОВЕНЬ %d" % player.level
	_roll_cards()
	_refresh()
	show()
	get_tree().paused = true


func _roll_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	_cards.clear()

	var pool := weapon_pool.duplicate()
	pool.shuffle()
	for i in mini(CARD_COUNT, pool.size()):
		_build_card(pool[i])


func _build_card(weapon: WeaponData) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 230)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	# TODO: позже добавить иконку оружия.
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	box.add_child(name_label)

	var type_label := Label.new()
	type_label.text = "Тип: %s" % _type_name(weapon.type)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 14)
	box.add_child(type_label)

	var damage_label := Label.new()
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.add_theme_font_size_override("font_size", 14)
	box.add_child(damage_label)

	var range_label := Label.new()
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_label.add_theme_font_size_override("font_size", 14)
	box.add_child(range_label)

	var cost_label := Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cost_label)

	var buy_button := Button.new()
	box.add_child(buy_button)

	cards_container.add_child(panel)
	var index := _cards.size()
	buy_button.pressed.connect(_on_card_pressed.bind(index))
	_cards.append({
		"weapon": weapon,
		"button": buy_button,
		"panel": panel,
		"bought": false,
		"name_label": name_label,
		"damage_label": damage_label,
		"range_label": range_label,
		"cost_label": cost_label,
	})


## Тексты карточки по текущему состоянию: уровень оружия (у купленного —
## уровень первой копии в арсенале, т.к. улучшение сольётся именно с ней;
## у чужого — 1), эффективные урон/дальность на этом уровне и цена (покупка
## или улучшение — смотря какой режим сейчас у кнопки).
func _update_card(entry: Dictionary) -> void:
	var weapon: WeaponData = entry["weapon"]
	var owned_index: int = _player.first_index_of_weapon(weapon)
	var owned: bool = owned_index >= 0
	var level: int = _player.get_weapon_level_at(owned_index) if owned else 1
	entry["name_label"].text = "%s · ур. %d" % [weapon.weapon_name, level]
	entry["damage_label"].text = "Урон: %d" % roundi(weapon.damage_at(level))
	entry["range_label"].text = "Дальность: %d" % roundi(weapon.range_at(level))
	if _slots_full() and owned:
		entry["cost_label"].text = "Улучшение: %d XP" % _player.upgrade_cost_at(owned_index)
	else:
		entry["cost_label"].text = "%d XP" % weapon.cost


func _type_name(type: WeaponData.WeaponType) -> String:
	return "Ближний" if type == WeaponData.WeaponType.MELEE else "Дальний"


func _slots_full() -> bool:
	return _player.unlocked_weapons.size() >= MAX_WEAPONS


## Кнопка карточки: пока есть свободные слоты — покупка (в т.ч. повторная
## копия уже имеющегося оружия); когда слоты заполнены — «Улучшить» для
## своего оружия: карточка "сливается" с первой копией этого типа в арсенале
## (ей +1 уровень) и исчезает из предложения, как при покупке. Чужое оружие
## при полных слотах купить нельзя — кнопка неактивна.
func _on_card_pressed(index: int) -> void:
	var entry := _cards[index]
	if entry["bought"]:
		return
	var weapon: WeaponData = entry["weapon"]
	if _slots_full():
		var owned_index: int = _player.first_index_of_weapon(weapon)
		if owned_index < 0 or not _player.can_upgrade_at(owned_index):
			return
		_player.spend_xp(_player.upgrade_cost_at(owned_index))
		_player.upgrade_weapon_at(owned_index)
		entry["bought"] = true
		_clear_card(entry["panel"])
		_refresh()
		return
	if not _can_afford(weapon):
		return
	_player.spend_xp(weapon.cost)
	_player.add_weapon(weapon)
	entry["bought"] = true
	_clear_card(entry["panel"])
	_refresh()


## Карточка куплена — снимаем её содержимое, оставляя пустое место в ряду,
## чтобы по одной и той же карточке нельзя было закупаться бесконечно.
func _clear_card(panel: PanelContainer) -> void:
	for child in panel.get_children():
		child.queue_free()
	var empty_label := Label.new()
	empty_label.text = "— куплено —"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_label.modulate = Color(1, 1, 1, 0.4)
	panel.add_child(empty_label)


func _can_afford(weapon: WeaponData) -> bool:
	return _player.unlocked_weapons.size() < MAX_WEAPONS and _player.current_xp >= weapon.cost


## Реролл — полностью новый набор из CARD_COUNT карточек за REROLL_COST XP,
## заменяет весь текущий ряд (включая уже опустевшие купленные слоты).
func _on_reroll_pressed() -> void:
	if _player.current_xp < REROLL_COST:
		return
	_player.spend_xp(REROLL_COST)
	_roll_cards()
	_refresh()


## Список уже купленного/стартового оружия с продажей — перестраивается
## целиком при каждом _refresh(), т.к. индексы в unlocked_weapons сдвигаются
## после каждой продажи.
func _rebuild_owned() -> void:
	for child in owned_container.get_children():
		child.queue_free()

	var weapons: Array[WeaponData] = _player.unlocked_weapons
	for i in weapons.size():
		_build_owned_entry(weapons[i], i)


func _build_owned_entry(weapon: WeaponData, index: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(100, 100)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var name_label := Label.new()
	name_label.text = "%s · ур. %d" % [weapon.weapon_name, _player.get_weapon_level_at(index)]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 16)
	box.add_child(name_label)

	var refund := _sell_refund(weapon)
	var sell_button := Button.new()
	sell_button.text = "Продать\n+%d XP" % refund
	# Последнее оружие продать нельзя — иначе игрок останется без атаки.
	sell_button.disabled = _player.unlocked_weapons.size() <= 1
	sell_button.pressed.connect(_on_sell_pressed.bind(index))
	box.add_child(sell_button)

	owned_container.add_child(panel)


func _sell_refund(weapon: WeaponData) -> int:
	return floori(weapon.cost * SELL_REFUND_RATIO)


func _on_sell_pressed(index: int) -> void:
	if _player.unlocked_weapons.size() <= 1:
		return
	var weapon: WeaponData = _player.unlocked_weapons[index]
	var refund := _sell_refund(weapon)
	_player.remove_weapon(index)
	_player.add_experience(refund)
	_refresh()


func _refresh() -> void:
	status_label.text = "XP: %d    Оружие: %d/%d" % [_player.current_xp, _player.unlocked_weapons.size(), MAX_WEAPONS]
	_rebuild_owned()
	reroll_button.disabled = _player.current_xp < REROLL_COST
	var slots_full := _slots_full()
	for entry in _cards:
		if entry["bought"]:
			continue
		var weapon: WeaponData = entry["weapon"]
		var button: Button = entry["button"]
		var owned: bool = _player.unlocked_weapons.has(weapon)
		_update_card(entry)
		if slots_full:
			# Слоты заполнены: своё оружие можно улучшать, чужое — нет.
			if owned:
				var owned_index: int = _player.first_index_of_weapon(weapon)
				var at_max: bool = _player.get_weapon_level_at(owned_index) >= _player.MAX_WEAPON_LEVEL
				button.text = "Макс. уровень" if at_max else "Улучшить"
				button.disabled = not _player.can_upgrade_at(owned_index)
			else:
				button.text = "Купить"
				button.disabled = true
		else:
			button.text = "Купить"
			button.disabled = not _can_afford(weapon)


func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = false
	continued.emit()
