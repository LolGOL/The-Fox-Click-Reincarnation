extends Node

var _last_min: int = -1
var _secret_done: bool = false
var _away: bool = false

func _ready() -> void:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var h: int = int(dt.get("hour", 12))
	if h >= 0 and h < 5:
		Fox.say_forced("%d утра, оператор. Ты вообще спишь?" % h if h > 0 else "Полночь. Самое время для взлома.")

func _process(_delta: float) -> void:
	var t: Dictionary = Time.get_datetime_dict_from_system()
	var m: int = int(t.get("minute", 0))
	var h: int = int(t.get("hour", 0))
	if m == _last_min:
		return
	_last_min = m
	if h == 3 and m == 33 and not _secret_done:
		_secret_done = true
		Fox.say_forced("03:33. Кто-то смотрит изнутри монитора.")
		Achievements.try_unlock_by_key("0333")
		Audio.play_sfx("error")
	elif not (h == 3 and m == 33):
		_secret_done = false

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_away = true
			DisplayServer.window_set_title("…не уходи…")
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _away:
				_away = false
				DisplayServer.window_set_title("The Fox Click Reincarnation")
				Fox.say_forced("…ты вернулся. Я считал секунды.")
