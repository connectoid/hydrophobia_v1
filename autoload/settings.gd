extends Node
## Глобальные настройки сессии (выбираются в меню паузы/главном меню).
##
## Персистентны — сохраняются в SAVE_PATH при КАЖДОМ изменении (см. все
## set_*, каждый заканчивается вызовом save_settings) и читаются обратно в
## _ready() при старте игры (load_settings). Сохранение "на каждое
## изменение", а не только по кнопке «Выход», — само собой работает и как
## "сохранение при выходе": на диске всегда уже лежит актуальное состояние,
## отдельно ловить закрытие окна/аварийный выход не нужно.
##
## Все мутации обязаны идти через set_*, а не прямым присваиванием в var —
## иначе изменение не попадёт на диск. UI (ui/main_menu.gd, ui/pause_menu.gd)
## это уже соблюдает.

const SAVE_PATH := "user://settings.cfg"
const SAVE_SECTION := "settings"

enum ControlMode { MOUSE, KEYBOARD, BOTH }

var control_mode: ControlMode = ControlMode.BOTH
var sound_enabled: bool = false

## Отладочный флаг из меню паузы (Отладка → Остановить всех врагов) —
## читается enemy.gd, останавливает движение/атаку всех врагов, пока включён.
var enemies_frozen: bool = false

## Отладочный флаг из меню паузы (Отладка → Режим Бога) — читается player.gd,
## отключает трату кислорода и получение урона, пока включён.
var god_mode: bool = false

## Отладочный флаг из меню паузы (Отладка → Attack Range) — читается
## player/attack_range_indicator.gd, скрывает круги зоны поражения оружия.
var show_attack_range: bool = true

## Визуальный вариант батискафа (Отладка → Батискаф) — id из
## BATHYSCAPHE_VARIANTS, читается player.gd. Единственный источник правды о
## том, какие варианты вообще доступны и где лежат их SpriteFrames — и
## player.gd (чтобы загрузить нужный .tres), и меню отладки (main_menu.gd,
## pause_menu.gd — чтобы построить кнопки переключения) берут список отсюда,
## а не хардкодят каждый свой. Остальные варианты-кандидаты, ещё не
## добавленные сюда, лежат в samples/player/bathyscaphes/ как библиотека на
## будущее (см. _generator/ там же — скрипт, которым они нарисованы).
const BATHYSCAPHE_VARIANTS := [
	{"id": "bulb", "title": "Пузырь", "frames": "res://player/bathyscaphes/bulb/bulb_frames.tres"},
	{"id": "harpoon", "title": "Гарпунёр", "frames": "res://player/bathyscaphes/harpoon/harpoon_frames.tres"},
	{"id": "bell", "title": "Колокол", "frames": "res://player/bathyscaphes/bell/bell_frames.tres"},
]
const DEFAULT_BATHYSCAPHE_VARIANT := "bulb"

signal bathyscaphe_variant_changed(variant_id: String)

var selected_bathyscaphe_variant: String = DEFAULT_BATHYSCAPHE_VARIANT

## Количество врагов (Отладка → Количество врагов) — 10 дискретных уровней,
## читается enemy_spawner.gd (get_enemy_density_multiplier) как ещё один
## множитель интервала спавна, независимый от остальных (прогресс волны,
## номер волны, "фарм на месте" — см. enemy_spawner.gd::_process). Не трогает
## состав/веса пула врагов, только то, как часто он вообще тикает.
##
## Уровень 10 (максимум, значение по умолчанию) даёт множитель ровно 1.0 —
## поведение без изменений, "как сейчас"; уровень 1 — 0.1 (в 10 раз реже).
const ENEMY_DENSITY_LEVELS := 10
const ENEMY_DENSITY_LABELS: Array[String] = [
	"Очень мало", "Мало", "Поменьше", "Ниже среднего", "Средне",
	"Выше среднего", "Многовато", "Много", "Очень много", "Как сейчас",
]

var enemy_density_level: int = ENEMY_DENSITY_LEVELS


func _ready() -> void:
	load_settings()
	# Применяем звук сразу при старте — сам по себе флаг sound_enabled на
	# звук не влияет, пока не применён к шине (ту же строку дёргает и
	# set_sound_enabled при последующих изменениях).
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_enabled)


func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not enabled)
	save_settings()


func set_control_mode(mode: ControlMode) -> void:
	control_mode = mode
	save_settings()


func set_enemies_frozen(frozen: bool) -> void:
	enemies_frozen = frozen
	save_settings()


func set_god_mode(enabled: bool) -> void:
	god_mode = enabled
	save_settings()


func set_show_attack_range(enabled: bool) -> void:
	show_attack_range = enabled
	save_settings()


## Переключает батискаф "на лету" (см. bathyscaphe_variant_changed) — не
## только для следующего забега, но и у уже заспавненного игрока, если
## меняется прямо посреди волны через меню паузы.
func set_bathyscaphe_variant(variant_id: String) -> void:
	selected_bathyscaphe_variant = variant_id
	bathyscaphe_variant_changed.emit(variant_id)
	save_settings()


## Путь к SpriteFrames варианта по его id — с фоллбэком на первый вариант в
## списке (bulb), если id почему-то не найден, вместо падения.
func get_bathyscaphe_frames_path(variant_id: String) -> String:
	for variant in BATHYSCAPHE_VARIANTS:
		if variant["id"] == variant_id:
			return variant["frames"]
	return BATHYSCAPHE_VARIANTS[0]["frames"]


func set_enemy_density_level(level: int) -> void:
	enemy_density_level = clampi(level, 1, ENEMY_DENSITY_LEVELS)
	save_settings()


func get_enemy_density_multiplier() -> float:
	return float(enemy_density_level) / float(ENEMY_DENSITY_LEVELS)


## Пишет текущие настройки в SAVE_PATH (ConfigFile — простой INI-формат,
## штатный способ Godot для такого рода данных). Вызывается из каждого
## set_* выше — отдельно обрабатывать выход из игры не требуется, см.
## doc-комментарий класса.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, "control_mode", control_mode)
	config.set_value(SAVE_SECTION, "sound_enabled", sound_enabled)
	config.set_value(SAVE_SECTION, "enemies_frozen", enemies_frozen)
	config.set_value(SAVE_SECTION, "god_mode", god_mode)
	config.set_value(SAVE_SECTION, "show_attack_range", show_attack_range)
	config.set_value(SAVE_SECTION, "selected_bathyscaphe_variant", selected_bathyscaphe_variant)
	config.set_value(SAVE_SECTION, "enemy_density_level", enemy_density_level)
	config.save(SAVE_PATH)


## Читает SAVE_PATH, если он есть. Отсутствие файла (первый запуск игры на
## этой машине) — не ошибка, просто остаёмся на дефолтах, объявленных выше
## у каждой переменной; get_value с третьим аргументом даёт тот же эффект
## и для отдельных ключей, которых в файле почему-то не оказалось (например,
## если он был сохранён более старой версией игры, до появления настройки).
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	control_mode = config.get_value(SAVE_SECTION, "control_mode", control_mode)
	sound_enabled = config.get_value(SAVE_SECTION, "sound_enabled", sound_enabled)
	enemies_frozen = config.get_value(SAVE_SECTION, "enemies_frozen", enemies_frozen)
	god_mode = config.get_value(SAVE_SECTION, "god_mode", god_mode)
	show_attack_range = config.get_value(SAVE_SECTION, "show_attack_range", show_attack_range)
	selected_bathyscaphe_variant = config.get_value(SAVE_SECTION, "selected_bathyscaphe_variant", selected_bathyscaphe_variant)
	enemy_density_level = config.get_value(SAVE_SECTION, "enemy_density_level", enemy_density_level)
