class_name MenuFox
extends Control

const S := 2.6
const HEAD_C := Vector2(65.0, 52.0)

var _t: float = 0.0
var _bounce: float = 0.0
var _blink: float = 0.0
var _blink_cd: float = 2.5
var _ear: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(340.0, 370.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func poke() -> void:
	_bounce = 1.0
	_ear = 0.4

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		poke()
		Audio.play_sfx("ui")

func _process(delta: float) -> void:
	_t += delta
	_bounce = maxf(0.0, _bounce - delta * 3.0)
	_ear = maxf(0.0, _ear - delta)
	_blink = maxf(0.0, _blink - delta)
	_blink_cd -= delta
	if _blink_cd <= 0.0:
		_blink = 0.12
		_blink_cd = randf_range(2.0, 5.0)
	queue_redraw()

func _p(pts: PackedVector2Array, bob: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(v + Vector2(0.0, bob))
	return out

func _outlined(pts: PackedVector2Array, fill: Color, line: Color, w: float) -> void:
	draw_colored_polygon(pts, fill)
	draw_polyline(pts + PackedVector2Array([pts[0]]), line, w, true)

func _draw() -> void:
	var calm: bool = FoxSettings.reduce_noise
	var bob := sin(_t * 2.0) * (0.4 if calm else 1.2) - sin(_bounce * PI) * 10.0
	var sway := sin(_t * 1.6) * (1.5 if calm else 5.0)
	draw_set_transform(Vector2(30.0, 20.0), 0.0, Vector2(S, S))

	draw_circle(Vector2(65.0, 126.0), 26.0, Color(0, 0, 0, 0.7))

	_outlined(_p(PackedVector2Array([Vector2(48, 86), Vector2(24, 48 - sway), Vector2(36, 30 - sway), Vector2(50, 74)]), bob),
		Color("#160205"), Color("#c0392b"), 1.6)
	_outlined(_p(PackedVector2Array([Vector2(48, 92), Vector2(18, 76 + sway), Vector2(22, 52 + sway), Vector2(46, 80)]), bob),
		Color("#1e0408"), RED, 2.0)

	draw_rect(Rect2(Vector2(50, 96 + bob * 0.3), Vector2(7, 24 - bob * 0.3)), Color("#160205"), true)
	draw_rect(Rect2(Vector2(68, 96 + bob * 0.3), Vector2(7, 24 - bob * 0.3)), Color("#240408"), true)

	_outlined(_p(PackedVector2Array([Vector2(48, 68), Vector2(82, 68), Vector2(87, 98), Vector2(43, 98)]), bob),
		Color("#180306"), RED, 2.0)

	_outlined(_p(PackedVector2Array([Vector2(40, 20), Vector2(57, 38), Vector2(42, 52)]), bob),
		Color("#1a0205"), RED, 2.2)
	var twitch := Vector2(randf_range(-4.0, 4.0), randf_range(-5.0, 2.0)) if _ear > 0.0 else Vector2.ZERO
	_outlined(_p(PackedVector2Array([Vector2(90, 20) + twitch, Vector2(73, 38), Vector2(88, 52)]), bob),
		Color("#1a0205"), Color("#d6ff3a") if _ear > 0.0 else RED, 2.4)

	_outlined(_p(PackedVector2Array([Vector2(42, 52), Vector2(65, 76), Vector2(88, 52), Vector2(73, 38), Vector2(57, 38)]), bob),
		Color("#120103"), RED, 2.2)

	# глаза следят за курсором
	var head_g := global_position + (HEAD_C + Vector2(30.0 / S, 20.0 / S + bob)) * S
	var to_mouse := get_global_mouse_position() - head_g
	var look := to_mouse.normalized() * clampf(to_mouse.length() / 160.0, 0.0, 1.0) * 2.0
	for ex: float in [55.0, 75.0]:
		var ec := Vector2(ex, 53.0 + bob)
		if _blink > 0.0:
			draw_line(ec + Vector2(-4, 0), ec + Vector2(4, 0), Color("#926870"), 2.0)
		else:
			draw_circle(ec, 4.4, Color.WHITE)
			draw_circle(ec + look, 2.4, RED)

	_outlined(_p(PackedVector2Array([Vector2(61, 63), Vector2(69, 63), Vector2(65, 68)]), bob),
		Color.WHITE, Color.WHITE, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

const RED := Color("#ff1e38")
