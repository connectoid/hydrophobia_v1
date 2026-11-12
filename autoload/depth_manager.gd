extends Node
## Центральная система прогрессии заплыва: текущая глубина, номер волны
## и кривые сложности (спавн-веса врагов, свет, давление) как функции от глубины.
## См. DESIGN.md, раздел 6.
##
## Глубина — "настоящая": привязана к фактическому вертикальному перемещению
## игрока в мире, а не к таймеру. player.gd вызывает update_depth() каждый
## физический кадр со своей мировой Y-координатой. SURFACE_Y — единая для
## всей игры мировая отметка "0 м" (уровень воды в начале забега). Погружение
## (движение вниз, Y растёт) увеличивает глубину, всплытие — уменьшает.
##
## Волна заканчивается не по таймеру, а когда игрок нырнёт на wave_depth_goal
## метров глубже отметки, на которой волна началась — так момент завершения
## выбирает сам игрок: пока враги за волну становятся только многочисленнее
## (см. enemy_spawner.gd), можно оставаться на текущей глубине и фармить их
## дальше, либо нырнуть и раньше выйти в магазин оружия.
##
## Каждая пройденная волна "запечатывает" за собой зону: подняться выше
## отметки, на которой началась текущая волна, физически нельзя (см.
## get_wave_floor_y() — жёсткий кламп позиции в player.gd/enemy.gd, граница
## спавна в enemy_spawner.gd/chest_spawner.gd) — по аналогии с исходной
## границей SURFACE_Y в волне 1, только сама граница переезжает вниз при
## каждом новом start_wave().

signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal depth_changed(new_depth: float)

enum EnemyTier { SHALLOW, TWILIGHT, DEEP, ABYSS }

## Мировая Y-координата уровня воды (глубина 0). Единая точка отсчёта для
## игрока и всех спавнеров — не координата старта конкретного игрока.
const SURFACE_Y := 0.0

## Масштаб перевода пикселей мира в "метры" глубины для HUD и кривых сложности
## ниже. Плейсхолдер-величина — не откалибрована под конкретный арт/левелдизайн.
const PIXELS_PER_METER := 32.0

const PRESSURE_START_DEPTH := 500.0 # с уровня 7+, DESIGN.md п.3

## Сколько волн в забеге — после прохождения последней level.gd объявляет
## победу вместо магазина/следующей волны. Настраивается в Project Settings →
## Autoload → DepthManager (инспектор автозагрузок показывает @export-поля).
@export var max_waves: int = 10

## На сколько метров нужно нырнуть глубже стартовой отметки волны, чтобы она
## завершилась. Одинаково для всех волн — сложность растёт не ростом этой
## дистанции, а количеством врагов (per_wave_frequency_growth в enemy_spawner.gd).
@export var wave_depth_goal: float = 250.0

var current_depth: float = 0.0
var current_wave: int = 0
## Глубина в момент начала текущей волны — точка отсчёта для wave_depth_goal.
var wave_start_depth: float = 0.0
var wave_active: bool = false


func start_wave(wave_number: int) -> void:
	current_wave = wave_number
	wave_active = true
	if wave_number == 1:
		current_depth = 0.0 # новый забег — старая глубина (если осталась от предыдущего) не актуальна
	wave_start_depth = current_depth
	wave_started.emit(current_wave)


func end_wave() -> void:
	wave_active = false
	wave_ended.emit(current_wave)


## Доля пути до цели текущей волны, от 0 (только начали) до 1 (глубина
## достигнута). Используется и для UI, и для нарастания частоты спавна врагов
## по ходу волны (enemy_spawner.gd) — раньше та кривая опиралась на время,
## теперь на прогресс погружения.
func get_wave_progress() -> float:
	if wave_depth_goal <= 0.0:
		return 1.0
	return clampf((current_depth - wave_start_depth) / wave_depth_goal, 0.0, 1.0)


## Мировая Y-координата нижней границы уже пройденной зоны — потолок,
## выше которого физически нельзя подняться в ТЕКУЩЕЙ волне. Для волны 1 это
## сама поверхность воды (SURFACE_Y, wave_start_depth = 0); для волны 2+ —
## отметка, на которой волна началась, т.е. дно предыдущей зоны. Игрок
## (player.gd), враги (enemy.gd) и спавнеры (enemy_spawner.gd/chest_spawner.gd)
## клампят позицию/спавн по этому значению вместо константы SURFACE_Y —
## граница "переезжает" вниз с каждой новой волной.
func get_wave_floor_y() -> float:
	return SURFACE_Y + wave_start_depth * PIXELS_PER_METER


## Мировая Y-координата, на которой волна завершится (wave_start_depth +
## wave_depth_goal) — она же становится get_wave_floor_y() следующей волны.
## Только для визуализации (world/depth_background.gd рисует эту границу
## снизу заранее, более тёмным цветом следующей зоны) — на физику не влияет.
func get_wave_goal_y() -> float:
	return SURFACE_Y + (wave_start_depth + wave_depth_goal) * PIXELS_PER_METER


## Вызывается player.gd каждый физический кадр с его текущей мировой
## Y-координатой. Глубина = расстояние от SURFACE_Y вниз, в метрах; не может
## уйти в минус, даже если игрок каким-то образом оказался выше уровня воды
## (в норме это уже исключено клампом позиции в player.gd). Как только с
## начала волны игрок нырнул на wave_depth_goal метров — волна завершается.
func update_depth(world_y: float) -> void:
	var new_depth := maxf(world_y - SURFACE_Y, 0.0) / PIXELS_PER_METER
	if is_equal_approx(new_depth, current_depth):
		return
	current_depth = new_depth
	depth_changed.emit(current_depth)
	if wave_active and current_depth - wave_start_depth >= wave_depth_goal:
		end_wave()


## Тяга движителя падает с глубиной (DESIGN.md п.2). Балласт/апгрейды позже
## будут компенсировать этот множитель — сейчас это базовая кривая-заглушка.
func get_speed_multiplier(depth: float = current_depth) -> float:
	return clampf(1.0 - depth * 0.00025, 0.35, 1.0)


## Видимость сужается с глубиной (DESIGN.md п.6, Light/Vision System).
func get_light_radius(depth: float = current_depth) -> float:
	return clampf(900.0 - depth * 0.35, 80.0, 900.0)


## Давление откусывает HP начиная с уровня 7+ (DESIGN.md п.3, п.6).
## Толщина корпуса игрока должна снижать итоговый урон - применяется вызывающей стороной.
func get_pressure_damage_per_second(depth: float = current_depth) -> float:
	if depth < PRESSURE_START_DEPTH:
		return 0.0
	return (depth - PRESSURE_START_DEPTH) * 0.015


## Веса спавна врагов по диапазону глубины (DESIGN.md таблица уровней + п.6 Enemy Scaling).
## Плейсхолдер-колокола вокруг типичной глубины каждого тира; заменить реальным балансом.
func get_enemy_spawn_weights(depth: float = current_depth) -> Dictionary:
	return {
		EnemyTier.SHALLOW: _bell(depth, 50.0, 100.0),
		EnemyTier.TWILIGHT: _bell(depth, 300.0, 250.0),
		EnemyTier.DEEP: _bell(depth, 1250.0, 800.0),
		EnemyTier.ABYSS: clampf((depth - 2000.0) / 500.0, 0.0, 1.0),
	}


func _bell(depth: float, center: float, width: float) -> float:
	var t := (depth - center) / width
	return clampf(1.0 - t * t, 0.0, 1.0)
