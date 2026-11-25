class_name FoxTheme
extends RefCounted

const BG := Color("#090204")
const PANEL_BG := Color("#0d0305")
const RED := Color("#ff1e38")
const RED_DARK := Color("#c0392b")
const LINE := Color("#4a0e16")
const GOOD := Color("#39ff88")
const ACID := Color("#d6ff3a")

static func panel_style(border_col: Color = RED, bg_col: Color = BG, border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.set_border_width_all(border_w)
	s.border_color = border_col
	s.shadow_color = Color(1.0, 0.05, 0.15, 0.25)
	s.shadow_size = 10
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

static func apply_scrollbar(sb: VScrollBar) -> void:
	if not sb:
		return
	var grab := StyleBoxFlat.new()
	grab.bg_color = RED_DARK
	var grab_h := StyleBoxFlat.new()
	grab_h.bg_color = RED
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#120305")
	sb.add_theme_stylebox_override("grabber", grab)
	sb.add_theme_stylebox_override("grabber_highlight", grab_h)
	sb.add_theme_stylebox_override("grabber_pressed", grab_h)
	sb.add_theme_stylebox_override("scroll", track)

static var _btn_styles: Dictionary = {}
static var _bar_bg: StyleBoxFlat
static var _bar_fill: StyleBoxFlat

static func _ensure_control_styles() -> void:
	if _btn_styles.is_empty():
		_btn_styles["normal"] = panel_style(RED_DARK, Color("#190609"), 2)
		_btn_styles["hover"] = panel_style(RED, Color("#2d0a11"), 2)
		_btn_styles["pressed"] = panel_style(RED, RED_DARK, 2)
		_btn_styles["disabled"] = panel_style(Color("#3a0b10"), PANEL_BG, 2)
		_btn_styles["acid"] = panel_style(ACID, Color("#161c04"), 2)
	if _bar_bg == null:
		_bar_bg = StyleBoxFlat.new()
		_bar_bg.bg_color = Color("#050102")
		_bar_bg.border_color = LINE
		_bar_bg.set_border_width_all(2)
	if _bar_fill == null:
		_bar_fill = StyleBoxFlat.new()
		_bar_fill.bg_color = RED_DARK

static func apply_button(btn: Button, is_acid: bool = false) -> void:
	_ensure_control_styles()
	btn.add_theme_stylebox_override("normal", _btn_styles["acid"] if is_acid else _btn_styles["normal"])
	btn.add_theme_stylebox_override("hover", _btn_styles["hover"])
	btn.add_theme_stylebox_override("pressed", _btn_styles["pressed"])
	btn.add_theme_stylebox_override("disabled", _btn_styles["disabled"])
	btn.add_theme_color_override("font_color", ACID if is_acid else RED)
	btn.add_theme_color_override("font_hover_color", Color("#ff5266"))
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_color_override("font_disabled_color", Color("#6e3b42"))

static func apply_progress_bar(bar: ProgressBar) -> void:
	_ensure_control_styles()
	bar.add_theme_stylebox_override("background", _bar_bg)
	bar.add_theme_stylebox_override("fill", _bar_fill)
