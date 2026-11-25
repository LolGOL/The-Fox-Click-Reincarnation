class_name CasinoModal
extends ColorRect

signal spin_won(win: int, busted: bool)
signal closed

const BET_OPTIONS: Array[int] = [1, 5, 10, 25]

@onready var _panel: PanelContainer = %PanelContainer
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _spores_label: Label = %SporesLabel
@onready var _status_label: Label = %StatusLabel
@onready var _bet_row: HBoxContainer = %BetRow
@onready var _spin_button: Button = %SpinButton
@onready var _catch_button: Button = %CatchButton

var _bet: int = 1

func _ready() -> void:
	visible = false
	set_process(false)

	_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(FoxTheme.RED, Color("#0a0103"), 3))
	_title_label.add_theme_color_override("font_color", FoxTheme.RED)
	_spores_label.add_theme_color_override("font_color", FoxTheme.GOOD)

	FoxTheme.apply_button(_close_button)
	FoxTheme.apply_button(_spin_button, true)
	FoxTheme.apply_button(_catch_button, true)

	var bet_buttons := _bet_row.get_children()
	for i: int in mini(bet_buttons.size(), BET_OPTIONS.size()):
		var btn := bet_buttons[i] as Button
		if btn:
			FoxTheme.apply_button(btn)
			btn.pressed.connect(_on_bet_pressed.bind(BET_OPTIONS[i]))

	_close_button.pressed.connect(_on_close_pressed)
	_spin_button.pressed.connect(_on_spin_pressed)
	_catch_button.pressed.connect(_on_catch_pressed)

	if not Casino.spin_started.is_connected(_on_casino_spin_started):
		Casino.spin_started.connect(_on_casino_spin_started)
	if not Casino.ear_twitch.is_connected(_on_casino_ear_twitch):
		Casino.ear_twitch.connect(_on_casino_ear_twitch)
	if not Casino.spin_resolved.is_connected(_on_casino_spin_resolved):
		Casino.spin_resolved.connect(_on_casino_spin_resolved)
	if not GameState.state_changed.is_connected(_on_game_state_changed):
		GameState.state_changed.connect(_on_game_state_changed)

func _exit_tree() -> void:
	if Casino.spin_started.is_connected(_on_casino_spin_started):
		Casino.spin_started.disconnect(_on_casino_spin_started)
	if Casino.ear_twitch.is_connected(_on_casino_ear_twitch):
		Casino.ear_twitch.disconnect(_on_casino_ear_twitch)
	if Casino.spin_resolved.is_connected(_on_casino_spin_resolved):
		Casino.spin_resolved.disconnect(_on_casino_spin_resolved)
	if GameState.state_changed.is_connected(_on_game_state_changed):
		GameState.state_changed.disconnect(_on_game_state_changed)

func open() -> bool:
	if visible:
		return false
	_catch_button.visible = Casino.twitch_open and not Casino.pending.is_empty()
	refresh_ui()
	visible = true
	return true

func close() -> bool:
	if is_spin_active():
		Audio.play_sfx("error")
		return false
	if not visible:
		return true
	visible = false
	set_process(false)
	closed.emit()
	return true

func is_spin_active() -> bool:
	return not Casino.pending.is_empty() or _catch_button.visible

func refresh_ui() -> void:
	_spores_label.text = "Твои споры: %d  |  Выбранная ставка: %d  |  Улик поймано: %d" % [
		GameState.spores, _bet, Casino.clues
	]
	_close_button.disabled = is_spin_active()

func _on_bet_pressed(bet_value: int) -> void:
	_bet = bet_value
	refresh_ui()

func _on_spin_pressed() -> void:
	Casino.spin(_bet)
	refresh_ui()

func _on_catch_pressed() -> void:
	Casino.on_fox_ear_clicked()
	refresh_ui()

func _on_close_pressed() -> void:
	close()

func _on_casino_spin_started(bet: int) -> void:
	_status_label.text = "БАРАБАН КРУТИТСЯ... (Ставка: %d спор)\nСледи за правым ухом Лиса!" % bet
	_catch_button.visible = false
	refresh_ui()

func _on_casino_ear_twitch() -> void:
	if visible:
		_catch_button.visible = true
		refresh_ui()

func _on_casino_spin_resolved(res: Dictionary) -> void:
	_catch_button.visible = false
	var win := int(res.get("win", 0))
	var busted := bool(res.get("busted", false))
	if busted:
		_status_label.text = "ШУЛЕР ПОЙМАН ЗА УХО! Выигрыш: +%d спор (×2)" % win
		spin_won.emit(win, true)
	elif win > 0:
		_status_label.text = "ПОБЕДА ×%.0f! Выигрыш: +%d спор" % [float(res.get("mult", 0.0)), win]
		spin_won.emit(win, false)
	else:
		_status_label.text = "ПРОИГРЫШ... Лис усмехается и прячет твои %d спор." % int(res.get("bet", 0))
	refresh_ui()

func _on_game_state_changed() -> void:
	if visible:
		refresh_ui()
