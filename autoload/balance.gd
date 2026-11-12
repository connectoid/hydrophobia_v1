extends Node
## Баланс: единый реестр всех тюнингуемых параметров игры (враги, оружие,
## предметы, игрок) для меню Отладка → Баланс (ui/balance_menu.gd).
##
## Каждое значение описано определением (defs): метка, дефолт (= текущее
## значение в игре, оно же середина ползунка меню), мин и шаг; макс
## вычисляется как 2*default - min, чтобы дефолт всегда был ровно посередине
## шкалы. Изменённые значения хранятся в values и ПИШУТСЯ НА ДИСК при каждом
## изменении (user://balance.cfg, см. set_value) — автосохранение без
## отдельной кнопки, по тому же принципу, что Settings.
##
## Применение: враги/предметы читают свои значения в момент спавна/_ready
## (enemy_spawner.gd, chest.gd, seaweed.gd, research_module.gd, heal_pickup.gd),
## оружие применяется к загруженным WeaponData-ресурсам сразу при изменении
## (см. _apply_weapon), игрок — и при старте, и "на лету" через сигнал
## player_stats_changed (player.gd).
##
## Ключи: "enemy:<id>:<stat>", "weapon:<id>:<stat>", "items:<sub>:<stat>",
## "player:<stat>". id врага/оружия = имя файла его .tres без расширения.

const SAVE_PATH := "user://balance.cfg"
const SAVE_SECTION := "balance"

const WEAPON_PATHS := {
	"knife": "res://weapons/knife.tres",
	"pistol": "res://weapons/pistol.tres",
	"rifle": "res://weapons/rifle.tres",
	"saber": "res://weapons/saber.tres",
	"torpedo": "res://weapons/torpedo.tres",
	"grenade": "res://weapons/grenade.tres",
}

const SECTION_TITLES := {
	"enemies": "Враги",
	"weapons": "Оружие",
	"items": "Предметы",
	"player": "Игрок",
}

const ENEMY_TITLES := {
	"piranha": "Пиранья",
	"shark": "Акула",
	"angler": "Удильщик",
	"eel": "Мурена",
	"mutant_squid": "Мутант-кальмар",
	"puffermine": "Иглобомба",
	"oxygen_fish": "Кислородная рыба",
}

const WEAPON_TITLES := {
	"knife": "Нож",
	"pistol": "Пистолет",
	"rifle": "Автомат",
	"saber": "Сабля",
	"torpedo": "Торпеда",
	"grenade": "Граната",
}

const ITEM_TITLES := {
	"chest": "Сундуки",
	"seaweed": "Водоросли",
	"module": "Станции",
}

signal player_stats_changed

## key -> {label, default, min, max, step}. Порядок вставки = порядок в меню.
var defs: Dictionary = {}
## key -> изменённое значение; чего здесь нет, то равно defs[key].default.
var values: Dictionary = {}


func _init() -> void:
	# Враги: признак стайности, стайные параметры + характеристики особи.
	# Дефолты зеркалят текущие экспорты сцен (enemies/scenes/*.tscn) и xp из
	# enemies/data/*.tres. Стайная по умолчанию только пиранья — остальные
	# охотятся одиночками (спавнер читает это через is_schooling()).
	_add_pack_enemy("piranha", 28, 150, 8, 3, true, 70, 500)
	_add_pack_enemy("shark", 55, 310, 10, 5)
	_add_pack_enemy("angler", 110, 70, 18, 20)
	_add_pack_enemy("eel", 42, 170, 12, 9, false, 65, 550)
	_add_pack_enemy("mutant_squid", 65, 130, 12, 8)
	_add_pack_enemy("puffermine", 75, 45, 9, 18)
	# Фоновая живность: без стай, свой интервал спавна (см. enemy_spawner.gd).
	_def("enemy:oxygen_fish:health", "Здоровье особи", 45, 1, 1)
	_def("enemy:oxygen_fish:speed", "Скорость", 180, 10, 5)
	_def("enemy:oxygen_fish:spawn_interval", "Частота спавна, сек", 6, 1, 0.5)

	# Оружие: дефолты из weapons/*.tres; rpm = 60 / attack_interval.
	_add_weapon("knife", "Нож", 20, 90, 400)
	_add_weapon("pistol", "Пистолет", 18, 200, 60)
	_add_weapon("rifle", "Автомат", 10, 300, 240)
	_add_weapon("saber", "Сабля", 35, 130, 133)
	_add_weapon("torpedo", "Торпеда", 28, 220, 30)
	_add_weapon("grenade", "Граната", 28, 220, 30)

	# Предметы: дефолты из world/*.gd и pickups/heal_pickup.gd.
	_def("items:chest:spawn_interval", "Частота спавна, сек", 10, 1, 0.5)
	_def("items:chest:health", "Здоровье сундука", 50, 1, 1)
	_def("items:chest:heal", "Восстанавливаемое здоровье", 20, 1, 1)
	_def("items:seaweed:spawn_interval", "Частота спавна, сек", 2.4, 0.5, 0.1)
	_def("items:seaweed:regen_per_second", "Восстановление кислорода в сек", 6, 1, 0.5)
	_def("items:module:total", "Запас прочности станции", 40, 5, 5)
	_def("items:module:regen_per_second", "Восстановление прочности в сек", 8, 1, 0.5)

	# Игрок: дефолты из player.gd (max_health, base_speed).
	_def("player:health", "Здоровье", 100, 10, 5)
	_def("player:speed", "Скорость", 320, 50, 10)

	# Фонарь (подраздел Баланс → Игрок → Фонарь): радиус круга вокруг игрока,
	# внутри которого видимость обычная; снаружи вода темнеет с глубиной
	# (оверлей затемнения — world/lighting.gd). Читается lighting.gd каждый
	# кадр, поэтому ползунок действует на лету.
	_def("player:flashlight:radius", "Радиус", 260, 60, 10)


func _ready() -> void:
	_load()
	for weapon_id in WEAPON_PATHS:
		_apply_weapon(weapon_id)


func _add_pack_enemy(id: String, health: float, speed: float, damage: float, xp: int, schooling: bool = false, lunge_range: float = -1.0, lunge_speed: float = -1.0) -> void:
	var prefix := "enemy:%s:" % id
	_def_bool(prefix + "schooling", "Стая", schooling)
	_def(prefix + "pack_size", "Особей в стае", 4, 1, 1)
	_def(prefix + "pack_interval", "Частота респауна, сек", 6, 1, 0.5)
	_def(prefix + "health", "Здоровье особи", health, 1, 1)
	_def(prefix + "speed", "Скорость", speed, 10, 5)
	_def(prefix + "damage", "Урон особи", damage, 1, 1)
	_def(prefix + "xp", "Опыт за убийство", xp, 0, 1)
	if lunge_range >= 0.0:
		_def(prefix + "lunge_range", "Дистанция прыжка", lunge_range, 10, 5)
		_def(prefix + "lunge_speed", "Скорость прыжка", lunge_speed, 50, 10)


## Признак стайности врага: стаи собираются только из типов со включённым
## schooling (enemy_spawner.gd); остальные спавнятся одиночными особями.
func is_schooling(enemy_id: String) -> bool:
	var key := "enemy:%s:schooling" % enemy_id
	return defs.has(key) and get_value(key) > 0.5


func _add_weapon(id: String, _title: String, damage: float, attack_range: float, rpm: float) -> void:
	# Имя оружия для меню живёт в WEAPON_TITLES; метки статов короткие, т.к.
	# меню и так группирует их внутри подраздела конкретного оружия.
	var prefix := "weapon:%s:" % id
	_def(prefix + "damage", "Урон", damage, 1, 1)
	_def(prefix + "range", "Дистанция", attack_range, 20, 10)
	_def(prefix + "rpm", "Выстрелов в минуту", rpm, 5, 5)


func _def(key: String, label: String, default: float, min: float, step: float) -> void:
	defs[key] = {
		"label": label,
		"default": default,
		"min": min,
		"max": 2.0 * default - min, # дефолт ровно посередине шкалы
		"step": step,
	}


## Булево определение (флаг вкл/выкл, напр. стайность): меню рисует его
## чекбоксом вместо ползунка (см. balance_menu.gd), значение хранится как
## 0.0/1.0 в общем формате.
func _def_bool(key: String, label: String, default: bool) -> void:
	defs[key] = {
		"label": label,
		"default": 1.0 if default else 0.0,
		"min": 0.0,
		"max": 1.0,
		"step": 1.0,
		"bool": true,
	}


func get_value(key: String) -> float:
	if values.has(key):
		return values[key]
	return defs[key]["default"]


## Единственная точка изменения: меню ползунков зовёт её на каждое движение.
## Сразу пишет на диск (автосохранение) и применяет то, что применимо "на
## лету" (оружие, игрок); остальное подхватится при следующем спавне/_ready.
func set_value(key: String, value: float) -> void:
	values[key] = value
	_save()
	if key.begins_with("weapon:"):
		_apply_weapon(key.get_slice(":", 1))
	elif key.begins_with("player:"):
		player_stats_changed.emit()


func _apply_weapon(weapon_id: String) -> void:
	var path: String = WEAPON_PATHS.get(weapon_id, "")
	if path.is_empty():
		return
	var weapon := load(path) as WeaponData
	if weapon == null:
		return
	var prefix := "weapon:%s:" % weapon_id
	weapon.damage = get_value(prefix + "damage")
	weapon.attack_range = get_value(prefix + "range")
	var rpm := maxf(get_value(prefix + "rpm"), 1.0)
	weapon.attack_interval = 60.0 / rpm


## Ключи определений данного подраздела в порядке вставки — меню строит
## ползунки прямо по этому списку.
func keys_with_prefix(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for key in defs:
		if key.begins_with(prefix):
			result.append(key)
	return result


func _save() -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value(SAVE_SECTION, key, values[key])
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in config.get_section_keys(SAVE_SECTION):
		if defs.has(key):
			values[key] = config.get_value(SAVE_SECTION, key)
