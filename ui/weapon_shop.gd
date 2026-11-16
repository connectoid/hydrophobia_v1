extends CanvasLayer
## Экран прокачки по левел-апу: 3 случайные карточки оружия за XP (до
## MAX_WEAPONS единиц оружия суммарно). У каждой КАРТОЧКИ свой уровень:
## выпадение повышенных уровней открывается с ростом уровня игрока (пороги —
## Баланс → Магазин, см. _max_card_level), цена карточки = base_cost × её
## уровень. Пока есть свободный слот — покупка даёт единицу уровня карточки
## (повторная копия типа возможна, уровни копий независимы). Когда слоты
## ЗАПОЛНЕНЫ, карточка сливается только с единицей того же типа ТОГО же
## уровня (ур. N + ур. N = ур. N+1) — кнопка «Улучшить», карточка исчезает из
## предложения, как при покупке; если подходящей единицы нет — кнопка покупки
## неактивна (сначала освободи слот продажей). Уровень виден во всех карточках,
## в списке купленного и в HUD. Кнопка "Заменить" за REROLL_COST XP полностью
## перекатывает весь ряд карточек (в т.ч. уже опустевшие слоты). Список
## купленного оружия — с продажей за половину БАЗОВОЙ цены (округление вниз).
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


## Максимальный уровень карточек при текущем уровне игрока: пороги
## открываются по одному (Баланс → Магазин), т.е. на уровне игрока между
## порогами N и N+1 карточки могут быть уровней 1..N. Выпавший уровень
## конкретной карточки — случайный из доступных (см. _build_card).
func _max_card_level() -> int:
	var player_level: int = _player.level
	var max_level := 1
	for level in range(2, _player.MAX_WEAPON_LEVEL + 1):
		if player_level >= Balance.get_value("shop:card_lvl%d_at" % level):
			max_level = level
	return max_level


func _build_card(weapon: WeaponData) -> void:
	var card_level := randi_range(1, _max_card_level())
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
		"level": card_level,
		"button": buy_button,
		"panel": panel,
		"bought": false,
		"name_label": name_label,
		"damage_label": damage_label,
		"range_label": range_label,
		"cost_label": cost_label,
	})


## Цена карточки её уровня: покупка единицы этого уровня или слияние с такой
## же единицей в арсенале стоят base_cost × уровень карточки.
func _card_price(entry: Dictionary) -> int:
	var weapon: WeaponData = entry["weapon"]
	return weapon.cost * int(entry["level"])


## Тексты карточки: её собственный уровень (карточки выпадают с уровнем,
## зависящим от уровня игрока — см. _max_card_level), эффективные урон/
## дальность оружия на этом уровне и цена. Кнопка и её состояние — в _refresh.
func _update_card(entry: Dictionary) -> void:
	var weapon: WeaponData = entry["weapon"]
	var level: int = entry["level"]
	entry["name_label"].text = "%s · ур. %d" % [weapon.weapon_name, level]
	entry["damage_label"].text = "Урон: %d" % roundi(weapon.damage_at(level))
	entry["range_label"].text = "Дальность: %d" % roundi(weapon.range_at(level))
	if _slots_full() and _merge_target_index(entry) >= 0:
		entry["cost_label"].text = "Улучшение: %d XP" % _card_price(entry)
	else:
		entry["cost_label"].text = "%d XP" % _card_price(entry)


## Индекс единицы в арсенале, с которой эта карточка может слиться: тот же
## тип ТОГО же уровня (ур. N + ур. N = ур. N+1). -1, если такой нет.
func _merge_target_index(entry: Dictionary) -> int:
	return _player.first_index_of_weapon_with_level(entry["weapon"], int(entry["level"]))


func _type_name(type: WeaponData.WeaponType) -> String:
	return "Ближний" if type == WeaponData.WeaponType.MELEE else "Дальний"


func _slots_full() -> bool:
	return _player.unlocked_weapons.size() >= MAX_WEAPONS


## Кнопка карточки: пока есть свободные слоты — покупка единицы УРОВНЯ
## КАРТОЧКИ (в т.ч. повторная копия уже имеющегося типа); когда слоты
## заполнены — карточка сливается только с единицей того же типа ТОГО же
## уровня (ур. N + ур. N = ур. N+1): «Улучшить» за цену карточки, карточка
## исчезает из предложения, как при покупке. Если подходящей единицы в
## арсенале нет (или карточка максимального уровня — сливать некуда), кнопка
## неактивна: сначала освободи слот продажей или прокачай нужную ступень.
func _on_card_pressed(index: int) -> void:
	var entry := _cards[index]
	if entry["bought"]:
		return
	var weapon: WeaponData = entry["weapon"]
	var price := _card_price(entry)
	if _player.current_xp < price:
		return
	if _slots_full():
		var merge_index := _merge_target_index(entry)
		if merge_index < 0 or int(entry["level"]) >= _player.MAX_WEAPON_LEVEL:
			return
		_player.spend_xp(price)
		_player.upgrade_weapon_at(merge_index)
	else:
		_player.spend_xp(price)
		_player.add_weapon(weapon, int(entry["level"]))
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
		var button: Button = entry["button"]
		var price := _card_price(entry)
		_update_card(entry)
		if slots_full:
			var merge_index := _merge_target_index(entry)
			if merge_index >= 0 and int(entry["level"]) < _player.MAX_WEAPON_LEVEL:
				button.text = "Улучшить"
				button.disabled = _player.current_xp < price
			elif merge_index >= 0:
				# Карточка максимального уровня: сливать некуда (N+1 > потолка).
				button.text = "Макс. уровень"
				button.disabled = true
			else:
				# Чужое оружие или нет единицы нужного уровня — только продажа
				# освободит слот; покупка/слияние недоступны.
				button.text = "Купить"
				button.disabled = true
		else:
			button.text = "Купить"
			button.disabled = _player.current_xp < price


func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = false
	continued.emit()
