extends Node

signal reduce_noise_changed(enabled: bool)

const PATH := "user://fox_settings.cfg"

var reduce_noise: bool = false

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		reduce_noise = bool(c.get_value("visual", "reduce_noise", false))

func set_reduce_noise(enabled: bool) -> void:
	if reduce_noise == enabled:
		return
	reduce_noise = enabled
	_save()
	reduce_noise_changed.emit(enabled)

func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("visual", "reduce_noise", reduce_noise)
	c.save(PATH)
