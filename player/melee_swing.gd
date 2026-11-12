extends Node2D
## Кратковременная визуализация удара ближним оружием: покадровая пиксельная
## анимация броска гарпуна-остроги (см. player/harpoon_strike/), направленная
## от игрока к цели — создаётся отдельно на каждое попадание (см.
## player.gd::_fire_melee), чтобы при нескольких целях за один удар было
## видно, в кого именно ударили. Раньше здесь был процедурно рисуемый
## клин-полигон (см. git-историю, если понадобится откатить) — теперь
## собственно рисованная анимация, сама "бросок" передаётся прогрессией
## кадров (остриё удлиняется), а не программным твином.
##
## length задаёт итоговую длину на экране — узел растягивается по X
## (sprite.scale.x = length / REF_LENGTH) до weapon.attack_range, Y не
## трогаем, поэтому для разного attack_range (90 у ножа, 130 у сабли) гарпун
## лишь слегка растягивается/сжимается по длине, не теряя толщину.

## Опорная длина кадра в пикселях при scale.x = 1.0 — должна совпадать с
## REF_LENGTH в generator-скрипте, которым нарисован harpoon_strike_sheet.png.
const REF_LENGTH := 100.0

@export var length: float = 80.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.scale.x = length / REF_LENGTH
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"strike")
