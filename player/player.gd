extends CharacterBody2D
## Движение, здоровье, кислород, прочность корпуса и оружие игрока (минимальный
## игровой цикл, DESIGN.md).
## Оружие вынесено из кода в отдельное "хранилище" — weapons/*.tres (WeaponData).
## Игрок стартует с одним starting_weapon (нож); остальное покупается за XP
## в магазине между волнами (ui/weapon_shop.gd::open_for → add_weapon).
## Оружие можно покупать повторно (напр. 2 ножа) — каждая копия хранится
## отдельным элементом unlocked_weapons/_weapon_cooldowns и стреляет независимо.

signal died
signal health_changed(current_health: float, max_health: float)
signal experience_changed(current_xp: int)
## Новый уровень игрока: level.gd по нему открывает магазин оружия/прокачки
## (см. _check_level_up). Уровни считаются по СУММАРНОМУ заработанному опыту
## и не зависят от трат XP в магазине.
signal level_up(new_level: int)
signal oxygen_changed(current_oxygen: float, max_oxygen: float)
signal durability_changed(current_durability: float, max_durability: float)
signal weapon_unlocked(weapon: WeaponData)
signal weapon_sold(weapon: WeaponData)

## Физические слои проекта: бит "мира" общий (сундуки и т.п.), игрок и враги —
## на отдельных битах (см. также enemies/enemy.gd, player/projectile.gd),
## чтобы их collision_mask мог избирательно не толкать друг друга физически,
## оставаясь при этом видимыми для снарядов (те матчат по collision_layer,
## не по чужому mask).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

@export var base_speed: float = 320.0
@export var acceleration: float = 1500.0
@export var friction: float = 900.0

@export var max_health: float = 100.0

## Кислород тратится постоянно (DESIGN.md п.3) — полного бака без пополнения
## хватает примерно на max_oxygen/oxygen_drain_rate секунд, поэтому нужно
## активно искать кислородных рыб. При 0 — игрок тонет (die()).
@export var max_oxygen: float = 100.0
@export var oxygen_drain_rate: float = 4.0

## Кольцо атаки вокруг игрока: враги атакуют его границу, а не точку центра
## (иначе вблизи центра вектор курса вырождается и рыбы дёргаются/вращаются
## на месте). Цикл атаки врага: сближение до кольца → тычок → отскок →
## случайная пауза с круговым дрейфом вдоль кольца → снова сближение
## (см. enemy.gd::AttackPhase). Настраивается в Баланс → Игрок.
@export var attack_ring_radius: float = 90.0
## Дальность отскока врага после атаки (px ОТ границы кольца) и разброс
## паузы между атаками (сек) — читаются циклом атаки врагов, как и радиус
## кольца; все три ползунка в Баланс → Игрок.
@export var attack_retreat_distance: float = 60.0
@export var attack_wait_min: float = 0.3
@export var attack_wait_max: float = 0.9

## Прогрессия уровней игрока: следующий уровень требует в level_xp_growth раз
## больше опыта, чем предыдущий (100 → 150 → 225 → ...). Прогресс
## (_level_xp_progress) копится с ЛЮБОГО полученного опыта и не уменьшается от
## трат XP в магазине — текущий баланс current_xp является только валютой.
@export var level_xp_base: int = 100
@export var level_xp_growth: float = 1.5

## Прочность корпуса: давление её пока НЕ разрушает (забег сфокусирован на
## отражении атак врагов; дренаж и ремонт станциями временно убраны). Чем ниже
## прочность, тем больше урона наносят враги (см.
## _durability_damage_multiplier/take_damage) — при полной множитель = 1.
@export var max_durability: float = 100.0
@export var max_durability_damage_multiplier: float = 2.0 # множитель урона врагов при прочности 0

@export var mouse_move_deadzone: float = 20.0 # px вокруг курсора, где игрок не дёргается

## Оружие, с которым игрок начинает забег (назначается в player.tscn).
@export var starting_weapon: WeaponData

## Сцена визуализации удара ближним оружием (продолговатый клинок в сторону
## цели, длиной в attack_range) — создаётся на каждое попадание _fire_melee.
@export var melee_swing_scene: PackedScene

## Арт батискафа — AnimatedSprite2D со SpriteFrames из player/bathyscaphes/<вариант>/
## (сейчас "bulb", см. samples/player/bathyscaphes/ для остальных вариантов на
## выбор). Ожидаемые имена анимаций: idle/move (обе зациклены, переключаются
## по факту движения — см. _update_locomotion_animation) и attack/hurt (обе
## одноразовые, см. _play_one_shot_animation/_on_sprite_animation_finished).
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_health: float
var current_xp: int = 0
## Уровень игрока и прогресс текущего уровня. xp_to_next — сколько суммарного
## опыта нужно собрать на этом уровне; траты XP в магазине прогресс не
## откатывают (валюта и прогрессия раздельны).
var level: int = 1
var xp_to_next: int = 100
var _level_xp_progress: int = 0
var current_oxygen: float
var current_durability: float
var movement_input: Vector2 = Vector2.ZERO # актуальное направление движения (клавиатура или мышь) — читает depth_background.gd
## Купленное/стартовое оружие, может содержать повторы одного и того же
## WeaponData — у каждого элемента свой кулдаун в _weapon_cooldowns (тот же индекс).
var unlocked_weapons: Array[WeaponData] = []
var _weapon_cooldowns: Array[float] = []
## Состояние очереди для каждого слота (тот же индекс): сколько выстрелов
## очереди ещё осталось отдать и таймер до следующего выстрела очереди.
## См. burst_count/burst_cooldown в weapon_data.gd и _process_weapons.
var _burst_remaining: Array[int] = []
var _burst_timers: Array[float] = []

## Уровни (тиры) оружия: ПЕРЕДИННАЯ единица арсенала (параллельный массив к
## unlocked_weapons, тот же индекс). Растут кнопкой «Улучшить» в магазине
## (ui/weapon_shop.gd) при заполненных слотах: карточка оружия "сливается" с
## ОДНОЙ единицей в арсенале — её уровень +1, а карточка исчезает из
## предложения, как при покупке. Характеристики читаются через
## WeaponData.damage_at/range_at/interval_at. Продажа единицы убирает её
## уровень вместе с ней.
var _weapon_levels: Array[int] = []

signal weapon_upgraded(weapon: WeaponData, new_level: int)

## Потолок прокачки одной единицы оружия.
const MAX_WEAPON_LEVEL := 5

## Общий "стаггер" между бросками торпед — отдельный от attack_interval
## каждой отдельной торпеды. Без него, если экипировано несколько торпед,
## все они успевают отсчитать кулдаун одновременно и в один и тот же кадр
## закидывают одну и ту же цель разом; со стаггером второй бросок ждёт
## TORPEDO_THROW_STAGGER после первого, даже если её личный кулдаун уже истёк.
const TORPEDO_THROW_STAGGER := 0.35
var _torpedo_throw_cooldown: float = 0.0
var _is_dead: bool = false
var _base_modulate: Color

## Анимация по факту движения (idle/move, обе зациклены) — то, к чему спрайт
## возвращается сразу, как заканчивается одноразовая (attack/hurt, см. ниже).
var _locomotion_anim: StringName = &"idle"
## true, пока играет одноразовая анимация (attack/hurt) — _update_locomotion_animation
## в это время не перебивает её сменой idle/move, дожидается animation_finished.
var _one_shot_playing: bool = false


func _ready() -> void:
	add_to_group("player")
	_apply_balance_stats()
	Balance.player_stats_changed.connect(_apply_balance_stats)
	current_health = max_health
	current_oxygen = max_oxygen
	current_durability = max_durability
	_base_modulate = sprite.modulate

	collision_layer = LAYER_PLAYER
	# Не толкает и не толкается врагами; сундуки выведены на отдельный слой
	# LAYER_CHEST (8, см. world/chest.tscn) и тоже больше не блокируют игрока —
	# в маске остаётся только "мир" под будущую статичную геометрию уровня.
	collision_mask = LAYER_WORLD

	# Стартовое оружие: выбор из главного меню (Settings.starting_weapon_path)
	# переопределяет экспорт starting_weapon сцены — тот остаётся фолбэком на
	# случай отсутствующего/битого файла настроек.
	var chosen_starting := load(Settings.starting_weapon_path) as WeaponData
	var starting := chosen_starting if chosen_starting else starting_weapon
	if starting:
		add_weapon(starting)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_apply_bathyscaphe_variant(Settings.selected_bathyscaphe_variant)
	Settings.bathyscaphe_variant_changed.connect(_apply_bathyscaphe_variant)

	# Забег один и непрерывный: здоровье/кислород больше не пополняются между
	# "волнами" (их нет) — ресурсы приходится беречь всю дистанцию.
	xp_to_next = _level_xp_requirement(level)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	var input_dir := _get_movement_input()
	movement_input = input_dir

	# У спрайта батискафа нос смотрит вправо (хвост/пропеллер — влево), поэтому
	# при движении влево спрайт нужно отразить. Чисто вертикальный ввод
	# (input_dir.x == 0, только вверх/вниз) не трогает ориентацию — иначе она
	# бы сбрасывалась к дефолту при каждом вертикальном рывке.
	if input_dir.x > 0.0:
		sprite.flip_h = false
	elif input_dir.x < 0.0:
		sprite.flip_h = true

	_update_locomotion_animation(input_dir)

	## Кислород тратится только во время движения — стоя на месте и отбиваясь
	## от подступающих врагов (бой автоматический, не требует ввода), игрок
	## его не расходует; попытка уплыть от драки/погружение снова его тратит.
	if not Settings.god_mode: # Отладка → Режим Бога (меню паузы)
		if input_dir != Vector2.ZERO:
			current_oxygen = maxf(current_oxygen - oxygen_drain_rate * delta, 0.0)
			oxygen_changed.emit(current_oxygen, max_oxygen)
		if current_oxygen <= 0.0:
			die()
			return

	var target_velocity := input_dir * base_speed * DepthManager.get_speed_multiplier()

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	# Уровень воды (DepthManager.get_floor_y()) — физический потолок: всплыть
	# выше поверхности нельзя (прежняя "переезжающая" граница волны упразднена
	# вместе с волнами).
	var floor_y := DepthManager.get_floor_y()
	if global_position.y < floor_y:
		global_position.y = floor_y
		velocity.y = maxf(velocity.y, 0.0)

	DepthManager.update_depth(global_position.y)

	_process_weapons(delta)


## Схема управления выбирается в меню паузы (Settings.control_mode).
## В режиме BOTH клавиатура в приоритете — можно мгновенно перехватить
## управление у мыши, которая иначе тянет персонажа к курсору без кнопки.
func _get_movement_input() -> Vector2:
	if Settings.control_mode != Settings.ControlMode.MOUSE:
		var keyboard_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if keyboard_dir != Vector2.ZERO:
			return keyboard_dir

	if Settings.control_mode != Settings.ControlMode.KEYBOARD:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > mouse_move_deadzone:
			return to_mouse.normalized()

	return Vector2.ZERO


## Кулдаун стартует только после реального попадания/выстрела (см. return
## bool у _fire_weapon) — пока цели нет, оружие проверяет её каждый кадр и
## бьёт в тот же кадр, как только враг пересёк attack_range, а не ждёт
## следующего тика метронома (иначе за секунды простоя враг успевает зайти
## глубоко внутрь круга атаки прежде, чем удар вообще случится).
##
## claimed_targets собирает врагов, уже выбранных дальнобойным оружием в этом
## кадре — следующее оружие в списке предпочтёт другого ближайшего врага
## (см. _find_nearest_enemy), а не будет дублировать урон по тому же самому.
func _process_weapons(delta: float) -> void:
	if _torpedo_throw_cooldown > 0.0:
		_torpedo_throw_cooldown -= delta

	var claimed_targets: Array[Node2D] = []
	for i in unlocked_weapons.size():
		var weapon := unlocked_weapons[i]
		var level := _weapon_levels[i]
		if _weapon_cooldowns[i] > 0.0:
			_weapon_cooldowns[i] -= delta
			continue
		# Середина очереди: добираем выстрелы с темпом attack_interval,
		# независимо от основного кулдауна (он нулевой, пока очередь жива).
		if _burst_remaining[i] > 0:
			_burst_timers[i] -= delta
			if _burst_timers[i] > 0.0:
				continue
			if _fire_weapon(weapon, claimed_targets, level):
				_burst_remaining[i] -= 1
				_play_one_shot_animation(&"attack")
				if _burst_remaining[i] > 0:
					_burst_timers[i] = weapon.interval_at(level)
				else:
					# Очередь отстреляна — пауза до следующей.
					_weapon_cooldowns[i] = weapon.interval_at(level) + weapon.burst_cooldown
			else:
				# Цель исчезла посреди очереди — не тратить выстрелы в пустоту:
				# прерываем очередь, следующий кадр начнёт новую по готовности.
				_burst_remaining[i] = 0
			continue
		if _fire_weapon(weapon, claimed_targets, level):
			if weapon.burst_count > 1:
				# Первая пуля очереди уже вышла; остальные доберёт ветка выше.
				_burst_remaining[i] = weapon.burst_count - 1
				_burst_timers[i] = weapon.interval_at(level)
			else:
				_weapon_cooldowns[i] = weapon.interval_at(level) + weapon.burst_cooldown
			# Быстрое оружие (напр. нож, attack_interval 0.15с) успевает
			# перезапустить "attack" раньше, чем та доиграет до конца — тогда
			# она просто крутится на повторе всё время боя, пока не станет
			# можно показать idle/move; ожидаемо, не баг.
			_play_one_shot_animation(&"attack")


func _fire_weapon(weapon: WeaponData, claimed_targets: Array[Node2D], level: int) -> bool:
	if weapon.type == WeaponData.WeaponType.MELEE:
		return _fire_melee(weapon, level)
	return _fire_ranged(weapon, claimed_targets, level)


## Дистанция меряется до края коллизии цели, а не до её центра — иначе крупный
## враг (например увеличенная акула) получал бы удар только когда его центр
## уже глубоко внутри attack_range, хотя визуально коллизия давно пересекла
## границу круга атаки.
func _fire_melee(weapon: WeaponData, level: int) -> bool:
	var hit_something := false
	for body in get_tree().get_nodes_in_group("attackable"):
		if not body.has_method("take_damage"):
			continue
		var effective_range := weapon.range_at(level) + _get_collision_radius(body)
		if global_position.distance_squared_to(body.global_position) <= effective_range * effective_range:
			body.take_damage(weapon.damage_at(level))
			_spawn_melee_swing(weapon, body.global_position, level)
			hit_something = true
	if hit_something:
		SFX.play(weapon.fire_sound)
	return hit_something


## Отдельный эффект на каждую поражённую цель — при нескольких врагах в
## радиусе за один удар видно направление на каждого из них. Дочерний узел
## САМОГО игрока (не current_scene) — так эффект движется вместе с ним,
## пока доигрывает: раньше он спавнился в мировых координатах и оставался на
## месте, если игрок продолжал плыть во время анимации удара, визуально
## отставая и "бил" из точки, где игрок был в момент начала анимации, а не
## из его текущего центра. position = Vector2.ZERO — центр игрока в его же
## локальных координатах; Player.rotation всегда 0 (ориентация передаётся
## через sprite.flip_h, не поворот узла), поэтому локальный rotation
## эффекта не складывается с посторонним поворотом.
func _spawn_melee_swing(weapon: WeaponData, target_position: Vector2, level: int) -> void:
	if melee_swing_scene == null:
		return
	var swing: Node2D = melee_swing_scene.instantiate()
	# length/rotation/position — ДО add_child(): melee_swing.gd читает length
	# синхронно в своём _ready() (чтобы сразу выставить масштаб спрайта под
	# attack_range), а _ready() вызывается немедленно внутри самого
	# add_child() — выставленные после него значения эффект уже не увидит,
	# отрисуется с дефолтным length.
	swing.position = Vector2.ZERO
	swing.rotation = (target_position - global_position).angle()
	swing.length = weapon.range_at(level)
	add_child(swing)


## Радиус круглой коллизии цели (враг/сундук) в мировых единицах — 0, если
## коллизия не найдена или это не CircleShape2D (текущие сцены — все круглые).
func _get_collision_radius(body: Node) -> float:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return 0.0
	var shape := shape_node.shape
	if shape is CircleShape2D:
		return shape.radius * shape_node.global_scale.x
	return 0.0


func _fire_ranged(weapon: WeaponData, claimed_targets: Array[Node2D], level: int) -> bool:
	if weapon.projectile_scene == null:
		return false

	# Оружие с уроном по площади (торпеда) целится не в ближайшего врага, а в
	# самое плотное скопление — и не "клеймит" цель (бьёт по всем в радиусе,
	# claimed_targets тут не при чём).
	if weapon.splash_radius > 0.0:
		return _fire_torpedo(weapon, level)

	var target := _find_nearest_target(weapon.range_at(level), claimed_targets)
	if target == null:
		return false
	claimed_targets.append(target)

	var projectile: Node2D = weapon.projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.launch(target, target.global_position - global_position, weapon.damage_at(level))
	SFX.play(weapon.fire_sound)
	return true


func _fire_torpedo(weapon: WeaponData, level: int) -> bool:
	# Общий стаггер между бросками (см. TORPEDO_THROW_STAGGER) — не даёт
	# нескольким экипированным торпедам улететь в одну и ту же цель одним
	# кадром; личный кулдаун весом weapon.attack_interval при этом не
	# расходуется (_process_weapons просто повторит попытку следующим кадром).
	if _torpedo_throw_cooldown > 0.0:
		return false

	var target := _find_cluster_target(weapon.range_at(level))
	if target == null:
		return false

	var projectile: Node2D = weapon.projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	var direction := target.global_position - global_position
	projectile.launch(direction, weapon.damage_at(level), weapon.splash_radius, weapon.range_at(level))
	SFX.play(weapon.fire_sound)
	_torpedo_throw_cooldown = TORPEDO_THROW_STAGGER
	return true


## Не просто ближайший враг, а тот, вокруг которого больше всего соседей в
## радиусе CLUSTER_RADIUS — торпеда летит в сторону самого плотного скопления,
## а не первого попавшегося (направление задаётся один раз при броске, снаряд
## не наводится — см. projectile_torpedo.gd).
const CLUSTER_RADIUS := 140.0

func _find_cluster_target(max_range: float) -> Node2D:
	var range_sq := max_range * max_range
	var candidates: Array = get_tree().get_nodes_in_group("enemy").filter(
		func(enemy): return global_position.distance_squared_to(enemy.global_position) <= range_sq
	)
	if candidates.is_empty():
		return null

	var cluster_range_sq := CLUSTER_RADIUS * CLUSTER_RADIUS
	var best: Node2D = null
	var best_count := -1
	for enemy in candidates:
		var count := 0
		for other in candidates:
			if enemy.global_position.distance_squared_to(other.global_position) <= cluster_range_sq:
				count += 1
		if count > best_count:
			best_count = count
			best = enemy
	return best


## Сундук вплотную (в радиусе CHEST_ENGAGE_RADIUS) — цель наравне с врагами,
## побеждает просто ближайший. Иначе при активных врагах он всегда проигрывал
## бы им приоритет и ствол ни разу не переключился бы на сундук, даже стоя
## рядом с ним. Дальний сундук (вне радиуса) остаётся "запасной" целью — идёт
## в ход, только когда врагов в радиусе оружия вообще нет (иначе он недосягаем
## для игрока без единицы ближнего боя — у сундука своей атаки нет).
const CHEST_ENGAGE_RADIUS := 150.0

func _find_nearest_target(max_range: float, claimed: Array[Node2D] = []) -> Node2D:
	var nearby_chest_range := minf(max_range, CHEST_ENGAGE_RADIUS)
	var candidates := get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("chest").filter(
		func(chest): return global_position.distance_squared_to(chest.global_position) <= nearby_chest_range * nearby_chest_range
	)
	var priority_target := _find_nearest_among(candidates, max_range, claimed)
	if priority_target != null:
		return priority_target
	return _find_nearest_in_group("chest", max_range, claimed)


func _find_nearest_in_group(group: String, max_range: float, claimed: Array[Node2D]) -> Node2D:
	return _find_nearest_among(get_tree().get_nodes_in_group(group), max_range, claimed)


func _find_nearest_among(bodies: Array, max_range: float, claimed: Array[Node2D]) -> Node2D:
	var range_sq := max_range * max_range
	var nearest_free: Node2D = null
	var nearest_free_dist := range_sq
	var nearest_any: Node2D = null
	var nearest_any_dist := range_sq
	for body in bodies:
		if not body.has_method("take_damage"):
			continue
		var dist := global_position.distance_squared_to(body.global_position)
		if dist < nearest_any_dist:
			nearest_any_dist = dist
			nearest_any = body
		if dist < nearest_free_dist and not claimed.has(body):
			nearest_free_dist = dist
			nearest_free = body
	return nearest_free if nearest_free != null else nearest_any


func add_experience(amount: int) -> void:
	current_xp += amount
	_level_xp_progress += amount
	experience_changed.emit(current_xp)
	_check_level_up()


## Сколько суммарного опыта нужно собрать на данном уровне: прогрессивная
## шкала, каждый следующий уровень в level_xp_growth раз дороже
## (100 → 150 → 225 → ...).
func _level_xp_requirement(for_level: int) -> int:
	return roundi(level_xp_base * pow(level_xp_growth, for_level - 1))


## Прогресс уровня копится с ЛЮБОГО полученного опыта и не зависит от трат XP
## в магазине. За один подбор может накопиться несколько уровней — цикл
## обрабатывает все и шлёт level_up на каждый (level.gd переоткроет магазин
## нужное число раз).
func _check_level_up() -> void:
	while _level_xp_progress >= xp_to_next:
		_level_xp_progress -= xp_to_next
		level += 1
		xp_to_next = _level_xp_requirement(level)
		level_up.emit(level)


## XP тратится в магазине (ui/weapon_shop.gd, открывается по левел-апу) — сам
## магазин проверяет платёжеспособность перед вызовом, здесь без проверок.
## На прогресс уровня трата НЕ влияет (см. _level_xp_progress).
func spend_xp(amount: int) -> void:
	current_xp -= amount
	experience_changed.emit(current_xp)


## Добавляет ещё одну единицу оружия — стартовую, купленную в магазине
## (level = уровень выпавшей карточки) или улучшенную. Повторная покупка того
## же WeaponData даёт независимую копию (свой кулдаун и свой уровень).
func add_weapon(weapon: WeaponData, level: int = 1) -> void:
	unlocked_weapons.append(weapon)
	_weapon_cooldowns.append(0.0)
	_burst_remaining.append(0)
	_burst_timers.append(0.0)
	_weapon_levels.append(level)
	weapon_unlocked.emit(weapon)
	print("Открыто оружие: %s (ур. %d)" % [weapon.weapon_name, level])


## Уровень единицы арсенала по индексу (1 = куплена/стартовая, ещё не улучшена).
func get_weapon_level_at(index: int) -> int:
	if index < 0 or index >= _weapon_levels.size():
		return 1
	return _weapon_levels[index]


## Индекс первой копии данного типа оружия указанного уровня (-1, если такой
## нет) — магазин сливает карточку уровня N только с единицей уровня N
## (см. ui/weapon_shop.gd::_on_card_pressed).
func first_index_of_weapon_with_level(weapon: WeaponData, level: int) -> int:
	for i in unlocked_weapons.size():
		if unlocked_weapons[i] == weapon and _weapon_levels[i] == level:
			return i
	return -1


## Прокачка ОДНОЙ единицы арсенала (карточка магазина того же уровня,
## "слившаяся" с ней, исчезает из предложения — это делает магазин). XP
## тратит вызывающая сторона, здесь только рост уровня и сигнал для
## HUD/индикатора.
func upgrade_weapon_at(index: int) -> void:
	var new_level := get_weapon_level_at(index) + 1
	_weapon_levels[index] = new_level
	weapon_upgraded.emit(unlocked_weapons[index], new_level)
	print("Оружие улучшено: %s → ур. %d" % [unlocked_weapons[index].weapon_name, new_level])


## Продажа оружия в магазине (ui/weapon_shop.gd) — возврат XP считает и
## начисляет вызывающая сторона, здесь только удаление копии из инвентаря.
func remove_weapon(index: int) -> void:
	if index < 0 or index >= unlocked_weapons.size():
		return
	var weapon := unlocked_weapons[index]
	unlocked_weapons.remove_at(index)
	_weapon_cooldowns.remove_at(index)
	_burst_remaining.remove_at(index)
	_burst_timers.remove_at(index)
	_weapon_levels.remove_at(index)
	weapon_sold.emit(weapon)
	print("Продано оружие: %s" % weapon.weapon_name)


func heal(amount: float) -> void:
	if _is_dead:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_flash(Color(0.5, 1.0, 0.6, 1))


func add_oxygen(amount: float) -> void:
	if _is_dead:
		return
	current_oxygen = minf(current_oxygen + amount, max_oxygen)
	oxygen_changed.emit(current_oxygen, max_oxygen)
	_flash(Color(0.6, 0.9, 1.0, 1))


## Пассивное пополнение кислорода небольшими порциями каждый кадр (водоросли,
## см. world/seaweed.gd) — в отличие от add_oxygen (разовый пузырёк) без
## цветовой вспышки: та создаёт новый tween при каждом вызове и на каждом
## кадре подряд просто мельтешила бы поверх самой себя.
func regenerate_oxygen(amount: float) -> void:
	if _is_dead:
		return
	current_oxygen = minf(current_oxygen + amount, max_oxygen)
	oxygen_changed.emit(current_oxygen, max_oxygen)


## Пассивное восстановление прочности корпуса небольшими порциями каждый
## кадр (затонувшие исследовательские модули, см. world/research_module.gd).
## Давление прочность пока не разрушает (дренаж убран), так что на текущий
## момент прочность всегда полная и множитель урона = 1 — метод оставлен на
## будущее возвращение механики.
func regenerate_durability(amount: float) -> void:
	if _is_dead:
		return
	current_durability = minf(current_durability + amount, max_durability)
	durability_changed.emit(current_durability, max_durability)


## Загружает SpriteFrames выбранного визуального варианта батискафа (Отладка
## → Батискаф, см. Settings.BATHYSCAPHE_VARIANTS) — вызывается и при старте
## (Settings.selected_bathyscaphe_variant), и "на лету" при каждой смене через
## bathyscaphe_variant_changed, поэтому сразу возобновляет проигрывание
## текущей локомоции/одноразовой анимации на новом наборе кадров — иначе
## после смены sprite_frames спрайт застыл бы на последнем кадре старого.
func _apply_bathyscaphe_variant(variant_id: String) -> void:
	var frames_path := Settings.get_bathyscaphe_frames_path(variant_id)
	var frames := load(frames_path) as SpriteFrames
	if frames == null:
		return
	sprite.sprite_frames = frames
	# Если смена варианта застала игрока посреди одноразовой анимации
	# (attack/hurt) — та всё равно обрывается новым набором кадров, так что
	# сбрасываем флаг и явно возвращаемся к локомоции, а не оставляем
	# _one_shot_playing залипшим без шанса когда-либо сброситься.
	_one_shot_playing = false
	sprite.play(_locomotion_anim)


## Переключает зацикленную idle/move-анимацию по факту движения — но не
## перебивает ею одноразовую (attack/hurt), пока та играет (см. _one_shot_playing,
## _on_sprite_animation_finished вернёт локомоцию сам, как только доиграет).
func _update_locomotion_animation(input_dir: Vector2) -> void:
	var target_anim: StringName = &"move" if input_dir != Vector2.ZERO else &"idle"
	if target_anim == _locomotion_anim:
		return
	_locomotion_anim = target_anim
	if not _one_shot_playing:
		sprite.play(_locomotion_anim)


## Запускает одноразовую анимацию (attack/hurt) поверх текущей локомоции —
## если у sprite_frames нет такой анимации (например, выбран арт-вариант без
## attack/hurt), тихо ничего не делает вместо ошибки.
func _play_one_shot_animation(anim_name: StringName) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		return
	_one_shot_playing = true
	sprite.play(anim_name)


## Одноразовая анимация доиграла — возвращаемся к текущей idle/move. Зацикленные
## анимации тоже шлют animation_finished на каждый проход цикла, поэтому
## обязательно проверяем _one_shot_playing, иначе каждый цикл idle/move
## перезапускал бы сам себя без дела.
func _on_sprite_animation_finished() -> void:
	if not _one_shot_playing:
		return
	_one_shot_playing = false
	sprite.play(_locomotion_anim)


func _flash(color: Color, duration: float = 0.25) -> void:
	sprite.modulate = color
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_modulate, duration)


## Чем ниже прочность корпуса, тем больнее бьют враги — при 0 урон умножается
## на max_durability_damage_multiplier, при полной прочности множитель = 1.
## Давление прочность пока не точит (дренаж убран вместе с волнами) —
## множитель остаётся единицей, пока прочность не появится как механика.
func _durability_damage_multiplier() -> float:
	var durability_fraction := current_durability / max_durability
	return lerpf(1.0, max_durability_damage_multiplier, 1.0 - durability_fraction)


## Здоровье и тяга движителя из Balance (Отладка → Баланс → Игрок) —
## применяются и при старте забега, и "на лету" по player_stats_changed,
## если ползунки двигают прямо посреди волны через меню паузы.
func _apply_balance_stats() -> void:
	base_speed = Balance.get_value("player:speed")
	max_health = Balance.get_value("player:health")
	current_health = minf(current_health, max_health)
	attack_ring_radius = Balance.get_value("player:attack_ring")
	attack_retreat_distance = Balance.get_value("player:retreat_distance")
	attack_wait_min = Balance.get_value("player:attack_wait_min")
	attack_wait_max = Balance.get_value("player:attack_wait_max")
	health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if _is_dead or Settings.god_mode: # Отладка → Режим Бога (меню паузы)
		return
	current_health = maxf(current_health - amount * _durability_damage_multiplier(), 0.0)
	health_changed.emit(current_health, max_health)
	SFX.play(SFX.HIT)
	if current_health <= 0.0:
		die()
	else:
		_play_one_shot_animation(&"hurt")


func die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	hide()
	died.emit()
