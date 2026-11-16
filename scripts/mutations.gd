extends Node

signal choices_offered(options: Array[String])
signal glitch_changed(active_glitches: Array[String])

const POOL: Dictionary = {
	"bin_shop":   { "name": "Двоичный магазин",  "desc": "+25% к модулям | Искажение цен",      "bld": 1.25, "clk": 1.0,  "glitch": "binary_shop" },
	"spore_fist": { "name": "Споровый кулак",    "desc": "+45% к клику | Дрожь интерфейса",     "bld": 1.0,  "clk": 1.45, "glitch": "ui_jitter" },
	"hyphae":     { "name": "Кровавые гифы",     "desc": "+18% ко всему | Красный сканлайн",    "bld": 1.18, "clk": 1.18, "glitch": "red_scan" },
	"rot":        { "name": "Гниль ядра",        "desc": "+50% к модулям, -15% клик | Хрома",   "bld": 1.50, "clk": 0.85, "glitch": "chroma" },
	"echo":       { "name": "Резонансное эхо",   "desc": "+65% к клику, -15% модули | Мерцание","bld": 0.85, "clk": 1.65, "glitch": "echo" },
	"swarm":      { "name": "Рой ботнета",       "desc": "+35% к модулям | Побег кнопок",       "bld": 1.35, "clk": 1.0,  "glitch": "dodge_shop" },
	"fang_code":  { "name": "Клыкастый код",     "desc": "+55% к клику | Разрывы экрана",       "bld": 1.0,  "clk": 1.55, "glitch": "tear" },
	"symbiosis":  { "name": "Полный симбиоз",    "desc": "+30% ко всему | Пульс ядра",          "bld": 1.30, "clk": 1.30, "glitch": "pulse" },
	"void_spore": { "name": "Споры Пустоты",     "desc": "+40% к модулям и клику | Тьма",       "bld": 1.40, "clk": 1.40, "glitch": "dark_vignette" }
}

var active: Array[String] = []

func _ready() -> void:
	GameState.infection_step.connect(func(_step: int) -> void: offer())

func offer() -> void:
	var ids: Array[String] = []
	for k: String in POOL.keys():
		if not (k in active):
			ids.append(k)
	ids.shuffle()
	if not ids.is_empty():
		choices_offered.emit(ids.slice(0, mini(3, ids.size())))

func pick(id: String) -> void:
	if POOL.has(id) and not (id in active):
		active.append(id)
		_emit_glitches()
		GameState.state_changed.emit()

func purge() -> void:
	active.clear()
	_emit_glitches()

func load_active(arr: Array) -> void:
	active.clear()
	for item in arr:
		var s := str(item)
		if POOL.has(s):
			active.append(s)
	_emit_glitches()

func _emit_glitches() -> void:
	var list: Array[String] = []
	for id: String in active:
		list.append(str(POOL[id]["glitch"]))
	glitch_changed.emit(list)

func has_glitch(g: String) -> bool:
	for id: String in active:
		if POOL[id]["glitch"] == g:
			return true
	return false

func building_mult() -> float:
	var m := 1.0
	for id: String in active:
		m *= float(POOL[id]["bld"])
	return m

func click_mult() -> float:
	var m := 1.0
	for id: String in active:
		m *= float(POOL[id]["clk"])
	return m
