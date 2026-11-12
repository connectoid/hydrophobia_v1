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
@export var attack_interval: float = 1.0
@export var cost: int = 0

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
