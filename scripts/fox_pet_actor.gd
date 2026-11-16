class_name FoxPetActor
extends Control

# Лис сидит на левом краю кнопки-печати. Назначается из main.gd: fox_pet.anchor = sigil_btn
var anchor: Control

# Положение относительно прямоугольника кнопки (подстройте под свой макет)
const SIT_DX := -112.0            # влево от левого края кнопки
const SIT_Y_FRAC := 0.58          # доля высоты кнопки, на которой сидит лис
const SIT_DY := -72.0

var _t: float = 0.0
var _hop: float = 0.0
var _wake: float = 0.0
var _ear_twitch: float = 0.0
var _blink: float = 0.0
var _blink_cd: float = 3.0
var _was_sleeping: bool = false

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
	bubble_lbl.text = "Жми на красную печать! Нам нужна энергия!"
	bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_lbl.add_theme_color_override("font_color", Color("#ecd9dc"))
	bubble_lbl.add_theme_font_size_override("font_size", 12)
	bubble.add_child(bubble_lbl)

	Fox.say.connect(func(txt: String) -> void: bubble_lbl.text = txt)
	Casino.ear_twitch.connect(func() -> void: _ear_twitch = 0.45)

# Реакция на клик игрока по кнопке (вызывается из main.gd)
func react(is_crit: bool = false) -> void:
	_hop = 1.0
	if is_crit:
		_ear_twitch = 0.35
	Fox.on_activity()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hop = 1.0
		if event.position.y <= 78.0 and Casino.on_fox_ear_clicked():
			return
		Fox.on_poke()

func _process(delta: float) -> void:
	_t += delta
	bubble.visible = not Fox.muted
	_hop = maxf(0.0, _hop - delta * 3.5)
	_wake = maxf(0.0, _wake - delta)
	_ear_twitch = maxf(0.0, _ear_twitch - delta)
	_blink = maxf(0.0, _blink - delta)
	_blink_cd -= delta
	if _blink_cd <= 0.0:
		_blink = 0.12
		_blink_cd = randf_range(2.0, 5.0)

	var sleeping := Fox.state == Fox.S.SLEEPING
	if _was_sleeping and not sleeping:
		_wake = 0.6
		_hop = 1.0
	_was_sleeping = sleeping

	var vp := get_viewport_rect().size
	var target: Vector2
	if anchor != null and is_instance_valid(anchor):
		var r := anchor.get_global_rect()
		target = Vector2(r.position.x + SIT_DX, r.position.y + r.size.y * SIT_Y_FRAC + SIT_DY)
	else:
		target = Vector2(120.0, vp.y - 142.0)
	position = position.lerp(target, minf(1.0, delta * 10.0))

	# облачко не вылезает за края окна
	var shift := 0.0
	if position.x - 65.0 < 12.0:
		shift = 12.0 - (position.x - 65.0)
	elif position.x + 195.0 > vp.x - 12.0:
		shift = (vp.x - 12.0) - (position.x + 195.0)
	bubble.position.x = -65.0 + shift
	queue_redraw()

func _pt(v: Vector2, bob: float) -> Vector2:
	return v + Vector2(0.0, bob)

func _poly(pts: PackedVector2Array, bob: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in range(pts.size()):
		out[i] = _pt(pts[i], bob)
	return out

func _shape(pts: PackedVector2Array, fill: Color, line: Color, w: float) -> void:
	draw_colored_polygon(pts, fill)
	draw_polyline(pts + PackedVector2Array([pts[0]]), line, w, true)

func _draw() -> void:
	var tier := Economy.tier_of(Economy.phase_of(GameState))
	var sleeping := Fox.state == Fox.S.SLEEPING
	var calm: bool = FoxSettings.reduce_noise
	var breathe := sin(_t * (1.2 if sleeping else 2.2)) * (0.8 if calm else 1.6)
	var body_bob := breathe + (4.0 if sleeping else 0.0) - sin(_hop * PI) * 16.0
	var head_bob := body_bob + (5.0 if sleeping else 0.0)
	var sway := sin(_t * 1.5) * (2.0 if calm else 6.0)
	var red := Color("#ff1e38")

	# тень
	draw_circle(Vector2(65.0, 128.0), 24.0, Color(0, 0, 0, 0.7))

	# хвост свисает вниз с края кнопки и покачивается
	var tail := _poly(PackedVector2Array([
		Vector2(48, 100), Vector2(26 + sway * 0.4, 112), Vector2(10 + sway, 132), Vector2(22 + sway, 136), Vector2(40, 116)
	]), body_bob)
	_shape(tail, Color("#1e0408"), red, 2.0)
	if tier >= 3:
		var tail2 := _poly(PackedVector2Array([
			Vector2(50, 96), Vector2(30, 104 - sway * 0.3), Vector2(16, 120 - sway), Vector2(30, 122 - sway), Vector2(46, 108)
		]), body_bob)
		_shape(tail2, Color("#160205"), Color("#c0392b"), 1.6)

	# туловище (сидит)
	var body := _poly(PackedVector2Array([Vector2(46, 70), Vector2(84, 70), Vector2(92, 118), Vector2(40, 118)]), body_bob)
	_shape(body, Color("#180306"), red if tier >= 2 else Color("#c0392b"), 2.0)

	# передние лапки
	draw_rect(Rect2(_pt(Vector2(54, 104), body_bob), Vector2(8, 16)), Color("#240408"), true)
	draw_rect(Rect2(_pt(Vector2(68, 104), body_bob), Vector2(8, 16)), Color("#240408"), true)

	# уши
	_shape(_poly(PackedVector2Array([Vector2(40, 20), Vector2(57, 38), Vector2(42, 52)]), head_bob),
		Color("#1a0205"), red, 2.2)
	var tw := Vector2(randf_range(-5.0, 5.0), randf_range(-6.0, 3.0)) if _ear_twitch > 0.0 else Vector2.ZERO
	var perk := Vector2(0.0, -6.0) if _wake > 0.0 else Vector2.ZERO
	_shape(_poly(PackedVector2Array([Vector2(90, 20) + tw + perk, Vector2(73, 38), Vector2(88, 52)]), head_bob),
		Color("#2d050b") if _ear_twitch > 0.0 else Color("#1a0205"),
		Color("#d6ff3a") if _ear_twitch > 0.0 else red, 2.4)

	# морда
	_shape(_poly(PackedVector2Array([Vector2(42, 52), Vector2(65, 76), Vector2(88, 52), Vector2(73, 38), Vector2(57, 38)]), head_bob),
		Color("#120103"), Color.WHITE if tier >= 4 else red, 2.2)

	# глаза: следят за курсором
	if sleeping or _blink > 0.0:
		draw_line(_pt(Vector2(51, 53), head_bob), _pt(Vector2(59, 54), head_bob), Color("#926870"), 2.0)
		draw_line(_pt(Vector2(71, 54), head_bob), _pt(Vector2(79, 53), head_bob), Color("#926870"), 2.0)
	else:
		var head_global := global_position + Vector2(65.0, 53.0 + head_bob)
		var to_mouse := get_global_mouse_position() - head_global
		var look := to_mouse.normalized() * clampf(to_mouse.length() / 140.0, 0.0, 1.0) * 1.9
		var pup := Color("#39ff88") if _ear_twitch > 0.0 else red
		for ex: float in [55.0, 75.0]:
			var ec := _pt(Vector2(ex, 53.0), head_bob)
			draw_circle(ec, 4.0, Color.WHITE)
			draw_circle(ec + look, 2.3, pup)
	if tier >= 4:
		draw_circle(_pt(Vector2(65, 38), head_bob), 3.0, red)

	# носик
	draw_colored_polygon(_poly(PackedVector2Array([Vector2(61, 63), Vector2(69, 63), Vector2(65, 68)]), head_bob), Color.WHITE)

	# восклицание при пробуждении
	if _wake > 0.0:
		draw_string(get_theme_default_font(), _pt(Vector2(94, 22), head_bob), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#d6ff3a"))
