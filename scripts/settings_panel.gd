class_name SettingsPanel
extends PanelContainer

signal closed
signal shake_preview(mult: float)

const RED := Color("#ff1e38")
const RED_DIM := Color("#660014")
const RED_SOFT := Color("#ff5266")
const BG := Color("#080103")
const GREEN := Color("#39ff88")
const TEXT := Color("#ecd9dc")

var _tabs: Array[Button] = []
var _pages: Array[VBoxContainer] = []

func _ready() -> void:
	add_theme_stylebox_override("panel", FoxTheme.panel_style(RED, BG, 2))
	custom_minimum_size = Vector2(640.0, 420.0)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "/SYS/CONFIG // НАСТРОЙКИ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", RED)
	title.add_theme_font_size_override("font_size", 18)
	head.add_child(title)
	var close_btn := _flat_button("[ X ]")
	close_btn.pressed.connect(func() -> void: closed.emit())
	head.add_child(close_btn)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	root.add_child(tab_row)

	var pages_holder := VBoxContainer.new()
	pages_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages_holder)

	var names := ["ОБЩИЕ / СПЕЦ. ВОЗМОЖНОСТИ", "ВИДЕО", "АУДИО"]
	for i in range(names.size()):
		var b := Button.new()
		b.text = names[i]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select_tab.bind(i))
		tab_row.add_child(b)
		_tabs.append(b)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 16)
		page.visible = false
		pages_holder.add_child(page)
		_pages.append(page)

	# --- Общие
	_slider(_pages[0], "Тряска экрана", "screen_shake", true)
	_toggle(_pages[0], "Отскок кнопки", "button_bounce")
	_toggle(_pages[0], "Авто-клик при зажатии", "autoclick_hold")
	# --- Видео
	_toggle(_pages[1], "Снизить визуальный шум / CRT", "reduce_noise")
	_toggle(_pages[1], "Полноэкранный режим", "fullscreen")
	# --- Аудио
	_slider(_pages[2], "Общая громкость", "master_volume", false)
	_toggle(_pages[2], "Звук интерфейса и кликов", "sfx_on")

	_select_tab(0)

func _flat_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", RED_DIM)
	b.add_theme_color_override("font_hover_color", RED)
	return b

func _tab_style(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = RED if active else Color("#1a0205")
	s.set_border_width_all(2)
	s.border_color = RED if active else RED_DIM
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _select_tab(idx: int) -> void:
	for i in range(_tabs.size()):
		var act := i == idx
		_pages[i].visible = act
		var b := _tabs[i]
		for st: String in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, _tab_style(act))
		var fc := Color.BLACK if act else RED_SOFT
		b.add_theme_color_override("font_color", fc)
		b.add_theme_color_override("font_hover_color", fc)
		b.add_theme_color_override("font_pressed_color", fc)
	if is_inside_tree():
		Audio.play_sfx("ui")

func _row(page: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_font_size_override("font_size", 16)
	row.add_child(l)
	var dots := Label.new()
	dots.text = "........................................................................"
	dots.clip_text = true
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.add_theme_color_override("font_color", RED_DIM)
	row.add_child(dots)
	return row

func _toggle(page: VBoxContainer, text: String, key: String) -> void:
	var row := _row(page, text)
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(110.0, 0.0)
	b.button_pressed = bool(FoxSettings.get(key))
	var refresh := func() -> void:
		var on := b.button_pressed
		b.text = "[ ВКЛ ]" if on else "[ ВЫКЛ ]"
		var s := StyleBoxFlat.new()
		s.bg_color = Color("#06200f") if on else Color("#1a0205")
		s.set_border_width_all(2)
		s.border_color = GREEN if on else RED_DIM
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		for st: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, s)
		var fc := GREEN if on else RED_SOFT
		b.add_theme_color_override("font_color", fc)
		b.add_theme_color_override("font_hover_color", fc)
		b.add_theme_color_override("font_pressed_color", fc)
		b.add_theme_color_override("font_hover_pressed_color", fc)
	refresh.call()
	b.toggled.connect(func(on: bool) -> void:
		FoxSettings.set_value(key, on)
		refresh.call()
		Audio.play_sfx("click")
	)
	row.add_child(b)
	# внешние изменения (например, через другой экран)
	FoxSettings.changed.connect(func(k: String) -> void:
		if k == key and b.button_pressed != bool(FoxSettings.get(key)):
			b.set_pressed_no_signal(bool(FoxSettings.get(key)))
			refresh.call()
	)

func _slider(page: VBoxContainer, text: String, key: String, preview_shake: bool) -> void:
	var row := _row(page, text)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = float(FoxSettings.get(key))
	sl.custom_minimum_size = Vector2(220.0, 26.0)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#1a0205")
	track.set_border_width_all(2)
	track.border_color = RED_DIM
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = RED
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	row.add_child(sl)
	var val := Label.new()
	val.custom_minimum_size = Vector2(52.0, 0.0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_color_override("font_color", RED_SOFT)
	val.text = "%d%%" % int(round(sl.value * 100.0))
	row.add_child(val)
	sl.value_changed.connect(func(v: float) -> void:
		FoxSettings.set_value(key, v)
		val.text = "%d%%" % int(round(v * 100.0))
	)
	sl.drag_ended.connect(func(_changed: bool) -> void:
		Audio.play_sfx("click")
		if preview_shake:
			shake_preview.emit(FoxSettings.screen_shake)
	)
