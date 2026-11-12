extends CenterContainer
## Динамическое меню Баланс: дерево разделов (Враги / Оружие / Предметы /
## Игрок) → подразделы (конкретный враг / оружие / группа предметов) →
## ползунки характеристик. Всё содержимое строится кодом из реестра
## Balance.defs — новые враги/оружие/статы появляются здесь сами, без правок
## этого файла и сцены.
##
## Компактная вёрстка: корень — CenterContainer во весь экран, панель
## подстраивается под содержимое и всегда центрирована (без жёстких offsets,
## из-за которых заголовок/«Назад» уезжали за края экрана), каждый стат —
## одна строка «название — ползунок — значение».
##
## Каждый ползунок: дефолт (= текущее значение в игре) ровно посередине шкалы
## (мин/макс задаёт Balance), при движении сразу пишет значение в Balance
## (автосохранение там же) и показывает цифру справа.
##
## Сцена встраивается в главное меню и меню паузы; кнопка «Назад» на корневом
## уровне дерева шлёт сигнал back — владелец меню возвращает свою главную
## панель.

signal back

const SECTION_ORDER := ["enemies", "weapons", "items", "player"]

## Имена разделов меню ≠ префиксам ключей Balance (enemies → enemy:,
## weapons → weapon:) — соответствие явное, иначе ползунки подразделов
## не находятся и разделы оказываются пустыми.
const SECTION_KEY_PREFIX := {
	"enemies": "enemy",
	"weapons": "weapon",
	"items": "items",
	"player": "player",
}

const LABEL_WIDTH := 250.0
const SLIDER_MIN_WIDTH := 220.0
const VALUE_WIDTH := 70.0

@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var items_container: VBoxContainer = $Panel/Margin/VBox/ItemsContainer
@onready var back_button: Button = $Panel/Margin/VBox/BackButton

## Текущая позиция в дереве: [] — корень (список разделов), ["enemies"] —
## список врагов, ["enemies", "piranha"] — ползунки пираньи.
var _path: Array = []


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	hide()


func open() -> void:
	_path.clear()
	_render()
	show()


func _on_back_pressed() -> void:
	if _path.is_empty():
		hide()
		back.emit()
		return
	_path.pop_back()
	_render()


func _render() -> void:
	for child in items_container.get_children():
		child.queue_free()

	match _path.size():
		0:
			title_label.text = "БАЛАНС"
			for section in SECTION_ORDER:
				_add_nav_button(Balance.SECTION_TITLES[section], [section])
		1:
			var section: String = _path[0]
			title_label.text = "БАЛАНС → " + Balance.SECTION_TITLES[section].to_upper()
			if section == "player":
				# У игрока свои статы сразу списком, скин батискафа и
				# подраздел «Фонарь» (радиус/яркость света).
				_add_stat_rows("player:")
				_add_skin_row()
				_add_nav_button("Фонарь", ["player", "flashlight"])
			else:
				for subsection in _subsections(section):
					_add_nav_button(subsection["title"], [section, subsection["id"]])
		2:
			var section: String = _path[0]
			var subsection: String = _path[1]
			title_label.text = "БАЛАНС → %s → %s" % [Balance.SECTION_TITLES[section].to_upper(), _subsection_title(section, subsection).to_upper()]
			_add_stat_rows("%s:%s:" % [SECTION_KEY_PREFIX[section], subsection])


func _subsections(section: String) -> Array:
	match section:
		"enemies":
			var result := []
			for id in Balance.ENEMY_TITLES:
				result.append({"id": id, "title": Balance.ENEMY_TITLES[id]})
			return result
		"weapons":
			var result := []
			for id in Balance.WEAPON_TITLES:
				result.append({"id": id, "title": Balance.WEAPON_TITLES[id]})
			return result
		"items":
			var result := []
			for id in Balance.ITEM_TITLES:
				result.append({"id": id, "title": Balance.ITEM_TITLES[id]})
			return result
	return []


func _subsection_title(section: String, subsection: String) -> String:
	match section:
		"enemies":
			return Balance.ENEMY_TITLES.get(subsection, subsection)
		"weapons":
			return Balance.WEAPON_TITLES.get(subsection, subsection)
		"items":
			return Balance.ITEM_TITLES.get(subsection, subsection)
		"player":
			return "Фонарь" if subsection == "flashlight" else subsection
	return subsection


func _add_nav_button(title: String, path: Array) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(LABEL_WIDTH + SLIDER_MIN_WIDTH + VALUE_WIDTH, 34)
	button.pressed.connect(func():
		_path = path.duplicate()
		_render()
	)
	items_container.add_child(button)


## Ползунки всех статов с данным префиксом ключа, в порядке описания в Balance.
## У врагов-одиночек (флаг "Стая" выключен) строка "Особей в стае" скрывается —
## она для них не имеет смысла.
func _add_stat_rows(prefix: String) -> void:
	var schooling_off := prefix.begins_with("enemy:") \
		and Balance.defs.has(prefix + "schooling") \
		and Balance.get_value(prefix + "schooling") <= 0.5
	for key in Balance.keys_with_prefix(prefix):
		# Ключи более глубоких подразделов (напр. player:flashlight:*) здесь
		# не показываются — у них своя страница дерева.
		if key.substr(prefix.length()).contains(":"):
			continue
		if schooling_off and key.ends_with(":pack_size"):
			continue
		_add_stat_row(key)


## Одна строка стата: название слева, ползунок по центру, числовое значение
## справа (обновляется на каждое движение — цифра видна сразу).
## Булевы статы (def["bool"]) рисуются чекбоксом.
func _add_stat_row(key: String) -> void:
	var def: Dictionary = Balance.defs[key]
	if def.get("bool", false):
		_add_bool_row(key, def)
		return

	var label := Label.new()
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.text = def["label"]

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(SLIDER_MIN_WIDTH, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = def["min"]
	slider.max_value = def["max"]
	slider.step = def["step"]
	slider.value = Balance.get_value(key)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var format := "%.1f" if def["step"] < 1.0 else "%d"
	value_label.text = format % slider.value

	slider.value_changed.connect(func(value: float):
		Balance.set_value(key, value)
		value_label.text = format % value
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	items_container.add_child(row)


## Строка булева флага: название слева, чекбокс справа. Переключение "Стаи"
## перерисовывает раздел — строка "Особей в стае" появляется/исчезает сразу.
func _add_bool_row(key: String, def: Dictionary) -> void:
	var label := Label.new()
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.text = def["label"]

	var check := CheckBox.new()
	check.button_pressed = Balance.get_value(key) > 0.5
	check.toggled.connect(func(on: bool):
		Balance.set_value(key, 1.0 if on else 0.0)
		if key.ends_with(":schooling"):
			_render()
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(label)
	row.add_child(check)
	items_container.add_child(row)


## Скин батискафа — выпадающий список вариантов Settings.BATHYSCAPHE_VARIANTS.
## Заменил собой прежние кнопки скинов в панели Отладки; выбор сразу
## персистится Settings-автозагрузкой и применяется player.gd на лету
## (сигнал bathyscaphe_variant_changed).
func _add_skin_row() -> void:
	var label := Label.new()
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.text = "Скин"
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for variant in Settings.BATHYSCAPHE_VARIANTS:
		option.add_item(variant["title"])
		if variant["id"] == Settings.selected_bathyscaphe_variant:
			option.select(option.item_count - 1)
	option.item_selected.connect(func(index: int):
		Settings.set_bathyscaphe_variant(Settings.BATHYSCAPHE_VARIANTS[index]["id"])
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(label)
	row.add_child(option)
	items_container.add_child(row)
