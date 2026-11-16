class_name FoxPetActor
extends Control

var pos_x: float = 420.0
var target_x: float = 760.0
var dir: int = 1
var walking: bool = true
var walk_phase: float = 0.0
var pause_timer: float = 0.0
var ear_twitch_timer: float = 0.0

var bubble: PanelContainer
var bubble_lbl: Label

func _ready() -> void:
	custom_minimum_size = Vector2(130, 140)
	size = Vector2(130, 140)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", FoxTheme.panel_style(Color("#c0392b"), Color(0.04, 0.005, 0.012, 0.95), 2))
	bubble.custom_minimum_size = Vector2(260, 0)
	bubble.position = Vector2(-65, -78)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)

	bubble_lbl = Label.new()
	bubble_lbl.text = "Жми на красную печать в центре! Нам нужна энергия!"
	bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_lbl.add_theme_color_override("font_color", Color("#ecd9dc"))
	bubble_lbl.add_theme_font_size_override("font_size", 12)
	bubble.add_child(bubble_lbl)

	Fox.say.connect(func(txt: String) -> void:
		bubble_lbl.text = txt
	)
	Casino.ear_twitch.connect(func() -> void:
		ear_twitch_timer = 0.45
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Проверяем клик в область ушей/головы (верхняя половина спрайта)
		if event.position.y <= 78.0 and Casino.on_fox_ear_clicked():
			return
		Fox.on_poke()

func _process(delta: float) -> void:
	bubble.visible = not Fox.muted
	if ear_twitch_timer > 0.0:
		ear_twitch_timer -= delta

	var vp_w := get_viewport_rect().size.x
	var min_x := 80.0
	var max_x := maxf(240.0, vp_w - 210.0)

	if Fox.state == Fox.S.SLEEPING:
		walking = false
	elif pause_timer > 0.0:
		walking = false
		pause_timer -= delta
		if pause_timer <= 0.0:
			target_x = randf_range(min_x, max_x)
	else:
		var diff := target_x - pos_x
		if absf(diff) > 5.0:
			walking = true
			dir = 1 if diff > 0.0 else -1
			pos_x += float(dir) * 85.0 * delta
		else:
			walking = false
			pause_timer = randf_range(1.6, 3.4)

	pos_x = clampf(pos_x, min_x, max_x)
	position = Vector2(pos_x, get_viewport_rect().size.y - 142.0)

	if walking:
		walk_phase += delta * 11.0
	else:
		walk_phase += delta * 2.5

	# Не даём облачку диалога вылезать за края окна
	var shift := 0.0
	if pos_x - 65.0 < 12.0:
		shift = 12.0 - (pos_x - 65.0)
	elif pos_x + 195.0 > vp_w - 12.0:
		shift = (vp_w - 12.0) - (pos_x + 195.0)
	bubble.position.x = -65.0 + shift

	queue_redraw()

func _xf(pt: Vector2, bob_y: float) -> Vector2:
	var cx := 65.0
	var rx := cx + (pt.x - cx) * float(dir)
	return Vector2(rx, pt.y + bob_y)

func _xpoly(pts: PackedVector2Array, bob_y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in range(pts.size()):
		out[i] = _xf(pts[i], bob_y)
	return out

func _draw() -> void:
	var tier := Economy.tier_of(Economy.phase_of(GameState))
	var sleeping := (Fox.state == Fox.S.SLEEPING)
	var bob_y := 8.0 if sleeping else (-absf(sin(walk_phase)) * (4.5 if walking else 1.5))

	# Тень на полу
	draw_circle(Vector2(65.0, 126.0), 22.0, Color(0, 0, 0, 0.7))

	# Хвост (на старших тирах добавляются дополнительные хвосты)
	var tail_sway := sin(walk_phase * 0.7) * 5.0
	var tail := _xpoly(PackedVector2Array([
		Vector2(48, 92), Vector2(18, 76 + tail_sway), Vector2(22, 52 + tail_sway), Vector2(46, 80)
	]), bob_y)
	draw_colored_polygon(tail, Color("#1e0408"))
	draw_polyline(tail + PackedVector2Array([tail[0]]), Color("#ff1e38"), 2.0, true)

	if tier >= 3:
		var tail2 := _xpoly(PackedVector2Array([
			Vector2(48, 86), Vector2(24, 48 - tail_sway), Vector2(36, 30 - tail_sway), Vector2(50, 74)
		]), bob_y)
		draw_colored_polygon(tail2, Color("#160205"))
		draw_polyline(tail2 + PackedVector2Array([tail2[0]]), Color("#c0392b"), 1.6, true)

	# Лапки
	var leg_off := sin(walk_phase) * (5.0 if walking else 0.0)
	draw_rect(Rect2(_xf(Vector2(50 + leg_off, 96), bob_y), Vector2(7, 24)), Color("#160205"), true)
	draw_rect(Rect2(_xf(Vector2(68 - leg_off, 96), bob_y), Vector2(7, 24)), Color("#240408"), true)

	# Туловище-накидка
	var body := _xpoly(PackedVector2Array([
		Vector2(48, 68), Vector2(82, 68), Vector2(87, 98), Vector2(43, 98)
	]), bob_y)
	draw_colored_polygon(body, Color("#180306"))
	draw_polyline(body + PackedVector2Array([body[0]]), Color("#ff1e38") if tier >= 2 else Color("#c0392b"), 2.0, true)

	# Левое ухо
	var ear_l := _xpoly(PackedVector2Array([Vector2(40, 20), Vector2(57, 38), Vector2(42, 52)]), bob_y)
	draw_colored_polygon(ear_l, Color("#1a0205"))
	draw_polyline(ear_l + PackedVector2Array([ear_l[0]]), Color("#ff1e38"), 2.2, true)

	# Правое ухо с пластырем (дёргается при шулерстве в Казино!)
	var twitch_off := Vector2(randf_range(-5.0, 5.0), randf_range(-6.0, 3.0)) if ear_twitch_timer > 0.0 else Vector2.ZERO
	var ear_col := Color("#d6ff3a") if ear_twitch_timer > 0.0 else Color("#ff1e38")
	var ear_r := _xpoly(PackedVector2Array([
		Vector2(90, 20) + twitch_off, Vector2(73, 38), Vector2(88, 52)
	]), bob_y)
	draw_colored_polygon(ear_r, Color("#2d050b") if ear_twitch_timer > 0.0 else Color("#1a0205"))
	draw_polyline(ear_r + PackedVector2Array([ear_r[0]]), ear_col, 2.4, true)

	# Пятиугольная морда
	var head := _xpoly(PackedVector2Array([
		Vector2(42, 52), Vector2(65, 76), Vector2(88, 52), Vector2(73, 38), Vector2(57, 38)
	]), bob_y)
	draw_colored_polygon(head, Color("#120103"))
	draw_polyline(head + PackedVector2Array([head[0]]), Color.WHITE if tier >= 4 else Color("#ff1e38"), 2.2, true)

	# Глаза и третий глаз на Тире 4
	if sleeping:
		draw_line(_xf(Vector2(51, 53), bob_y), _xf(Vector2(59, 54), bob_y), Color("#926870"), 2.0)
		draw_line(_xf(Vector2(71, 54), bob_y), _xf(Vector2(79, 53), bob_y), Color("#926870"), 2.0)
	else:
		var eye_col := Color("#39ff88") if ear_twitch_timer > 0.0 else Color("#ff1e38")
		draw_circle(_xf(Vector2(55, 53), bob_y), 3.2, eye_col)
		draw_circle(_xf(Vector2(75, 53), bob_y), 3.2, eye_col)
	if tier >= 4:
		draw_circle(_xf(Vector2(65, 38), bob_y), 3.0, Color("#ff1e38"))

	# Носик
	var nose := _xpoly(PackedVector2Array([Vector2(61, 63), Vector2(69, 63), Vector2(65, 68)]), bob_y)
	draw_colored_polygon(nose, Color.WHITE)
