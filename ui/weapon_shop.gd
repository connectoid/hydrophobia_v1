extends CanvasLayer
## Экран между волнами: 3 случайные карточки оружия за XP (до MAX_WEAPONS
## единиц оружия суммарно; купленное оружие можно повторить, если такая же
## карточка выпадет ещё раз в другой волне, но каждая конкретная карточка
## разово — после покупки она исчезает, оставляя пустое место, чтобы нельзя
## было закупаться бесконечно с одного слота — см. player.gd::add_weapon).
## Кнопка "Заменить" за REROLL_COST XP полностью перекатывает весь ряд карточек
## (в т.ч. уже опустевшие купленные слоты) — реролл, если предложенные
## варианты не устроили. Плюс список уже купленного оружия с продажей за
## половину цены (округление вниз) — player.gd::remove_weapon. Открывается
## level.gd по сигналу DepthManager.wave_ended, закрывается по кнопке "Дальше"
## (сигнал continued), после чего level.gd запускает следующую волну. Сам узел
## и его дети — PROCESS_MODE_ALWAYS, как в pause_menu.gd, чтобы кнопки
## работали при поставленном на паузу дереве.

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
	title_label.text = "ВОЛНА %d ИЗ %d ПРОЙДЕНА" % [DepthManager.current_wave, DepthManager.max_waves]
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
	name_label.text = weapon.weapon_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	box.add_child(name_label)

	var type_label := Label.new()
	type_label.text = "Тип: %s" % _type_name(weapon.type)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 14)
	box.add_child(type_label)

	var damage_label := Label.new()
	damage_label.text = "Урон: %d" % roundi(weapon.damage)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.add_theme_font_size_override("font_size", 14)
	box.add_child(damage_label)

	var range_label := Label.new()
	range_label.text = "Дальность: %d" % roundi(weapon.attack_range)
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_label.add_theme_font_size_override("font_size", 14)
	box.add_child(range_label)

	var cost_label := Label.new()
	cost_label.text = "%d XP" % weapon.cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cost_label)

	var buy_button := Button.new()
	buy_button.text = "Купить"
	box.add_child(buy_button)

	cards_container.add_child(panel)
	var index := _cards.size()
	buy_button.pressed.connect(_on_buy_pressed.bind(index))
	_cards.append({"weapon": weapon, "button": buy_button, "panel": panel, "bought": false})


func _type_name(type: WeaponData.WeaponType) -> String:
	return "Ближний" if type == WeaponData.WeaponType.MELEE else "Дальний"


func _on_buy_pressed(index: int) -> void:
	var entry := _cards[index]
	if entry["bought"]:
		return
	var weapon: WeaponData = entry["weapon"]
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
	name_label.text = weapon.weapon_name
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
	for entry in _cards:
		if entry["bought"]:
			continue
		var weapon: WeaponData = entry["weapon"]
		var button: Button = entry["button"]
		button.disabled = not _can_afford(weapon)


func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = false
	continued.emit()
