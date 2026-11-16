class_name DrawerPinButton
extends Control

signal toggled(is_pinned: bool)

var pinned: bool = false:
	set(val):
		pinned = val
		tooltip_text = "Открепить панель" if pinned else "Закрепить панель открытой"
		queue_redraw()

var hovered: bool = false
var pressed_down: bool = false
var anim_t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(30, 30)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Закрепить панель открытой"
	mouse_entered.connect(func() -> void:
		hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hovered = false
		pressed_down = false
		queue_redraw()
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed_down = true
			queue_redraw()
		elif pressed_down:
			pressed_down = false
			pinned = not pinned
			Audio.play_sfx("ui")
			toggled.emit(pinned)
			queue_redraw()

func _process(delta: float) -> void:
	var target := 1.0 if pinned else 0.0
	if not is_equal_approx(anim_t, target):
		anim_t = lerpf(anim_t, target, minf(1.0, delta * 18.0))
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := size * 0.5
	var press_off := Vector2(0.0, 1.5) if pressed_down else Vector2.ZERO

	var accent := Color("#39ff88").lerp(Color("#ff1e38"), 1.0 - anim_t)
	if hovered and not pinned:
		accent = Color("#ff5266")

	var bg := Color("#0a1f12") if pinned else (Color("#2d0a11") if hovered else Color("#190609"))

	# Рамка кнопки
	draw_rect(Rect2(Vector2.ZERO, size), bg, true)
	draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), accent, false, 1.6)

	# Угловые фиксаторы (сжимаются к центру при закреплении)
	var inset := lerpf(2.0, 4.5, anim_t)
	var b_len := 5.0
	draw_polyline(PackedVector2Array([
		Vector2(inset, inset + b_len),
		Vector2(inset, inset),
		Vector2(inset + b_len, inset)
	]), accent, 1.5)
	draw_polyline(PackedVector2Array([
		Vector2(w - inset, h - inset - b_len),
		Vector2(w - inset, h - inset),
		Vector2(w - inset - b_len, h - inset)
	]), accent, 1.5)

	# Дужка механического замка
	var lift := lerpf(-3.8, 0.0, anim_t)
	var open_gap := lerpf(2.2, 0.0, anim_t)
	draw_polyline(PackedVector2Array([
		c + press_off + Vector2(-4.5, -1.5 + lift),
		c + press_off + Vector2(-4.5, -6.5 + lift),
		c + press_off + Vector2(0.0, -9.0 + lift),
		c + press_off + Vector2(4.5, -6.5 + lift),
		c + press_off + Vector2(4.5, -1.5 + lift - open_gap)
	]), accent, 1.8, true)

	# Остроугольный корпус замка
	var body := PackedVector2Array([
		c + press_off + Vector2(-6.5, -1.5),
		c + press_off + Vector2(6.5, -1.5),
		c + press_off + Vector2(6.5, 6.0),
		c + press_off + Vector2(0.0, 9.5),
		c + press_off + Vector2(-6.5, 6.0)
	])
	draw_colored_polygon(body, Color("#090204"))
	body.append(body[0])
	draw_polyline(body, accent, 1.7, true)

	# Сердцевина
	if pinned:
		draw_line(c + press_off + Vector2(0.0, 1.0), c + press_off + Vector2(0.0, 6.0), accent, 2.2)
	else:
		draw_circle(c + press_off + Vector2(0.0, 3.2), 1.6, accent)
