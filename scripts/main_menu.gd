extends Control

const BG_COL := Color("#050000")
const RED := Color("#ff0033")
const RED_DIM := Color("#660014")
const RED_SOFT := Color("#ff5266")
const GREEN := Color("#00ff44")

const MAIN_SCENE := "res://scenes/main.tscn"
const CRT_SHADER := "res://shaders/fox_crt.gdshader"
const TITLE_TEXT := "THE FOX CLICK REINCARNATION"
const GLITCH_GLYPHS := "#%&@01▓░▒/\\"

@onready var title_lbl: Label = %TitleLabel
@onready var tag_lbl: Label = %TagLabel
@onready var start_btn: Button = %StartButton
@onready var voice_lbl: Label = %VoiceLabel
@onready var archive_btn: Button = %ArchiveButton
@onready var sound_btn: Button = %SoundButton
@onready var noise_btn: Button = %NoiseButton
@onready var quit_btn: Button = %QuitButton
@onready var crt_overlay: ColorRect = %CrtOverlay
@onready var flash: ColorRect = %Flash
@onready var fade: ColorRect = %Fade
@onready var archive_shade: ColorRect = %ArchiveShade
@onready var archive_panel: PanelContainer = %ArchivePanel
@onready var archive_title: Label = %ArchiveTitle
@onready var archive_close_btn: Button = %CloseButton
@onready var archive_scroll: ScrollContainer = %ArchiveScroll
@onready var archive_list: VBoxContainer = %ArchiveList
@onready var lore_lbl: Label = %LoreLabel

var _entering: bool = false
var _sb_normal: StyleBoxFlat
var _sb_hover: StyleBoxFlat
var _pulse_tw: Tween
var _crt_mat: ShaderMaterial

func _ready() -> void:
	_apply_mono_theme()
	_style_title()
	_style_start_button()
	_style_flat_button(archive_btn)
	_style_flat_button(sound_btn)
	_style_flat_button(noise_btn)
	_style_flat_button(quit_btn)
	_style_archive_panel()
	_setup_crt()

	flash.modulate.a = 0.0
	fade.modulate.a = 1.0
	archive_shade.visible = false
	archive_panel.visible = false

	start_btn.pressed.connect(_enter_game)
	start_btn.mouse_entered.connect(func() -> void: Audio.play_sfx("ui"))
	archive_btn.pressed.connect(_open_archive)
	sound_btn.pressed.connect(_toggle_sound)
	noise_btn.pressed.connect(_toggle_noise)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	archive_close_btn.pressed.connect(_close_archive)
	archive_shade.gui_input.connect(_on_shade_input)
	for b: Button in [archive_btn, sound_btn, noise_btn, quit_btn, archive_close_btn]:
		b.mouse_entered.connect(func() -> void: Audio.play_sfx("ui"))

	title_lbl.resized.connect(func() -> void: title_lbl.pivot_offset = title_lbl.size * 0.5)
	title_lbl.text = TITLE_TEXT

	_refresh_toggle_labels()
	_apply_noise_mode()

	var intro := create_tween()
	intro.tween_property(fade, "modulate:a", 0.0, 0.7)
	intro.tween_callback(_type_voice_line)

	start_btn.grab_focus()
	_title_glitch_loop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and archive_panel.visible:
		_close_archive()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- СТИЛИ

func _box(bg: Color, border: Color, border_w: int, shadow: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_corner_radius_all(0)
	s.shadow_color = Color(1.0, 0.0, 0.2, 0.35)
	s.shadow_size = shadow
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 18
	s.content_margin_bottom = 18
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

func _style_title() -> void:
	title_lbl.add_theme_font_size_override("font_size", 44)
	title_lbl.add_theme_color_override("font_color", RED)
	title_lbl.add_theme_color_override("font_shadow_color", Color(1.0, 0.0, 0.2, 0.35))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 0)
	tag_lbl.add_theme_font_size_override("font_size", 13)
	tag_lbl.add_theme_color_override("font_color", GREEN)
	voice_lbl.add_theme_font_size_override("font_size", 16)
	voice_lbl.add_theme_color_override("font_color", RED_SOFT)

func _style_start_button() -> void:
	_sb_normal = _box(BG_COL, RED_DIM, 2, 4)
	_sb_hover = _box(RED, RED, 2, 22)
	var sb_press := _box(RED_SOFT, RED_SOFT, 2, 8)
	start_btn.add_theme_stylebox_override("normal", _sb_normal)
	start_btn.add_theme_stylebox_override("hover", _sb_hover)
	start_btn.add_theme_stylebox_override("pressed", sb_press)
	start_btn.add_theme_stylebox_override("disabled", _sb_hover)
	start_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	start_btn.add_theme_color_override("font_color", RED)
	start_btn.add_theme_color_override("font_focus_color", RED)
	start_btn.add_theme_color_override("font_hover_color", BG_COL)
	start_btn.add_theme_color_override("font_pressed_color", BG_COL)
	start_btn.add_theme_color_override("font_disabled_color", BG_COL)
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.custom_minimum_size = Vector2(560.0, 100.0)
	start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _style_flat_button(btn: Button) -> void:
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", RED_DIM)
	btn.add_theme_color_override("font_hover_color", RED)
	btn.add_theme_color_override("font_pressed_color", RED_SOFT)
	btn.add_theme_font_size_override("font_size", 13)

func _style_archive_panel() -> void:
	archive_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(RED, BG_COL, 2))
	archive_title.add_theme_color_override("font_color", RED)
	archive_title.add_theme_font_size_override("font_size", 18)
	lore_lbl.add_theme_color_override("font_color", RED_SOFT)
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.custom_minimum_size = Vector2(0.0, 56.0)
	_style_flat_button(archive_close_btn)
	archive_close_btn.add_theme_font_size_override("font_size", 14)
	FoxTheme.apply_scrollbar(archive_scroll.get_v_scroll_bar())

func _setup_crt() -> void:
	if not ResourceLoader.exists(CRT_SHADER):
		crt_overlay.visible = false
		return
	_crt_mat = ShaderMaterial.new()
	_crt_mat.shader = load(CRT_SHADER)
	crt_overlay.material = _crt_mat

# ---------------------------------------------------------------- ШУМ / АНИМАЦИИ

func _apply_noise_mode() -> void:
	var calm: bool = FoxSettings.reduce_noise
	if _pulse_tw:
		_pulse_tw.kill()
		_pulse_tw = null
	if calm:
		_sb_normal.border_color = RED
		_sb_normal.shadow_size = 6
	else:
		_start_pulse()
	if _crt_mat:
		_crt_mat.set_shader_parameter("aberration", 0.0 if calm else 0.0015)
		_crt_mat.set_shader_parameter("scanline_alpha", 0.07 if calm else 0.16)
		_crt_mat.set_shader_parameter("tear_strength", 0.0)
	_restore_title()

func _start_pulse() -> void:
	_pulse_tw = create_tween()
	_pulse_tw.set_loops()
	_pulse_tw.tween_property(_sb_normal, "border_color", RED, 1.1).set_trans(Tween.TRANS_SINE)
	_pulse_tw.parallel().tween_property(_sb_normal, "shadow_size", 18, 1.1).set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_property(_sb_normal, "border_color", RED_DIM, 1.1).set_trans(Tween.TRANS_SINE)
	_pulse_tw.parallel().tween_property(_sb_normal, "shadow_size", 4, 1.1).set_trans(Tween.TRANS_SINE)

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
		if chars[i] != " ":
			chars[i] = GLITCH_GLYPHS[randi() % GLITCH_GLYPHS.length()]
	title_lbl.text = "".join(chars)
	title_lbl.scale = Vector2(randf_range(0.97, 1.04), 1.0)
	title_lbl.modulate = Color(1.0, 0.45, 0.5, 1.0) if randf() < 0.5 else Color.WHITE

func _restore_title() -> void:
	title_lbl.text = TITLE_TEXT
	title_lbl.scale = Vector2.ONE
	title_lbl.modulate = Color.WHITE

# ---------------------------------------------------------------- ЛОГ ЛИСА

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
	if GameState.manual_clicks > 0 or GameState.total_sec > 1.0:
		return "> Fox OS: Ты вернулся. Фаза %d. Я не скучал." % GameState.last_phase
	return "> Fox OS: Я ждал тебя. Нажми."

func _type_voice_line() -> void:
	voice_lbl.text = _voice_text()
	voice_lbl.visible_ratio = 0.0
	var dur := maxf(0.4, float(voice_lbl.text.length()) * 0.03)
	var tw := create_tween()
	tw.tween_property(voice_lbl, "visible_ratio", 1.0, dur)

# ---------------------------------------------------------------- ПЕРЕКЛЮЧАТЕЛИ

func _refresh_toggle_labels() -> void:
	sound_btn.text = "[ ЗВУК: ВКЛ ]" if Audio.sound_on else "[ ЗВУК: ВЫКЛ ]"
	noise_btn.text = "[ ШУМ СНИЖЕН ]" if FoxSettings.reduce_noise else "[ СНИЗИТЬ ШУМ ]"

func _toggle_sound() -> void:
	Audio.set_sound(not Audio.sound_on)
	_refresh_toggle_labels()
	Audio.play_sfx("ui")

func _toggle_noise() -> void:
	FoxSettings.set_reduce_noise(not FoxSettings.reduce_noise)
	_apply_noise_mode()
	_refresh_toggle_labels()
	Audio.play_sfx("ui")

# ---------------------------------------------------------------- АРХИВ /SYS/146

func _open_archive() -> void:
	_populate_archive()
	archive_shade.visible = true
	archive_panel.visible = true
	archive_panel.modulate.a = 0.0
	archive_shade.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(archive_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(archive_shade, "modulate:a", 1.0, 0.18)

func _close_archive() -> void:
	if not archive_panel.visible:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(archive_panel, "modulate:a", 0.0, 0.12)
	tw.tween_property(archive_shade, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func() -> void:
		archive_panel.visible = false
		archive_shade.visible = false
	)

func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_archive()

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
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1.0, 0.0, 0.2, 0.12)
		row.add_theme_stylebox_override("hover", hover)
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", RED if ok else RED_DIM)
		row.add_theme_color_override("font_hover_color", RED_SOFT if ok else RED_DIM)
		if ok:
			row.text = "[OK]     %s   %s" % [e["path"], e["title"]]
		else:
			row.text = "[LOCKED] /sys/146/%03d.log   ???" % int(e["id"])
		var lore: String = e["lore"]
		row.pressed.connect(func() -> void:
			lore_lbl.text = "> " + lore
			Audio.play_sfx("ui")
		)
		archive_list.add_child(row)
	archive_title.text = "/SYS/146 // АРХИВ  [%d / %d]" % [open_cnt, Achievements.TOTAL]
	lore_lbl.text = "> Выбери файл."

# ---------------------------------------------------------------- ВХОД В ИГРУ

func _enter_game() -> void:
	if _entering:
		return
	_entering = true
	start_btn.disabled = true
	if _pulse_tw:
		_pulse_tw.kill()
		_pulse_tw = null
	Audio.play_sfx("crit")
	Audio.play_sfx("click")

	var calm: bool = FoxSettings.reduce_noise
	var peak := 0.5 if calm else 1.0
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", peak, 0.05)
	tw.tween_property(flash, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(fade, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(MAIN_SCENE))

	if not calm:
		var sh := create_tween()
		for _i in range(6):
			sh.tween_property(self, "position", Vector2(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0)), 0.03)
		sh.tween_property(self, "position", Vector2.ZERO, 0.03)
