extends Node
## Глобальный проигрыватель звуковых эффектов. Спавнит одноразовый
## AudioStreamPlayer как своего ребёнка — звук не обрывается, даже если узел,
## который его вызвал (враг/пикап/снаряд), тут же делает queue_free().

const HIT := preload("res://assets/sounds/hit.mp3")
const CHEST := preload("res://assets/sounds/chest.mp3")
const XP_ORB := preload("res://assets/sounds/xp_orb.mp3")
const OXYGEN := preload("res://assets/sounds/oxygen.mp3")


func play(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
