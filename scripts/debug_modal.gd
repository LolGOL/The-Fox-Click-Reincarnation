class_name DebugModal
extends ColorRect

signal casino_requested
signal deal_requested(deal: Dictionary)
signal glitch_spawn_requested
signal glitches_clear_requested
signal closed

const PHASE_PRESETS: Array[int] = [1, 5, 9, 13, 16]
const MYCELIUM_PRESETS: Array[int] = [0, 20, 40, 60, 80, 100]

var modal_busy_probe: Callable

@onready var _panel: PanelContainer = %PanelContainer
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _body_scroll: ScrollContainer = %BodyScroll

@onready var _events_panel: PanelContainer = %EventsPanel
@onready var _events_title: Label = %EventsTitle
@onready var _events_info_label: Label = %EventsInfoLabel
@onready var _open_casino_btn: Button = %OpenCasinoButton
@onready var _trigger_stall_btn: Button = %TriggerStallButton
@onready var _open_deal_btn: Button = %OpenDealButton
@onready var _ghost_beat_btn: Button = %GhostBeatButton
@onready var _ghost_reset_btn: Button = %GhostResetButton
@onready var _spawn_glitch_btn: Button = %SpawnGlitchButton
@onready var _clear_fx_btn: Button = %ClearFxButton
@onready var _myc_row: HBoxContainer = %MycRow

@onready var _economy_panel: PanelContainer = %EconomyPanel
@onready var _economy_title: Label = %EconomyTitle
@onready var _add_1m_btn: Button = %Add1MButton
@onready var _add_100m_btn: Button = %Add100MButton
@onready var _add_1t_btn: Button = %Add1TButton
@onready var _add_1qi_btn: Button = %Add1QiButton
@onready var _mul_10_btn: Button = %Mul10CoinsButton
@onready var _add_spores_btn: Button = %AddSporesButton
@onready var _add_shards_btn: Button = %AddShardsButton
@onready var _add_free_shards_btn: Button = %AddFreeShardsButton
@onready var _phases_row: HBoxContainer = %PhasesRow
@onready var _save_btn: Button = %SaveButton
@onready var _load_btn: Button = %LoadButton
@onready var _reset_save_btn: Button = %ResetSaveButton

@onready var _telemetry_panel: PanelContainer = %TelemetryPanel
@onready var _telemetry_title: Label = %TelemetryTitle
@onready var _telemetry_label: Label = %TelemetryLabel

func _ready() -> void:
	visible = false
	set_process(false)

	_apply_theme()
	_build_dynamic_rows()
	_bind_ui_signals()
	_connect_autoload_signals()

func _exit_tree() -> void:
	_disconnect_autoload_signals()

func open() -> void:
	visible = true
	set_process(true)
	_refresh_live_data()

func close() -> void:
	if not visible:
		set_process(false)
		return
	visible = false
	set_process(false)
	closed.emit()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _process(_delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_refresh_live_data()

func _apply_theme() -> void:
	_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(FoxTheme.ACID, Color("#080203"), 3))
	_title_label.add_theme_color_override("font_color", FoxTheme.ACID)
	FoxTheme.apply_button(_close_button, true)
	FoxTheme.apply_scrollbar(_body_scroll.get_v_scroll_bar())

	for sec: PanelContainer in [_events_panel, _economy_panel, _telemetry_panel]:
		sec.add_theme_stylebox_override("panel", FoxTheme.panel_style(FoxTheme.LINE, FoxTheme.PANEL_BG, 2))

	_events_title.add_theme_color_override("font_color", FoxTheme.RED)
	_economy_title.add_theme_color_override("font_color", FoxTheme.GOOD)
	_telemetry_title.add_theme_color_override("font_color", FoxTheme.ACID)
	_events_info_label.add_theme_color_override("font_color", Color("#ecd9dc"))
	_telemetry_label.add_theme_color_override("font_color", Color("#ecd9dc"))

	for btn: Button in [
		_open_casino_btn, _trigger_stall_btn, _open_deal_btn,
		_ghost_beat_btn, _ghost_reset_btn, _spawn_glitch_btn, _clear_fx_btn,
		_add_1m_btn, _add_100m_btn, _add_1t_btn, _add_1qi_btn, _mul_10_btn,
		_add_spores_btn, _add_shards_btn, _add_free_shards_btn,
		_save_btn, _load_btn
	]:
		FoxTheme.apply_button(btn)
	FoxTheme.apply_button(_reset_save_btn, true)

func _build_dynamic_rows() -> void:
	for inf_v: int in MYCELIUM_PRESETS:
		var ib := Button.new()
		ib.text = "Миц. %d%%" % inf_v
		ib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		FoxTheme.apply_button(ib)
		ib.pressed.connect(_on_set_infection.bind(inf_v))
		_myc_row.add_child(ib)

	var prev_btn := Button.new()
	prev_btn.text = "Фаза -1"
	prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FoxTheme.apply_button(prev_btn)
	prev_btn.pressed.connect(func() -> void:
		GameState.debug_set_phase(maxi(1, GameState.last_phase - 1))
	)
	_phases_row.add_child(prev_btn)

	for p_num: int in PHASE_PRESETS:
		var pb := Button.new()
		pb.text = "Фаза %d" % p_num
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		FoxTheme.apply_button(pb)
		pb.pressed.connect(func() -> void:
			GameState.debug_set_phase(p_num)
		)
		_phases_row.add_child(pb)

	var next_btn := Button.new()
	next_btn.text = "Фаза +1"
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FoxTheme.apply_button(next_btn)
	next_btn.pressed.connect(func() -> void:
		GameState.debug_set_phase(mini(GameData.PHASES.size(), GameState.last_phase + 1))
	)
	_phases_row.add_child(next_btn)

func _bind_ui_signals() -> void:
	_close_button.pressed.connect(close)

	_open_casino_btn.pressed.connect(func() -> void:
		close()
		casino_requested.emit()
	)
	_trigger_stall_btn.pressed.connect(func() -> void:
		GameState._stall_offered = false
		GameState._stall_cd = 0.0
		GameState.stall_detected.emit()
		_refresh_live_data()
	)
	_open_deal_btn.pressed.connect(func() -> void:
		close()
		deal_requested.emit(GameState.DEALS[randi() % GameState.DEALS.size()])
	)
	_ghost_beat_btn.pressed.connect(_on_simulate_ghost_beat)
	_ghost_reset_btn.pressed.connect(_on_reset_ghost_records)
	_spawn_glitch_btn.pressed.connect(func() -> void:
		close()
		glitch_spawn_requested.emit()
	)
	_clear_fx_btn.pressed.connect(func() -> void:
		GameState.fx.clear()
		glitches_clear_requested.emit()
		GameState.state_changed.emit()
	)

	_add_1m_btn.pressed.connect(_on_add_coins.bind(1.0, 6))
	_add_100m_btn.pressed.connect(_on_add_coins.bind(1.0, 8))
	_add_1t_btn.pressed.connect(_on_add_coins.bind(1.0, 12))
	_add_1qi_btn.pressed.connect(_on_add_coins.bind(1.0, 18))
	_mul_10_btn.pressed.connect(func() -> void:
		var base := GameState.coins.copy()
		if is_zero_approx(base.mantissa):
			GameState.earn(BigNum.from_float(10.0))
		else:
			GameState.earn(base.mul_float(9.0))
		GameState.state_changed.emit()
	)

	_add_spores_btn.pressed.connect(func() -> void:
		GameState.spores += 50
		GameState.state_changed.emit()
	)
	_add_shards_btn.pressed.connect(func() -> void:
		GameState.shards += 10
		GameState.state_changed.emit()
	)
	_add_free_shards_btn.pressed.connect(func() -> void:
		GameState.free_shards += 10
		GameState.state_changed.emit()
	)

	_save_btn.pressed.connect(func() -> void:
		GameState.save_game()
		GameState.voice_logged.emit("[DEBUG] Сохранение записано.")
		_refresh_live_data()
	)
	_load_btn.pressed.connect(func() -> void:
		GameState.load_game()
		GameState.last_phase = Economy.phase_of(GameState)
		GameState.state_changed.emit()
		GameState.voice_logged.emit("[DEBUG] Сохранение загружено.")
		_refresh_live_data()
	)
	_reset_save_btn.pressed.connect(func() -> void:
		GameState.reset_save_data()
		GameState.voice_logged.emit("[DEBUG] Сохранение полностью сброшено.")
		_refresh_live_data()
	)

func _connect_autoload_signals() -> void:
	if not GameState.state_changed.is_connected(_on_autoload_updated):
		GameState.state_changed.connect(_on_autoload_updated)
	if not Casino.spin_started.is_connected(_on_casino_spin_started):
		Casino.spin_started.connect(_on_casino_spin_started)
	if not Casino.spin_resolved.is_connected(_on_casino_spin_resolved):
		Casino.spin_resolved.connect(_on_casino_spin_resolved)
	if not Ghost.records_reset.is_connected(_on_autoload_updated):
		Ghost.records_reset.connect(_on_autoload_updated)

func _disconnect_autoload_signals() -> void:
	if GameState.state_changed.is_connected(_on_autoload_updated):
		GameState.state_changed.disconnect(_on_autoload_updated)
	if Casino.spin_started.is_connected(_on_casino_spin_started):
		Casino.spin_started.disconnect(_on_casino_spin_started)
	if Casino.spin_resolved.is_connected(_on_casino_spin_resolved):
		Casino.spin_resolved.disconnect(_on_casino_spin_resolved)
	if Ghost.records_reset.is_connected(_on_autoload_updated):
		Ghost.records_reset.disconnect(_on_autoload_updated)

func _on_autoload_updated() -> void:
	if visible:
		_refresh_live_data()

func _on_casino_spin_started(_bet: int) -> void:
	if visible:
		_refresh_live_data()

func _on_casino_spin_resolved(_res: Dictionary) -> void:
	if visible:
		_refresh_live_data()

func _on_set_infection(inf_v: int) -> void:
	GameState.infection = inf_v
	GameState._check_infection_step()
	GameState.state_changed.emit()

func _on_add_coins(mantissa: float, exponent: int) -> void:
	GameState.earn(BigNum.new(mantissa, exponent))
	GameState.state_changed.emit()

func _on_simulate_ghost_beat() -> void:
	var ph: int = GameState.last_phase
	var g: float = Ghost.ghost_time(ph)
	if g <= 0.0:
		Ghost.best[ph] = maxf(GameState.phase_time + 15.0, 60.0)
		g = float(Ghost.best[ph])
	var sim_time: float = maxf(0.1, g * 0.5)
	close()
	Ghost.on_phase_end(ph, sim_time)
	GameState.state_changed.emit()

func _on_reset_ghost_records() -> void:
	Ghost.reset_records()
	GameState.voice_logged.emit("[DEBUG] Рекорды user://ghost.cfg сброшены.")
	_refresh_live_data()

func _refresh_live_data() -> void:
	_refresh_events_info()
	_refresh_telemetry()

func _refresh_events_info() -> void:
	var stall_gap_str := _calc_stall_eta_text()
	var ghost_rec := Ghost.ghost_time(GameState.last_phase)
	var ghost_str := ("%.1fс" % ghost_rec) if ghost_rec > 0.0 else "нет"
	var pity_active := Casino.loss_streak >= Casino.PITY_LIMIT
	_events_info_label.text = (
		"Казино (Stall): _stall_cd=%.2fс | _stall_offered=%s | до здания=%s (порог %.0fс)\n"
		+ "Casino RNG: loss_streak=%d/%d (pity=%s) | шансы ×0:58%% ×1:17%% ×2:16%% ×5:7%% ×10:2%%\n"
		+ "Таймеры: deal=%.1f/900.0с | glitch=%.1fс | Ghost[Ф%d]=%s (phase_time=%.1fс)"
	) % [
		GameState._stall_cd,
		str(GameState._stall_offered),
		stall_gap_str,
		GameState.STALL_SECONDS,
		Casino.loss_streak,
		Casino.PITY_LIMIT,
		"ON" if pity_active else "OFF",
		GameState.deal_timer,
		GameState.glitch_timer,
		GameState.last_phase,
		ghost_str,
		GameState.phase_time
	]

func _refresh_telemetry() -> void:
	var modal_busy: bool = modal_busy_probe.call() if modal_busy_probe.is_valid() else visible
	var fx_keys := PackedStringArray()
	for k: String in GameState.fx.keys():
		fx_keys.append("%s:%.0fс" % [k, float(GameState.fx[k])])
	var fx_text := ", ".join(fx_keys) if not fx_keys.is_empty() else "нет"
	_telemetry_label.text = (
		"FPS: %d  |  modal_busy: %s  |  is_debug_build: %s\n"
		+ "Фаза: %d/%d  |  run_sec: %.1fс  |  buff_active: %s  |  reinc: %d\n"
		+ "coins: %s  |  cps: %s  |  spores: %d  |  shards: %d  |  free_shards: %d\n"
		+ "infection: %d%% (steps=%d)  |  mutations: %d/5  |  casino_clues: %d\n"
		+ "active_fx: [%s]"
	) % [
		Engine.get_frames_per_second(),
		str(modal_busy),
		str(OS.is_debug_build()),
		GameState.last_phase,
		GameData.PHASES.size(),
		GameState.run_sec,
		str(GameState.is_buff_active()),
		GameState.reinc,
		GameState.coins.format_ru(),
		GameState.get_effective_cps().format_ru(),
		GameState.spores,
		GameState.shards,
		GameState.free_shards,
		GameState.infection,
		GameState.infection_steps_done,
		Mutations.active.size(),
		Casino.clues,
		fx_text
	]

func _calc_stall_eta_text() -> String:
	var cps := GameState.get_effective_cps().to_float()
	if cps <= 0.0:
		return "∞ (CPS=0)"
	var cheapest: BigNum = BigNum.new(9.9, 999)
	for i: int in range(GameData.BUILDINGS.size()):
		var c := Economy.b_cost(GameState, i, GameState.b[i])
		if not c.gte(cheapest):
			cheapest = c
	var gap := cheapest.sub(GameState.coins).to_float()
	if gap <= 0.0:
		return "0.0с"
	return "%.1fс" % (gap / cps)
