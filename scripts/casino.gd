extends Node

signal spin_started(bet: int)
signal spin_resolved(result: Dictionary)
signal ear_twitch
signal clue_found(total_clues: int)

const TWITCH_WINDOW := 0.4
const PITY_LIMIT := 6
const TABLE := [[0.0, 0.58], [1.0, 0.17], [2.0, 0.16], [5.0, 0.07], [10.0, 0.02]]

var rng := RandomNumberGenerator.new()
var pending: Dictionary = {}
var loss_streak: int = 0
var clues: int = 0
var twitch_open: bool = false
var _spin_token: int = 0

func _ready() -> void:
	rng.randomize()

func get_state() -> Dictionary:
	return { "pending": pending, "loss_streak": loss_streak, "clues": clues }

func load_state(d: Dictionary) -> void:
	loss_streak = int(d.get("loss_streak", 0))
	clues = int(d.get("clues", 0))
	var saved_pending: Dictionary = d.get("pending", {})
	# Если игрок закрыл/перезагрузил игру посреди вращения (anti-F5), ставка уже сгорела
	pending = {}
	if not saved_pending.is_empty():
		loss_streak += 1

func spin(bet: int) -> bool:
	if not pending.is_empty() or bet <= 0 or GameState.spores < bet:
		Audio.play_sfx("error")
		return false
	GameState.spores -= bet
	var mult := _roll()
	if mult == 0.0 and loss_streak >= PITY_LIMIT:
		mult = 1.0 if rng.randf() < 0.7 else 2.0
	loss_streak = (loss_streak + 1) if mult == 0.0 else 0
	pending = { "bet": bet, "mult": mult }
	GameState.save_game()
	GameState.state_changed.emit()

	_spin_token += 1
	var token := _spin_token
	spin_started.emit(bet)

	if mult == 0.0:
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if token == _spin_token:
				_open_twitch(token)
		)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if token == _spin_token:
			_finish()
	)
	return true

func _roll() -> float:
	var r := rng.randf()
	var acc := 0.0
	for row in TABLE:
		acc += float(row[1])
		if r < acc:
			return float(row[0])
	return 0.0

func _open_twitch(token: int) -> void:
	if pending.is_empty():
		return
	twitch_open = true
	Audio.duck_for_twitch(0.5)
	Audio.play_sfx("twitch")
	ear_twitch.emit()
	get_tree().create_timer(TWITCH_WINDOW).timeout.connect(func() -> void:
		if token == _spin_token:
			twitch_open = false
	)

func on_fox_ear_clicked() -> bool:
	if twitch_open and not pending.is_empty():
		twitch_open = false
		_spin_token += 1
		var bet := int(pending["bet"])
		GameState.spores += bet * 2
		clues += 1
		pending = {}
		Audio.play_sfx("win")
		Fox.say_forced("Ч-что?! Ты заметил?! Ладно, забирай двойную ставку, глазастый...")
		clue_found.emit(clues)
		Achievements.try_unlock_by_key("clue")
		GameState.save_game()
		GameState.state_changed.emit()
		spin_resolved.emit({ "bet": bet, "mult": 2.0, "win": bet * 2, "busted": true })
		return true
	return false

func _finish() -> void:
	if pending.is_empty():
		return
	var bet := int(pending["bet"])
	var mult := float(pending["mult"])
	var win := int(round(float(bet) * mult))
	GameState.spores += win
	var res := { "bet": bet, "mult": mult, "win": win, "busted": false }
	pending = {}
	Audio.play_sfx("win" if win > 0 else "error")
	GameState.save_game()
	GameState.state_changed.emit()
	spin_resolved.emit(res)

func offer_via_fox() -> void:
	Fox.say_forced("Затык в экономике? Сыграем в Casino.exe на споры... Я сегодня честный. Почти.")
