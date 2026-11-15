extends Node2D
## Спавнит врагов стаями и одиночками на протяжении одного непрерывного забега
## (DepthManager.start_run → run_completed). Стайные типы (Balance.is_schooling
## — переключается в меню Баланс → Враги → «Стая», по умолчанию только пиранья)
## появляются группами ОДНОГО типа из одной точки (разброс pack_radius) и
## атакуют вместе; у каждого стайного типа свой таймер (интервал из Balance,
## модулируется кривыми сложности ниже), размер стаи — тоже из Balance плюс
## рост от тира глубины. Одиночные типы приходят по одному за тик своего
## таймера, не участвуют в учёте стай (_packs) и не ограничены
## max_active_packs. Характеристики особей (здоровье/скорость/урон/прыжок/
## опыт) применяются при спавне из Balance тем же меню и дополнительно
## умножаются на кривые агрессии DepthManager (чем глубже — тем злее).
## Доступные типы врагов открываются по тиру глубины
## (DepthManager.get_depth_tier() — каждые 100 м следующий тир, заменяет
## прежний "номер волны" в EnemyData.min_level/max_level); при смене тира
## таймеры типов пересобираются.
## Когда игрок выбил все живые СТАИ, таймер одного случайного стайного типа
## перезапускается ускоренно (pack_respawn_delay) — ритм "отбился — приплыла
## следующая".
## Фоновая живность (EnemyData.ambient, кислородная рыба) ходит отдельным
## равномерным циклом AmbientTimer со своим интервалом из Balance и в стаях
## не участвует.
## Виды врагов — в enemy_pool (EnemyData, enemies/data/*.tres).

@export var enemy_pool: Array[EnemyData] = []

@export var spawn_distance: float = 500.0

## К концу забега (по мере погружения к DepthManager.run_depth) стаи приходят
## в этот множитель раз чаще (2.5 = интервал в 2.5 раза короче), нарастает
## линейно вместе с прогрессом погружения — чем глубже, тем гуще, подталкивает
## нырять быстрее.
@export var end_of_wave_frequency_multiplier: float = 2.5

## Рост частоты стай от тира к тиру (0.2 = +20% за каждый тир глубины после
## первого, DepthManager.get_depth_tier()) — вместе с открытием новых типов
## врагов делает погружение всё напряжённее.
@export var per_wave_frequency_growth: float = 0.2

## "Штраф за фарм на месте" — в отличие от прогресс-множителя (который зависит
## от ГЛУБИНЫ погружения) этот множитель растёт от ВРЕМЕНИ, если игрок не
## продвигается вниз хотя бы на camp_progress_step метров. Не даёт
## бесконечно долго стоять на одной глубине и фармить врагов без риска —
## чем дольше топчешься на месте, тем чаще стаи. Сбрасывается на 0 каждый
## раз, как только глубина реально продвинулась (см. _process), и заново —
## при старте забега.
@export var camp_progress_step: float = 5.0 # метров, ниже которых прогресс не засчитывается
@export var camp_ramp_time: float = 8.0 # сек до полного эффекта camp_max_multiplier
@export var camp_max_multiplier: float = 3.0

## Сколько особей добавляется к базовому размеру стаи из Balance за каждый
## тир глубины после первого.
@export var pack_size_wave_growth: float = 0.5

## Радиус разброса особей вокруг центра стаи — точка появления одна, но особи
## не спавнятся в одном пикселе.
@export var pack_radius: float = 130.0

## Потолок одновременно живых стай: пока он достигнут, новые стаи не появляются
## (таймер типа перезапустится и попробует снова).
@export var max_active_packs: int = 3

## Пауза перед новой стаей после полного выбивания всех живых стай — если
## таймер случайного типа не должен прозвучать раньше.
@export var pack_respawn_delay: float = 2.0

## Пока на экране видна поверхность воды (DepthManager.get_floor_y()), стаи не
## должны спавниться "из" неё сверху — только снизу и по бокам. Как только
## игрок опускается достаточно глубоко и поверхность уходит за пределы вида
## камеры, спавн сверху снова разрешён (см. _is_surface_visible).
const UP_ANGLE := -PI / 2.0
const UP_FORBIDDEN_ARC := PI / 2.0 # ширина запретного конуса "сверху", в радианах

@onready var ambient_timer: Timer = $AmbientTimer

## enemy_id -> one_shot Timer его стай. Пересоздаются при смене тира глубины
## (состав доступных типов зависит от DepthManager.get_depth_tier()).
var _type_timers: Dictionary = {}
var _current_tier: int = 0
var _pack_seq: int = 0
## pack_id -> число живых особей стаи. Пустой словарь = все стаи выбиты,
## следующая придёт ускоренно (см. _on_enemy_died).
var _packs: Dictionary = {}
var _camp_reference_depth: float = 0.0
var _camp_timer: float = 0.0
## Произведение всех множителей частоты за последний кадр (см. _process) —
## таймеры типов читают его в _type_wait(), не пересчитывая сами.
var _frequency_multiplier: float = 1.0


func _ready() -> void:
	ambient_timer.timeout.connect(_on_ambient_timer_timeout)
	DepthManager.run_started.connect(_on_run_started)
	DepthManager.run_completed.connect(_on_run_completed)


func _process(delta: float) -> void:
	if not DepthManager.run_active:
		return

	if DepthManager.current_depth >= _camp_reference_depth + camp_progress_step:
		_camp_reference_depth = DepthManager.current_depth
		_camp_timer = 0.0
	else:
		_camp_timer += delta
	var camp_multiplier := 1.0 + clampf(_camp_timer / camp_ramp_time, 0.0, 1.0) * (camp_max_multiplier - 1.0)

	var progress := DepthManager.get_dive_progress()
	var dive_multiplier := lerpf(1.0, end_of_wave_frequency_multiplier, progress)
	var tier_multiplier := 1.0 + maxf(DepthManager.get_depth_tier() - 1, 0) * per_wave_frequency_growth
	# Отладка → Количество врагов (Settings.enemy_density_level, 1..10) — ещё
	# один множитель частоты, независимый от остальных. На максимуме (10/10)
	# даёт ровно 1.0 — поведение без изменений, как было всегда; ниже —
	# пропорционально более редкий спавн (10x на минимуме).
	var density_multiplier := Settings.get_enemy_density_multiplier()
	_frequency_multiplier = dive_multiplier * tier_multiplier * camp_multiplier * density_multiplier

	# Новые тиры глубины открывают новых врагов (EnemyData.min_level) —
	# пересобираем таймеры типов, чтобы новенькие сразу включились в ротацию.
	var tier := DepthManager.get_depth_tier()
	if tier != _current_tier:
		_current_tier = tier
		if not _type_timers.is_empty():
			_rebuild_type_timers()

	# wait_time, выставленный посреди тика one_shot-таймера, применяется при
	# следующем start() — то есть со следующей стаи типа, что и нужно: текущая
	# уже плывёт, её частоту менять поздно.
	for enemy_id in _type_timers:
		_type_timers[enemy_id].wait_time = _type_wait(enemy_id)


func _on_run_started() -> void:
	_camp_reference_depth = DepthManager.current_depth
	_camp_timer = 0.0
	_packs.clear()
	_current_tier = DepthManager.get_depth_tier()
	_rebuild_type_timers()
	# Первыми приходят стайные типы (если они есть на текущем тире) — стартовая
	# атака должна читаться как нападение стаи.
	var ids := _type_timers.keys().filter(func(id): return Balance.is_schooling(id))
	if ids.is_empty():
		ids = _type_timers.keys()
	if not ids.is_empty():
		var first_id: String = ids[randi() % ids.size()]
		_spawn_pack_for(first_id)
	ambient_timer.wait_time = Balance.get_value("enemy:oxygen_fish:spawn_interval")
	ambient_timer.start()


func _on_run_completed() -> void:
	ambient_timer.stop()
	for enemy_id in _type_timers:
		_type_timers[enemy_id].queue_free()
	_type_timers.clear()
	# level.gd удаляет врагов queue_free() без die() — сигнал died не придёт,
	# учёт стай чистим здесь сами.
	_packs.clear()


## По таймеру на каждый доступный в текущем тире глубины тип. Стартовые
## интервалы со случайным множителем 0.5–1.0, чтобы стаи разных типов не
## выстраивались в синхронный конвейер.
func _rebuild_type_timers() -> void:
	for enemy_id in _type_timers:
		_type_timers[enemy_id].queue_free()
	_type_timers.clear()
	for data in enemy_pool:
		if data.ambient or not data.can_spawn_on_level(DepthManager.get_depth_tier()):
			continue
		var enemy_id := _data_id(data)
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = _type_wait(enemy_id) * randf_range(0.5, 1.0)
		timer.timeout.connect(_on_type_timer_timeout.bind(enemy_id))
		_type_timers[enemy_id] = timer
		add_child(timer)
		timer.start()


func _type_wait(enemy_id: String) -> float:
	var base := Balance.get_value("enemy:%s:pack_interval" % enemy_id)
	return maxf(base / _frequency_multiplier, 0.2)


func _on_type_timer_timeout(enemy_id: String) -> void:
	var timer: Timer = _type_timers.get(enemy_id)
	if timer == null:
		return
	if Balance.is_schooling(enemy_id):
		if _packs.size() < max_active_packs:
			_spawn_pack_for(enemy_id)
	else:
		# Одиночки не входят в учёт стай (_packs) и не ограничены
		# max_active_packs — они фоновая угроза со своим медленным ритмом.
		_spawn_single(enemy_id)
	timer.wait_time = _type_wait(enemy_id)
	timer.start()


## Одиночная особь нестайного типа: одна точка спавна, без учёта в _packs.
func _spawn_single(enemy_id: String) -> void:
	var data := _data_by_id(enemy_id)
	if data == null or data.scene == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var enemy: Node2D = data.scene.instantiate()
	enemy.global_position = _clamp_to_floor(player.global_position + Vector2.RIGHT.rotated(_pick_spawn_angle(player)) * spawn_distance)
	enemy.xp_reward = data.xp_reward
	_apply_enemy_stats(enemy, enemy_id)
	get_tree().current_scene.add_child(enemy)


## Фоновая живность идёт своим ритмом: одна особь за тик, интервал каждый раз
## заново из Balance (равномерно всю волну, без кривых сложности хищников).
func _on_ambient_timer_timeout() -> void:
	_spawn_ambient()
	ambient_timer.wait_time = Balance.get_value("enemy:oxygen_fish:spawn_interval")


func _spawn_ambient() -> void:
	var data := _pick_ambient_data()
	if data == null or data.scene == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var enemy_id := _data_id(data)
	var enemy: Node2D = data.scene.instantiate()
	enemy.global_position = _clamp_to_floor(player.global_position + Vector2.RIGHT.rotated(_pick_spawn_angle(player)) * spawn_distance)
	enemy.xp_reward = data.xp_reward
	_apply_enemy_stats(enemy, enemy_id)
	get_tree().current_scene.add_child(enemy)


## Одна стая = один тип врага, один центр появления. Особи разводятся по
## диску pack_radius вокруг центра, чтобы стая выглядела стаей, а не одной
## точкой, но при этом держалась вместе и плыла к игроку группой (одинаковые
## speed/поведение у одного типа не дают ей разбежаться).
func _spawn_pack_for(enemy_id: String) -> void:
	var data := _data_by_id(enemy_id)
	if data == null or data.scene == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_pack_seq += 1
	var pack_id := _pack_seq
	var center := _pick_pack_center(player)
	var count := _roll_pack_size(enemy_id)
	_packs[pack_id] = count
	for i in count:
		var enemy: Node2D = data.scene.instantiate()
		enemy.global_position = _clamp_to_floor(center + _random_pack_offset())
		enemy.xp_reward = data.xp_reward
		_apply_enemy_stats(enemy, enemy_id)
		enemy.died.connect(_on_enemy_died.bind(pack_id))
		get_tree().current_scene.add_child(enemy)


## Характеристики особи из Balance (Отладка → Баланс → Враги) поверх кривых
## агрессии DepthManager: чем глубже, тем злее (урон и скорость умножаются на
## get_enemy_damage_multiplier/get_enemy_speed_multiplier). "Урон особи"
## ложится в lunge_damage у прыгуньих типов и в contact_damage у остальных —
## там, где у этого врага реально живёт урон. У фоновой живности (ambient)
## статов урона/опыта/прыжка в Balance нет по дизайну меню — эти секции
## пропускаются, xp остаётся из EnemyData.
func _apply_enemy_stats(enemy: Node2D, enemy_id: String) -> void:
	var prefix := "enemy:%s:" % enemy_id
	var aggression := DepthManager.get_enemy_damage_multiplier()
	var speed_aggression := DepthManager.get_enemy_speed_multiplier()
	enemy.max_health = Balance.get_value(prefix + "health")
	enemy.speed = Balance.get_value(prefix + "speed") * speed_aggression
	if Balance.defs.has(prefix + "damage"):
		var damage := Balance.get_value(prefix + "damage") * aggression
		if enemy.get("lunge_enabled") == true:
			enemy.lunge_damage = damage
			enemy.lunge_range = Balance.get_value(prefix + "lunge_range")
			enemy.lunge_speed = Balance.get_value(prefix + "lunge_speed")
		else:
			enemy.contact_damage = damage
	if Balance.defs.has(prefix + "xp"):
		enemy.xp_reward = roundi(Balance.get_value(prefix + "xp"))


func _roll_pack_size(enemy_id: String) -> int:
	var growth := int(maxf(DepthManager.get_depth_tier() - 1, 0) * pack_size_wave_growth)
	return roundi(Balance.get_value("enemy:%s:pack_size" % enemy_id)) + growth


## Равномерная точка в диске pack_radius (sqrt — иначе особи липли бы к центру).
func _random_pack_offset() -> Vector2:
	return Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf()) * pack_radius


func _pick_pack_center(player: Node2D) -> Vector2:
	var angle := _pick_spawn_angle(player)
	return _clamp_to_floor(player.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance)


## Выше уровня воды враги не появляются — прижимаем точку к границе.
func _clamp_to_floor(pos: Vector2) -> Vector2:
	pos.y = maxf(pos.y, DepthManager.get_floor_y())
	return pos


func _on_enemy_died(pack_id: int) -> void:
	if not _packs.has(pack_id):
		return
	_packs[pack_id] -= 1
	if _packs[pack_id] <= 0:
		_packs.erase(pack_id)
	if not _packs.is_empty() or not DepthManager.run_active:
		return
	# Все стаи выбиты — одна случайная приплывает ускоренно, но не раньше,
	# чем её таймер прозвучал бы сам, если тот ближе. Предпочитаем стайные
	# типы: ускоренный ответ на зачистку — часть ритма "стая → отбился → стая".
	var ids := _type_timers.keys().filter(func(id): return Balance.is_schooling(id))
	if ids.is_empty():
		ids = _type_timers.keys()
	var candidates: Array = ids.filter(
		func(id): return _type_timers[id].time_left > pack_respawn_delay
	)
	if candidates.is_empty():
		return
	var chosen: String = candidates.pick_random()
	_type_timers[chosen].start(pack_respawn_delay)


func _data_id(data: EnemyData) -> String:
	return data.resource_path.get_file().get_basename()


func _data_by_id(enemy_id: String) -> EnemyData:
	for data in enemy_pool:
		if _data_id(data) == enemy_id:
			return data
	return null


func _pick_spawn_angle(player: Node2D) -> float:
	if not _is_surface_visible(player):
		return randf() * TAU
	# Граница воды видна на экране — исключаем конус "сверху", чтобы стаи не
	# материализовались прямо из неё; спавн остаётся возможен снизу и по бокам.
	var forbidden_start := UP_ANGLE - UP_FORBIDDEN_ARC * 0.5
	var allowed_span := TAU - UP_FORBIDDEN_ARC
	return forbidden_start + UP_FORBIDDEN_ARC + randf() * allowed_span


func _is_surface_visible(player: Node2D) -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return false
	var half_view_height: float = (get_viewport().get_visible_rect().size.y * 0.5) / camera.zoom.y
	return player.global_position.y - DepthManager.get_floor_y() <= half_view_height


func _pick_ambient_data() -> EnemyData:
	var candidates: Array[EnemyData] = []
	for data in enemy_pool:
		if data.ambient and data.can_spawn_on_level(DepthManager.get_depth_tier()):
			candidates.append(data)
	if candidates.is_empty():
		return null

	var total_weight := 0.0
	for data in candidates:
		total_weight += data.spawn_weight
	if total_weight <= 0.0:
		return candidates[0]

	var roll := randf() * total_weight
	var cumulative := 0.0
	for data in candidates:
		cumulative += data.spawn_weight
		if roll < cumulative:
			return data
	return candidates[-1]
