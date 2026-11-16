extends Node2D

var coins_lbl: Label
var cps_lbl: Label
var phase_lbl: Label
var voice_lbl: Label
var phase_bar: ProgressBar
var myc_lbl: Label
var myc_bar: ProgressBar
var spore_btn: Button
var purify_btn: Button
var shop_rows: Array[Dictionary] = []
var ups_box: VBoxContainer
var amt_btns: Dictionary = {}
var last_up_sig: String = ""

func _ready() -> void:
	_build_ui()
	GameState.state_changed.connect(_refresh_ui)
	GameState.voice_logged.connect(func(txt: String) -> void:
		voice_lbl.text = "> Fox OS: " + txt
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

func _make_box_style(bg: Color, border: Color, radius: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_box_style(Color("#190609"), Color("#c0392b")))
	btn.add_theme_stylebox_override("hover", _make_box_style(Color("#2d0a11"), Color("#ff1e38")))
	btn.add_theme_stylebox_override("pressed", _make_box_style(Color("#c0392b"), Color("#ff1e38")))
	btn.add_theme_color_override("font_color", Color("#ff1e38"))
	btn.add_theme_color_override("font_hover_color", Color("#ff5266"))
	btn.add_theme_color_override("font_pressed_color", Color("#000000"))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color("#030102")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 6)
	layer.add_child(root_vbox)

	# Шапка
	var hdr := PanelContainer.new()
	hdr.add_theme_stylebox_override("panel", _make_box_style(Color("#0c0204"), Color("#c0392b")))
	root_vbox.add_child(hdr)

	var hdr_hbox := HBoxContainer.new()
	hdr.add_child(hdr_hbox)

	var title := Label.new()
	title.text = "FOX OS // THE FOX REINCARNATION (GODOT PORT)"
	title.add_theme_color_override("font_color", Color("#ff1e38"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(title)

	phase_lbl = Label.new()
	phase_lbl.add_theme_color_override("font_color", Color("#c0392b"))
	hdr_hbox.add_child(phase_lbl)

	# Голос Fox OS
	var voice_panel := PanelContainer.new()
	voice_panel.add_theme_stylebox_override("panel", _make_box_style(Color("#090204"), Color("#4a0e16")))
	root_vbox.add_child(voice_panel)

	voice_lbl = Label.new()
	voice_lbl.text = "> Fox OS: Заработай. Возвысься. Стань мной."
	voice_lbl.add_theme_color_override("font_color", Color("#ff1e38"))
	voice_panel.add_child(voice_lbl)

	# 3-колоночная сетка
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	root_vbox.add_child(cols)

	# === ЛЕВАЯ КОЛОНКА: МАГАЗИН ===
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.15
	left_panel.add_theme_stylebox_override("panel", _make_box_style(Color("#090406"), Color("#4a0e16")))
	cols.add_child(left_panel)

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

	var shop_list := VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 6)
	shop_scroll.add_child(shop_list)

	for i: int in range(GameData.BUILDINGS.size()):
		var row_box := VBoxContainer.new()
		shop_list.add_child(row_box)

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(btn)
		btn.pressed.connect(func() -> void: GameState.buy_building(i))
		row_box.add_child(btn)

		var meta := Label.new()
		meta.add_theme_color_override("font_color", Color("#926870"))
		meta.add_theme_font_size_override("font_size", 12)
		row_box.add_child(meta)

		shop_rows.append({ "btn": btn, "meta": meta })

	# === ЦЕНТРАЛЬНАЯ КОЛОНКА: ЯДРО И КНОПКА ===
	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 1.25
	center_panel.add_theme_stylebox_override("panel", _make_box_style(Color("#0c0305"), Color("#c0392b")))
	cols.add_child(center_panel)

	var center_vbox := VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 14)
	center_panel.add_child(center_vbox)

	coins_lbl = Label.new()
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.add_theme_font_size_override("font_size", 40)
	coins_lbl.add_theme_color_override("font_color", Color("#ff1e38"))
	center_vbox.add_child(coins_lbl)

	cps_lbl = Label.new()
	cps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cps_lbl.add_theme_color_override("font_color", Color("#ecd9dc"))
	center_vbox.add_child(cps_lbl)

	var btn_center := CenterContainer.new()
	btn_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(btn_center)

	var click_btn := Button.new()
	click_btn.text = "КЛИК // 146"
	click_btn.custom_minimum_size = Vector2(190, 190)
	click_btn.add_theme_stylebox_override("normal", _make_box_style(Color("#910b1c"), Color("#ff5268"), 95))
	click_btn.add_theme_stylebox_override("hover", _make_box_style(Color("#b81126"), Color("#ff8a98"), 95))
	click_btn.add_theme_stylebox_override("pressed", _make_box_style(Color("#54040e"), Color("#ffffff"), 95))
	click_btn.add_theme_color_override("font_color", Color.WHITE)
	click_btn.add_theme_font_size_override("font_size", 18)
	click_btn.pressed.connect(func() -> void: GameState.do_click())
	btn_center.add_child(click_btn)

	# Блок мицелия внизу центральной колонки
	var myc_box := VBoxContainer.new()
	center_vbox.add_child(myc_box)

	myc_lbl = Label.new()
	myc_lbl.add_theme_color_override("font_color", Color("#c0392b"))
	myc_box.add_child(myc_lbl)

	myc_bar = ProgressBar.new()
	myc_bar.max_value = 100.0
	myc_bar.show_percentage = false
	myc_bar.custom_minimum_size = Vector2(0, 14)
	myc_box.add_child(myc_bar)

	var myc_btns := HBoxContainer.new()
	myc_box.add_child(myc_btns)

	spore_btn = Button.new()
	spore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(spore_btn)
	spore_btn.pressed.connect(GameState.buy_spore)
	myc_btns.add_child(spore_btn)

	purify_btn = Button.new()
	purify_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(purify_btn)
	purify_btn.pressed.connect(GameState.purify)
	myc_btns.add_child(purify_btn)

	# === ПРАВАЯ КОЛОНКА: УЛУЧШЕНИЯ И ПРОГРЕСС ФАЗЫ ===
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.1
	right_panel.add_theme_stylebox_override("panel", _make_box_style(Color("#090406"), Color("#4a0e16")))
	cols.add_child(right_panel)

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
	right_vbox.add_child(phase_bar)

func _refresh_ui() -> void:
	var ph: int = Economy.phase_of(GameState)
	var ph_data: Dictionary = GameData.PHASES[ph - 1]
	phase_lbl.text = "ФАЗА %d/%d: %s" % [ph, GameData.PHASES.size(), ph_data["name"].to_upper()]

	coins_lbl.text = GameState.coins.format_ru()
	var total_cps: BigNum = Economy.cps(GameState, GameState.is_buff_active())
	cps_lbl.text = "%s / сек  (×%.2f)" % [total_cps.format_ru(), Economy.global_mult(GameState)]

	if ph < GameData.PHASES.size():
		var next_edge: BigNum = BigNum.from_float(float(GameData.PHASES[ph]["edge"]))
		phase_bar.value = clampf(GameState.run_earned.div(next_edge).to_float(), 0.0, 1.0)
	else:
		phase_bar.value = 1.0

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
		meta.text = "Цена%s: %s · +%s/с" % [(" ×%d" % n if n > 1 else ""), cost.format_ru(), unit_cps.format_ru()]

	var ups: Array[Dictionary] = GameState.get_available_upgrades()
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
			ub.pressed.connect(func() -> void: GameState.buy_upgrade(u))
			ups_box.add_child(ub)

	for ub: Button in ups_box.get_children():
		var c: BigNum = ub.get_meta("cost")
		ub.disabled = not GameState.coins.gte(c)

	myc_lbl.text = "МИЦЕЛИЙ: %d%% (доход ×%.1f)" % [GameState.infection, Economy.inf_mult(GameState)]
	myc_bar.value = GameState.infection
	var next_myc: BigNum = Economy.myc_cost(GameState)
	spore_btn.text = "МАКС" if GameState.infection >= 100 else "Споры (%s)" % next_myc.format_ru()
	spore_btn.disabled = GameState.infection >= 100 or not GameState.coins.gte(next_myc)
	purify_btn.text = "Очистить (-50%)"
	purify_btn.disabled = GameState.infection <= 0
