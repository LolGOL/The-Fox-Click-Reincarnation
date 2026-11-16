extends Control

const BG_COL := Color("#050000")
const RED := Color("#ff0033")
const RED_DIM := Color("#660014")
const RED_SOFT := Color("#ff5266")
const GREEN := Color("#00ff44")

const MAIN_SCENE := "res://scenes/main.tscn"
const CRT_SHADER := "res://shaders/fox_crt.gdshader"
const TITLE_TEXT := "THE FOX CLICK\nREINCARNATION"
const GLITCH_GLYPHS := "#%&@01▓░▒/\\"
const SEAL_SCALE := 1.35

@onready var visual: Control = %Visual
@onready var fox: MenuFox = %MenuFox
@onready var seal_holder: Control = %SealHolder
@onready var tag_lbl: Label = %TagLabel
@onready var title_lbl: Label = %TitleLabel
@onready var voice_lbl: Label = %VoiceLabel
@onready var version_lbl: Label = %VersionLabel
@onready var continue_btn: Button = %ContinueButton
@onready var new_btn: Button = %NewGameButton
@onready var ach_btn: Button = %AchievementsButton
@onready var settings_btn: Button = %SettingsButton
@onready var credits_btn: Button = %CreditsButton
@onready var quit_btn: Button = %QuitButton
@onready var shade: ColorRect = %Shade
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var archive_panel: PanelContainer = %ArchivePanel
@onready var archive_title: Label = %ArchiveTitle
@onready var archive_close_btn: Button = %CloseButton
@onready var archive_scroll: ScrollContainer = %ArchiveScroll
@onready var archive_list: VBoxContainer = %ArchiveList
@onready var lore_lbl: Label = %LoreLabel
@onready var confirm_panel: PanelContainer = %ConfirmPanel
@onready var confirm_lbl: Label = %ConfirmLabel
@onready var yes_btn: Button = %YesButton
@onready var no_btn: Button = %NoButton
@onready var info_panel: PanelContainer = %InfoPanel
@onready var info_lbl: Label = %InfoLabel
@onready var info_close_btn: Button = %InfoCloseButton
@onready var crt_overlay: ColorRect = %CrtOverlay
@onready var flash: ColorRect = %Flash
@onready var fade: ColorRect = %Fade

var _seal: CoreSigilButton
var _entering: bool = false
var _open_panel: Control = null
var _has_save: bool = false
var _crt_mat: ShaderMaterial

func _ready() -> void:
	_has_save = FileAccess.file_exists(GameData.SAVE_PATH)
	_apply_mono_theme()
	_style_texts()
	_style_menu_buttons()
	_style_panels()
	_build_seal()
	_setup_crt()

	flash.modulate.a = 0.0
	fade.modulate.a = 1.0
	for p: Control in [shade, settings_panel, archive_panel, confirm_panel, info_panel]:
		p.visible = false

	continue_btn.disabled = not _has_save
	continue_btn.pressed.connect(_enter_game)
	new_btn.pressed.connect(_on_new_game)
	ach_btn.pressed.connect(_open_archive)
	settings_btn.pressed.connect(func() -> void: _show_panel(settings_panel))
	credits_btn.pressed.connect(func() -> void: _show_panel(info_panel))
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	yes_btn.pressed.connect(func() -> void:
		_hide_panels()
		_wipe_progress()
		_enter_game()
	)
	no_btn.pressed.connect(_hide_panels)
	info_close_btn.pressed.connect(_hide_panels)
	archive_close_btn.pressed.connect(_hide_panels)
	settings_panel.closed.connect(_hide_panels)
	settings_panel.shake_preview.connect(_shake)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_hide_panels()
	)
	for b: Button in [continue_btn, new_btn, ach_btn, settings_btn, credits_btn, quit_btn, yes_btn, no_btn, archive_close_btn, info_close_btn]:
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				Audio.play_sfx("ui")
		)
	FoxSettings.reduce_noise_changed.connect(func(_on: bool) -> void: _apply_noise_mode())

	visual.resized.connect(_layout_visual)
	title_lbl.resized.connect(func() -> void: title_lbl.pivot_offset = title_lbl.size * 0.5)
	title_lbl.text = TITLE_TEXT
	_layout_visual()
	_apply_noise_mode()

	var intro := create_tween()
	intro.tween_property(fade, "modulate:a", 0.0, 0.7)
	intro.tween_callback(_type_voice_line)

	(continue_btn if _has_save else new_btn).grab_focus()
	_title_glitch_loop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _open_panel != null:
		_hide_panels()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- СТИЛИ

func _box(bg: Color, border: Color, bw: int, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.shadow_color = Color(1.0, 0.0, 0.2, 0.3)
	s.shadow_size = shadow
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func _apply_mono_theme() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"JetBrains Mono", "Consolas", "Cascadia Mono", "Courier New",
		"DejaVu Sans Mono", "Liberation Mono", "monospace"
	])
	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 14
	theme = th

func _style_texts() -> void:
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", RED)
	title_lbl.add_theme_color_override("font_shadow_color", Color(1.0, 0.0, 0.2, 0.35))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	tag_lbl.add_theme_font_size_override("font_size", 13)
	tag_lbl.add_theme_color_override("font_color", GREEN)
	voice_lbl.add_theme_font_size_override("font_size", 15)
	voice_lbl.add_theme_color_override("font_color", RED_SOFT)
	voice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	version_lbl.add_theme_font_size_override("font_size", 12)
	version_lbl.add_theme_color_override("font_color", RED_DIM)
	version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _style_menu_buttons() -> void:
	var normal := _box(Color("#12030a"), RED_DIM, 2)
	var hover := _box(RED, RED, 2, 14)
	var press := _box(RED_SOFT, RED_SOFT, 2, 6)
	var off := _box(Color("#0a0205"), Color("#2a0a10"), 2)
	for b: Button in [continue_btn, new_btn, ach_btn, settings_btn, credits_btn, quit_btn, yes_btn, no_btn, info_close_btn]:
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("focus", hover)
		b.add_theme_stylebox_override("pressed", press)
		b.add_theme_stylebox_override("disabled", off)
		b.add_theme_color_override("font_color", RED_SOFT)
		b.add_theme_color_override("font_hover_color", BG_COL)
		b.add_theme_color_override("font_focus_color", BG_COL)
		b.add_theme_color_override("font_pressed_color", BG_COL)
		b.add_theme_color_override("font_disabled_color", Color("#3a1018"))
		b.add_theme_font_size_override("font_size", 18)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for b: Button in [continue_btn, new_btn, ach_btn, settings_btn, credits_btn, quit_btn]:
		b.custom_minimum_size = Vector2(380.0, 50.0)
	# кнопка выхода — как в референсе, выделена красным
	quit_btn.add_theme_stylebox_override("normal", _box(Color("#2a050c"), RED, 2))

func _style_panels() -> void:
	for p: PanelContainer in [archive_panel, confirm_panel, info_panel]:
		p.add_theme_stylebox_override("panel", FoxTheme.panel_style(RED, Color("#080103"), 2))
	archive_title.add_theme_color_override("font_color", RED)
	archive_title.add_theme_font_size_override("font_size", 18)
	lore_lbl.add_theme_color_override("font_color", RED_SOFT)
	lore_lbl.custom_minimum_size = Vector2(0.0, 56.0)
	confirm_lbl.add_theme_color_override("font_color", RED_SOFT)
	confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_lbl.custom_minimum_size = Vector2(420.0, 0.0)
	info_lbl.add_theme_color_override("font_color", Color("#ecd9dc"))
	archive_close_btn.flat = true
	for st: String in ["normal", "hover", "pressed", "focus"]:
		archive_close_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	archive_close_btn.add_theme_color_override("font_color", RED_DIM)
	archive_close_btn.add_theme_color_override("font_hover_color", RED)
	FoxTheme.apply_scrollbar(archive_scroll.get_v_scroll_bar())

func _setup_crt() -> void:
	if not ResourceLoader.exists(CRT_SHADER):
		crt_overlay.visible = false
		return
	_crt_mat = ShaderMaterial.new()
	_crt_mat.shader = load(CRT_SHADER)
	crt_overlay.material = _crt_mat

func _apply_noise_mode() -> void:
	var calm: bool = FoxSettings.reduce_noise
	if _crt_mat:
		_crt_mat.set_shader_parameter("aberration", 0.0 if calm else 0.0015)
		_crt_mat.set_shader_parameter("scanline_alpha", 0.0 if calm else 0.16)
		_crt_mat.set_shader_parameter("tear_strength", 0.0)
	crt_overlay.visible = (_crt_mat != null) and not calm
	_restore_title()

# ---------------------------------------------------------------- ПРАВАЯ ЧАСТЬ: ПЕЧАТЬ + ЛИС

func _build_seal() -> void:
	_seal = CoreSigilButton.new()
	_seal.custom_minimum_size = Vector2(216.0, 216.0)
	_seal.size = Vector2(216.0, 216.0)
	_seal.tier = 2
	_seal.scale = Vector2(SEAL_SCALE, SEAL_SCALE)
	_seal.pivot_offset = _seal.size * 0.5
	seal_holder.add_child(_seal)
	_seal.clicked.connect(func(_gp: Vector2) -> void:
		_seal.trigger_hit_vfx(randf() < 0.12)
		fox.poke()
		Audio.play_sfx("click")
		if FoxSettings.button_bounce:
			var tw := create_tween()
			tw.tween_property(_seal, "scale", Vector2.ONE * SEAL_SCALE * 0.9, 0.05)
			tw.tween_property(_seal, "scale", Vector2.ONE * SEAL_SCALE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func _layout_visual() -> void:
	var s := visual.size
	seal_holder.position = s * Vector2(0.30, 0.55) - Vector2(108.0, 108.0)
	fox.position = s * Vector2(0.70, 0.52) - fox.custom_minimum_size * 0.5
	fox.size = fox.custom_minimum_size

# ---------------------------------------------------------------- НАЗВАНИЕ / ЛОГ ЛИСА

func _title_glitch_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(1.8, 4.5)).timeout
		if not is_inside_tree():
			return
		if FoxSettings.reduce_noise or _entering:
			continue
		var tw := create_tween()
		for _i in range(randi_range(2, 4)):
			tw.tween_callback(_scramble_title)
			tw.tween_interval(randf_range(0.03, 0.07))
		tw.tween_callback(_restore_title)

func _scramble_title() -> void:
	var chars: PackedStringArray = TITLE_TEXT.split("")
	for _n in range(randi_range(2, 4)):
		var i := randi() % chars.size()
		if chars[i] != " " and chars[i] != "\n":
			chars[i] = GLITCH_GLYPHS[randi() % GLITCH_GLYPHS.length()]
	title_lbl.text = "".join(chars)
	title_lbl.scale = Vector2(randf_range(0.97, 1.04), 1.0)
	title_lbl.modulate = Color(1.0, 0.45, 0.5, 1.0) if randf() < 0.5 else Color.WHITE

func _restore_title() -> void:
	title_lbl.text = TITLE_TEXT
	title_lbl.scale = Vector2.ONE
	title_lbl.modulate = Color.WHITE

func _fmt_time(sec: float) -> String:
	var s := int(sec)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]

func _record_text() -> String:
	var best: Dictionary = Ghost.best
	if best.is_empty():
		return "—"
	var top := 0
	for k: int in best.keys():
		top = maxi(top, k)
	return "%s (ф.%d)" % [_fmt_time(float(best[top])), top]

func _voice_text() -> String:
	if GameState.reinc > 0:
		return "> Fox OS: Снова ты? Рекорд фазы: %s" % _record_text()
	if _has_save:
		return "> Fox OS: Ты вернулся. Фаза %d. Я не скучал." % GameState.last_phase
	return "> Fox OS: Я ждал тебя. Нажми."

func _type_voice_line() -> void:
	voice_lbl.text = _voice_text()
	voice_lbl.visible_ratio = 0.0
	var dur := maxf(0.4, float(voice_lbl.text.length()) * 0.03)
	create_tween().tween_property(voice_lbl, "visible_ratio", 1.0, dur)

# ---------------------------------------------------------------- ОКНА

func _show_panel(p: Control) -> void:
	if _entering:
		return
	_hide_panels(true)
	_open_panel = p
	shade.visible = true
	p.visible = true
	shade.modulate.a = 0.0
	p.modulate.a = 0.0
	p.scale = Vector2(0.96, 0.96)
	p.pivot_offset = p.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.16)
	tw.tween_property(shade, "modulate:a", 1.0, 0.16)
	tw.tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_panels(instant: bool = false) -> void:
	if _open_panel == null:
		return
	var p := _open_panel
	_open_panel = null
	if instant:
		p.visible = false
		shade.visible = false
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 0.0, 0.1)
	tw.tween_property(shade, "modulate:a", 0.0, 0.1)
	tw.chain().tween_callback(func() -> void:
		if _open_panel != p:
			p.visible = false
		if _open_panel == null:
			shade.visible = false
	)

func _open_archive() -> void:
	_populate_archive()
	_show_panel(archive_panel)

func _populate_archive() -> void:
	for c: Node in archive_list.get_children():
		c.queue_free()
	var entries: Array[Dictionary] = Achievements.listing()
	var open_cnt := 0
	for e: Dictionary in entries:
		var ok: bool = e["ok"]
		if ok:
			open_cnt += 1
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		for st: String in ["normal", "pressed", "focus"]:
			row.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var hv := StyleBoxFlat.new()
		hv.bg_color = Color(1.0, 0.0, 0.2, 0.12)
		row.add_theme_stylebox_override("hover", hv)
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", RED if ok else RED_DIM)
		row.add_theme_color_override("font_hover_color", RED_SOFT if ok else RED_DIM)
		if ok:
			row.text = "[OK]     %s   %s" % [e["path"], e["title"]]
		else:
			row.text = "[LOCKED] /sys/146/%03d.log   ???" % int(e["id"])
		var lore: String = e["lore"]
		row.pressed.connect(func() -> void:
			lore_lbl.text = ("> " + lore) if ok else "> [ДОСТУП ЗАПРЕЩЁН]"
			Audio.play_sfx("ui")
		)
		archive_list.add_child(row)
	archive_title.text = "/SYS/146 // ДОСТИЖЕНИЯ  [%d / %d]" % [open_cnt, Achievements.TOTAL]
	lore_lbl.text = "> Выбери файл."

# ---------------------------------------------------------------- НОВАЯ ИГРА / ВХОД

func _on_new_game() -> void:
	if _has_save:
		confirm_lbl.text = "ПЕРЕЗАПИСАТЬ СОХРАНЕНИЕ?\nВесь прогресс забега будет удалён. Достижения и рекорды фаз останутся."
		_show_panel(confirm_panel)
		no_btn.grab_focus()
	else:
		_enter_game()

func _wipe_progress() -> void:
	if FileAccess.file_exists(GameData.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameData.SAVE_PATH))
	GameState.reset_run_data()
	GameState.life_earned = BigNum.zero()
	GameState.max_coins = BigNum.zero()
	GameState.spores = 3
	GameState.shards = 0
	GameState.free_shards = 0
	GameState.spent = 0
	GameState.tree = {}
	GameState.perks = {}
	GameState.reinc = 0
	GameState.run_sec = 0.0
	GameState.total_sec = 0.0
	GameState.phase_time = 0.0
	GameState.clicks = 0
	GameState.manual_clicks = 0
	GameState.fake_clicks = 0
	GameState.infection = 0
	GameState.infection_steps_done = 0
	GameState.last_phase = 1
	Mutations.purge()
	Casino.load_state({})
	_has_save = false

func _shake(mult: float) -> void:
	if FoxSettings.reduce_noise or mult <= 0.0:
		return
	var amp := 14.0 * mult
	var sh := create_tween()
	for _i in range(6):
		sh.tween_property(self, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp) * 0.6), 0.03)
	sh.tween_property(self, "position", Vector2.ZERO, 0.03)

func _enter_game() -> void:
	if _entering:
		return
	_entering = true
	_hide_panels(true)
	for b: Button in [continue_btn, new_btn, ach_btn, settings_btn, credits_btn, quit_btn]:
		b.disabled = true
	Audio.play_sfx("crit")
	Audio.play_sfx("click")
	var calm: bool = FoxSettings.reduce_noise
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.5 if calm else 1.0, 0.05)
	tw.tween_property(flash, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(fade, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(MAIN_SCENE))
	_shake(FoxSettings.screen_shake)
