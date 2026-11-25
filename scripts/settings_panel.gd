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
var _toggle_btns: Dictionary = {} # key: String -> Button
var _slider_controls: Dictionary = {} # key: String -> { "slider": HSlider, "label": Label }
var _settings_changed_cb: Callable

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

	_settings_changed_cb = Callable(self, "_on_external_setting_changed")
	if not FoxSettings.changed.is_connected(_settings_changed_cb):
		FoxSettings.changed.connect(_settings_changed_cb)

	_select_tab(0)

func _exit_tree() -> void:
	if _settings_changed_cb.is_valid() and FoxSettings.changed.is_connected(_settings_changed_cb):
		FoxSettings.changed.disconnect(_settings_changed_cb)

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
	var initial_on := bool(FoxSettings.get(key))
	b.set_pressed_no_signal(initial_on)
	_apply_toggle_visual(b, initial_on)
	b.toggled.connect(_on_toggle_pressed.bind(key))
	row.add_child(b)
	_toggle_btns[key] = b

func _apply_toggle_visual(b: Button, on: bool) -> void:
	if b == null or not is_instance_valid(b):
		return
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

func _on_toggle_pressed(on: bool, key: String) -> void:
	if not is_inside_tree():
		return
	FoxSettings.set_value(key, on)
	if _toggle_btns.has(key):
		_apply_toggle_visual(_toggle_btns[key], on)
	Audio.play_sfx("click")

func _on_external_setting_changed(key: String) -> void:
	if not is_inside_tree():
		return
	if _toggle_btns.has(key):
		var b: Button = _toggle_btns[key]
		if b != null and is_instance_valid(b):
			var target_on := bool(FoxSettings.get(key))
			if b.button_pressed != target_on:
				b.set_pressed_no_signal(target_on)
			_apply_toggle_visual(b, target_on)
	if _slider_controls.has(key):
		var entry: Dictionary = _slider_controls[key]
		var sl: HSlider = entry["slider"]
		var lbl: Label = entry["label"]
		var v := float(FoxSettings.get(key))
		if sl != null and is_instance_valid(sl) and not is_equal_approx(sl.value, v):
			sl.set_value_no_signal(v)
		if lbl != null and is_instance_valid(lbl):
			lbl.text = "%d%%" % int(round(v * 100.0))

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
	_slider_controls[key] = { "slider": sl, "label": val }
	sl.value_changed.connect(_on_slider_value_changed.bind(key, val))
	sl.drag_ended.connect(_on_slider_drag_ended.bind(preview_shake))

func _on_slider_value_changed(v: float, key: String, lbl: Label) -> void:
	if not is_inside_tree():
		return
	FoxSettings.set_value(key, v)
	if lbl != null and is_instance_valid(lbl):
		lbl.text = "%d%%" % int(round(v * 100.0))

func _on_slider_drag_ended(_changed: bool, preview_shake: bool) -> void:
	if not is_inside_tree():
		return
	Audio.play_sfx("click")
	if preview_shake:
		shake_preview.emit(FoxSettings.screen_shake)
