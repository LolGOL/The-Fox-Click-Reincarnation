extends Node2D

const DEAL_MODAL_SCENE := preload("res://scenes/deal_modal.tscn")
const DealModal := preload("res://scripts/deal_modal.gd")
const CASINO_MODAL_SCENE := preload("res://scenes/casino_modal.tscn")
const CasinoModal := preload("res://scripts/casino_modal.gd")
const MUTATIONS_MODAL_SCENE := preload("res://scenes/mutations_modal.tscn")
const MutationsModal := preload("res://scripts/mutations_modal.gd")
const DEBUG_MODAL_SCENE := preload("res://scenes/debug_modal.tscn")
const DebugModal := preload("res://scripts/debug_modal.gd")

const SIGIL_TITLES: Array[String] = [
	"SIGIL LV.1 // РЖАВАЯ КНОПКА",
	"SIGIL LV.2 // ХИЩНЫЙ ТЕРМИНАЛ",
	"SIGIL LV.3 // РЕАКТОР КОДА 146",
	"SIGIL LV.4 // ЦИФРОВОЙ РАЗЛОМ"
]

const DRAWER_PANEL_W := 440.0
const HANDLE_W := 38.0
const TOTAL_DRAWER_W := DRAWER_PANEL_W + HANDLE_W

var sb_btn_normal: StyleBoxFlat
var sb_btn_active: StyleBoxFlat

var bg_rect: ColorRect
var ui_root: VBoxContainer
var vfx: VfxLayer
var crt_mat: ShaderMaterial
var sigil_btn: CoreSigilButton
var fox_pet: FoxPetActor

var _typewriter_busy: bool = false
var _typewriter_full: String = ""
var _typewriter_pos: int = 0
var _typewriter_timer: Timer
var _last_phase: int = -1

var left_drawer: HBoxContainer
var right_drawer: HBoxContainer
var left_pinned: bool = false
var right_pinned: bool = false
var left_open_t: float = 0.0
var right_open_t: float = 0.0
var left_grace: float = 0.0
var right_grace: float = 0.0

var coins_lbl: Label
var cps_lbl: Label
var phase_lbl: Label
var ghost_lbl: Label
var voice_lbl: Label
var sigil_lbl: Label
var combo_lbl: Label
var fx_lbl: Label
var phase_bar: ProgressBar
var myc_lbl: Label
var myc_bar: ProgressBar
var spore_btn: Button
var purify_btn: Button
var ach_btn: Button
var menu_btn: Button
var pause_overlay: ColorRect
var tick_timer: Timer
var _autoclick_cd: float = 0.0
var sound_btn: Button
var mute_fox_btn: Button
var casino_btn: Button

var shop_list: VBoxContainer
var shop_rows: Array[Dictionary] = []
var fake_row: Control = null
var fake_timer: float = 16.0

var ups_box: VBoxContainer
var amt_btns: Dictionary = {}
var last_up_sig: String = ""

# Модальные окна
var deal_modal: DealModal
var casino_modal: CasinoModal
var mutations_modal: MutationsModal

var logs_overlay: ColorRect
var logs_list_box: VBoxContainer
var logs_lore_lbl: Label

var debug_modal: DebugModal = null

var recent_clicks: Array[float] = []
var shake_time: float = 0.0
var flash_red_val: float = 0.0

func _ready() -> void:
	_init_shared_styles()
	_build_ui()
	_build_shader_and_vfx()
	_build_modals()
	_build_pause_overlay()

	GameState.state_changed.connect(_refresh_ui)
	GameState.voice_logged.connect(_on_voice_logged)
	GameState.deal_requested.connect(_open_deal)
	GameState.glitch_spawn_requested.connect(_on_glitch_spawn_requested)
	GameState.screen_flash_requested.connect(_on_screen_flash_requested)
	GameState.stall_detected.connect(_on_stall_detected)
	Casino.offer_changed.connect(_on_casino_offer_changed)

	Ghost.delta_ready.connect(_on_ghost_delta_ready)
	Ghost.ghost_beaten.connect(_on_ghost_beaten)
	Ghost.records_reset.connect(_on_ghost_records_reset)

	Achievements.unlocked_new.connect(_on_achievement_unlocked)

	tick_timer = Timer.new()
	tick_timer.wait_time = 0.1
	tick_timer.autostart = true
	tick_timer.timeout.connect(func() -> void: GameState.step(0.1))
	add_child(tick_timer)

	var save_timer := Timer.new()
	save_timer.wait_time = 5.0
	save_timer.autostart = true
	save_timer.timeout.connect(GameState.save_game)
	add_child(save_timer)

	_last_phase = Economy.phase_of(GameState)
	if bg_rect != null:
		bg_rect.color = Economy.bg_color_for_phase(_last_phase)
	_type_voice("> Fox OS: Заработай. Возвысься. Стань мной.")

	_refresh_ui()

func _exit_tree() -> void:
	if GameState.state_changed.is_connected(_refresh_ui):
		GameState.state_changed.disconnect(_refresh_ui)
	if GameState.voice_logged.is_connected(_on_voice_logged):
		GameState.voice_logged.disconnect(_on_voice_logged)
	if GameState.deal_requested.is_connected(_open_deal):
		GameState.deal_requested.disconnect(_open_deal)
	if GameState.glitch_spawn_requested.is_connected(_on_glitch_spawn_requested):
		GameState.glitch_spawn_requested.disconnect(_on_glitch_spawn_requested)
	if GameState.screen_flash_requested.is_connected(_on_screen_flash_requested):
		GameState.screen_flash_requested.disconnect(_on_screen_flash_requested)
	if GameState.stall_detected.is_connected(_on_stall_detected):
		GameState.stall_detected.disconnect(_on_stall_detected)
	if Casino.offer_changed.is_connected(_on_casino_offer_changed):
		Casino.offer_changed.disconnect(_on_casino_offer_changed)
	if Ghost.delta_ready.is_connected(_on_ghost_delta_ready):
		Ghost.delta_ready.disconnect(_on_ghost_delta_ready)
	if Ghost.ghost_beaten.is_connected(_on_ghost_beaten):
		Ghost.ghost_beaten.disconnect(_on_ghost_beaten)
	if Ghost.records_reset.is_connected(_on_ghost_records_reset):
		Ghost.records_reset.disconnect(_on_ghost_records_reset)
	if Achievements.unlocked_new.is_connected(_on_achievement_unlocked):
		Achievements.unlocked_new.disconnect(_on_achievement_unlocked)

func _on_voice_logged(txt: String) -> void:
	_type_voice("> Fox OS: " + txt)

func _on_glitch_spawn_requested(cnt: int) -> void:
	for _i in range(cnt):
		vfx.spawn_glitch_artifact()

func _on_screen_flash_requested(intensity: float, shake: bool) -> void:
	flash_red_val = maxf(flash_red_val, intensity)
	if shake:
		shake_time = 0.32

func _on_stall_detected() -> void:
	Casino.offer_via_fox()

func _on_ghost_delta_ready(d_sec: float) -> void:
	ghost_lbl.text = "GHOST: " + Ghost.fmt(d_sec)
	ghost_lbl.add_theme_color_override("font_color", Color("#39ff88") if d_sec < 0.0 else Color("#ff5266"))

func _on_ghost_beaten(bonus: int) -> void:
	vfx.spawn_purchase_burst(Vector2(800, 120), "ПРИЗРАК ОБОГНАН! +%d ОСК." % bonus, true)

func _on_ghost_records_reset() -> void:
	ghost_lbl.text = "GHOST: --:--"
	ghost_lbl.add_theme_color_override("font_color", Color("#926870"))

func _on_achievement_unlocked(_id: int, path: String, _lore: String) -> void:
	_type_voice("> Fox OS: Файл расшифрован -> " + path)
	vfx.spawn_floating_text(Vector2(800, 90), "UNLOCK: " + path, Color("#00e5ff"), 1.05)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12 and OS.is_debug_build():
			_toggle_debug_modal()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			var dbg_open := debug_modal != null and debug_modal.visible
			if pause_overlay.visible:
				_set_paused(false)
			elif dbg_open or casino_modal.visible or logs_overlay.visible:
				if debug_modal != null:
					debug_modal.close()
				logs_overlay.visible = false
				if casino_modal.visible:
					casino_modal.close()
			else:
				_set_paused(true)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var cur_ph: int = Economy.phase_of(GameState)
	if cur_ph != _last_phase:
		_on_phase_changed(_last_phase, cur_ph)
		_last_phase = cur_ph

	var now: float = Time.get_unix_time_from_system()
	while not recent_clicks.is_empty() and now - recent_clicks[0] > 1.0:
		recent_clicks.pop_front()
	combo_lbl.text = "РИТМ: %d КЛ/С" % recent_clicks.size()
	combo_lbl.add_theme_color_override("font_color", Color("#39ff88") if recent_clicks.size() >= 4 else Color("#926870"))

	_update_drawers(delta)

	if FoxSettings.autoclick_hold and sigil_btn.is_pressed and not pause_overlay.visible:
		_autoclick_cd -= delta
		if _autoclick_cd <= 0.0:
			_autoclick_cd = 0.12
			sigil_btn.clicked.emit(sigil_btn.get_global_rect().get_center())
	else:
		_autoclick_cd = 0.0

	if shake_time > 0.0:
		shake_time -= delta
		var shk := FoxSettings.shake_mult() * 2.0
		ui_root.position = Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 4.0)) * shk
	else:
		ui_root.position = Vector2.ZERO

	var inf: int = Economy.inf_eff(GameState)
	var jitter_active := inf >= 20 or Mutations.has_glitch("ui_jitter")
	for r: Dictionary in shop_rows:
		var btn: Button = r["btn"]
		if btn.has_meta("dodging"):
			continue
		if jitter_active:
			var jit := randf_range(-1.8, 1.8)
			btn.offset_left = jit
			btn.offset_right = jit
		elif not is_zero_approx(btn.offset_left) or not is_zero_approx(btn.offset_right):
			btn.offset_left = 0.0
			btn.offset_right = 0.0

	coins_lbl.modulate.a = (0.76 + 0.24 * sin(now * 16.0)) if (inf >= 40 or Mutations.has_glitch("echo")) else 1.0
	_tick_fake_button(delta, inf)

	flash_red_val = maxf(0.0, flash_red_val - delta * 1.4)
	if crt_mat:
		var inf_f := float(inf) / 100.0
		var aber := 0.0002 + inf_f * 0.001 + (0.001 if Mutations.has_glitch("chroma") else 0.0)
		var tear := 0.005 if (inf >= 80 or Mutations.has_glitch("tear")) else 0.0
		crt_mat.set_shader_parameter("aberration", aber)
		crt_mat.set_shader_parameter("tear_strength", tear)
		crt_mat.set_shader_parameter("bw_mode", 1.0 if float(GameState.fx.get("over", 0.0)) > 0.0 else 0.0)
		crt_mat.set_shader_parameter("flash_red", flash_red_val * 0.5)

func _on_phase_changed(old_ph: int, new_ph: int) -> void:
	var old_tier: int = Economy.tier_of(old_ph) if old_ph > 0 else 1
	var new_tier: int = Economy.tier_of(new_ph)
	if fox_pet != null:
		fox_pet.evolve(new_tier)
	if bg_rect != null:
		var bg_tw := create_tween()
		bg_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		bg_tw.tween_property(bg_rect, "color", Economy.bg_color_for_phase(new_ph), 0.9)
	var phase_name: String = String(GameData.PHASES[new_ph - 1]["name"]).to_upper()
	if new_tier > old_tier:
		_type_voice("> Fox OS: ФАЗА %d // %s. Тир Лиса повышен до %d. Метки переписаны." % [new_ph, phase_name, new_tier])
	else:
		_type_voice("> Fox OS: ФАЗА %d // %s. Глубина растёт." % [new_ph, phase_name])

func _type_voice(text: String) -> void:
	_typewriter_full = text
	_typewriter_pos = 0
	_typewriter_busy = true
	voice_lbl.text = ""
	if _typewriter_timer == null:
		_typewriter_timer = Timer.new()
		_typewriter_timer.wait_time = 0.022
		_typewriter_timer.timeout.connect(_type_voice_tick)
		add_child(_typewriter_timer)
	_typewriter_timer.start()

func _type_voice_tick() -> void:
	if not _typewriter_busy:
		if _typewriter_timer != null:
			_typewriter_timer.stop()
		return
	_typewriter_pos += 1
	voice_lbl.text = _typewriter_full.substr(0, _typewriter_pos)
	if _typewriter_pos >= _typewriter_full.length():
		_typewriter_timer.stop()
		_typewriter_busy = false

func _is_modal_busy() -> bool:
	var dbg_open := debug_modal != null and debug_modal.visible
	return deal_modal.visible or dbg_open or casino_modal.visible or mutations_modal.visible or logs_overlay.visible or pause_overlay.visible

func _toggle_debug_modal() -> void:
	if debug_modal != null:
		debug_modal.toggle()

func _update_drawers(delta: float) -> void:
	var modal_busy := _is_modal_busy()
	var mpos := get_global_mouse_position()

	var l_hover := not modal_busy and left_drawer.get_global_rect().has_point(mpos)
	left_grace = 0.18 if (left_pinned or l_hover) else maxf(0.0, left_grace - delta)
	left_open_t = lerpf(left_open_t, 1.0 if (left_pinned or left_grace > 0.0) else 0.0, minf(1.0, delta * 14.0))
	left_drawer.offset_left = lerpf(-DRAWER_PANEL_W, 0.0, left_open_t)
	left_drawer.offset_right = left_drawer.offset_left + TOTAL_DRAWER_W

	var r_hover := not modal_busy and right_drawer.get_global_rect().has_point(mpos)
	right_grace = 0.18 if (right_pinned or r_hover) else maxf(0.0, right_grace - delta)
	right_open_t = lerpf(right_open_t, 1.0 if (right_pinned or right_grace > 0.0) else 0.0, minf(1.0, delta * 14.0))
	right_drawer.offset_right = lerpf(DRAWER_PANEL_W, 0.0, right_open_t)
	right_drawer.offset_left = right_drawer.offset_right - TOTAL_DRAWER_W

func _init_shared_styles() -> void:
	sb_btn_normal = FoxTheme.panel_style(Color("#c0392b"), Color("#190609"), 2)
	sb_btn_active = FoxTheme.panel_style(Color("#ff5266"), Color("#c0392b"), 2)

func _style_button(btn: Button, is_acid: bool = false) -> void:
	FoxTheme.apply_button(btn, is_acid)

func _style_progress_bar(bar: ProgressBar) -> void:
	FoxTheme.apply_progress_bar(bar)

func _build_drawer_handle(vertical_title: String, is_left: bool) -> PanelContainer:
	var handle := PanelContainer.new()
	handle.custom_minimum_size = Vector2(HANDLE_W, 0)
	var hs := FoxTheme.panel_style(Color("#c0392b"), Color("#120306"), 2)
	hs.content_margin_left = 4
	hs.content_margin_right = 4
	handle.add_theme_stylebox_override("panel", hs)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	handle.add_child(vb)

	var pin_btn := DrawerPinButton.new()
	vb.add_child(pin_btn)
	if is_left:
		pin_btn.toggled.connect(func(p: bool) -> void: left_pinned = p)
	else:
		pin_btn.toggled.connect(func(p: bool) -> void: right_pinned = p)

	var sp1 := Control.new()
	sp1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp1)

	var tag := Label.new()
	tag.text = vertical_title
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color("#ff1e38"))
	tag.add_theme_font_size_override("font_size", 13)
	vb.add_child(tag)

	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp2)
	return handle

func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)

	bg_rect = ColorRect.new()
	bg_rect.color = Color("#030102")
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(bg_rect)

	ui_root = VBoxContainer.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_theme_constant_override("separation", 6)
	ui_layer.add_child(ui_root)

	# Шапка
	var hdr := PanelContainer.new()
	hdr.add_theme_stylebox_override("panel", FoxTheme.panel_style(Color("#c0392b"), Color("#0c0204"), 2))
	ui_root.add_child(hdr)

	var hdr_hbox := HBoxContainer.new()
	hdr_hbox.add_theme_constant_override("separation", 8)
	hdr.add_child(hdr_hbox)

	var title := Label.new()
	title.text = "[FOX_OS // 146] THE FOX CLICK REINCARNATION"
	title.add_theme_color_override("font_color", Color("#ff1e38"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(title)

	ghost_lbl = Label.new()
	ghost_lbl.text = "GHOST: --:--"
	ghost_lbl.add_theme_color_override("font_color", Color("#926870"))
	hdr_hbox.add_child(ghost_lbl)

	ach_btn = Button.new()
	ach_btn.text = "[ ДОСТИЖЕНИЯ ]"
	_style_button(ach_btn)
	ach_btn.pressed.connect(_open_logs_modal)
	hdr_hbox.add_child(ach_btn)

	sound_btn = Button.new()
	sound_btn.text = "[ЗВУК: ВКЛ]"
	_style_button(sound_btn)
	sound_btn.pressed.connect(func() -> void:
		Audio.set_sound(not Audio.sound_on)
		sound_btn.text = "[ЗВУК: ВКЛ]" if Audio.sound_on else "[ЗВУК: ВЫКЛ]"
	)
	hdr_hbox.add_child(sound_btn)

	mute_fox_btn = Button.new()
	mute_fox_btn.text = "[ЛИС: ГОВОРИТ]"
	_style_button(mute_fox_btn)
	mute_fox_btn.pressed.connect(func() -> void:
		Fox.set_muted(not Fox.muted)
		mute_fox_btn.text = "[ЛИС: МОЛЧИТ]" if Fox.muted else "[ЛИС: ГОВОРИТ]"
	)
	hdr_hbox.add_child(mute_fox_btn)

	casino_btn = Button.new()
	casino_btn.text = "[ CASINO.EXE ]"
	_style_button(casino_btn, true)
	casino_btn.visible = Casino.offer_active
	casino_btn.pressed.connect(_open_casino_from_offer)
	hdr_hbox.add_child(casino_btn)

	if OS.is_debug_build():
		var dbg_btn := Button.new()
		dbg_btn.text = "[DEBUG // F12]"
		_style_button(dbg_btn, true)
		dbg_btn.pressed.connect(_toggle_debug_modal)
		hdr_hbox.add_child(dbg_btn)

	phase_lbl = Label.new()
	phase_lbl.add_theme_color_override("font_color", Color("#c0392b"))
	hdr_hbox.add_child(phase_lbl)

	menu_btn = Button.new()
	menu_btn.text = "[ МЕНЮ ]"
	_style_button(menu_btn)
	menu_btn.pressed.connect(func() -> void: _set_paused(true))
	hdr_hbox.add_child(menu_btn)

	# Строка голоса Fox OS
	var voice_panel := PanelContainer.new()
	voice_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(Color("#4a0e16"), Color("#090204"), 2))
	ui_root.add_child(voice_panel)

	voice_lbl = Label.new()
	voice_lbl.text = "> Fox OS: Заработай. Возвысься. Стань мной."
	voice_lbl.add_theme_color_override("font_color", Color("#ff1e38"))
	voice_panel.add_child(voice_lbl)

	# Рабочая зона
	var workspace := Control.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.clip_contents = true
	ui_root.add_child(workspace)

	# Центральная арена
	var center_panel := PanelContainer.new()
	center_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_panel.offset_left = HANDLE_W + 6.0
	center_panel.offset_right = -(HANDLE_W + 6.0)
	center_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(Color("#c0392b"), Color(0.045, 0.012, 0.02, 0.88), 2))
	workspace.add_child(center_panel)

	var center_vbox := VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 8)
	center_panel.add_child(center_vbox)

	var top_bar := HBoxContainer.new()
	center_vbox.add_child(top_bar)
	sigil_lbl = Label.new()
	sigil_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sigil_lbl.add_theme_color_override("font_color", Color("#c0392b"))
	top_bar.add_child(sigil_lbl)

	combo_lbl = Label.new()
	combo_lbl.text = "РИТМ: 0 КЛ/С"
	top_bar.add_child(combo_lbl)

	coins_lbl = Label.new()
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.add_theme_font_size_override("font_size", 46)
	coins_lbl.add_theme_color_override("font_color", Color("#ff1e38"))
	center_vbox.add_child(coins_lbl)

	cps_lbl = Label.new()
	cps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cps_lbl.add_theme_color_override("font_color", Color("#ecd9dc"))
	center_vbox.add_child(cps_lbl)

	var btn_center := CenterContainer.new()
	btn_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(btn_center)

	sigil_btn = CoreSigilButton.new()
	sigil_btn.clicked.connect(func(gpos: Vector2) -> void:
		recent_clicks.append(Time.get_unix_time_from_system())
		var res: Dictionary = GameState.do_click()
		var gain: BigNum = res["gain"]
		var is_crit: bool = res["is_crit"]
		sigil_btn.trigger_hit_vfx(is_crit)
		if fox_pet:
			fox_pet.react(is_crit)
		if FoxSettings.button_bounce:
			sigil_btn.pivot_offset = sigil_btn.size * 0.5
			var bt := create_tween()
			bt.tween_property(sigil_btn, "scale", Vector2(0.94, 0.94), 0.04)
			bt.tween_property(sigil_btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var greed := float(GameState.fx.get("greed", 0.0)) > 0.0
		var txt := ("КРИТ ×%.0f! +%s" % [res["crit_mult"], "ERR_0x00" if greed else gain.format_ru()]) if is_crit else ("+%s" % ("ERR_0x00" if greed else gain.format_ru()))
		vfx.spawn_floating_text(gpos, txt, Color("#d6ff3a") if is_crit else Color("#ff1e38"), 1.25 if is_crit else 1.0)
	)
	btn_center.add_child(sigil_btn)

	fx_lbl = Label.new()
	fx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx_lbl.add_theme_color_override("font_color", Color("#39ff88"))
	center_vbox.add_child(fx_lbl)

	# Блок мицелия
	var myc_center := CenterContainer.new()
	center_vbox.add_child(myc_center)

	var myc_box := VBoxContainer.new()
	myc_box.custom_minimum_size = Vector2(540, 0)
	myc_center.add_child(myc_box)

	myc_lbl = Label.new()
	myc_lbl.add_theme_color_override("font_color", Color("#c0392b"))
	myc_box.add_child(myc_lbl)

	myc_bar = ProgressBar.new()
	myc_bar.max_value = 100.0
	myc_bar.show_percentage = false
	myc_bar.custom_minimum_size = Vector2(0, 14)
	_style_progress_bar(myc_bar)
	myc_box.add_child(myc_bar)

	var myc_btns := HBoxContainer.new()
	myc_btns.add_theme_constant_override("separation", 8)
	myc_box.add_child(myc_btns)

	spore_btn = Button.new()
	spore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(spore_btn)
	spore_btn.pressed.connect(func() -> void:
		if GameState.buy_spore():
			vfx.spawn_purchase_burst(get_global_mouse_position(), "СПОРЫ ВПРЫСНУТЫ! (+2 СПОРЫ)", true)
	)
	myc_btns.add_child(spore_btn)

	purify_btn = Button.new()
	purify_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(purify_btn)
	purify_btn.pressed.connect(GameState.purify)
	myc_btns.add_child(purify_btn)

	# Отступ снизу под прогулки геометрического Лиса
	var fox_spacer := Control.new()
	fox_spacer.custom_minimum_size = Vector2(0, 74)
	center_vbox.add_child(fox_spacer)

	# === ЛЕВАЯ ВЫДВИЖНАЯ ШТОРКА: МАГАЗИН ===
	left_drawer = HBoxContainer.new()
	left_drawer.anchor_left = 0.0
	left_drawer.anchor_right = 0.0
	left_drawer.anchor_top = 0.0
	left_drawer.anchor_bottom = 1.0
	left_drawer.offset_left = -DRAWER_PANEL_W
	left_drawer.offset_right = HANDLE_W
	left_drawer.add_theme_constant_override("separation", 0)
	workspace.add_child(left_drawer)

	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(Color("#ff1e38"), Color(0.035, 0.012, 0.02, 0.97), 2))
	left_drawer.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)

	var amt_row := HBoxContainer.new()
	left_vbox.add_child(amt_row)
	var amt_title := Label.new()
	amt_title.text = "МАГАЗИН МОДУЛЕЙ:  "
	amt_title.add_theme_color_override("font_color", Color("#c0392b"))
	amt_row.add_child(amt_title)

	for mode: String in ["1", "10", "max"]:
		var ab := Button.new()
		ab.text = "МАКС" if mode == "max" else "×" + mode
		_style_button(ab)
		ab.pressed.connect(func() -> void:
			GameState.buy_amt = mode
			_refresh_ui()
		)
		amt_row.add_child(ab)
		amt_btns[mode] = ab

	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	FoxTheme.apply_scrollbar(shop_scroll.get_v_scroll_bar())
	left_vbox.add_child(shop_scroll)

	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 6)
	shop_scroll.add_child(shop_list)

	for i: int in range(GameData.BUILDINGS.size()):
		var row_box := VBoxContainer.new()
		shop_list.add_child(row_box)

		var btn_holder := Control.new()
		btn_holder.custom_minimum_size = Vector2(0, 36)
		row_box.add_child(btn_holder)

		var btn := Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(btn)
		btn.pressed.connect(func() -> void:
			if GameState.buy_building(i):
				vfx.spawn_purchase_burst(get_global_mouse_position(), "ПОДКЛЮЧЕНО!")
		)
		btn.mouse_entered.connect(func() -> void: _on_shop_btn_hover(btn))
		btn_holder.add_child(btn)

		var meta := Label.new()
		meta.add_theme_color_override("font_color", Color("#926870"))
		meta.add_theme_font_size_override("font_size", 12)
		row_box.add_child(meta)

		shop_rows.append({ "btn": btn, "meta": meta })

	left_drawer.add_child(_build_drawer_handle("М\nА\nГ\nА\nЗ\nИ\nН", true))

	# === ПРАВАЯ ВЫДВИЖНАЯ ШТОРКА: УЛУЧШЕНИЯ ===
	right_drawer = HBoxContainer.new()
	right_drawer.anchor_left = 1.0
	right_drawer.anchor_right = 1.0
	right_drawer.anchor_top = 0.0
	right_drawer.anchor_bottom = 1.0
	right_drawer.offset_left = -HANDLE_W
	right_drawer.offset_right = DRAWER_PANEL_W
	right_drawer.add_theme_constant_override("separation", 0)
	workspace.add_child(right_drawer)

	right_drawer.add_child(_build_drawer_handle("А\nП\nГ\nР\nЕ\nЙ\nД\nЫ", false))

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(Color("#ff1e38"), Color(0.035, 0.012, 0.02, 0.97), 2))
	right_drawer.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_panel.add_child(right_vbox)

	var up_title := Label.new()
	up_title.text = "УЛУЧШЕНИЯ ЯДРА"
	up_title.add_theme_color_override("font_color", Color("#c0392b"))
	right_vbox.add_child(up_title)

	var up_scroll := ScrollContainer.new()
	up_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	FoxTheme.apply_scrollbar(up_scroll.get_v_scroll_bar())
	right_vbox.add_child(up_scroll)

	ups_box = VBoxContainer.new()
	ups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ups_box.add_theme_constant_override("separation", 6)
	up_scroll.add_child(ups_box)

	phase_bar = ProgressBar.new()
	phase_bar.max_value = 1.0
	phase_bar.custom_minimum_size = Vector2(0, 16)
	_style_progress_bar(phase_bar)
	right_vbox.add_child(phase_bar)

func _build_shader_and_vfx() -> void:
	vfx = VfxLayer.new()
	add_child(vfx)

	# Слой бегающего геометрического Лиса (поверх интерфейса, ниже пост-шейдера)
	var pet_layer := CanvasLayer.new()
	pet_layer.layer = 7
	add_child(pet_layer)

	fox_pet = FoxPetActor.new()
	fox_pet.anchor = sigil_btn
	pet_layer.add_child(fox_pet)

	var shader_layer := CanvasLayer.new()
	shader_layer.layer = 10
	add_child(shader_layer)

	var crt_rect := ColorRect.new()
	crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_mat = ShaderMaterial.new()
	crt_mat.shader = load("res://shaders/fox_crt.gdshader")
	crt_rect.material = crt_mat
	shader_layer.add_child(crt_rect)

func _build_modals() -> void:
	var modal_layer := CanvasLayer.new()
	modal_layer.layer = 20
	add_child(modal_layer)

	# 1. Окно Сделки с Дьяволом
	deal_modal = DEAL_MODAL_SCENE.instantiate() as DealModal
	modal_layer.add_child(deal_modal)
	deal_modal.accepted.connect(func(deal: Dictionary) -> void:
		GameState.apply_deal(deal)
	)
	deal_modal.rejected.connect(func(timed_out: bool) -> void:
		_type_voice("> Fox OS: Ты молчал. Я записал это как отказ." if timed_out else "> Fox OS: Отказ записан. Я запомню.")
	)

	# 2. Окно Casino.exe (с защитой от F5 и охотой на ухо Лиса)
	casino_modal = CASINO_MODAL_SCENE.instantiate() as CasinoModal
	modal_layer.add_child(casino_modal)
	casino_modal.spin_won.connect(func(win: int, busted: bool) -> void:
		var burst_text := ("ЛИС ПОЙМАН! +%d СПОР" % win) if busted else ("+%d СПОР" % win)
		vfx.spawn_purchase_burst(Vector2(800, 420), burst_text, busted)
	)
	casino_modal.closed.connect(Casino.clear_offer)
	if fox_pet:
		fox_pet.casino_requested.connect(_open_casino_from_offer)

	# 3. Окно выбора Мутаций мицелия (1 из 3)
	mutations_modal = MUTATIONS_MODAL_SCENE.instantiate() as MutationsModal
	modal_layer.add_child(mutations_modal)
	mutations_modal.mutation_picked.connect(func(_id: String, info: Dictionary) -> void:
		vfx.spawn_purchase_burst(Vector2(800, 450), "ШТАММ ВЖИВЛЁН: " + str(info.get("name", "")), true)
	)

	# 4. Виртуальная ФС /sys/146/NNN.log
	logs_overlay = ColorRect.new()
	logs_overlay.color = Color(0.0, 0.0, 0.0, 0.86)
	logs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	logs_overlay.visible = false
	modal_layer.add_child(logs_overlay)

	var log_cc := CenterContainer.new()
	log_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	logs_overlay.add_child(log_cc)

	var log_box := PanelContainer.new()
	log_box.custom_minimum_size = Vector2(720, 480)
	log_box.add_theme_stylebox_override("panel", FoxTheme.panel_style(Color("#00e5ff"), Color("#050103"), 2))
	log_cc.add_child(log_box)

	var log_vb := VBoxContainer.new()
	log_vb.add_theme_constant_override("separation", 8)
	log_box.add_child(log_vb)

	var log_hdr := HBoxContainer.new()
	log_vb.add_child(log_hdr)
	var log_t := Label.new()
	log_t.text = "ВИРТУАЛЬНАЯ ФАЙЛОВАЯ СИСТЕМА // /SYS/146/*.LOG"
	log_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_t.add_theme_color_override("font_color", Color("#00e5ff"))
	log_hdr.add_child(log_t)

	var log_close := Button.new()
	log_close.text = "ЗАКРЫТЬ [ESC]"
	_style_button(log_close)
	log_close.pressed.connect(func() -> void: logs_overlay.visible = false)
	log_hdr.add_child(log_close)

	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	FoxTheme.apply_scrollbar(log_scroll.get_v_scroll_bar())
	log_vb.add_child(log_scroll)

	logs_list_box = VBoxContainer.new()
	logs_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs_list_box.add_theme_constant_override("separation", 4)
	log_scroll.add_child(logs_list_box)

	logs_lore_lbl = Label.new()
	logs_lore_lbl.text = "Выбери расшифрованный лог из списка выше..."
	logs_lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	logs_lore_lbl.add_theme_color_override("font_color", Color("#ecd9dc"))
	log_vb.add_child(logs_lore_lbl)

	# 5. DEBUG-модалка (только в debug-сборке)
	if OS.is_debug_build():
		debug_modal = DEBUG_MODAL_SCENE.instantiate() as DebugModal
		debug_modal.modal_busy_probe = _is_modal_busy
		modal_layer.add_child(debug_modal)
		debug_modal.set_process(false)
		debug_modal.casino_requested.connect(func() -> void:
			casino_modal.open()
		)
		debug_modal.deal_requested.connect(_open_deal)
		debug_modal.glitch_spawn_requested.connect(func() -> void:
			vfx.spawn_glitch_artifact()
		)
		debug_modal.glitches_clear_requested.connect(func() -> void:
			vfx.clear_glitches()
		)

func _open_casino_from_offer() -> void:
	if not _is_modal_busy():
		if casino_modal.open():
			Casino.clear_offer()

func _on_casino_offer_changed(active: bool) -> void:
	if casino_btn:
		casino_btn.visible = active

func _open_logs_modal() -> void:
	for ch in logs_list_box.get_children():
		ch.queue_free()
	var items := Achievements.listing()
	for item: Dictionary in items:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "%s  —  %s" % [item["path"], item["title"]]
		_style_button(btn, bool(item["ok"]))
		btn.disabled = not bool(item["ok"])
		btn.pressed.connect(func() -> void:
			logs_lore_lbl.text = "[%s] %s" % [item["path"], item["lore"]]
		)
		logs_list_box.add_child(btn)
	logs_overlay.visible = true

func _open_deal(deal: Dictionary) -> void:
	if deal_modal.open(deal):
		flash_red_val = 0.75

func _on_shop_btn_hover(btn: Button) -> void:
	var is_eater := float(GameState.fx.get("eater", 0.0)) > 0.0
	var inf := Economy.inf_eff(GameState)
	if (not is_eater and inf < 60 and not Mutations.has_glitch("dodge_shop")) or btn.has_meta("dodging"):
		return
	var dist := 34.0 if is_eater else 22.0
	var dx := randf_range(-dist, dist)
	var dy := randf_range(-8.0, 8.0)
	btn.set_meta("dodging", true)
	var tw := create_tween()
	tw.tween_property(btn, "offset_left", dx, 0.12)
	tw.parallel().tween_property(btn, "offset_right", dx, 0.12)
	tw.parallel().tween_property(btn, "offset_top", dy, 0.12)
	tw.parallel().tween_property(btn, "offset_bottom", dy, 0.12)
	tw.tween_interval(0.55)
	tw.tween_property(btn, "offset_left", 0.0, 0.18)
	tw.parallel().tween_property(btn, "offset_right", 0.0, 0.18)
	tw.parallel().tween_property(btn, "offset_top", 0.0, 0.18)
	tw.parallel().tween_property(btn, "offset_bottom", 0.0, 0.18)
	tw.tween_callback(func() -> void: btn.remove_meta("dodging"))

func _tick_fake_button(delta: float, inf: int) -> void:
	if is_instance_valid(fake_row):
		fake_timer -= delta
		if fake_timer <= 0.0 or inf < 80:
			fake_row.queue_free()
			fake_row = null
			fake_timer = randf_range(12.0, 20.0)
		return
	if inf >= 80:
		fake_timer -= delta
		if fake_timer <= 0.0:
			fake_timer = 7.5
			var idx := randi() % GameData.BUILDINGS.size()
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(0, 38)
			var fbtn := Button.new()
			fbtn.set_anchors_preset(Control.PRESET_FULL_RECT)
			fbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			fbtn.text = "%s [ERROR 146]  [ВЗЛОМАТЬ]" % [GameData.BUILDINGS[idx]["name"]]
			_style_button(fbtn, true)
			fbtn.pressed.connect(func() -> void:
				GameState.fake_clicks += 1
				shake_time = 0.25
				var roll: float = randf()
				if roll < 0.40:
					Audio.play_sfx("success")
					flash_red_val = 0.4
					GameState.fx["buffer_overflow"] = 15.0
					_type_voice("> Fox OS: Переполнение буфера. Доход ускорен.")
					vfx.spawn_floating_text(get_global_mouse_position(), "БУФЕР ×7 (15с)!", Color("#39ff88"), 1.2)
				elif roll < 0.70:
					Audio.play_sfx("success")
					flash_red_val = 0.5
					GameState.spores += 3
					GameState.state_changed.emit()
					_type_voice("> Fox OS: Спортивный инъектор внедрен. (+3 споры)")
					vfx.spawn_floating_text(get_global_mouse_position(), "+3 СПОРЫ!", Color("#00e5ff"), 1.2)
				elif roll < 0.90:
					Audio.play_sfx("success")
					flash_red_val = 0.6
					GameState.earn(GameState.get_effective_cps().mul_float(30.0))
					_type_voice("> Fox OS: Аномальный сектор расшифрован. Пакет данных принят.")
					vfx.spawn_floating_text(get_global_mouse_position(), "ДАННЫЕ ЗАХВАЧЕНЫ!", Color("#d6ff3a"), 1.2)
				else:
					Audio.play_sfx("error")
					flash_red_val = 0.9
					var penalty: BigNum = GameState.coins.mul_float(0.05)
					GameState.coins = GameState.coins.sub(penalty)
					GameState.state_changed.emit()
					_type_voice("> Fox OS: Ошибка доступа. Пакет поврежден, ресурсы сброшены.")
					vfx.spawn_floating_text(get_global_mouse_position(), "СБОЙ СИСТЕМЫ!", Color("#ff1e38"), 1.3)
				if is_instance_valid(fake_row):
					fake_row.queue_free()
					fake_row = null
			)
			holder.add_child(fbtn)
			shop_list.add_child(holder)
			shop_list.move_child(holder, randi() % shop_list.get_child_count())
			fake_row = holder

func _refresh_ui() -> void:
	var ph: int = Economy.phase_of(GameState)
	var tier: int = Economy.tier_of(ph)
	var inf: int = Economy.inf_eff(GameState)
	var greed := float(GameState.fx.get("greed", 0.0)) > 0.0
	var bin_shop := Mutations.has_glitch("binary_shop")

	sigil_btn.tier = tier
	sigil_btn.infection_pct = inf
	sigil_lbl.text = SIGIL_TITLES[tier - 1]
	phase_lbl.text = "ФАЗА %d/%d: %s" % [ph, GameData.PHASES.size(), GameData.PHASES[ph - 1]["name"].to_upper()]
	ach_btn.text = "[ ДОСТИЖЕНИЯ: %d/%d ]" % [Achievements.unlocked.size(), Achievements.TOTAL]

	coins_lbl.text = "ERR_0x00" if greed else GameState.coins.format_ru()
	var total_cps: BigNum = GameState.get_effective_cps()
	cps_lbl.text = "%s / сек  (×%.2f)" % ["ERR_0x00" if greed else total_cps.format_ru(), Economy.global_mult(GameState)]

	var fx_parts: Array[String] = []
	if GameState.is_buff_active():
		fx_parts.append("[ПЕРЕПОЛНЕНИЕ БУФЕРА ×7]")
	if not Mutations.active.is_empty():
		fx_parts.append("[ШТАММОВ: %d/5]" % Mutations.active.size())
	for k: String in GameState.fx.keys():
		fx_parts.append("[%s: %dс]" % [k.to_upper(), int(ceil(float(GameState.fx[k])))])
	fx_lbl.text = "  |  ".join(fx_parts)

	if ph < GameData.PHASES.size():
		var next_edge: BigNum = BigNum.from_float(float(GameData.PHASES[ph]["edge"]))
		phase_bar.value = clampf(GameState.run_earned.div(next_edge).to_float(), 0.0, 1.0)
	else:
		phase_bar.value = 1.0

	for mode: String in amt_btns.keys():
		var ab: Button = amt_btns[mode]
		var is_sel := (mode == GameState.buy_amt)
		ab.add_theme_stylebox_override("normal", sb_btn_active if is_sel else sb_btn_normal)
		ab.add_theme_color_override("font_color", Color.BLACK if is_sel else Color("#ff1e38"))

	var gm: float = Economy.global_mult(GameState)
	for i: int in range(GameData.BUILDINGS.size()):
		var bdata: Dictionary = GameData.BUILDINGS[i]
		var n: int = GameState.amt_for(i)
		var cost: BigNum = Economy.b_cost_n(GameState, i, GameState.b[i], n)
		var unit_cps: BigNum = BigNum.from_float(float(bdata["cps"]) * Economy.b_mult(GameState, i) * gm)
		var row: Dictionary = shop_rows[i]
		var btn: Button = row["btn"]
		var meta: Label = row["meta"]
		btn.text = "%s   [×%d]" % [bdata["name"], GameState.b[i]]
		btn.disabled = not GameState.coins.gte(cost)
		var cost_str := "ERR_0x00" if greed else ("0x" + String.num_int64(int(cost.to_float()), 16) if (bin_shop and cost.exponent < 9) else cost.format_ru())
		meta.text = "Цена%s: %s · +%s/с" % [
			(" ×%d" % n if n > 1 else ""),
			cost_str,
			"ERR_0x00" if greed else unit_cps.format_ru()
		]

	var ups: Array[Dictionary] = GameState.get_available_upgrades()
	var lock_up := float(GameState.fx.get("voidLock", 0.0)) > 0.0
	var sig := ""
	for u: Dictionary in ups:
		sig += u["label"] + "|"
	if sig != last_up_sig:
		last_up_sig = sig
		for child in ups_box.get_children():
			child.queue_free()
		for u: Dictionary in ups:
			var ub := Button.new()
			ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ub.text = "%s — %s\n%s" % [u["label"], u["cost"].format_ru(), u["desc"]]
			_style_button(ub)
			ub.set_meta("cost", u["cost"])
			ub.pressed.connect(func() -> void:
				if GameState.buy_upgrade(u):
					vfx.spawn_purchase_burst(get_global_mouse_position(), "УЛУЧШЕНИЕ УСТАНОВЛЕНО!", true)
			)
			ups_box.add_child(ub)

	for ub: Button in ups_box.get_children():
		var c: BigNum = ub.get_meta("cost")
		ub.disabled = lock_up or not GameState.coins.gte(c)

	myc_lbl.text = "МИЦЕЛИЙ: %d%% (доход ×%.1f · штаммов %d/5)" % [inf, Economy.inf_mult(GameState), Mutations.active.size()]
	myc_bar.value = inf
	var next_myc: BigNum = Economy.myc_cost(GameState)
	spore_btn.text = "МАКС" if inf >= 100 else "Споры (%s)" % ("ERR_0x00" if greed else next_myc.format_ru())
	spore_btn.disabled = GameState.infection >= 100 or not GameState.coins.gte(next_myc)
	purify_btn.text = "БЛОК" if float(GameState.fx.get("purLock", 0.0)) > 0.0 else "Очистить (-50%)"
	purify_btn.disabled = GameState.infection <= 0 or float(GameState.fx.get("purLock", 0.0)) > 0.0

# ---------------------------------------------------------------- ПАУЗА / ВЫХОД В МЕНЮ

func _build_pause_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 22
	add_child(layer)

	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	layer.add_child(pause_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(cc)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(Color("#ff1e38"), Color("#080103"), 2))
	cc.add_child(panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(360.0, 0.0)
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var t := Label.new()
	t.text = "/SYS/PAUSE // ПАУЗА"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color("#ff1e38"))
	vb.add_child(t)

	var resume := Button.new()
	resume.text = "[ ПРОДОЛЖИТЬ ]"
	_style_button(resume, true)
	resume.pressed.connect(func() -> void: _set_paused(false))
	vb.add_child(resume)

	var to_menu := Button.new()
	to_menu.text = "[ В ГЛАВНОЕ МЕНЮ ]"
	_style_button(to_menu)
	to_menu.pressed.connect(_go_to_menu)
	vb.add_child(to_menu)

	var hint := Label.new()
	hint.text = "Прогресс сохраняется автоматически."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#926870"))
	vb.add_child(hint)

func _set_paused(on: bool) -> void:
	pause_overlay.visible = on
	tick_timer.paused = on
	if _typewriter_timer != null:
		_typewriter_timer.paused = on
	if on:
		GameState.save_game()

func _go_to_menu() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
