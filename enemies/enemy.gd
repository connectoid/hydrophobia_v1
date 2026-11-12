extends CharacterBody2D
## Враг-заглушка: идёт к игроку, наносит урон при сближении (дистанция, а не
## физическое столкновение — см. _check_contact_damage), показывает шкалу
## здоровья и вспышку цвета при получении урона.
##
## aggressive = false (см. enemy_fish.tscn/oxygen_fish.tscn) отключает погоню
## и контактный урон — такой враг просто плавает волнообразно (см. wander_*
## экспорты и _process_wander), время от времени меняя курс, и не реагирует
## на игрока.
## Убить его всё ещё можно (take_damage/die не зависят от aggressive) —
## например, ради оксигенового пузыря из oxygen_reward.
##
## Физическая коллизия между врагами и с игроком отключена через слои
## (см. _ready: собственный collision_layer = LAYER_ENEMY, collision_mask
## реагирует только на "мир" — не на LAYER_PLAYER и не на LAYER_ENEMY) — враги
## не толкаются друг с другом и не толкают/не блокируют игрока, а просто
## визуально перекрываются. Снаряды (Area2D, projectile.gd) по-прежнему
## находят врага через body_entered — их маска отдельно включает LAYER_ENEMY.
## Кто из перекрывающихся спрайтов рисуется поверх — решает случайный
## z_index, выбранный один раз при спавне (см. _ready).
##
## Узел Sprite2D (по имени — см. _animated_sprite) может быть и обычным
## Sprite2D (статика, напр. oxygen_fish.tscn), и AnimatedSprite2D
## (piranha/shark/angler — swim/attack/hurt/death). Для анимированных враг
## сам переключает attack при попадании по игроку, hurt при получении
## урона и death перед queue_free(); для статичных всё это просто no-op.

signal died

## Физические слои проекта (см. комментарий выше и player.gd/projectile.gd) —
## бит "мира" (1, объекты вроде сундука) общий, игрок и враги на отдельных
## битах, чтобы их collision_mask мог избирательно исключать друг друга.
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

## Множитель скорости проигрывания "death"-анимации (см. die()) — на
## обычной скорости (как записана в *_frames.tres) она ощущалась слишком
## медленной, особенно когда гибнет сразу несколько врагов подряд (стая
## пираний и т.п.). 1.0 = как записано в ресурсе, больше — быстрее.
const DEATH_ANIM_SPEED_SCALE := 3.0

@export var max_health: float = 50.0
@export var speed: float = 220.0
@export var contact_damage: float = 7.0
@export var attack_interval: float = 1.0
@export var xp_reward: int = 5
@export var xp_orb_scene: PackedScene

## false — не преследует игрока и не наносит контактный урон, просто плывёт
## волнообразно в случайном направлении, время от времени меняя курс, вплоть
## до разворота на 180° (см. doc-комментарий класса выше и _process_wander).
@export var aggressive: bool = true

## Параметры "блуждающего" плавания (только aggressive = false, см. _process_wander).
## Курс держится не абсолютно прямо: постоянно виляет синусоидой (wave_*), и
## раз в несколько секунд (turn_interval_*) выбирает новую цель курса — либо
## мягкий поворот, либо (с вероятностью reverse_chance) разворот почти на 180°.
## Поворот к цели курса плавный (turn_speed, рад/сек), а не мгновенный, чтобы
## не выглядело как телепорт направления.
@export_group("Wander (aggressive = false)")
@export var wander_turn_interval_min: float = 2.0
@export var wander_turn_interval_max: float = 5.0
@export var wander_reverse_chance: float = 0.3
@export var wander_turn_angle_max: float = PI * 0.5
@export var wander_turn_speed: float = 2.0
@export var wander_wave_amplitude: float = 0.35
@export var wander_wave_frequency: float = 1.5

## Рывок (пиранья, см. piranha.tscn; изначально был у кальмара — enemies/scenes/squid.tscn,
## сейчас выведен из активного пула, см. node_2d.tscn) — вместо равномерного
## контактного урона враг обычно плывёт к игроку на обычной speed и НЕ
## наносит урон касанием; как только дистанция до игрока падает ниже
## lunge_range — резко бросается на него по прямой на скорости lunge_speed
## в течение lunge_duration секунд, и только в этом окне касание наносит
## разовый lunge_damage. После рывка — lunge_cooldown секунд обычного
## медленного сближения, прежде чем рывок снова возможен.
@export var lunge_enabled: bool = false
@export var lunge_range: float = 150.0
@export var lunge_speed: float = 900.0
@export var lunge_damage: float = 30.0
@export var lunge_duration: float = 0.35
@export var lunge_cooldown: float = 2.5

enum LungeState { IDLE, LUNGING, COOLDOWN }
var _lunge_state: LungeState = LungeState.IDLE
var _lunge_timer: float = 0.0
var _lunge_direction: Vector2 = Vector2.ZERO
var _lunge_has_hit: bool = false

## Стайная органика (aggressive-враги): без неё все особи одного типа движутся
## абсолютно синхронно (одинаковые speed/курс — стая выглядит как один
## цельный объект). Каждой особи в _ready() достаются слегка свои параметры:
## - множитель скорости ±school_speed_variation;
## - плавное синусоидальное рыскание курса (амплитуда school_wobble_amplitude
##   в радианах, медленное — периоды ~8-20 c, чтобы не дёргано);
## - "рывки": полусинусоидальные ускорения (~каждые 3-7 c) до
##   school_surge_amplitude сверху к скорости — наращивание плавное.
## Случайные фазы/частоты у каждой особи свои, поэтому соседи по стае
## рыскают и ускоряются не в такт, но в среднем все держат курс на цель —
## стая остаётся стаей. Разброс позиций внутри стаи задаётся при спавне
## (enemy_spawner.gd, pack_radius).
##
## Особи-одиночки ("выбившиеся из стаи") пробовались дважды и убраны:
## преследование орбитальной точки давало либо синхронное залипание у игрока
## с вращением, либо постоянные дёргания курса — плавно кружить рядом с
## движущейся целью и оставаться убиваемой одиночка не умела.
@export var school_speed_variation: float = 0.2
@export var school_wobble_amplitude: float = 0.3
@export var school_surge_amplitude: float = 0.35

## Пульсирующее плавание толчками (была у медузы, enemies/scenes/jellyfish.tscn —
## сейчас выведена из активного пула, см. node_2d.tscn; механика осталась в
## enemy.gd про запас для будущих врагов) — вместо равномерной скорости
## чередует короткий резкий толчок (pulse_duration на speed *
## pulse_speed_multiplier) с более долгой фазой вялого дрейфа (pulse_interval
## на speed * pulse_coast_multiplier), как настоящая медуза, сокращающая
## колокол. Направление при этом всё так же каждый кадр считается заново
## (см. _physics_process) — толчками меняется только скорость, а не манера
## погони.
@export var pulse_movement: bool = false
@export var pulse_speed_multiplier: float = 2.2
@export var pulse_coast_multiplier: float = 0.2
@export var pulse_duration: float = 0.25
@export var pulse_interval: float = 0.9

var _pulse_active: bool = false
var _pulse_timer: float = 0.0

## Базовое смещение шлейфа пузырьков по X из сцены (BubbleTrail — дочерний узел
## спрайта, позади хвоста). Читается один раз в _ready() и знакоинвертируется
## при зеркальном отражении спрайта (см. _face_direction): flip_h не влияет на
## дочерние узлы, без компенсации шлейф бил бы из носа отражённой рыбы.
var _trail_base_x: float = 0.0

## Пер-инстанс параметры стайной органики (см. экспорты school_* выше),
## заполняются один раз в _ready() случайными значениями вокруг базовых.
var _school_time: float = 0.0
var _speed_variation: float = 1.0
var _wobble_phase: float = 0.0
var _wobble_freq: float = 0.08 # Гц, период ~12 c
var _wobble_amp: float = 0.0
var _surge_phase: float = 0.0
var _surge_freq: float = 0.2 # Гц, "рывок" примерно каждые 5 c
var _surge_amp: float = 0.0

## Повернуть спрайт носом к цели (актуально для узкотелых врагов вроде акулы —
## медузе/рыбе без выраженного "перёда" не нужно). sprite_default_facing —
## угол в радианах, в который смотрит нос спрайта при rotation = 0
## (0 = вправо/+X, PI = влево/-X — зависит от того, куда смотрит исходный арт).
## Курс за ±90° от этого направления не доворачивает спрайт через переворот
## брюхом вверх, а зеркалит его по горизонтали (см. _face_direction).
@export var face_target: bool = false
@export var sprite_default_facing: float = 0.0

## Кислородный пузырь роняют только "особые" враги (см. enemy_fish.tscn) —
## по умолчанию 0/null, обычные враги его не роняют.
@export var oxygen_reward: float = 0.0
@export var oxygen_bubble_scene: PackedScene

## Взрыв при смерти (иглобомба, см. puffermine.tscn) — по умолчанию
## выключено (damage/radius = 0), на остальных врагов никак не влияет. Если
## задано — в момент смерти, независимо от того, кто/что нанесло финальный
## удар, разово наносит death_explosion_damage игроку, если он в радиусе
## death_explosion_radius от точки гибели. Чисто логический урон — визуал
## (расширяющийся круг) берётся из той же сцены, что и взрыв гранаты игрока
## (player/explosion_effect.tscn), см. _spawn_death_explosion_visual.
@export var death_explosion_damage: float = 0.0
@export var death_explosion_radius: float = 0.0

## Node2D, а не конкретно Sprite2D — сцена может нести здесь как обычный
## Sprite2D (статичные враги, напр. oxygen_fish.tscn), так и AnimatedSprite2D
## (piranha/shark/angler — см. _animated_sprite ниже); оба узла в любом
## случае называются "Sprite2D" в сцене (имя узла, не тип), поэтому $-путь
## общий для обоих вариантов. Всё, что сейчас реально читается через sprite
## (.modulate, .rotation), объявлено на CanvasItem/Node2D и доступно в любом
## случае — animated-специфичные вызовы (play/sprite_frames) идут отдельно
## через _animated_sprite.
@onready var sprite: Node2D = $Sprite2D
@onready var health_bar: Node2D = $HealthBar

## Безопасный `as`-каст — null для статичных врагов (sprite тогда Sprite2D),
## заполнен для анимированных. Вся логика attack/hurt/death-анимаций ниже
## проверяет его на null и просто ничего не делает для статичных врагов —
## им не нужно ничего дополнительно настраивать, они продолжают работать
## как раньше.
var _animated_sprite: AnimatedSprite2D
var _one_shot_playing: bool = false
var _is_dying: bool = false

var current_health: float
var _attack_cooldown: float = 0.0
var _target: Node2D
var _base_modulate: Color
var _wander_direction: Vector2 = Vector2.RIGHT # только для aggressive = false
var _wander_base_angle: float = 0.0 # текущий "крейсерский" курс, до вихляния синусоидой
var _wander_target_angle: float = 0.0 # курс, к которому сейчас плавно поворачиваем
var _wander_wave_phase: float = 0.0
var _wander_turn_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("attackable")
	current_health = max_health
	_target = get_tree().get_first_node_in_group("player")
	_base_modulate = sprite.modulate
	health_bar.set_fraction(1.0)

	_animated_sprite = sprite as AnimatedSprite2D
	if _animated_sprite:
		_animated_sprite.animation_finished.connect(_on_sprite_animation_finished)

	collision_layer = LAYER_ENEMY
	# Не толкает и не толкается игроком/другими врагами; сундуки выведены на
	# отдельный слой LAYER_CHEST (8, см. world/chest.tscn) и тоже больше не
	# блокируют врагов — в маске остаётся только "мир" под будущую статику.
	collision_mask = LAYER_WORLD

	# Случайный порядок отрисовки поверх/под игроком (и другими врагами) —
	# раз навсегда при спавне, а не каждый кадр, иначе спрайты будут дёргаться.
	z_index = 1 if randf() < 0.5 else -1

	if not aggressive:
		_wander_base_angle = randf() * TAU
		_wander_target_angle = _wander_base_angle
		_wander_wave_phase = randf() * TAU
		_wander_turn_timer = randf_range(wander_turn_interval_min, wander_turn_interval_max)

	if pulse_movement:
		# Случайная фаза старта — иначе все медузы одной волны толкались бы синхронно.
		_pulse_timer = randf_range(0.0, pulse_interval)

	if aggressive:
		# Стайная органика: каждой особи свои отклонения параметров и случайные
		# фазы, чтобы соседи по стае рыскали и ускорялись не в такт.
		_speed_variation = 1.0 + randf_range(-school_speed_variation, school_speed_variation)
		_wobble_phase = randf() * TAU
		_wobble_freq = randf_range(0.05, 0.12)
		_wobble_amp = school_wobble_amplitude * randf_range(0.6, 1.0)
		_surge_phase = randf() * TAU
		_surge_freq = randf_range(0.15, 0.35)
		_surge_amp = school_surge_amplitude * randf_range(0.6, 1.0)

	var trail := sprite.get_node_or_null("BubbleTrail") as Node2D
	if trail:
		_trail_base_x = trail.position.x


func _physics_process(delta: float) -> void:
	if Settings.enemies_frozen: # Отладка → Остановить всех врагов (меню паузы)
		velocity = Vector2.ZERO
		return

	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	if not aggressive:
		_process_wander(delta)
		velocity = _wander_direction * speed
		if face_target:
			_face_direction(_wander_direction)
	else:
		if _target == null or not is_instance_valid(_target):
			_target = get_tree().get_first_node_in_group("player")
			velocity = Vector2.ZERO
			return

		_school_time += delta
		var to_target := _target.global_position - global_position
		if lunge_enabled:
			_process_lunge(delta, to_target)
		elif pulse_movement:
			velocity = to_target.normalized() * speed * _process_pulse(delta)
		else:
			velocity = _school_velocity(to_target)
		if face_target and velocity != Vector2.ZERO:
			_face_direction(velocity)

	move_and_slide()

	# Враги преследуют игрока, который сам не может подняться выше дна уже
	# пройденной зоны (DepthManager.get_wave_floor_y()) — но при погоне у самой
	# границы враг может на кадр "перелететь" цель по Y; прижимаем обратно,
	# чтобы враг тоже не оказался в недоступной игроку зоне. Действует и на
	# невраждебных — тоже не должны заплывать в недоступную игроку зону.
	var wave_floor_y := DepthManager.get_wave_floor_y()
	if global_position.y < wave_floor_y:
		global_position.y = wave_floor_y
		# Блуждающий враг (см. wander_*) иначе застревал бы, скользя вдоль
		# границы — курс у него меняется только по таймеру/синусоидой, сам
		# факт упора в потолок волны его не разворачивает. В волне 1 эта
		# граница — буквально поверхность воды (DepthManager.SURFACE_Y), в
		# волне 2+ — дно предыдущей зоны; логика та же в обоих случаях.
		if not aggressive:
			_turn_away_from_surface()

	if aggressive:
		_check_contact_damage()


## Состояния рывка (см. doc-комментарий у lunge_enabled): IDLE — обычное
## медленное сближение, как только дистанция до цели упадёт ниже lunge_range —
## переход в LUNGING (бросок по прямой на lunge_speed на lunge_duration
## секунд); после — COOLDOWN (снова медленное сближение lunge_cooldown секунд,
## прежде чем рывок опять разрешён).
func _process_lunge(delta: float, to_target: Vector2) -> void:
	match _lunge_state:
		LungeState.LUNGING:
			_lunge_timer -= delta
			velocity = _lunge_direction * lunge_speed
			if _lunge_timer <= 0.0:
				_lunge_state = LungeState.COOLDOWN
				_lunge_timer = lunge_cooldown
		LungeState.COOLDOWN:
			_lunge_timer -= delta
			velocity = _school_velocity(to_target)
			if _lunge_timer <= 0.0:
				_lunge_state = LungeState.IDLE
		LungeState.IDLE:
			velocity = _school_velocity(to_target)
			if to_target.length() <= lunge_range:
				_lunge_state = LungeState.LUNGING
				_lunge_timer = lunge_duration
				_lunge_direction = to_target.normalized()
				_lunge_has_hit = false


## Стайная органика движения (см. экспорты school_*): курс на цель с плавным
## синусоидальным рысканием, скорость — базовая × пер-инстанс множитель ×
## плавный полусинусоидальный "рывок". Фазы/частоты/амплитуды у каждой особи
## свои (_ready), поэтому соседи двигаются не в такт.
## Не применяется во время самого lunge-броска (там фиксированная lunge_speed)
## и к pulse_movement (у него собственная рваная динамика).
func _school_velocity(to_target: Vector2) -> Vector2:
	var direction := to_target.normalized()
	direction = direction.rotated(sin(_school_time * _wobble_freq * TAU + _wobble_phase) * _wobble_amp)
	var surge := 1.0 + maxf(0.0, sin(_school_time * _surge_freq * TAU + _surge_phase)) * _surge_amp
	return direction * speed * _speed_variation * surge


## Множитель скорости для pulse_movement (см. doc-комментарий у экспортов) —
## переключает толчок/дрейф по таймеру и возвращает текущий множитель к speed.
## Направление движения при этом не трогает — вызывающая сторона считает его
## отдельно (to_target для погони), pulse только делает саму скорость рваной.
func _process_pulse(delta: float) -> float:
	_pulse_timer -= delta
	if _pulse_active:
		if _pulse_timer <= 0.0:
			_pulse_active = false
			_pulse_timer = pulse_interval
		return pulse_speed_multiplier
	else:
		if _pulse_timer <= 0.0:
			_pulse_active = true
			_pulse_timer = pulse_duration
		return pulse_coast_multiplier


## Небоевое "блуждающее" плавание (aggressive = false, см. doc-комментарий у
## wander_* экспортов): раз в randf_range(turn_interval_min, turn_interval_max)
## секунд выбирает новую цель курса (обычно мягкий поворот в пределах
## turn_angle_max, но с вероятностью reverse_chance — почти разворот на 180°,
## ±0.3 рад для разнообразия), плавно поворачивает к ней со скоростью
## turn_speed рад/сек, и поверх этого крейсерского курса добавляет
## синусоидальное виляние (wave_amplitude/wave_frequency) — вместе это даёт
## волнообразную, а не строго прямую траекторию.
func _process_wander(delta: float) -> void:
	_wander_turn_timer -= delta
	if _wander_turn_timer <= 0.0:
		_wander_turn_timer = randf_range(wander_turn_interval_min, wander_turn_interval_max)
		if randf() < wander_reverse_chance:
			_wander_target_angle = _wander_base_angle + PI + randf_range(-0.3, 0.3)
		else:
			_wander_target_angle = _wander_base_angle + randf_range(-wander_turn_angle_max, wander_turn_angle_max)

	_wander_base_angle = rotate_toward(_wander_base_angle, _wander_target_angle, wander_turn_speed * delta)
	_wander_wave_phase += delta * wander_wave_frequency
	var heading := _wander_base_angle + sin(_wander_wave_phase) * wander_wave_amplitude
	_wander_direction = Vector2.RIGHT.rotated(heading)


## Мгновенный (не через плавный rotate_toward, как обычная смена курса в
## _process_wander) разворот вниз — вызывается, когда блуждающий враг упёрся
## в потолок текущей волны (см. вызов в _physics_process). PI * 0.5 — курс
## вниз (+Y в системе координат Godot), с небольшим случайным разбросом по
## горизонтали, чтобы несколько врагов не расходились от границы по одной
## и той же прямой. Заодно сбрасывает таймер смены курса, чтобы _process_wander
## не перебила разворот следующим же тиком.
func _turn_away_from_surface() -> void:
	_wander_target_angle = PI * 0.5 + randf_range(-0.3, 0.3)
	_wander_base_angle = _wander_target_angle
	_wander_turn_timer = randf_range(wander_turn_interval_min, wander_turn_interval_max)


## Ориентирует спрайт носом по направлению движения, не давая ему перевернуться
## брюхом вверх: пока курс в пределах ±90° от sprite_default_facing — обычный
## поворот; как только курс уходит за эту границу (рыба плыла бы к цели
## хвостом вперёд), спрайт зеркалится по горизонтали и доворачивается на
## отражённый угол, оставаясь в тех же ±90° — нос по курсу, брюхо внизу.
## Момент зеркализации — курс строго вверх/вниз, силуэт в этот момент
## вертикален, поэтому отражение читается как естественный разворот.
func _face_direction(direction: Vector2) -> void:
	var relative := wrapf(direction.angle() - sprite_default_facing, -PI, PI)
	var flipped := absf(relative) > PI * 0.5
	sprite.flip_h = flipped
	if flipped:
		sprite.rotation = wrapf(relative - signf(relative) * PI, -PI, PI)
	else:
		sprite.rotation = relative
	# flip_h отражает только сам спрайт, не дочерние узлы: без компенсации
	# шлейф пузырьков остался бы с прежней стороны и бил бы из носа отражённой
	# рыбы вместо хвоста.
	var trail := sprite.get_node_or_null("BubbleTrail") as Node2D
	if trail:
		var trail_x := -_trail_base_x if flipped else _trail_base_x
		if not is_equal_approx(trail.position.x, trail_x):
			trail.position.x = trail_x


## Урон по дистанции, а не по физическому столкновению — с отключённой
## коллизией enemy/player (см. _ready) move_and_slide больше не репортит
## столкновения между ними, поэтому старый способ через get_slide_collision
## перестал бы срабатывать вообще.
func _check_contact_damage() -> void:
	if not _target.has_method("take_damage"):
		return

	if lunge_enabled:
		# Вне самого рывка (IDLE/COOLDOWN) враг медленно подплывает, но
		# урона касанием не наносит — только один раз за сам бросок.
		if _lunge_state != LungeState.LUNGING or _lunge_has_hit:
			return
		var lunge_contact_range := _get_collision_radius(self) + _get_collision_radius(_target)
		if global_position.distance_to(_target.global_position) <= lunge_contact_range:
			_target.take_damage(lunge_damage)
			_lunge_has_hit = true
			_play_one_shot_animation(&"attack")
		return

	if _attack_cooldown > 0.0:
		return
	var contact_range := _get_collision_radius(self) + _get_collision_radius(_target)
	if global_position.distance_to(_target.global_position) <= contact_range:
		_target.take_damage(contact_damage)
		_attack_cooldown = attack_interval
		_play_one_shot_animation(&"attack")


## Радиус круглой коллизии узла в мировых единицах — 0, если коллизия не
## найдена или это не CircleShape2D (дублирует player.gd::_get_collision_radius;
## тот же паттерн, но раздельно — enemy.gd и player.gd не имеют общей базы).
func _get_collision_radius(body: Node) -> float:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return 0.0
	var shape := shape_node.shape
	if shape is CircleShape2D:
		return shape.radius * shape_node.global_scale.x
	return 0.0


func take_damage(amount: float) -> void:
	if _is_dying:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_bar.set_fraction(current_health / max_health)
	_flash_hit()
	SFX.play(SFX.HIT)
	if current_health <= 0.0:
		die()
	else:
		_play_one_shot_animation(&"hurt")


func _flash_hit() -> void:
	sprite.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_modulate, 0.15)


## Запускает одноразовую анимацию (attack/hurt) поверх текущего плавания —
## для статичных врагов (_animated_sprite == null) просто ничего не делает.
## Если у sprite_frames нет такой анимации (неполный набор у какого-то
## будущего варианта) — тоже тихо выходит, а не падает.
func _play_one_shot_animation(anim_name: StringName) -> void:
	if _animated_sprite == null or _is_dying:
		return
	if not _animated_sprite.sprite_frames.has_animation(anim_name):
		return
	_one_shot_playing = true
	_animated_sprite.play(anim_name)


## Одноразовая анимация (attack/hurt) доиграла — возвращаемся к "swim".
## Умирающего врага (_is_dying) вместо этого удаляем прямо здесь: это тот же
## сигнал animation_finished, которым заканчивается death-анимация.
func _on_sprite_animation_finished() -> void:
	if _is_dying:
		queue_free()
		return
	if not _one_shot_playing:
		return
	_one_shot_playing = false
	_animated_sprite.play(&"swim")


## _is_dying — на случай, если по врагу продолжают попадать уже после
## смерти (пока доигрывает death-анимация, он ещё не queue_free()'ен и
## формально доступен для take_damage): не даёт повторно запустить die().
func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	print("Враг уничтожен")
	if xp_orb_scene:
		var orb: Node2D = xp_orb_scene.instantiate()
		orb.xp_amount = xp_reward
		orb.global_position = global_position
		# die() может быть вызван из колбэка Area2D.body_entered снаряда —
		# в этот момент физический сервер обрабатывает запросы, и синхронное
		# add_child нового Area2D падает с "flushing queries". call_deferred
		# откладывает добавление до конца кадра, когда это уже безопасно.
		get_tree().current_scene.call_deferred("add_child", orb)
	if oxygen_bubble_scene and oxygen_reward > 0.0:
		var bubble: Node2D = oxygen_bubble_scene.instantiate()
		bubble.oxygen_amount = oxygen_reward
		bubble.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", bubble)
	died.emit()
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)

	if death_explosion_damage > 0.0 and death_explosion_radius > 0.0:
		_trigger_death_explosion()

	# Анимированный враг с кадрами смерти доигрывает её (см.
	# _on_sprite_animation_finished) прежде чем реально исчезнуть — иначе
	# (статичный спрайт или вариант без набора "death") пропадает сразу,
	# как и раньше. DEATH_ANIM_SPEED_SCALE ускоряет именно этот плейбек —
	# при большом количестве одновременных смертей (стая пираний и т.п.)
	# обычная скорость ощущалась как "слишком долго исчезают".
	if _animated_sprite and _animated_sprite.sprite_frames.has_animation(&"death"):
		_one_shot_playing = true
		_animated_sprite.speed_scale = DEATH_ANIM_SPEED_SCALE
		_animated_sprite.play(&"death")
	else:
		queue_free()


## Разовый урон игроку при гибели (иглобомба/puffermine, см. doc-комментарий
## у death_explosion_damage) — срабатывает сразу в die(), не дожидаясь конца
## death-анимации: отходить от взорвавшейся мины, пока она просто доигрывает
## картинку, смысла нет. Визуал — тот же расширяющийся круг, что и у взрыва
## гранаты (player/explosion_effect.tscn), чисто декоративный.
func _trigger_death_explosion() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("take_damage"):
		if global_position.distance_to(player.global_position) <= death_explosion_radius:
			player.take_damage(death_explosion_damage)
	var blast_scene: PackedScene = load("res://player/explosion_effect.tscn")
	var blast: Node2D = blast_scene.instantiate()
	get_tree().current_scene.call_deferred("add_child", blast)
	blast.global_position = global_position
	blast.radius = death_explosion_radius
