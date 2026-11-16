extends Control

const NEXT_SCENE := "res://scenes/main_menu.tscn"
const HOLD_TIME := 0.8
const AUTO_TIME := 4.0

const RED := Color("#ff1e38")
const RED_DEEP := Color("#c0392b")
const DIM := Color("#7a5a60")

@onready var logo_stage: Control = %LogoStage
@onready var logo_canvas: Control = %LogoCanvas
@onready var studio_lbl: Label = %StudioLabel
@onready var warn_stage: Control = %WarnStage
@onready var icon_canvas: Control = %IconCanvas
@onready var controls_txt: Label = %ControlsText
@onready var esc_txt: Label = %EscText
@onready var warn_title: Label = %WarnTitle
@onready var warn_body: Label = %WarnBody
@onready var skip_hint: Label = %SkipHint
@onready var hold_bar: ProgressBar = %HoldBar
@onready var fade: ColorRect = %Fade

var _stage: int = 0
var _holding: bool = false
var _hold: float = 0.0
var _warn_time: float = 0.0
var _glitch_off: Vector2 = Vector2.ZERO
var _glitch_left: float = 0.0
var _glitch_cd: float = 0.9
var _leaving: bool = false
var _spiral: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["JetBrains Mono", "Consolas", "Cascadia Mono", "Courier New", "DejaVu Sans Mono", "monospace"])
	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 16
	theme = th

	for i in range(97):
		var t := float(i) / 96.0
		_spiral.append(Vector2.from_angle(t * TAU * 3.2 - PI * 0.5) * (0.1 + 0.9 * t))

	studio_lbl.add_theme_font_size_override("font_size", 28)
	studio_lbl.add_theme_color_override("font_color", Color.WHITE)
	controls_txt.add_theme_color_override("font_color", Color("#ecd9dc"))
	esc_txt.add_theme_color_override("font_color", Color("#ecd9dc"))
	for l: Label in [controls_txt, esc_txt, warn_body]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_title.add_theme_font_size_override("font_size", 38)
	warn_title.add_theme_color_override("font_color", RED)
	warn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_body.add_theme_font_size_override("font_size", 19)
	skip_hint.add_theme_color_override("font_color", DIM)
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var fill := StyleBoxFlat.new()
	fill.bg_color = RED
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#1a0205")
	hold_bar.add_theme_stylebox_override("fill", fill)
	hold_bar.add_theme_stylebox_override("background", back)
	hold_bar.show_percentage = false
	hold_bar.max_value = 1.0
	hold_bar.value = 0.0

	resized.connect(_layout)
	logo_canvas.draw.connect(_draw_logo)
	icon_canvas.draw.connect(_draw_icons)
	_layout()

	logo_stage.modulate.a = 0.0
	warn_stage.modulate.a = 0.0
	warn_stage.visible = false
	fade.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(logo_stage, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.0)
	tw.tween_property(logo_stage, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_start_warning)

func _layout() -> void:
	var w := size.x
	var h := size.y
	studio_lbl.position = Vector2(0.0, h * 0.5 + 150.0)
	studio_lbl.size = Vector2(w, 40.0)
	studio_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_txt.position = Vector2(60.0, 290.0)
	controls_txt.size = Vector2(430.0, 90.0)
	esc_txt.position = Vector2(w - 490.0, 290.0)
	esc_txt.size = Vector2(430.0, 90.0)
	warn_title.position = Vector2(0.0, h * 0.55)
	warn_title.size = Vector2(w, 50.0)
	warn_body.position = Vector2(w * 0.1, h * 0.55 + 70.0)
	warn_body.size = Vector2(w * 0.8, 90.0)
	skip_hint.position = Vector2(0.0, h - 110.0)
	skip_hint.size = Vector2(w, 30.0)
	hold_bar.position = Vector2(w * 0.5 - 150.0, h - 70.0)
	hold_bar.size = Vector2(300.0, 8.0)
	logo_canvas.queue_redraw()
	icon_canvas.queue_redraw()

# ---------------------------------------------------------------- ЛОГО

func _draw_logo() -> void:
	var c := logo_canvas.size * 0.5 + Vector2(0.0, -30.0)
	if _glitch_left > 0.0:
		_logo_pass(c + _glitch_off, RED, true)
		_logo_pass(c - _glitch_off * 0.6, Color(0.2, 1.0, 0.9, 0.6), true)
	_logo_pass(c, Color.WHITE, false)

func _logo_pass(c: Vector2, tint: Color, flat: bool) -> void:
	var R := 110.0
	logo_canvas.draw_circle(c, R * 1.55, Color(1.0, 0.0, 0.15, 0.07))
	var pts := PackedVector2Array()
	for p: Vector2 in _spiral:
		pts.append(c + p * R)
	var ear_fill := tint if flat else RED_DEEP
	var line_col := tint if flat else Color.WHITE
	var back_col := tint if flat else Color.BLACK
	# уши (печать-лиса)
	for sgn: float in [-1.0, 1.0]:
		var tri := PackedVector2Array([
			c + Vector2(sgn * R * 0.95, -R * 0.30),
			c + Vector2(sgn * R * 0.72, -R * 1.30),
			c + Vector2(sgn * R * 0.12, -R * 0.85)
		])
		logo_canvas.draw_colored_polygon(tri, ear_fill)
		logo_canvas.draw_polyline(tri + PackedVector2Array([tri[0]]), line_col, 6.0, true)
	# спираль
	logo_canvas.draw_polyline(pts, back_col, 24.0, true)
	logo_canvas.draw_polyline(pts, line_col, 13.0, true)
	# глаз-зрачок в центре
	logo_canvas.draw_circle(c, 7.0, ear_fill)

func _process(delta: float) -> void:
	if _stage == 0 and not FoxSettings.reduce_noise:
		_glitch_cd -= delta
		if _glitch_cd <= 0.0:
			_glitch_cd = randf_range(0.5, 1.1)
			_glitch_left = 0.09
			_glitch_off = Vector2(randf_range(-14.0, 14.0), randf_range(-4.0, 4.0))
			logo_canvas.queue_redraw()
		elif _glitch_left > 0.0:
			_glitch_left -= delta
			if _glitch_left <= 0.0:
				logo_canvas.queue_redraw()
	elif _stage == 1 and not _leaving:
		_warn_time += delta
		if _holding:
			_hold += delta
		else:
			_hold = maxf(0.0, _hold - delta * 2.0)
		hold_bar.value = _hold / HOLD_TIME
		if _hold >= HOLD_TIME or _warn_time >= AUTO_TIME:
			_leave()

# ---------------------------------------------------------------- ПРЕДУПРЕЖДЕНИЕ

func _start_warning() -> void:
	_stage = 1
	logo_stage.visible = false
	warn_stage.visible = true
	create_tween().tween_property(warn_stage, "modulate:a", 1.0, 0.5)

func _sb(col: Color, r: Array = [8, 8, 8, 8]) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left = r[0]
	s.corner_radius_top_right = r[1]
	s.corner_radius_bottom_right = r[2]
	s.corner_radius_bottom_left = r[3]
	return s

func _mouse_icon(pos: Vector2, left: bool) -> void:
	var sz := Vector2(60.0, 86.0)
	icon_canvas.draw_style_box(_sb(Color("#e8e0e0"), [30, 30, 30, 30]), Rect2(pos, sz))
	var hl := Rect2(pos + (Vector2.ZERO if left else Vector2(sz.x * 0.5, 0.0)), Vector2(sz.x * 0.5, 38.0))
	var rr: Array = [30, 0, 0, 0] if left else [0, 30, 0, 0]
	icon_canvas.draw_style_box(_sb(RED, rr), hl)
	icon_canvas.draw_line(pos + Vector2(0.0, 38.0), pos + Vector2(sz.x, 38.0), Color.BLACK, 2.0)
	icon_canvas.draw_line(pos + Vector2(sz.x * 0.5, 0.0), pos + Vector2(sz.x * 0.5, 38.0), Color.BLACK, 2.0)

func _key_icon(rect: Rect2, label: String, fsize: int) -> void:
	icon_canvas.draw_style_box(_sb(Color("#6a5a5e"), [6, 6, 6, 6]), Rect2(rect.position + Vector2(0.0, 6.0), rect.size))
	icon_canvas.draw_style_box(_sb(Color("#e8e0e0"), [6, 6, 6, 6]), rect)
	var font := icon_canvas.get_theme_default_font()
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	icon_canvas.draw_string(font, rect.position + Vector2((rect.size.x - ts.x) * 0.5, (rect.size.y + ts.y * 0.6) * 0.5),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.BLACK)

func _draw_icons() -> void:
	_mouse_icon(Vector2(150.0, 70.0), true)
	_mouse_icon(Vector2(250.0, 70.0), false)
	_key_icon(Rect2(105.0, 175.0, 290.0, 52.0), "Пробел", 20)
	var w := icon_canvas.size.x
	_key_icon(Rect2(w - 275.0, 130.0, 80.0, 52.0), "Esc", 20)

# ---------------------------------------------------------------- ВВОД / ВЫХОД

func _input(event: InputEvent) -> void:
	if _stage != 1:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			_holding = true
		elif event.is_released():
			_holding = false

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.4)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(NEXT_SCENE))
