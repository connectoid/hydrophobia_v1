extends Node
## Центральная система прогрессии забега: текущая глубина и кривые сложности
## (частота/сила врагов, свет, давление) как функции от глубины.
## См. DESIGN.md, раздел 6.
##
## Забег ОДИН и непрерывный: волн больше нет. Игрок стартует с поверхности
## (SURFACE_Y = "0 м") и должен спуститься на run_depth метров (по умолчанию
## 1000 — короткая дистанция для отладки, позже будет увеличена). Как только
## глубина достигнута — забег пройден (run_completed → победа в level.gd).
##
## Глубина — "настоящая": привязана к фактическому вертикальному перемещению
## игрока в мире. player.gd вызывает update_depth() каждый физический кадр со
## своей мировой Y-координатой. Погружение (движение вниз, Y растёт)
## увеличивает глубину, всплытие — уменьшает; подняться выше уровня воды
## физически нельзя (get_floor_y()).
##
## Сложность растёт плавно вместе с глубиной:
## - get_dive_progress() — доля пути (0..1), на неё опираются частота спавна
##   (enemy_spawner.gd) и плавное затемнение воды (world/lighting.gd);
## - get_depth_tier() — "уровень" сложности шагом tier_depth метров: по нему
##   спавнер открывает новые типы врагов (EnemyData.min_level/max_level) и
##   растит размер стай;
## - get_enemy_damage_multiplier()/get_enemy_speed_multiplier() — враги
##   становятся агрессивнее к концу забега (применяются при спавне).

signal run_started
signal run_completed
signal depth_changed(new_depth: float)

## Мировая Y-координата уровня воды (глубина 0). Единая точка отсчёта для
## игрока и всех спавнеров — не координата старта конкретного игрока.
const SURFACE_Y := 0.0

## Масштаб перевода пикселей мира в "метры" глубины для HUD и кривых сложности
## ниже. Плейсхолдер-величина — не откалибрована под конкретный арт/левелдизайн.
const PIXELS_PER_METER := 32.0

const PRESSURE_START_DEPTH := 500.0 # давление корпуса, DESIGN.md п.3 (пока не применяется)

## Цель забега: глубина (м), на которой спуск завершается победой.
## Временно короткая (1000) — врагов и механик мало, тестируем на малой
## дистанции; позже будет увеличена.
@export var run_depth: float = 1000.0

## Шаг "тирa" сложности (м): каждые tier_depth метров открывается следующий
## тир (1..), spawner трактует его как бывший "номер волны" для пула врагов.
@export var tier_depth: float = 100.0

## Насколько злее становятся враги к концу забега: множители урона и скорости
## плавно растут от 1.0 на поверхности до 1+growth на run_depth.
@export var aggression_damage_growth: float = 0.6
@export var aggression_speed_growth: float = 0.2

var current_depth: float = 0.0
var run_active: bool = false


func start_run() -> void:
	current_depth = 0.0
	run_active = true
	run_started.emit()


func complete_run() -> void:
	run_active = false
	run_completed.emit()


## Доля пути до цели забега, от 0 (поверхность) до 1 (run_depth достигнута).
## Используется и для UI, и для плавного нарастания сложности/темноты.
func get_dive_progress() -> float:
	if run_depth <= 0.0:
		return 1.0
	return clampf(current_depth / run_depth, 0.0, 1.0)


## Тир сложности по глубине: 1 на первых tier_depth метрах, 2 на следующих и
## т.д. Заменяет прежний "номер волны" в EnemyData.can_spawn_on_level и в
## росте размера стай.
func get_depth_tier() -> int:
	return 1 + int(current_depth / maxf(tier_depth, 1.0))


## Вызывается player.gd каждый физический кадр с его текущей мировой
## Y-координатой. Глубина = расстояние от SURFACE_Y вниз, в метрах; не может
## уйти в минус, даже если игрок каким-то образом оказался выше уровня воды
## (в норме это уже исключено клампом позиции в player.gd). Как только
## достигнута run_depth — забег завершается.
func update_depth(world_y: float) -> void:
	var new_depth := maxf(world_y - SURFACE_Y, 0.0) / PIXELS_PER_METER
	if is_equal_approx(new_depth, current_depth):
		return
	current_depth = new_depth
	depth_changed.emit(current_depth)
	if run_active and current_depth >= run_depth:
		complete_run()


## Мировая Y-координата физической границы, выше которой нельзя подняться —
## уровень воды. Игрок (player.gd), враги (enemy.gd) и спавнеры
## (enemy_spawner.gd/chest_spawner.gd) клампят позицию/спавн по этому
## значению (прежняя "переезжающая" граница волны упразднена вместе с волнами).
func get_floor_y() -> float:
	return SURFACE_Y


## Мировая Y-координата цели забега (run_depth) — для визуализации финишной
## границы (world/depth_background.gd). На физику не влияет.
func get_goal_y() -> float:
	return SURFACE_Y + run_depth * PIXELS_PER_METER


## Тяга движителя падает с глубиной (DESIGN.md п.2). Балласт/апгрейды позже
## будут компенсировать этот множитель — сейчас это базовая кривая-заглушка.
func get_speed_multiplier(depth: float = current_depth) -> float:
	return clampf(1.0 - depth * 0.00025, 0.35, 1.0)


## Видимость сужается с глубиной (DESIGN.md п.6, Light/Vision System).
## Legacy-кривая: фактический радиус фонаря задаётся в Balance, а затемнение —
## в world/lighting.gd.
func get_light_radius(depth: float = current_depth) -> float:
	return clampf(900.0 - depth * 0.35, 80.0, 900.0)


## Давление откусывает HP начиная с PRESSURE_START_DEPTH (DESIGN.md п.3, п.6).
## ВРЕМЕННО НЕ ПРИМЕНЯЕТСЯ: давление корпус пока не разрушает (забег
## сфокусирован на отражении атак врагов), кривая оставлена на будущее.
func get_pressure_damage_per_second(depth: float = current_depth) -> float:
	if depth < PRESSURE_START_DEPTH:
		return 0.0
	return (depth - PRESSURE_START_DEPTH) * 0.015


## Враги становятся агрессивнее с глубиной — множители применяются спавнером
## при создании особи (enemy_spawner.gd::_apply_enemy_stats).
func get_enemy_damage_multiplier(depth: float = current_depth) -> float:
	return 1.0 + clampf(depth / run_depth, 0.0, 1.0) * aggression_damage_growth


func get_enemy_speed_multiplier(depth: float = current_depth) -> float:
	return 1.0 + clampf(depth / run_depth, 0.0, 1.0) * aggression_speed_growth
