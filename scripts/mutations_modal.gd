class_name MutationsModal
extends ColorRect

signal mutation_picked(id: String, info: Dictionary)
signal closed

@onready var _panel: PanelContainer = %PanelContainer
@onready var _title_label: Label = %TitleLabel
@onready var _cards_box: VBoxContainer = %CardsBox

func _ready() -> void:
	visible = false
	set_process(false)

	_panel.add_theme_stylebox_override("panel", FoxTheme.panel_style(FoxTheme.RED, Color("#090103"), 3))
	_title_label.add_theme_color_override("font_color", FoxTheme.RED)

	if not Mutations.choices_offered.is_connected(open):
		Mutations.choices_offered.connect(open)

func _exit_tree() -> void:
	if Mutations.choices_offered.is_connected(open):
		Mutations.choices_offered.disconnect(open)

func open(options: Array[String]) -> void:
	for ch: Node in _cards_box.get_children():
		ch.queue_free()

	for id: String in options:
		var info: Dictionary = Mutations.POOL[id]
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text = "%s\n%s" % [info["name"], info["desc"]]
		FoxTheme.apply_button(btn, true)
		btn.pressed.connect(_on_card_pressed.bind(id, info))
		_cards_box.add_child(btn)

	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	closed.emit()

func _on_card_pressed(id: String, info: Dictionary) -> void:
	Mutations.pick(id)
	close()
	mutation_picked.emit(id, info)
