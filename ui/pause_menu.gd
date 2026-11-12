extends CanvasLayer
## Меню паузы по Esc: Продолжить / Управление / Отладка / Звук / Выход.
## Сам узел и его дети работают в PROCESS_MODE_ALWAYS, поэтому кнопки
## остаются кликабельными, даже когда дерево сцены стоит на паузе — по той же
## причине здесь же (а не в level.gd) живёт и экран конца игры (GameOverPanel,
## см. _connect_level_signals/_show_game_over): level.gd специально НЕ ALWAYS,
## чтобы враги/спавнеры реально останавливались на паузе, а значит сам он не
## может надёжно показать интерактивный UI поверх паузы.

@onready var main_panel: Control = $MainPanel
@onready var controls_panel: Control = $ControlsPanel
@onready var mouse_button: Button = $ControlsPanel/MouseButton
@onready var keyboard_button: Button = $ControlsPanel/KeyboardButton
@onready var both_button: Button = $ControlsPanel/BothButton
@onready var debug_panel: Control = $DebugPanel
@onready var balance_menu: Control = $BalanceMenu
@onready var freeze_enemies_button: Button = $DebugPanel/FreezeEnemiesButton
@onready var god_mode_button: Button = $DebugPanel/GodModeButton
@onready var show_attack_range_button: Button = $DebugPanel/ShowAttackRangeButton
@onready var enemy_density_label: Label = $DebugPanel/EnemyDensityLabel
@onready var enemy_density_slider: HSlider = $DebugPanel/EnemyDensitySlider
@onready var game_over_panel: Control = $GameOverPanel
@onready var game_over_title: Label = $GameOverPanel/TitleLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	$MainPanel/ResumeButton.pressed.connect(_close_menu)
	$MainPanel/ControlsButton.pressed.connect(_show_controls)
	$MainPanel/DebugButton.pressed.connect(_show_debug)
	$MainPanel/SoundButton.pressed.connect(_toggle_sound)
	$MainPanel/QuitButton.pressed.connect(func(): get_tree().quit())
	_refresh_sound_button()

	mouse_button.pressed.connect(_set_control_mode.bind(Settings.ControlMode.MOUSE))
	keyboard_button.pressed.connect(_set_control_mode.bind(Settings.ControlMode.KEYBOARD))
	both_button.pressed.connect(_set_control_mode.bind(Settings.ControlMode.BOTH))
	$ControlsPanel/BackButton.pressed.connect(_show_main)

	freeze_enemies_button.pressed.connect(_toggle_freeze_enemies)
	god_mode_button.pressed.connect(_toggle_god_mode)
	show_attack_range_button.pressed.connect(_toggle_show_attack_range)
	$MainPanel/BalanceButton.pressed.connect(_show_balance)
	$DebugPanel/BackButton.pressed.connect(_show_main)
	balance_menu.back.connect(_show_main)
	_refresh_freeze_enemies_button()
	_refresh_god_mode_button()
	_refresh_show_attack_range_button()

	enemy_density_slider.value = Settings.enemy_density_level
	enemy_density_slider.value_changed.connect(_on_enemy_density_slider_changed)
	_refresh_enemy_density_label()

	$GameOverPanel/RestartButton.pressed.connect(_on_restart_pressed)
	$GameOverPanel/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$GameOverPanel/QuitButton.pressed.connect(func(): get_tree().quit())

	# level.gd висит на корневом узле сцены — его _ready() выполняется ПОСЛЕ
	# _ready() всех детей (в т.ч. этого меню), поэтому группа "level" в момент
	# этого вызова ещё пуста. call_deferred откладывает поиск на конец кадра.
	call_deferred("_connect_level_signals")


func _connect_level_signals() -> void:
	var level := get_tree().get_first_node_in_group("level")
	if level:
		level.game_lost.connect(_on_game_lost)
		level.game_won.connect(_on_game_won)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Экран конца игры закрывается только его кнопками, не по Esc —
		# иначе игрок мог бы "сбежать" в пустую паузу без доступного меню.
		var level := get_tree().get_first_node_in_group("level")
		if level and level.game_ended:
			return
		get_viewport().set_input_as_handled()
		_toggle_menu()


func _toggle_menu() -> void:
	if visible:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	# После смерти пауза уже стоит из-за экрана поражения — меню в этот
	# момент открывать не даём, иначе "Продолжить" сломает состояние.
	var level := get_tree().get_first_node_in_group("level")
	if level and level.game_ended:
		return
	# Пока открыт магазин оружия между волнами (тоже ставит паузу) — по той же причине.
	var shop := get_tree().get_first_node_in_group("weapon_shop")
	if shop and shop.visible:
		return
	show()
	_show_main()
	$MainPanel/WaveLabel.text = "Волна %d из %d" % [DepthManager.current_wave, DepthManager.max_waves]
	get_tree().paused = true


func _close_menu() -> void:
	hide()
	get_tree().paused = false


func _show_main() -> void:
	main_panel.show()
	controls_panel.hide()
	debug_panel.hide()
	balance_menu.hide()
	game_over_panel.hide()


func _on_game_lost() -> void:
	_show_game_over("ИГРА ОКОНЧЕНА")


func _on_game_won() -> void:
	_show_game_over("ПОБЕДА!\nВы прошли все волны.")


func _show_game_over(title: String) -> void:
	main_panel.hide()
	controls_panel.hide()
	debug_panel.hide()
	balance_menu.hide()
	game_over_title.text = title
	game_over_panel.show()
	show()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _show_controls() -> void:
	main_panel.hide()
	controls_panel.show()
	_refresh_control_buttons()


func _show_debug() -> void:
	main_panel.hide()
	debug_panel.show()
	balance_menu.hide()


func _show_balance() -> void:
	main_panel.hide()
	balance_menu.open()


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
