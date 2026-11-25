class_name DealModal
extends ColorRect

signal accepted(deal: Dictionary)
signal rejected(timed_out: bool)

const DEAL_DURATION := 30.0

@onready var _panel: PanelContainer = %PanelContainer
@onready var _title_label: Label = %TitleLabel
@onready var _name_label: Label = %NameLabel
@onready var _reward_label: Label = %RewardLabel
@onready var _curse_label: Label = %CurseLabel
@onready var _timer_bar: ProgressBar = %TimerBar
@onready var _accept_button: Button = %AcceptButton
@onready var _reject_button: Button = %RejectButton

var _current_deal: Dictionary = {}
var _time_left: float = 0.0

func _ready() -> void:
	visible = false
	set_process(false)

	_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(FoxTheme.RED, Color.BLACK, 4))
	_title_label.add_theme_color_override("font_color", FoxTheme.RED)
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_reward_label.add_theme_color_override("font_color", FoxTheme.GOOD)
	_curse_label.add_theme_color_override("font_color", Color("#ff5266"))

	FoxTheme.apply_progress_bar(_timer_bar)
	FoxTheme.apply_button(_accept_button)
	FoxTheme.apply_button(_reject_button)

	_accept_button.pressed.connect(_on_accept_pressed)
	_reject_button.pressed.connect(_on_reject_pressed)

func open(deal: Dictionary) -> bool:
	if visible:
		return false
	_current_deal = deal
	_time_left = DEAL_DURATION
	_name_label.text = str(deal.get("name", ""))
	_reward_label.text = "НАГРАДА: " + str(deal.get("rew", ""))
	_curse_label.text = "ПРОКЛЯТИЕ: " + str(deal.get("cur", ""))
	_timer_bar.value = 1.0
	visible = true
	set_process(true)
	return true

func _process(delta: float) -> void:
	_time_left -= delta
	_timer_bar.value = clampf(_time_left / DEAL_DURATION, 0.0, 1.0)
	if _time_left <= 0.0:
		_close()
		rejected.emit(true)

func _close() -> void:
	visible = false
	set_process(false)

func _on_accept_pressed() -> void:
	var deal := _current_deal
	_close()
	accepted.emit(deal)

func _on_reject_pressed() -> void:
	_close()
	rejected.emit(false)
