extends Resource
class_name EnemyData
## Данные одного типа врага для спавна — "хранилище" (enemies/data/*.tres),
## отдельное от боевых характеристик самой сцены (здоровье/скорость/урон
## остаются в enemies/scenes/*.tscn, как экспортируемые поля enemy.gd).

@export var enemy_name: String = ""
@export var scene: PackedScene
@export var levels: Array[int] = []   # на каких уровнях (номерах волн) может появляться — пусто -> без ограничения этим списком
@export var min_level: int = 1        # прогрессия: враг не появляется раньше этой волны (акула с волны 2, кальмар с волны 3 и т.п.)
@export var spawn_weight: float = 1.0 # частота спавна относительно других врагов этого уровня
@export var xp_reward: int = 3        # опыт за убийство — переопределяет дефолт в сцене врага
## Фоновая живность (кислородная рыба): спавнится поодиночке равномерным
## отдельным таймером на протяжении всей волны и НЕ ходит стаями (см.
## enemy_spawner.gd — ambient-цикл независим от кривых сложности хищников).
@export var ambient: bool = false


func can_spawn_on_level(level: int) -> bool:
	return level >= min_level and (levels.is_empty() or levels.has(level))
