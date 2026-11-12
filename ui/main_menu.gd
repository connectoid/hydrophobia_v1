extends Control
## Стартовое меню — точка входа в игру (см. project.godot: run/main_scene).
## "Начать игру" переключает сцену на res://node_2d.tscn (сам уровень).
## Управление/Отладка/Звук читают/пишут те же флаги Settings, что и
## ui/pause_menu.gd (единственный источник правды) — настройки, выбранные
## здесь до старта, действуют и в самой игре.

@onready var main_panel: Control = $MainPanel
@onready var controls_panel: Control = $ControlsPanel
@onready var debug_panel: Control = $DebugPanel
@onready var balance_menu: Control = $BalanceMenu
@onready var help_panel: Control = $HelpPanel
@onready var dev_diary_panel: Control = $DevDiaryPanel
@onready var mouse_button: Button = $ControlsPanel/MouseButton
@onready var keyboard_button: Button = $ControlsPanel/KeyboardButton
@onready var both_button: Button = $ControlsPanel/BothButton
@onready var freeze_enemies_button: Button = $DebugPanel/FreezeEnemiesButton
@onready var god_mode_button: Button = $DebugPanel/GodModeButton
@onready var show_attack_range_button: Button = $DebugPanel/ShowAttackRangeButton
@onready var enemy_density_label: Label = $DebugPanel/EnemyDensityLabel
@onready var enemy_density_slider: HSlider = $DebugPanel/EnemyDensitySlider


func _ready() -> void:
	_show_main()

	$MainPanel/StartButton.pressed.connect(_on_start_pressed)
	$MainPanel/ControlsButton.pressed.connect(_show_controls)
	$MainPanel/DebugButton.pressed.connect(_show_debug)
	$MainPanel/BalanceButton.pressed.connect(_show_balance)
	$MainPanel/SoundButton.pressed.connect(_toggle_sound)
	$MainPanel/HelpButton.pressed.connect(_show_help)
	$MainPanel/DevDiaryButton.pressed.connect(_show_dev_diary)
	$MainPanel/QuitButton.pressed.connect(func(): get_tree().quit())
	_refresh_sound_button()
	balance_menu.back.connect(_show_main)

	mouse_button.pressed.connect(_set_control_mode.bind(Settings.ControlMode.MOUSE))
	keyboard_button.pressed.connect(_set_control_mode.bind(Settings.ControlMode.KEYBOARD))
	both_button.pressed.connect(_set_control_mode.bind(Settings.ControlMode.BOTH))
	$ControlsPanel/BackButton.pressed.connect(_show_main)
	_refresh_control_buttons()

	freeze_enemies_button.pressed.connect(_toggle_freeze_enemies)
	god_mode_button.pressed.connect(_toggle_god_mode)
	show_attack_range_button.pressed.connect(_toggle_show_attack_range)
	$DebugPanel/BackButton.pressed.connect(_show_main)
	_refresh_freeze_enemies_button()
	_refresh_god_mode_button()
	_refresh_show_attack_range_button()

	enemy_density_slider.value = Settings.enemy_density_level
	enemy_density_slider.value_changed.connect(_on_enemy_density_slider_changed)
	_refresh_enemy_density_label()

	$HelpPanel/BackButton.pressed.connect(_show_main)
	$DevDiaryPanel/BackButton.pressed.connect(_show_main)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://node_2d.tscn")


func _show_main() -> void:
	main_panel.show()
	controls_panel.hide()
	debug_panel.hide()
	balance_menu.hide()
	help_panel.hide()
	dev_diary_panel.hide()


func _show_controls() -> void:
	main_panel.hide()
	controls_panel.show()


func _show_debug() -> void:
	main_panel.hide()
	debug_panel.show()
	balance_menu.hide()


func _show_balance() -> void:
	main_panel.hide()
	balance_menu.open()


func _show_help() -> void:
	main_panel.hide()
	help_panel.show()


func _show_dev_diary() -> void:
	main_panel.hide()
	dev_diary_panel.show()


func _toggle_sound() -> void:
	Settings.set_sound_enabled(not Settings.sound_enabled)
	_refresh_sound_button()


func _refresh_sound_button() -> void:
	$MainPanel/SoundButton.text = "Звук: " + ("Вкл" if Settings.sound_enabled else "Выкл")


func _toggle_freeze_enemies() -> void:
	Settings.set_enemies_frozen(not Settings.enemies_frozen)
	_refresh_freeze_enemies_button()


func _refresh_freeze_enemies_button() -> void:
	freeze_enemies_button.text = "Возобновить всех врагов" if Settings.enemies_frozen else "Остановить всех врагов"


func _toggle_god_mode() -> void:
	Settings.set_god_mode(not Settings.god_mode)
	_refresh_god_mode_button()


func _refresh_god_mode_button() -> void:
	god_mode_button.text = "Режим Бога: " + ("Вкл" if Settings.god_mode else "Выкл")


func _toggle_show_attack_range() -> void:
	Settings.set_show_attack_range(not Settings.show_attack_range)
	_refresh_show_attack_range_button()


func _refresh_show_attack_range_button() -> void:
	show_attack_range_button.text = "Attack Range: " + ("Вкл" if Settings.show_attack_range else "Выкл")


func _on_enemy_density_slider_changed(value: float) -> void:
	Settings.set_enemy_density_level(roundi(value))
	_refresh_enemy_density_label()


func _refresh_enemy_density_label() -> void:
	var level := Settings.enemy_density_level
	var label: String = Settings.ENEMY_DENSITY_LABELS[level - 1]
	enemy_density_label.text = "Количество врагов:\n%s (%d/%d)" % [label, level, Settings.ENEMY_DENSITY_LEVELS]


func _set_control_mode(mode: Settings.ControlMode) -> void:
	Settings.set_control_mode(mode)
	_refresh_control_buttons()


func _refresh_control_buttons() -> void:
	mouse_button.text = "Мышь" + (" ✓" if Settings.control_mode == Settings.ControlMode.MOUSE else "")
	keyboard_button.text = "Клавиатура" + (" ✓" if Settings.control_mode == Settings.ControlMode.KEYBOARD else "")
	both_button.text = "Мышь + клавиатура" + (" ✓" if Settings.control_mode == Settings.ControlMode.BOTH else "")
