class_name VfxLayer
extends CanvasLayer

var canvas: Control
var particles: Array[Dictionary] = []
var ring_bursts: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var active_glitches: Array[Dictionary] = []
var bg_bits: Array[Dictionary] = []
var glitch_style: StyleBoxFlat
var time_acc: float = 0.0

func _ready() -> void:
	layer = 5
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_on_canvas_draw)
	add_child(canvas)

	glitch_style = StyleBoxFlat.new()
	glitch_style.bg_color = Color("#2a0004")
	glitch_style.border_color = Color("#ff1e38")
	glitch_style.set_border_width_all(3)

	for _i in range(48):
		bg_bits.append({
			"nx": randf(),
			"ny": randf(),
			"vy": randf_range(0.025, 0.075),
			"size": randf_range(2.0, 4.0)
		})

func spawn_floating_text(pos: Vector2, txt: String, color: Color = Color("#ff1e38"), scale_mult: float = 1.0) -> void:
	floating_texts.append({
		"pos": pos + Vector2(randf_range(-16.0, 16.0), -10.0),
		"vel": Vector2(randf_range(-12.0, 12.0), -72.0),
		"text": txt,
		"color": color,
		"life": 0.9,
		"max_life": 0.9,
		"scale": scale_mult
	})

func spawn_purchase_burst(pos: Vector2, label_txt: String, is_major: bool = false) -> void:
	var col := Color("#d6ff3a") if is_major else Color("#39ff88")
	ring_bursts.append({
		"pos": pos,
		"size": Vector2(24.0, 16.0),
		"target": Vector2(180.0, 56.0) if is_major else Vector2(120.0, 42.0),
		"alpha": 0.95,
		"color": col
	})
	for _i in range(18 if is_major else 10):
		var ang := randf() * TAU
		var spd := randf_range(70.0, 220.0)
		particles.append({
			"pos": pos,
			"vel": Vector2.from_angle(ang) * spd,
			"life": randf_range(0.35, 0.65),
			"max_life": 0.65,
			"size": randf_range(3.0, 6.0),
			"color": col if randf() > 0.35 else Color.WHITE
		})
	spawn_floating_text(pos + Vector2(0.0, -14.0), label_txt, col, 1.05 if is_major else 0.95)

func spawn_glitch_artifact(life_sec: float = 8.0) -> void:
	var vp := canvas.get_viewport_rect().size
	var btn := Button.new()
	btn.text = "ERROR\n146"
	btn.custom_minimum_size = Vector2(74, 74)
	btn.position = Vector2(
		randf_range(90.0, maxf(160.0, vp.x - 160.0)),
		randf_range(100.0, maxf(180.0, vp.y - 140.0))
	)
	btn.add_theme_stylebox_override("normal", glitch_style)
	btn.add_theme_stylebox_override("hover", glitch_style)
	btn.add_theme_color_override("font_color", Color("#ff1e38"))
	btn.add_theme_font_size_override("font_size", 15)
	add_child(btn)

	var entry := { "btn": btn, "life": life_sec, "base_pos": btn.position }
	active_glitches.append(entry)

	btn.pressed.connect(func() -> void:
		if entry in active_glitches:
			active_glitches.erase(entry)
			var gpos := btn.position + btn.size * 0.5
			btn.queue_free()
			var bonus: BigNum = GameState.catch_glitch()
			spawn_purchase_burst(gpos, "БУФЕР ×7! +%s" % bonus.format_ru(), true)
	)

func clear_glitches() -> void:
	for g: Dictionary in active_glitches:
		if is_instance_valid(g["btn"]):
			g["btn"].queue_free()
	active_glitches.clear()

func _process(delta: float) -> void:
	time_acc += delta

	for b: Dictionary in bg_bits:
		b["ny"] = fmod(float(b["ny"]) + float(b["vy"]) * delta, 1.0)

	var i := particles.size() - 1
	while i >= 0:
		var p: Dictionary = particles[i]
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
		p["vel"] = Vector2(p["vel"]) * 0.91
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			particles[i] = particles[particles.size() - 1]
			particles.pop_back()
		i -= 1

	i = ring_bursts.size() - 1
	while i >= 0:
		var rb: Dictionary = ring_bursts[i]
		rb["size"] = Vector2(rb["size"]).lerp(Vector2(rb["target"]), minf(1.0, delta * 9.0))
		rb["alpha"] = float(rb["alpha"]) - delta * 2.2
		if float(rb["alpha"]) <= 0.0:
			ring_bursts[i] = ring_bursts[ring_bursts.size() - 1]
			ring_bursts.pop_back()
		i -= 1

	i = floating_texts.size() - 1
	while i >= 0:
		var ft: Dictionary = floating_texts[i]
		ft["pos"] = Vector2(ft["pos"]) + Vector2(ft["vel"]) * delta
		ft["life"] = float(ft["life"]) - delta
		if float(ft["life"]) <= 0.0:
			floating_texts[i] = floating_texts[floating_texts.size() - 1]
			floating_texts.pop_back()
		i -= 1

	i = active_glitches.size() - 1
	while i >= 0:
		var g: Dictionary = active_glitches[i]
		g["life"] = float(g["life"]) - delta
		var btn: Button = g["btn"]
		if is_instance_valid(btn):
			btn.position = Vector2(g["base_pos"]) + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
			btn.modulate.a = clampf(float(g["life"]) / 1.5, 0.35, 1.0)
		if float(g["life"]) <= 0.0:
			active_glitches.remove_at(i)
			if is_instance_valid(btn):
				btn.queue_free()
			GameState.miss_glitch()
		i -= 1

	canvas.queue_redraw()

func _on_canvas_draw() -> void:
	var vp := canvas.get_viewport_rect().size
	var ph: int = Economy.phase_of(GameState)
	var tier: int = Economy.tier_of(ph)
	var inf: float = float(Economy.inf_eff(GameState)) / 100.0

	# 1. Динамический фон по тирам 1..4
	if tier == 1:
		for b: Dictionary in bg_bits:
			var sz := float(b["size"])
			canvas.draw_rect(Rect2(float(b["nx"]) * vp.x, float(b["ny"]) * vp.y, sz, sz), Color(0.85, 0.25, 0.2, 0.22), true)
	elif tier == 2:
		for k in range(12):
			var p1 := Vector2(vp.x * (0.1 + float(k % 4) * 0.26) + sin(time_acc + k) * 28.0, vp.y * (0.18 + float(k / 4) * 0.32))
			canvas.draw_rect(Rect2(p1 - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(1.0, 0.12, 0.22, 0.3), true)
			if k < 11:
				var p2 := Vector2(vp.x * (0.1 + float((k + 1) % 4) * 0.26), vp.y * (0.18 + float((k + 1) / 4) * 0.32))
				canvas.draw_line(p1, p2, Color(1.0, 0.12, 0.22, 0.12), 1.2)
	elif tier == 3:
		var center := vp * 0.5
		var r := minf(vp.x, vp.y) * 0.42
		canvas.draw_arc(center, r, 0.0, TAU, 64, Color(1.0, 0.12, 0.22, 0.14), 2.0, true)
		var tri := PackedVector2Array()
		tri.resize(4)
		for k in range(3):
			var a := time_acc * 0.15 + PI * 0.5 + float(k) * (TAU / 3.0)
			tri[k] = center + Vector2.from_angle(a) * r
		tri[3] = tri[0]
		canvas.draw_polyline(tri, Color(1.0, 0.12, 0.22, 0.14), 1.8, true)
	else:
		var center := vp * 0.5
		for r_idx in range(4):
			var rad := fmod(time_acc * 45.0 + float(r_idx) * 110.0, 440.0) + 40.0
			var a := clampf(0.24 * (1.0 - rad / 480.0), 0.0, 0.24)
			canvas.draw_arc(center, rad, 0.0, TAU, 64, Color(1.0, 0.12, 0.22, a), 2.0, true)

	# 2. Нити мицелия от краёв экрана
	if inf > 0.0:
		var vines := int(ceil(inf * 14.0))
		var vine_col := Color(1.0, 0.12, 0.22, 0.14 + inf * 0.25)
		var pts := PackedVector2Array()
		pts.resize(7)
		for v in range(vines):
			var from_left := (v % 2 == 0)
			var cx := 0.0 if from_left else vp.x
			var cy := fmod(float(v * 97), maxf(1.0, vp.y))
			pts[0] = Vector2(cx, cy)
			for s in range(6):
				cx += (1.0 if from_left else -1.0) * (24.0 + sin(time_acc + v + s) * 9.0)
				cy += cos(time_acc * 0.8 + v * 1.5 + s) * 18.0
				pts[s + 1] = Vector2(cx, cy)
			canvas.draw_polyline(pts, vine_col, 1.6, true)

	# 3. Импульсы покупок
	for rb: Dictionary in ring_bursts:
		var col: Color = rb["color"]
		col.a = clampf(float(rb["alpha"]), 0.0, 1.0)
		var sz: Vector2 = rb["size"]
		canvas.draw_rect(Rect2(Vector2(rb["pos"]) - sz * 0.5, sz), col, false, 2.2)

	# 4. Частицы
	for p: Dictionary in particles:
		var col: Color = p["color"]
		col.a = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var sz := float(p["size"])
		canvas.draw_rect(Rect2(Vector2(p["pos"]) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col, true)

	# 5. Всплывающий текст
	var font := ThemeDB.fallback_font
	for ft: Dictionary in floating_texts:
		var col: Color = ft["color"]
		col.a = clampf(float(ft["life"]) / float(ft["max_life"]), 0.0, 1.0)
		var fsize := int(17.0 * float(ft["scale"]))
		var pos: Vector2 = ft["pos"]
		canvas.draw_string(font, pos + Vector2(1.5, 1.5), str(ft["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, Color(0.0, 0.0, 0.0, col.a))
		canvas.draw_string(font, pos, str(ft["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, col)
