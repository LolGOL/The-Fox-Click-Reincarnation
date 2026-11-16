extends Node

signal say(text: String)

enum S { IDLE, TALKING, SLEEPING }

var state: S = S.IDLE
var muted: bool = false
var _afk: float = 0.0
var _taunt_cd: float = 35.0
const AFK_SLEEP := 45.0

var poke_lines: Array[String] = [
	"Ай! Не тыкай в меня, кнопка по центру!",
	"Опять ты? Курсор некуда деть?",
	"Фыр-р-р! Осторожнее, откушу палец.",
	"Щёлк. Щёлк. Щёлк. Иди монеты добывай!"
]
var taunt_lines: Array[String] = [
	"Ты всё ещё здесь? Нажимай центральную печать!",
	"Грибница растёт, а твой счётчик стоит на месте.",
	"Мицелий помнит каждый твой клик...",
	"Слева целый магазин ждёт, не маринуй монеты!"
]
var sleep_lines: Array[String] = [
	"zZz... [РЕЖИМ СНА: 0x00]... разбуди кликом...",
	"Хр-р-р... снится, как я жру дата-центр..."
]

func _ready() -> void:
	GameState.phase_changed.connect(func(p: int) -> void:
		say_forced("ЭВОЛЮЦИЯ // Фаза %d: «%s»!" % [p, GameData.PHASES[p - 1]["name"]])
	)

func _process(delta: float) -> void:
	_afk += delta
	_taunt_cd -= delta
	if _afk > AFK_SLEEP and state != S.SLEEPING:
		state = S.SLEEPING
		say_forced(sleep_lines[randi() % sleep_lines.size()])
	if _taunt_cd <= 0.0:
		_taunt_cd = randf_range(35.0, 75.0)
		if state != S.SLEEPING:
			_talk(taunt_lines[randi() % taunt_lines.size()])

func on_activity() -> void:
	_afk = 0.0
	if state == S.SLEEPING:
		state = S.IDLE
		_talk("А?! Я не спал, я патрулировал кэш!")

func on_poke() -> void:
	on_activity()
	_talk(poke_lines[randi() % poke_lines.size()])

func set_muted(m: bool) -> void:
	muted = m

func say_forced(t: String) -> void:
	if not muted:
		say.emit(t)

func _talk(t: String) -> void:
	if not muted:
		say.emit(t)
