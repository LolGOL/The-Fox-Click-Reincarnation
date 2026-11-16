class_name CoreSigilButton
extends Control

signal clicked(global_pos: Vector2)

const SIGIL_CENTER := Vector2(40.0, 42.0)
const SIGIL_SCALE := 0.92

var POLY_TRI_DOWN := PackedVector2Array([Vector2(40, 75), Vector2(11, 25), Vector2(69, 25)])
var POLY_TRI_UP := PackedVector2Array([Vector2(40, 9), Vector2(14, 57), Vector2(66, 57)])
var POLY_HORN_L := PackedVector2Array([Vector2(21, 25), Vector2(9, 13), Vector2(13, 5), Vector2(25, 21)])
var POLY_HORN_R := PackedVector2Array([Vector2(59, 25), Vector2(71, 13), Vector2(67, 5), Vector2(55, 21)])
var POLY_EAR_L := PackedVector2Array([Vector2(15, 16), Vector2(31, 31), Vector2(17, 43)])
var POLY_EAR_R := PackedVector2Array([Vector2(65, 16), Vector2(49, 31), Vector2(63, 43)])
var POLY_FACE := PackedVector2Array([Vector2(17, 43), Vector2(40, 68), Vector2(63, 43), Vector2(49, 31), Vector2(31, 31)])
var POLY_EYE_L := PackedVector2Array([Vector2(23, 42), Vector2(35, 45), Vector2(27, 48)])
var POLY_EYE_R := PackedVector2Array([Vector2(57, 42), Vector2(45, 45), Vector2(53, 48)])
var POLY_FANG_L := PackedVector2Array([Vector2(32, 59), Vector2(34.5, 66), Vector2(37, 61)])
var POLY_FANG_R := PackedVector2Array([Vector2(48, 59), Vector2(45.5, 66), Vector2(43, 61)])
var POLY_THIRD_EYE := PackedVector2Array([Vector2(40, 21), Vector2(46, 27), Vector2(40, 33), Vector2(34, 27)])
var POLY_NOSE := PackedVector2Array([Vector2(36, 54), Vector2(44, 54), Vector2(40, 59)])
var POLY_MYC_L := PackedVector2Array([Vector2(17, 43), Vector2(10, 35), Vector2(12, 26)])
var POLY_MYC_R := PackedVector2Array([Vector2(63, 43), Vector2(70, 35), Vector2(68, 26)])

var tier: int = 1
var infection_pct: int = 0
var press_anim: float = 0.0
var is_pressed: bool = false
var hovered: bool = false
var time_acc: float = 0.0
var crit_glow: float = 0.0

var shockwaves: Array[Dictionary] = []
var click_sparks: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(216, 216)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: hovered = true)
	mouse_exited.connect(func() -> void:
		hovered = false
		is_pressed = false
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_pressed = true
			clicked.emit(get_global_mouse_position())
		else:
			is_pressed = false

func trigger_hit_vfx(is_crit: bool) -> void:
	var c := size * 0.5
	shockwaves.append({
		"r": 74.0,
		"max_r": 148.0 if is_crit else 124.0,
		"alpha": 1.0,
		"color": Color("#d6ff3a") if is_crit else Color("#ff1e38"),
		"width": 4.0 if is_crit else 2.5
	})
	if is_crit:
		crit_glow = 1.0
	var count: int = 16 if is_crit else 7
	for _i in range(count):
		var ang := randf() * TAU
		var spd := randf_range(90.0, 260.0 if is_crit else 180.0)
		click_sparks.append({
			"pos": c + Vector2.from_angle(ang) * randf_range(40.0, 68.0),
			"vel": Vector2.from_angle(ang) * spd,
			"life": randf_range(0.25, 0.48),
			"max_life": 0.48,
			"size": randf_range(3.0, 6.0 if is_crit else 4.5),
			"color": Color("#d6ff3a") if is_crit else (Color.WHITE if randf() > 0.6 else Color("#ff1e38"))
		})

func _process(delta: float) -> void:
	time_acc += delta
	var target: float = 1.0 if is_pressed else 0.0
	press_anim = lerpf(press_anim, target, minf(1.0, delta * 28.0))
	crit_glow = maxf(0.0, crit_glow - delta * 3.5)

	var i := shockwaves.size() - 1
	while i >= 0:
		var sw: Dictionary = shockwaves[i]
		sw["r"] = lerpf(float(sw["r"]), float(sw["max_r"]), minf(1.0, delta * 9.0))
		sw["alpha"] = float(sw["alpha"]) - delta * 2.1
		if float(sw["alpha"]) <= 0.0:
			shockwaves[i] = shockwaves[shockwaves.size() - 1]
			shockwaves.pop_back()
		i -= 1

	i = click_sparks.size() - 1
	while i >= 0:
		var sp: Dictionary = click_sparks[i]
		sp["pos"] = Vector2(sp["pos"]) + Vector2(sp["vel"]) * delta
		sp["vel"] = Vector2(sp["vel"]) * 0.92
		sp["life"] = float(sp["life"]) - delta
		if float(sp["life"]) <= 0.0:
			click_sparks[i] = click_sparks[click_sparks.size() - 1]
			click_sparks.pop_back()
		i -= 1

	queue_redraw()

func _to_cap(pt: Vector2, cap_c: Vector2) -> Vector2:
	return cap_c + (pt - SIGIL_CENTER) * SIGIL_SCALE

func _poly_to_cap(pts: PackedVector2Array, cap_c: Vector2, close_loop: bool = false) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	out.resize(n + (1 if close_loop else 0))
	for idx in range(n):
		out[idx] = cap_c + (pts[idx] - SIGIL_CENTER) * SIGIL_SCALE
	if close_loop:
		out[n] = out[0]
	return out

func _draw() -> void:
	var c := size * 0.5
	var bezel_r := 92.0
	var cap_r := 72.0

	# 1. Ударные волны
	for sw: Dictionary in shockwaves:
		var col: Color = sw["color"]
		col.a = clampf(float(sw["alpha"]), 0.0, 1.0)
		draw_arc(c, float(sw["r"]), 0.0, TAU, 48, col, float(sw["width"]), true)

	# 2. Основание-безель кнопки (эволюция по тирам 1..4)
	draw_circle(c + Vector2(0.0, 11.0), bezel_r, Color(0.05, 0.01, 0.01, 0.95))
	var bezel_bg := Color("#240c09")
	var bezel_border := Color("#8c3b2b")
	if tier == 2:
		bezel_bg = Color("#24040a")
		bezel_border = Color("#ff1e38")
	elif tier == 3:
		bezel_bg = Color("#2e030b")
		bezel_border = Color("#ff5266")
	elif tier >= 4:
		bezel_bg = Color("#1a0105")
		bezel_border = Color.WHITE

	draw_circle(c, bezel_r, bezel_bg)
	draw_arc(c, bezel_r, 0.0, TAU, 64, bezel_border, 3.5, true)

	if tier >= 3:
		var segs := 18
		var step := TAU / float(segs)
		for s in range(segs):
			var a0 := time_acc * 0.7 + float(s) * step
			draw_arc(c, bezel_r - 7.0, a0, a0 + step * 0.55, 6, Color("#ff8a98"), 1.8, true)

	# 3. Подвижная 3D-шляпка
	var cap_y := lerpf(-6.0, 4.0, press_anim)
	var cap_c := c + Vector2(0.0, cap_y)
	draw_circle(cap_c + Vector2(0.0, 8.0 * (1.0 - press_anim)), cap_r, Color("#4d050f"))

	var cap_col := Color("#b81126") if hovered else Color("#9e0d20")
	if tier >= 4:
		cap_col = Color("#c8142c")
	cap_col = cap_col.lerp(Color.WHITE, crit_glow * 0.65)
	draw_circle(cap_c, cap_r, cap_col)
	draw_arc(cap_c, cap_r, 0.0, TAU, 64, Color.WHITE if (tier >= 4 or crit_glow > 0.2) else Color("#ff5268"), 3.0, true)

	# 4. Векторная печать Лиса
	if tier >= 3:
		draw_polyline(_poly_to_cap(POLY_TRI_DOWN, cap_c, true), Color(1.0, 0.6, 0.65, 0.65), 1.4, true)
		draw_colored_polygon(_poly_to_cap(POLY_HORN_L, cap_c), Color("#2b0309"))
		draw_polyline(_poly_to_cap(POLY_HORN_L, cap_c, true), Color.WHITE, 1.8, true)
		draw_colored_polygon(_poly_to_cap(POLY_HORN_R, cap_c), Color("#2b0309"))
		draw_polyline(_poly_to_cap(POLY_HORN_R, cap_c, true), Color.WHITE, 1.8, true)

	if tier >= 4:
		draw_polyline(_poly_to_cap(POLY_TRI_UP, cap_c, true), Color(1.0, 1.0, 1.0, 0.75), 1.3, true)

	draw_colored_polygon(_poly_to_cap(POLY_EAR_L, cap_c), Color("#1a0205"))
	draw_polyline(_poly_to_cap(POLY_EAR_L, cap_c, true), Color.WHITE, 2.0, true)
	draw_colored_polygon(_poly_to_cap(POLY_EAR_R, cap_c), Color("#1a0205"))
	draw_polyline(_poly_to_cap(POLY_EAR_R, cap_c, true), Color.WHITE, 2.0, true)
	draw_colored_polygon(_poly_to_cap(POLY_FACE, cap_c), Color("#120103"))
	draw_polyline(_poly_to_cap(POLY_FACE, cap_c, true), Color.WHITE, 2.2, true)

	if tier == 1:
		draw_circle(_to_cap(Vector2(31, 44), cap_c), 2.8, Color.WHITE)
		draw_circle(_to_cap(Vector2(49, 44), cap_c), 2.8, Color.WHITE)
	else:
		draw_colored_polygon(_poly_to_cap(POLY_EYE_L, cap_c), Color.WHITE)
		draw_colored_polygon(_poly_to_cap(POLY_EYE_R, cap_c), Color.WHITE)
		draw_colored_polygon(_poly_to_cap(POLY_FANG_L, cap_c), Color.WHITE)
		draw_colored_polygon(_poly_to_cap(POLY_FANG_R, cap_c), Color.WHITE)

	if tier >= 4:
		draw_colored_polygon(_poly_to_cap(POLY_THIRD_EYE, cap_c), Color("#1a0004"))
		draw_polyline(_poly_to_cap(POLY_THIRD_EYE, cap_c, true), Color.WHITE, 1.5, true)
		draw_circle(_to_cap(Vector2(40, 27), cap_c), 2.0, Color("#ff1e38"))

	draw_colored_polygon(_poly_to_cap(POLY_NOSE, cap_c), Color.WHITE)

	if infection_pct > 0:
		var m_col := Color(1.0, 0.8, 0.84, clampf(float(infection_pct) / 100.0, 0.2, 0.95))
		draw_polyline(_poly_to_cap(POLY_MYC_L, cap_c), m_col, 1.6, true)
		draw_polyline(_poly_to_cap(POLY_MYC_R, cap_c), m_col, 1.6, true)
		draw_circle(_to_cap(Vector2(12, 26), cap_c), 2.2, Color.WHITE)
		draw_circle(_to_cap(Vector2(68, 26), cap_c), 2.2, Color.WHITE)

	# 5. Искры
	for sp: Dictionary in click_sparks:
		var scol: Color = sp["color"]
		scol.a = clampf(float(sp["life"]) / float(sp["max_life"]), 0.0, 1.0)
		var sz := float(sp["size"])
		draw_rect(Rect2(Vector2(sp["pos"]) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), scol, true)
