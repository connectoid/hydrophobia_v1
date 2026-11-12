extends Node2D
## Круги зоны поражения вокруг игрока — по одному на каждое открытое оружие
## (ближнее и дальнобойное). Радиус берётся напрямую из WeaponData.attack_range,
## того же значения, которым задаётся урон/дальность в player.gd — числа не
## дублируются и не могут разъехаться.

@export var melee_fill_color: Color = Color(1, 1, 1, 0.06)
@export var melee_outline_color: Color = Color(1, 1, 1, 0.35)
@export var ranged_outline_color: Color = Color(0.4, 0.85, 1.0, 0.3)
@export var outline_width: float = 2.0

@onready var _player: Node = get_parent()


func _ready() -> void:
	_player.weapon_unlocked.connect(func(_weapon: WeaponData) -> void: queue_redraw())
	_player.weapon_sold.connect(func(_weapon: WeaponData) -> void: queue_redraw())
	queue_redraw()


## Меню паузы (Отладка → Attack Range) переключает Settings.show_attack_range
## напрямую, без сигнала — проще проверять флаг каждый кадр, чем тянуть сюда
## ссылку на pause_menu.
func _process(_delta: float) -> void:
	visible = Settings.show_attack_range


func _draw() -> void:
	for weapon: WeaponData in _player.unlocked_weapons:
		if weapon.type == WeaponData.WeaponType.MELEE:
			draw_circle(Vector2.ZERO, weapon.attack_range, melee_fill_color)
			draw_arc(Vector2.ZERO, weapon.attack_range, 0.0, TAU, 48, melee_outline_color, outline_width)
		else:
			draw_arc(Vector2.ZERO, weapon.attack_range, 0.0, TAU, 64, ranged_outline_color, outline_width)
