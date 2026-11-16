class_name CoreSigilButton
extends Control

signal clicked(global_pos: Vector2)

var tier: int = 1
var infection_pct: int = 0
var press_anim: float = 0.0
var is_pressed: bool = false
var time_acc: float = 0.0
var crit_glow: float = 0.0

var shockwaves: Array[Dictionary] = []
var click_sparks: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(216, 216)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

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

	for i in range(shockwaves.size() - 1, -1, -1):
		var sw: Dictionary = shockwaves[i]
		sw["r"] = lerpf(float(sw["r"]), float(sw["max_r"]), minf(1.0, delta * 9.0))
		sw["alpha"] = float(sw["alpha"]) - delta * 2.1
		if float(sw["alpha"]) <= 0.0:
			shockwaves.remove_at(i)

	for i in range(click_sparks.size() - 1, -1, -1):
		var sp: Dictionary = click_sparks[i]
		sp["pos"] = Vector2(sp["pos"]) + Vector2(sp["vel"]) * delta
		sp["vel"] = Vector2(sp["vel"]) * 0.92
		sp["life"] = float(sp["life"]) - delta
		if float(sp["life"]) <= 0.0:
			click_sparks.remove_at(i)

	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var bezel_r := 92.0
	var cap_r := 72.0

	# 1. Ударные волны позади кнопки
	for sw: Dictionary in shockwaves:
		var col: Color = sw["color"]
		col.a = clampf(float(sw["alpha"]), 0.0, 1.0)
		draw_arc(c, float(sw["r"]), 0.0, TAU, 48, col, float(sw["width"]), true)

	# 2. Основание-безель кнопки (меняется по тирам 1..4)
	draw_circle(c + Vector2(0, 11), bezel_r, Color(0.05, 0.01, 0.01, 0.95))
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

	# Вращающееся оккультное кольцо на 3-4 тирах
	if tier >= 3:
		var segs := 18
		for s in range(segs):
			var a0 := time_acc * 0.7 + float(s) * (TAU / float(segs))
			var a1 := a0 + (TAU / float(segs)) * 0.55
			draw_arc(c, bezel_r - 7.0, a0, a1, 6, Color("#ff8a98"), 1.8, true)

	# 3. Подвижная 3D-шляпка кнопки
	var cap_y := lerpf(-6.0, 4.0, press_anim)
	var cap_c := c + Vector2(0, cap_y)
	draw_circle(cap_c + Vector2(0, 8.0 * (1.0 - press_anim)), cap_r, Color("#4d050f"))

	var cap_col := Color("#b81126") if get_rect().has_point(get_local_mouse_position()) else Color("#9e0d20")
	if tier >= 4:
		cap_col = Color("#c8142c")
	cap_col = cap_col.lerp(Color.WHITE, crit_glow * 0.65)
	draw_circle(cap_c, cap_r, cap_col)
	draw_arc(cap_c, cap_r, 0.0, TAU, 64, Color.WHITE if (tier >= 4 or crit_glow > 0.2) else Color("#ff5268"), 3.0, true)

	# 4. Векторная печать Лиса внутри кнопки (#foxSigil)
	var sc := 0.92
	var p := func(x: float, y: float) -> Vector2:
		return cap_c + Vector2((x - 40.0) * sc, (y - 42.0) * sc)

	if tier >= 3:
		draw_polyline(PackedVector2Array([p.call(40, 75), p.call(11, 25), p.call(69, 25), p.call(40, 75)]), Color(1, 0.6, 0.65, 0.65), 1.4, true)
		draw_colored_polygon(PackedVector2Array([p.call(21, 25), p.call(9, 13), p.call(13, 5), p.call(25, 21)]), Color("#2b0309"))
		draw_polyline(PackedVector2Array([p.call(21, 25), p.call(9, 13), p.call(13, 5), p.call(25, 21)]), Color.WHITE, 1.8, true)
		draw_colored_polygon(PackedVector2Array([p.call(59, 25), p.call(71, 13), p.call(67, 5), p.call(55, 21)]), Color("#2b0309"))
		draw_polyline(PackedVector2Array([p.call(59, 25), p.call(71, 13), p.call(67, 5), p.call(55, 21)]), Color.WHITE, 1.8, true)

	if tier >= 4:
		draw_polyline(PackedVector2Array([p.call(40, 9), p.call(14, 57), p.call(66, 57), p.call(40, 9)]), Color(1, 1, 1, 0.75), 1.3, true)

	# Уши и пятиугольная морда
	var ear_l := PackedVector2Array([p.call(15, 16), p.call(31, 31), p.call(17, 43)])
	var ear_r := PackedVector2Array([p.call(65, 16), p.call(49, 31), p.call(63, 43)])
	var face := PackedVector2Array([p.call(17, 43), p.call(40, 68), p.call(63, 43), p.call(49, 31), p.call(31, 31)])

	draw_colored_polygon(ear_l, Color("#1a0205"))
	draw_polyline(ear_l + PackedVector2Array([ear_l[0]]), Color.WHITE, 2.0, true)
	draw_colored_polygon(ear_r, Color("#1a0205"))
	draw_polyline(ear_r + PackedVector2Array([ear_r[0]]), Color.WHITE, 2.0, true)
	draw_colored_polygon(face, Color("#120103"))
	draw_polyline(face + PackedVector2Array([face[0]]), Color.WHITE, 2.2, true)

	# Глаза и клыки по тирам
	if tier == 1:
		draw_circle(p.call(31, 44), 2.8, Color.WHITE)
		draw_circle(p.call(49, 44), 2.8, Color.WHITE)
	else:
		draw_colored_polygon(PackedVector2Array([p.call(23, 42), p.call(35, 45), p.call(27, 48)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([p.call(57, 42), p.call(45, 45), p.call(53, 48)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([p.call(32, 59), p.call(34.5, 66), p.call(37, 61)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([p.call(48, 59), p.call(45.5, 66), p.call(43, 61)]), Color.WHITE)

	# Третий глаз на Тире 4
	if tier >= 4:
		var eye3 := PackedVector2Array([p.call(40, 21), p.call(46, 27), p.call(40, 33), p.call(34, 27)])
		draw_colored_polygon(eye3, Color("#1a0004"))
		draw_polyline(eye3 + PackedVector2Array([eye3[0]]), Color.WHITE, 1.5, true)
		draw_circle(p.call(40, 27), 2.0, Color("#ff1e38"))

	# Носик
	draw_colored_polygon(PackedVector2Array([p.call(36, 54), p.call(44, 54), p.call(40, 59)]), Color.WHITE)

	# Нити мицелия на печати при заражении > 0
	if infection_pct > 0:
		var m_col := Color(1.0, 0.8, 0.84, clampf(float(infection_pct) / 100.0, 0.2, 0.95))
		draw_polyline(PackedVector2Array([p.call(17, 43), p.call(10, 35), p.call(12, 26)]), m_col, 1.6, true)
		draw_polyline(PackedVector2Array([p.call(63, 43), p.call(70, 35), p.call(68, 26)]), m_col, 1.6, true)
		draw_circle(p.call(12, 26), 2.2, Color.WHITE)
		draw_circle(p.call(68, 26), 2.2, Color.WHITE)

	# 5. Искры от клика
	for sp: Dictionary in click_sparks:
		var scol: Color = sp["color"]
		scol.a = clampf(float(sp["life"]) / float(sp["max_life"]), 0.0, 1.0)
		var sz := float(sp["size"])
		draw_rect(Rect2(Vector2(sp["pos"]) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), scol, true)
