extends Resource
class_name WeaponData
## Данные одного оружия, вынесенные из player.gd в отдельные .tres-ресурсы
## (weapons/*.tres) — это и есть "хранилище" оружия, независимое от кода.
## Игрок стартует с одним ножом; остальное покупается за XP в магазине между
## волнами (см. ui/weapon_shop.gd) — cost это цена одной покупки.

enum WeaponType { MELEE, RANGED }

@export var weapon_name: String = ""
@export var type: WeaponType = WeaponType.MELEE
@export var damage: float = 10.0
## Интервал МЕЖДУ ВЫСТРЕЛАМИ ВНУТРИ очереди (см. burst_count). Для обычного
## оружия (burst_count = 1) это просто интервал между выстрелами, как раньше.
@export var attack_interval: float = 1.0
@export var cost: int = 0

## Очереди: выстрелов за одну очередь. 1 (по умолчанию) — одиночные выстрелы
## с интервалом attack_interval, поведение прежнее. >1 — оружие стреляет
## очередью из burst_count выстрелов с интервалом attack_interval между ними
## (очень короткий у автомата — высокий темп внутри очереди), затем пауза
## burst_cooldown до следующей очереди (см. player.gd::_process_weapons).
@export var burst_count: int = 1
## Дополнительная пауза после конца очереди до следующей (сек). Для оружия
## без очередей просто добавляется к attack_interval (обычно 0).
@export var burst_cooldown: float = 0.0

## Только для RANGED — сцена снаряда, инстанцируется в player.gd.
@export var projectile_scene: PackedScene

## Радиус поражения. Для MELEE — зона вокруг игрока, которую бьёт удар;
## для RANGED — дальше этого радиуса оружие врагов не видит и не стреляет.
@export var attack_range: float = 90.0

## Звук выстрела/удара этим оружием (см. autoload/sfx.gd).
@export var fire_sound: AudioStream

## Только для RANGED-оружия с уроном по площади (торпеда) — при взрыве
## снаряда damage получают все цели в этом радиусе от точки взрыва, а не
## только та, во что он попал. 0 (по умолчанию) — обычный снаряд без сплэша,
## одна цель, как раньше (см. player.gd::_fire_ranged/_fire_torpedo).
@export var splash_radius: float = 0.0


## Уровни (тиры) оружия: хранятся у игрока ПОЕДИННО на каждую единицу
## арсенала (player.gd::_weapon_levels), растут кнопкой «Улучшить» в магазине
## при заполненных слотах, а здесь — кривые роста характеристик.
## Каждый следующий уровень НЕМНОГО улучшает базу: урон, дальность и темп
## (интервал делится на рост темпа). Базовые поля правятся "на лету" меню
## Баланс, поэтому множители применяются к ним в момент чтения через
## *_at(level), а не запекаются в поля.
const LEVEL_DAMAGE_GROWTH := 1.10
const LEVEL_RANGE_GROWTH := 1.05
const LEVEL_RATE_GROWTH := 1.05

func damage_at(level: int) -> float:
	return damage * pow(LEVEL_DAMAGE_GROWTH, maxi(level, 1) - 1)


func range_at(level: int) -> float:
	return attack_range * pow(LEVEL_RANGE_GROWTH, maxi(level, 1) - 1)


func interval_at(level: int) -> float:
	return attack_interval / pow(LEVEL_RATE_GROWTH, maxi(level, 1) - 1)
