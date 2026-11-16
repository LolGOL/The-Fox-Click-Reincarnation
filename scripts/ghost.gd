extends Node

const PATH := "user://ghost.cfg"

signal delta_ready(delta_sec: float)
signal ghost_beaten(bonus_shards: int)

var best: Dictionary = {}

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK and c.has_section("best"):
		for k: String in c.get_section_keys("best"):
			best[int(k)] = float(c.get_value("best", k))
	GameState.phase_completed.connect(on_phase_end)

func ghost_time(phase: int) -> float:
	return float(best.get(phase, -1.0))

func _process(_delta: float) -> void:
	var g := ghost_time(GameState.last_phase)
	if g < 0.0:
		return
	delta_ready.emit(GameState.phase_time - g)

func on_phase_end(phase: int, t: float) -> void:
	var g := ghost_time(phase)
	if g > 0.0 and t < g:
		var pct := randf_range(0.10, 0.25)
		var bonus := maxi(1, int(round(float(GameState.shards + 1) * pct)))
		GameState.free_shards += bonus
		ghost_beaten.emit(bonus)
	if g < 0.0 or t < g:
		best[phase] = t
		var c := ConfigFile.new()
		for k: int in best.keys():
			c.set_value("best", str(k), best[k])
		c.save(PATH)

static func fmt(sec: float) -> String:
	var s := int(absf(sec))
	return "%s%d:%02d" % ["-" if sec < 0.0 else "+", s / 60, s % 60]
