extends Node

signal changed(key: String)
signal reduce_noise_changed(enabled: bool)

const PATH := "user://fox_settings.cfg"

# Общие / спец. возможности
var screen_shake: float = 0.5      # 0..1
var button_bounce: bool = true
var autoclick_hold: bool = false
# Видео
var reduce_noise: bool = false     # снижает шум, CRT, мерцание
var fullscreen: bool = false
# Аудио
var master_volume: float = 0.8     # 0..1
var sfx_on: bool = true

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		screen_shake = clampf(float(c.get_value("general", "screen_shake", 0.5)), 0.0, 1.0)
		button_bounce = bool(c.get_value("general", "button_bounce", true))
		autoclick_hold = bool(c.get_value("general", "autoclick_hold", false))
		reduce_noise = bool(c.get_value("video", "reduce_noise", false))
		fullscreen = bool(c.get_value("video", "fullscreen", false))
		master_volume = clampf(float(c.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
		sfx_on = bool(c.get_value("audio", "sfx_on", true))
	# Аудио-шины создаёт Audio (автозагрузка после этой), поэтому применяем отложенно
	_apply_all.call_deferred()

func set_value(key: String, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	_apply(key)
	_save()
	changed.emit(key)
	if key == "reduce_noise":
		reduce_noise_changed.emit(reduce_noise)

# Совместимость с Шагом 1
func set_reduce_noise(enabled: bool) -> void:
	set_value("reduce_noise", enabled)

func _apply_all() -> void:
	for k: String in ["fullscreen", "master_volume", "sfx_on"]:
		_apply(k)

func _apply(key: String) -> void:
	match key:
		"fullscreen":
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		"master_volume":
			var bus := AudioServer.get_bus_index("Master")
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
			AudioServer.set_bus_mute(bus, master_volume <= 0.001 or not Audio.sound_on)
		"sfx_on":
			var sfx := AudioServer.get_bus_index("SFX")
			if sfx >= 0:
				AudioServer.set_bus_mute(sfx, not sfx_on)

# Для main.gd (Промт Б): множитель тряски экрана 0..1
func shake_mult() -> float:
	return 0.0 if reduce_noise else screen_shake

func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("general", "screen_shake", screen_shake)
	c.set_value("general", "button_bounce", button_bounce)
	c.set_value("general", "autoclick_hold", autoclick_hold)
	c.set_value("video", "reduce_noise", reduce_noise)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("audio", "master_volume", master_volume)
	c.set_value("audio", "sfx_on", sfx_on)
	c.save(PATH)
