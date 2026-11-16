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
