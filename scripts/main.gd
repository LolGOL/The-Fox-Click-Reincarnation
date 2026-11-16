extends Node2D

const SIGIL_TITLES: Array[String] = [
	"SIGIL LV.1 // РЖАВАЯ КНОПКА",
	"SIGIL LV.2 // ХИЩНЫЙ ТЕРМИНАЛ",
	"SIGIL LV.3 // РЕАКТОР КОДА 146",
	"SIGIL LV.4 // ЦИФРОВОЙ РАЗЛОМ"
]

const DRAWER_PANEL_W := 450.0
const HANDLE_W := 38.0
const TOTAL_DRAWER_W := DRAWER_PANEL_W + HANDLE_W

# Кэшированные стили интерфейса (без дублей в памяти)
var sb_btn_normal: StyleBoxFlat
var sb_btn_hover: StyleBoxFlat
var sb_btn_pressed: StyleBoxFlat
var sb_btn_disabled: StyleBoxFlat
var sb_btn_active: StyleBoxFlat
var sb_btn_acid: StyleBoxFlat
var sb_bar_bg: StyleBoxFlat
var sb_bar_fill: StyleBoxFlat

var ui_root: VBoxContainer
var vfx: VfxLayer
var crt_mat: ShaderMaterial
var sigil_btn: CoreSigilButton

var left_drawer: HBoxContainer
var right_drawer: HBoxContainer
var left_pinned: bool = false
var right_pinned: bool = false
var left_open_t: float = 0.0
var right_open_t: float = 0.0
var left_grace: float = 0.0
var right_grace: float = 0.0

var coins_lbl: Label
var cps_lbl: Label
var phase_lbl: Label
var voice_lbl: Label
var sigil_lbl: Label
var combo_lbl: Label
var fx_lbl: Label
var phase_bar: ProgressBar
var myc_lbl: Label
var myc_bar: ProgressBar
var spore_btn: Button
var purify_btn: Button

var shop_list: VBoxContainer
var shop_rows: Array[Dictionary] = []
var fake_row: Control = null
var fake_timer: float = 16.0

var ups_box: VBoxContainer
var amt_btns: Dictionary = {}
var last_up_sig: String = ""

var deal_overlay: ColorRect
var deal_name_lbl: Label
var deal_rew_lbl: Label
var deal_cur_lbl: Label
var deal_bar: ProgressBar
var current_deal: Dictionary = {}
var deal_left: float = 0.0

var debug_overlay: ColorRect

var recent_clicks: Array[float] = []
var shake_time: float = 0.0
var flash_red_val: float = 0.0

func _ready() -> void:
	_init_shared_styles()
	_build_ui()
	_build_shader_and_vfx()
	_build_modals()

	GameState.state_changed.connect(_refresh_ui)
	GameState.voice_logged.connect(func(txt: String) -> void:
		voice_lbl.text = "> Fox OS: " + txt
	)
	GameState.deal_requested.connect(_open_deal)
	GameState.glitch_spawn_requested.connect(func(cnt: int) -> void:
		for _i in range(cnt):
			vfx.spawn_glitch_artifact()
	)
	GameState.screen_flash_requested.connect(func(intensity: float, shake: bool) -> void:
		flash_red_val = maxf(flash_red_val, intensity)
		if shake:
			shake_time = 0.32
	)

	var tick_timer := Timer.new()
	tick_timer.wait_time = 0.1
	tick_timer.autostart = true
	tick_timer.timeout.connect(func() -> void: GameState.step(0.1))
	add_child(tick_timer)

	var save_timer := Timer.new()
	save_timer.wait_time = 5.0
	save_timer.autostart = true
	save_timer.timeout.connect(GameState.save_game)
	add_child(save_timer)

	_refresh_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			debug_overlay.visible = not debug_overlay.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and debug_overlay.visible:
			debug_overlay.visible = false
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var now: float = Time.get_unix_time_from_system()
	while not recent_clicks.is_empty() and now - recent_clicks[0] > 1.0:
		recent_clicks.pop_front()
	combo_lbl.text = "РИТМ: %d КЛ/С" % recent_clicks.size()
	combo_lbl.add_theme_color_override("font_color", Color("#39ff88") if recent_clicks.size() >= 4 else Color("#926870"))

	_update_drawers(delta)

	if shake_time > 0.0:
		shake_time -= delta
		ui_root.position = Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 4.0))
	else:
		ui_root.position = Vector2.ZERO

	# Эффекты мицелия: 20%+ дрожь кнопок, 40%+ мерцание цифр, 80%+ ловушки
	var inf: int = Economy.inf_eff(GameState)
	for r: Dictionary in shop_rows:
		var btn: Button = r["btn"]
		if btn.has_meta("dodging"):
			continue
		if inf >= 20:
			var jit := randf_range(-1.8, 1.8)
			btn.offset_left = jit
			btn.offset_right = jit
		elif not is_zero_approx(btn.offset_left) or not is_zero_approx(btn.offset_right):
			btn.offset_left = 0.0
			btn.offset_right = 0.0

	coins_lbl.modulate.a = (0.78 + 0.22 * sin(now * 16.0)) if inf >= 40 else 1.0

	_tick_fake_button(delta, inf)

	if deal_overlay.visible:
		deal_left -= delta
		deal_bar.value = clampf(deal_left / 30.0, 0.0, 1.0)
		if deal_left <= 0.0:
			deal_overlay.visible = false
			voice_lbl.text = "> Fox OS: Ты молчал. Я записал это как отказ."

	flash_red_val = maxf(0.0, flash_red_val - delta * 1.4)
	if crt_mat:
		var inf_f := float(inf) / 100.0
		crt_mat.set_shader_parameter("aberration", 0.0008 + inf_f * 0.0045)
		crt_mat.set_shader_parameter("tear_strength", 0.025 if inf >= 80 else (0.01 if inf >= 60 else 0.0))
		crt_mat.set_shader_parameter("bw_mode", 1.0 if float(GameState.fx.get("over", 0.0)) > 0.0 else 0.0)
		crt_mat.set_shader_parameter("flash_red", flash_red_val)

func _update_drawers(delta: float) -> void:
	var modal_busy := deal_overlay.visible or debug_overlay.visible
	var mpos := get_global_mouse_position()

	var l_hover := not modal_busy and left_drawer.get_global_rect().has_point(mpos)
	left_grace = 0.18 if (left_pinned or l_hover) else maxf(0.0, left_grace - delta)
	left_open_t = lerpf(left_open_t, 1.0 if (left_pinned or left_grace > 0.0) else 0.0, minf(1.0, delta * 14.0))
	left_drawer.offset_left = lerpf(-DRAWER_PANEL_W, 0.0, left_open_t)
	left_drawer.offset_right = left_drawer.offset_left + TOTAL_DRAWER_W

	var r_hover := not modal_busy and right_drawer.get_global_rect().has_point(mpos)
	right_grace = 0.18 if (right_pinned or r_hover) else maxf(0.0, right_grace - delta)
	right_open_t = lerpf(right_open_t, 1.0 if (right_pinned or right_grace > 0.0) else 0.0, minf(1.0, delta * 14.0))
	right_drawer.offset_right = lerpf(DRAWER_PANEL_W, 0.0, right_open_t)
	right_drawer.offset_left = right_drawer.offset_right - TOTAL_DRAWER_W

func _make_box_style(bg: Color, border: Color, border_w: int = 2, pad_x: int = 10, pad_y: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb

func _init_shared_styles() -> void:
	sb_btn_normal = _make_box_style(Color("#190609"), Color("#c0392b"))
	sb_btn_hover = _make_box_style(Color("#2d0a11"), Color("#ff1e38"))
	sb_btn_pressed = _make_box_style(Color("#c0392b"), Color("#ff1e38"))
	sb_btn_disabled = _make_box_style(Color("#0d0305"), Color("#3a0b10"))
	sb_btn_active = _make_box_style(Color("#c0392b"), Color("#ff5266"))
	sb_btn_acid = _make_box_style(Color("#161c04"), Color("#d6ff3a"))

	sb_bar_bg = _make_box_style(Color("#050102"), Color("#4a0e16"), 2, 0, 0)
	sb_bar_fill = _make_box_style(Color("#c0392b"), Color("#ff1e38"), 0, 0, 0)

func _style_button(btn: Button, is_acid: bool = false) -> void:
	btn.add_theme_stylebox_override("normal", sb_btn_acid if is_acid else sb_btn_normal)
	btn.add_theme_stylebox_override("hover", sb_btn_hover)
	btn.add_theme_stylebox_override("pressed", sb_btn_pressed)
	btn.add_theme_stylebox_override("disabled", sb_btn_disabled)
	btn.add_theme_color_override("font_color", Color("#d6ff3a") if is_acid else Color("#ff1e38"))
	btn.add_theme_color_override("font_hover_color", Color("#ff5266"))
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_color_override("font_disabled_color", Color("#6e3b42"))

func _style_progress_bar(bar: ProgressBar) -> void:
	bar.add_theme_stylebox_override("background", sb_bar_bg)
	bar.add_theme_stylebox_override("fill", sb_bar_fill)

func _build_drawer_handle(vertical_title: String, is_left: bool) -> PanelContainer:
	var handle := PanelContainer.new()
	handle.custom_minimum_size = Vector2(HANDLE_W, 0)
	handle.add_theme_stylebox_override("panel", _make_box_style(Color("#120306"), Color("#c0392b"), 2, 4, 8))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.add_theme_constant_override("separation", 10)
	handle.add_child(vb)

	var pin_btn := DrawerPinButton.new()
	vb.add_child(pin_btn)

	if is_left:
		pin_btn.toggled.connect(func(is_pinned: bool) -> void: left_pinned = is_pinned)
	else:
		pin_btn.toggled.connect(func(is_pinned: bool) -> void: right_pinned = is_pinned)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer_top)

	var tag := Label.new()
	tag.text = vertical_title
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color("#ff1e38"))
	tag.add_theme_font_size_override("font_size", 13)
	vb.add_child(tag)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer_bot)

	return handle

func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)

	var bg := ColorRect.new()
	bg.color = Color("#030102")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(bg)

	ui_root = VBoxContainer.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_theme_constant_override("separation", 6)
	ui_layer.add_child(ui_root)

	# Шапка
	var hdr := PanelContainer.new()
	hdr.add_theme_stylebox_override("panel", _make_box_style(Color("#0c0204"), Color("#c0392b")))
	ui_root.add_child(hdr)

	var hdr_hbox := HBoxContainer.new()
	hdr_hbox.add_theme_constant_override("separation", 12)
	hdr.add_child(hdr_hbox)

	var title := Label.new()
	title.text = "[FOX_OS // 146] THE FOX CLICK REINCARNATION"
	title.add_theme_color_override("font_color", Color("#ff1e38"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(title)

	var dbg_btn := Button.new()
	dbg_btn.text = "[DEBUG // F12]"
	_style_button(dbg_btn, true)
	dbg_btn.pressed.connect(func() -> void: debug_overlay.visible = not debug_overlay.visible)
	hdr_hbox.add_child(dbg_btn)

	phase_lbl = Label.new()
	phase_lbl.add_theme_color_override("font_color", Color("#c0392b"))
	hdr_hbox.add_child(phase_lbl)

	# Строка голоса Fox OS
	var voice_panel := PanelContainer.new()
	voice_panel.add_theme_stylebox_override("panel", _make_box_style(Color("#090204"), Color("#4a0e16")))
	ui_root.add_child(voice_panel)

	voice_lbl = Label.new()
	voice_lbl.text = "> Fox OS: Заработай. Возвысься. Стань мной."
	voice_lbl.add_theme_color_override("font_color", Color("#ff1e38"))
	voice_panel.add_child(voice_lbl)

	# Рабочая зона: центральная сцена + выдвижные боковые шторки
	var workspace := Control.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.clip_contents = true
	ui_root.add_child(workspace)

	# === ЦЕНТРАЛЬНАЯ АРЕНА ===
	var center_panel := PanelContainer.new()
	center_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_panel.offset_left = HANDLE_W + 6.0
	center_panel.offset_right = -(HANDLE_W + 6.0)
	center_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.045, 0.012, 0.02, 0.88), Color("#c0392b")))
	workspace.add_child(center_panel)

	var center_vbox := VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 10)
	center_panel.add_child(center_vbox)

	var top_bar := HBoxContainer.new()
	center_vbox.add_child(top_bar)
	sigil_lbl = Label.new()
	sigil_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sigil_lbl.add_theme_color_override("font_color", Color("#c0392b"))
	top_bar.add_child(sigil_lbl)

	combo_lbl = Label.new()
	combo_lbl.text = "РИТМ: 0 КЛ/С"
	top_bar.add_child(combo_lbl)

	coins_lbl = Label.new()
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.add_theme_font_size_override("font_size", 46)
	coins_lbl.add_theme_color_override("font_color", Color("#ff1e38"))
	center_vbox.add_child(coins_lbl)

	cps_lbl = Label.new()
	cps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cps_lbl.add_theme_color_override("font_color", Color("#ecd9dc"))
	center_vbox.add_child(cps_lbl)

	var btn_center := CenterContainer.new()
	btn_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(btn_center)

	sigil_btn = CoreSigilButton.new()
	sigil_btn.clicked.connect(func(gpos: Vector2) -> void:
		recent_clicks.append(Time.get_unix_time_from_system())
		var res: Dictionary = GameState.do_click()
		var gain: BigNum = res["gain"]
		var is_crit: bool = res["is_crit"]
		sigil_btn.trigger_hit_vfx(is_crit)
		var greed := float(GameState.fx.get("greed", 0.0)) > 0.0
		var txt := ("КРИТ ×%.0f! +%s" % [res["crit_mult"], "ERR_0x00" if greed else gain.format_ru()]) if is_crit else ("+%s" % ("ERR_0x00" if greed else gain.format_ru()))
		vfx.spawn_floating_text(gpos, txt, Color("#d6ff3a") if is_crit else Color("#ff1e38"), 1.25 if is_crit else 1.0)
	)
	btn_center.add_child(sigil_btn)

	fx_lbl = Label.new()
	fx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx_lbl.add_theme_color_override("font_color", Color("#39ff88"))
	center_vbox.add_child(fx_lbl)

	# Блок мицелия
	var myc_center := CenterContainer.new()
	center_vbox.add_child(myc_center)

	var myc_box := VBoxContainer.new()
	myc_box.custom_minimum_size = Vector2(540, 0)
	myc_center.add_child(myc_box)

	myc_lbl = Label.new()
	myc_lbl.add_theme_color_override("font_color", Color("#c0392b"))
	myc_box.add_child(myc_lbl)

	myc_bar = ProgressBar.new()
	myc_bar.max_value = 100.0
	myc_bar.show_percentage = false
	myc_bar.custom_minimum_size = Vector2(0, 14)
	_style_progress_bar(myc_bar)
	myc_box.add_child(myc_bar)

	var myc_btns := HBoxContainer.new()
	myc_btns.add_theme_constant_override("separation", 8)
	myc_box.add_child(myc_btns)

	spore_btn = Button.new()
	spore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(spore_btn)
	spore_btn.pressed.connect(func() -> void:
		if GameState.buy_spore():
			vfx.spawn_purchase_burst(get_global_mouse_position(), "СПОРЫ ВПРЫСНУТЫ!", true)
	)
	myc_btns.add_child(spore_btn)

	purify_btn = Button.new()
	purify_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(purify_btn)
	purify_btn.pressed.connect(GameState.purify)
	myc_btns.add_child(purify_btn)

	# === ЛЕВАЯ ВЫДВИЖНАЯ ШТОРКА: МАГАЗИН ===
	left_drawer = HBoxContainer.new()
	left_drawer.anchor_left = 0.0
	left_drawer.anchor_right = 0.0
	left_drawer.anchor_top = 0.0
	left_drawer.anchor_bottom = 1.0
	left_drawer.offset_left = -DRAWER_PANEL_W
	left_drawer.offset_right = HANDLE_W
	left_drawer.add_theme_constant_override("separation", 0)
	workspace.add_child(left_drawer)

	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.035, 0.012, 0.02, 0.97), Color("#ff1e38")))
	left_drawer.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)

	var amt_row := HBoxContainer.new()
	left_vbox.add_child(amt_row)
	var amt_title := Label.new()
	amt_title.text = "МАГАЗИН МОДУЛЕЙ:  "
	amt_title.add_theme_color_override("font_color", Color("#c0392b"))
	amt_row.add_child(amt_title)

	for mode: String in ["1", "10", "max"]:
		var ab := Button.new()
		ab.text = "МАКС" if mode == "max" else "×" + mode
		_style_button(ab)
		ab.pressed.connect(func() -> void:
			GameState.buy_amt = mode
			_refresh_ui()
		)
		amt_row.add_child(ab)
		amt_btns[mode] = ab

	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(shop_scroll)

	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 6)
	shop_scroll.add_child(shop_list)

	for i: int in range(GameData.BUILDINGS.size()):
		var row_box := VBoxContainer.new()
		shop_list.add_child(row_box)

		var btn_holder := Control.new()
		btn_holder.custom_minimum_size = Vector2(0, 36)
		row_box.add_child(btn_holder)

		var btn := Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(btn)
		btn.pressed.connect(func() -> void:
			if GameState.buy_building(i):
				vfx.spawn_purchase_burst(get_global_mouse_position(), "ПОДКЛЮЧЕНО!")
		)
		btn.mouse_entered.connect(func() -> void: _on_shop_btn_hover(btn))
		btn_holder.add_child(btn)

		var meta := Label.new()
		meta.add_theme_color_override("font_color", Color("#926870"))
		meta.add_theme_font_size_override("font_size", 12)
		row_box.add_child(meta)

		shop_rows.append({ "btn": btn, "meta": meta })

	left_drawer.add_child(_build_drawer_handle("М\nА\nГ\nА\nЗ\nИ\nН", true))

	# === ПРАВАЯ ВЫДВИЖНАЯ ШТОРКА: УЛУЧШЕНИЯ ===
	right_drawer = HBoxContainer.new()
	right_drawer.anchor_left = 1.0
	right_drawer.anchor_right = 1.0
	right_drawer.anchor_top = 0.0
	right_drawer.anchor_bottom = 1.0
	right_drawer.offset_left = -HANDLE_W
	right_drawer.offset_right = DRAWER_PANEL_W
	right_drawer.add_theme_constant_override("separation", 0)
	workspace.add_child(right_drawer)

	right_drawer.add_child(_build_drawer_handle("А\nП\nГ\nР\nЕ\nЙ\nД\nЫ", false))

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.035, 0.012, 0.02, 0.97), Color("#ff1e38")))
	right_drawer.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_panel.add_child(right_vbox)

	var up_title := Label.new()
	up_title.text = "УЛУЧШЕНИЯ ЯДРА"
	up_title.add_theme_color_override("font_color", Color("#c0392b"))
	right_vbox.add_child(up_title)

	var up_scroll := ScrollContainer.new()
	up_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(up_scroll)

	ups_box = VBoxContainer.new()
	ups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ups_box.add_theme_constant_override("separation", 6)
	up_scroll.add_child(ups_box)

	phase_bar = ProgressBar.new()
	phase_bar.max_value = 1.0
	phase_bar.custom_minimum_size = Vector2(0, 16)
	_style_progress_bar(phase_bar)
	right_vbox.add_child(phase_bar)

func _build_shader_and_vfx() -> void:
	vfx = VfxLayer.new()
	add_child(vfx)

	var shader_layer := CanvasLayer.new()
	shader_layer.layer = 10
	add_child(shader_layer)

	var crt_rect := ColorRect.new()
	crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_mat = ShaderMaterial.new()
	crt_mat.shader = load("res://shaders/fox_crt.gdshader")
	crt_rect.material = crt_mat
	shader_layer.add_child(crt_rect)

func _build_modals() -> void:
	var modal_layer := CanvasLayer.new()
	modal_layer.layer = 20
	add_child(modal_layer)

	# 1. Окно Сделки с Дьяволом
	deal_overlay = ColorRect.new()
	deal_overlay.color = Color(0.0, 0.0, 0.0, 0.84)
	deal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	deal_overlay.visible = false
	modal_layer.add_child(deal_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	deal_overlay.add_child(cc)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(540, 0)
	box.add_theme_stylebox_override("panel", _make_box_style(Color.BLACK, Color("#ff1e38"), 4))
	cc.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)

	var dtitle := Label.new()
	dtitle.text = "СИСТЕМНЫЙ ПЕРЕХВАТ // СДЕЛКА С ДЬЯВОЛОМ"
	dtitle.add_theme_color_override("font_color", Color("#ff1e38"))
	vb.add_child(dtitle)

	deal_name_lbl = Label.new()
	deal_name_lbl.add_theme_font_size_override("font_size", 22)
	deal_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(deal_name_lbl)

	deal_rew_lbl = Label.new()
	deal_rew_lbl.add_theme_color_override("font_color", Color("#39ff88"))
	vb.add_child(deal_rew_lbl)

	deal_cur_lbl = Label.new()
	deal_cur_lbl.add_theme_color_override("font_color", Color("#ff5266"))
	vb.add_child(deal_cur_lbl)

	deal_bar = ProgressBar.new()
	deal_bar.max_value = 1.0
	deal_bar.value = 1.0
	deal_bar.show_percentage = false
	deal_bar.custom_minimum_size = Vector2(0, 12)
	_style_progress_bar(deal_bar)
	vb.add_child(deal_bar)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	vb.add_child(btns)

	var yes_btn := Button.new()
	yes_btn.text = "ПРИНЯТЬ ГРЕХ"
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(yes_btn)
	yes_btn.pressed.connect(func() -> void:
		deal_overlay.visible = false
		GameState.apply_deal(current_deal)
	)
	btns.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "ОТВЕРГНУТЬ"
	no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(no_btn)
	no_btn.pressed.connect(func() -> void:
		deal_overlay.visible = false
		voice_lbl.text = "> Fox OS: Отказ записан. Я запомню."
	)
	btns.add_child(no_btn)

	# 2. DEBUG-меню
	debug_overlay = ColorRect.new()
	debug_overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	debug_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_overlay.visible = false
	modal_layer.add_child(debug_overlay)

	var dcc := CenterContainer.new()
	dcc.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_overlay.add_child(dcc)

	var dbox := PanelContainer.new()
	dbox.custom_minimum_size = Vector2(560, 0)
	dbox.add_theme_stylebox_override("panel", _make_box_style(Color("#080203"), Color("#d6ff3a"), 3))
	dcc.add_child(dbox)

	var dvb := VBoxContainer.new()
	dvb.add_theme_constant_override("separation", 10)
	dbox.add_child(dvb)

	var dhdr := HBoxContainer.new()
	dvb.add_child(dhdr)
	var dlbl := Label.new()
	dlbl.text = "[DEBUG] ПРОВЕРКА ВИЗУАЛА, ЭВОЛЮЦИИ И ХАОСА"
	dlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlbl.add_theme_color_override("font_color", Color("#d6ff3a"))
	dhdr.add_child(dlbl)

	var dclose := Button.new()
	dclose.text = "ЗАКРЫТЬ [ESC]"
	_style_button(dclose, true)
	dclose.pressed.connect(func() -> void: debug_overlay.visible = false)
	dhdr.add_child(dclose)

	var tier_row := HBoxContainer.new()
	dvb.add_child(tier_row)
	for p_num: int in [1, 5, 9, 13, 16]:
		var tb := Button.new()
		tb.text = "Фаза %d" % p_num
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(tb)
		tb.pressed.connect(func() -> void: GameState.debug_set_phase(p_num))
		tier_row.add_child(tb)

	var myc_row := HBoxContainer.new()
	dvb.add_child(myc_row)
	for inf_v: int in [0, 20, 40, 60, 80, 100]:
		var ib := Button.new()
		ib.text = "Мицелий %d%%" % inf_v
		ib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(ib)
		ib.pressed.connect(func() -> void:
			GameState.infection = inf_v
			GameState.state_changed.emit()
		)
		myc_row.add_child(ib)

	var chaos_row := HBoxContainer.new()
	dvb.add_child(chaos_row)

	var add_money := Button.new()
	add_money.text = "+100 млн монет"
	add_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(add_money)
	add_money.pressed.connect(func() -> void: GameState.earn(BigNum.from_float(1.0e8)))
	chaos_row.add_child(add_money)

	var sp_glitch := Button.new()
	sp_glitch.text = "Вызвать глитч 146"
	sp_glitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(sp_glitch)
	sp_glitch.pressed.connect(func() -> void:
		debug_overlay.visible = false
		vfx.spawn_glitch_artifact()
	)
	chaos_row.add_child(sp_glitch)

	var sp_deal := Button.new()
	sp_deal.text = "Случайная сделка"
	sp_deal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(sp_deal)
	sp_deal.pressed.connect(func() -> void:
		debug_overlay.visible = false
		_open_deal(GameState.DEALS[randi() % GameState.DEALS.size()])
	)
	chaos_row.add_child(sp_deal)

	var clr_fx := Button.new()
	clr_fx.text = "Снять эффекты"
	clr_fx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(clr_fx)
	clr_fx.pressed.connect(func() -> void:
		GameState.fx.clear()
		vfx.clear_glitches()
		GameState.state_changed.emit()
	)
	chaos_row.add_child(clr_fx)

func _open_deal(deal: Dictionary) -> void:
	if deal_overlay.visible:
		return
	current_deal = deal
	deal_left = 30.0
	deal_name_lbl.text = deal["name"]
	deal_rew_lbl.text = "НАГРАДА: " + deal["rew"]
	deal_cur_lbl.text = "ПРОКЛЯТИЕ: " + deal["cur"]
	deal_bar.value = 1.0
	deal_overlay.visible = true
	flash_red_val = 0.75

func _on_shop_btn_hover(btn: Button) -> void:
	var is_eater := float(GameState.fx.get("eater", 0.0)) > 0.0
	var inf := Economy.inf_eff(GameState)
	if (not is_eater and inf < 60) or btn.has_meta("dodging"):
		return
	var dist := 34.0 if is_eater else 22.0
	var dx := randf_range(-dist, dist)
	var dy := randf_range(-8.0, 8.0)
	btn.set_meta("dodging", true)
	var tw := create_tween()
	tw.tween_property(btn, "offset_left", dx, 0.12)
	tw.parallel().tween_property(btn, "offset_right", dx, 0.12)
	tw.parallel().tween_property(btn, "offset_top", dy, 0.12)
	tw.parallel().tween_property(btn, "offset_bottom", dy, 0.12)
	tw.tween_interval(0.55)
	tw.tween_property(btn, "offset_left", 0.0, 0.18)
	tw.parallel().tween_property(btn, "offset_right", 0.0, 0.18)
	tw.parallel().tween_property(btn, "offset_top", 0.0, 0.18)
	tw.parallel().tween_property(btn, "offset_bottom", 0.0, 0.18)
	tw.tween_callback(func() -> void: btn.remove_meta("dodging"))

func _tick_fake_button(delta: float, inf: int) -> void:
	if is_instance_valid(fake_row):
		fake_timer -= delta
		if fake_timer <= 0.0 or inf < 80:
			fake_row.queue_free()
			fake_row = null
			fake_timer = randf_range(12.0, 20.0)
		return
	if inf >= 80:
		fake_timer -= delta
		if fake_timer <= 0.0:
			fake_timer = 5.5
			var idx := randi() % GameData.BUILDINGS.size()
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(0, 38)
			var fbtn := Button.new()
			fbtn.set_anchors_preset(Control.PRESET_FULL_RECT)
			fbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			fbtn.text = "%s [ERROR 146]  [×%d]" % [GameData.BUILDINGS[idx]["name"], GameState.b[idx]]
			_style_button(fbtn)
			fbtn.pressed.connect(func() -> void:
				GameState.fake_clicks += 1
				flash_red_val = 0.85
				shake_time = 0.25
				voice_lbl.text = "> Fox OS: Доступ запрещен."
				vfx.spawn_floating_text(get_global_mouse_position(), "ДОСТУП ЗАПРЕЩЕН!", Color("#ff1e38"), 1.15)
				if is_instance_valid(fake_row):
					fake_row.queue_free()
					fake_row = null
			)
			holder.add_child(fbtn)
			shop_list.add_child(holder)
			shop_list.move_child(holder, randi() % shop_list.get_child_count())
			fake_row = holder

func _refresh_ui() -> void:
	var ph: int = Economy.phase_of(GameState)
	var tier: int = Economy.tier_of(ph)
	var inf: int = Economy.inf_eff(GameState)
	var greed := float(GameState.fx.get("greed", 0.0)) > 0.0

	sigil_btn.tier = tier
	sigil_btn.infection_pct = inf
	sigil_lbl.text = SIGIL_TITLES[tier - 1]
	phase_lbl.text = "ФАЗА %d/%d: %s" % [ph, GameData.PHASES.size(), GameData.PHASES[ph - 1]["name"].to_upper()]

	coins_lbl.text = "ERR_0x00" if greed else GameState.coins.format_ru()
	var total_cps: BigNum = GameState.get_effective_cps()
	cps_lbl.text = "%s / сек  (×%.2f)" % ["ERR_0x00" if greed else total_cps.format_ru(), Economy.global_mult(GameState)]

	var fx_parts: Array[String] = []
	if GameState.is_buff_active():
		fx_parts.append("[ПЕРЕПОЛНЕНИЕ БУФЕРА ×7]")
	for k: String in GameState.fx.keys():
		fx_parts.append("[%s: %dс]" % [k.to_upper(), int(ceil(float(GameState.fx[k])))])
	fx_lbl.text = "  |  ".join(fx_parts)

	if ph < GameData.PHASES.size():
		var next_edge: BigNum = BigNum.from_float(float(GameData.PHASES[ph]["edge"]))
		phase_bar.value = clampf(GameState.run_earned.div(next_edge).to_float(), 0.0, 1.0)
	else:
		phase_bar.value = 1.0

	# Подсветка активного режима покупки (×1 / ×10 / МАКС)
	for mode: String in amt_btns.keys():
		var ab: Button = amt_btns[mode]
		var is_sel := (mode == GameState.buy_amt)
		ab.add_theme_stylebox_override("normal", sb_btn_active if is_sel else sb_btn_normal)
		ab.add_theme_color_override("font_color", Color.BLACK if is_sel else Color("#ff1e38"))

	var gm: float = Economy.global_mult(GameState)
	for i: int in range(GameData.BUILDINGS.size()):
		var bdata: Dictionary = GameData.BUILDINGS[i]
		var n: int = GameState.amt_for(i)
		var cost: BigNum = Economy.b_cost_n(GameState, i, GameState.b[i], n)
		var unit_cps: BigNum = BigNum.from_float(float(bdata["cps"]) * Economy.b_mult(GameState, i) * gm)
		var row: Dictionary = shop_rows[i]
		var btn: Button = row["btn"]
		var meta: Label = row["meta"]
		btn.text = "%s   [×%d]" % [bdata["name"], GameState.b[i]]
		btn.disabled = not GameState.coins.gte(cost)
		meta.text = "Цена%s: %s · +%s/с" % [
			(" ×%d" % n if n > 1 else ""),
			"ERR_0x00" if greed else cost.format_ru(),
			"ERR_0x00" if greed else unit_cps.format_ru()
		]

	var ups: Array[Dictionary] = GameState.get_available_upgrades()
	var lock_up := float(GameState.fx.get("voidLock", 0.0)) > 0.0
	var sig := ""
	for u: Dictionary in ups:
		sig += u["label"] + "|"
	if sig != last_up_sig:
		last_up_sig = sig
		for child in ups_box.get_children():
			child.queue_free()
		for u: Dictionary in ups:
			var ub := Button.new()
			ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ub.text = "%s — %s\n%s" % [u["label"], u["cost"].format_ru(), u["desc"]]
			_style_button(ub)
			ub.set_meta("cost", u["cost"])
			ub.pressed.connect(func() -> void:
				if GameState.buy_upgrade(u):
					vfx.spawn_purchase_burst(get_global_mouse_position(), "УЛУЧШЕНИЕ УСТАНОВЛЕНО!", true)
			)
			ups_box.add_child(ub)

	for ub: Button in ups_box.get_children():
		var c: BigNum = ub.get_meta("cost")
		ub.disabled = lock_up or not GameState.coins.gte(c)

	myc_lbl.text = "МИЦЕЛИЙ: %d%% (доход ×%.1f)" % [inf, Economy.inf_mult(GameState)]
	myc_bar.value = inf
	var next_myc: BigNum = Economy.myc_cost(GameState)
	spore_btn.text = "МАКС" if inf >= 100 else "Споры (%s)" % ("ERR_0x00" if greed else next_myc.format_ru())
	spore_btn.disabled = GameState.infection >= 100 or not GameState.coins.gte(next_myc)
	purify_btn.text = "БЛОК" if float(GameState.fx.get("purLock", 0.0)) > 0.0 else "Очистить (-50%)"
	purify_btn.disabled = GameState.infection <= 0 or float(GameState.fx.get("purLock", 0.0)) > 0.0
