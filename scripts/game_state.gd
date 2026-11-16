extends Node

signal state_changed
signal phase_changed(new_phase: int, phase_data: Dictionary)
signal voice_logged(text: String)

var coins: BigNum = BigNum.zero()
var run_earned: BigNum = BigNum.zero()
var life_earned: BigNum = BigNum.zero()
var max_coins: BigNum = BigNum.zero()

var run_sec: float = 0.0
var total_sec: float = 0.0
var clicks: int = 0
var manual_clicks: int = 0

var b: Array[int] = []
var b_up: Array = []
var cu: Dictionary = {}
var infection: int = 0

var shards: int = 0
var free_shards: int = 0
var spent: int = 0
var tree: Dictionary = {}
var reinc: int = 0

var fx: Dictionary = {}
var perks: Dictionary = {}
var buy_amt: String = "1"
var buff_until: float = 0.0
var last_phase: int = 1
var click_win: Array[float] = []

func _ready() -> void:
	reset_run_data()
	load_game()
	last_phase = Economy.phase_of(self)
	voice_logged.emit(GameData.PHASES[last_phase - 1]["log"])

func reset_run_data() -> void:
	coins = BigNum.zero()
	run_earned = BigNum.zero()
	b.clear()
	b_up.clear()
	for _i in range(GameData.BUILDINGS.size()):
		b.append(0)
		b_up.append([])
	cu.clear()
	for u: Dictionary in GameData.SYSTEM_UPS:
		cu[u["k"]] = false
	infection = 0
	fx.clear()
	click_win.clear()

func is_buff_active() -> bool:
	return Time.get_unix_time_from_system() < buff_until

func earn(amount: BigNum) -> void:
	if is_zero_approx(amount.mantissa) or amount.mantissa < 0.0:
		return
	coins = coins.add(amount)
	run_earned = run_earned.add(amount)
	life_earned = life_earned.add(amount)
	if coins.gte(max_coins):
		max_coins = coins.copy()
	var ph: int = Economy.phase_of(self)
	if ph > last_phase:
		last_phase = ph
		var pdata: Dictionary = GameData.PHASES[ph - 1]
		voice_logged.emit(pdata["log"])
		phase_changed.emit(ph, pdata)

func do_click() -> Dictionary:
	var now: float = Time.get_unix_time_from_system()
	clicks += 1
	manual_clicks += 1

	var cap: int = GameData.CLICK_CAP + int(perks.get("clickCapAdd", 0))
	while not click_win.is_empty() and now - click_win[0] > 1.0:
		click_win.pop_front()

	var gain: BigNum = BigNum.from_float(Economy.click_base(self))
	var pct: float = Economy.click_pct(self)
	if pct > 0.0 and click_win.size() < cap:
		click_win.append(now)
		gain = gain.add(Economy.cps(self, is_buff_active()).mul_float(pct))

	gain = gain.mul_float(1.0 + float(perks.get("clickMult", 0.0)))

	var crit_chance: float = minf(0.75, float(perks.get("critChance", 0.0)))
	var is_crit: bool = crit_chance > 0.0 and randf() < crit_chance
	var crit_mult: float = 1.0
	if is_crit:
		crit_mult = GameData.CRIT_BASE + float(perks.get("critMultAdd", 0.0))
		gain = gain.mul_float(crit_mult)

	earn(gain)
	state_changed.emit()
	return { "gain": gain, "is_crit": is_crit, "crit_mult": crit_mult }

func amt_for(i: int) -> int:
	if buy_amt == "max":
		return maxi(1, Economy.max_affordable(self, i, b[i], coins))
	return int(buy_amt)

func buy_building(i: int) -> bool:
	var n: int = amt_for(i)
	var cost: BigNum = Economy.b_cost_n(self, i, b[i], n)
	if not coins.gte(cost):
		return false
	coins = coins.sub(cost)
	b[i] += n
	state_changed.emit()
	return true

func get_available_upgrades() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var up_red: float = 1.0 - minf(0.6, float(perks.get("upCostRed", 0.0)))
	for u: Dictionary in GameData.SYSTEM_UPS:
		var k: String = u["k"]
		if bool(cu.get(k, false)):
			continue
		var req: String = u["req"]
		if req != "" and not bool(cu.get(req, false)):
			continue
		list.append({
			"type": "sys",
			"key": k,
			"label": u["name"],
			"desc": u["desc"],
			"cost": BigNum.from_float(float(u["cost"]) * up_red)
		})
	for i: int in range(GameData.BUILDINGS.size()):
		for ti: int in range(GameData.UP_TH.size()):
			var th: int = GameData.UP_TH[ti]
			if b[i] >= th and not (th in b_up[i]):
				list.append({
					"type": "bld",
					"bld_idx": i,
					"th": th,
					"label": "%s — %s (%d шт)" % [GameData.BUILDINGS[i]["name"], GameData.UP_TIER[ti], th],
					"desc": "Доход этого здания ×%.1f" % (2.0 + float(perks.get("upBonus", 0.0))),
					"cost": Economy.up_cost(self, i, th)
				})
	list.sort_custom(func(a: Dictionary, b_item: Dictionary) -> bool:
		return not a["cost"].gte(b_item["cost"])
	)
	return list

func buy_upgrade(up: Dictionary) -> bool:
	var cost: BigNum = up["cost"]
	if not coins.gte(cost):
		return false
	coins = coins.sub(cost)
	if up["type"] == "sys":
		cu[up["key"]] = true
	else:
		b_up[int(up["bld_idx"])].append(int(up["th"]))
	state_changed.emit()
	return true

func buy_spore() -> bool:
	if infection >= 100:
		return false
	var cost: BigNum = Economy.myc_cost(self)
	if not coins.gte(cost):
		return false
	coins = coins.sub(cost)
	infection = mini(100, infection + 20)
	state_changed.emit()
	return true

func purify() -> bool:
	if infection <= 0:
		return false
	coins = coins.mul_float(1.0 - GameData.PURIFY_FRAC)
	infection = 0
	state_changed.emit()
	return true

func step(dt: float) -> void:
	run_sec += dt
	total_sec += dt
	earn(Economy.cps(self, is_buff_active()).mul_float(dt))
	state_changed.emit()

func save_game() -> void:
	var data := {
		"ver": GameData.VERSION,
		"coins": coins.to_dict(),
		"run_earned": run_earned.to_dict(),
		"life_earned": life_earned.to_dict(),
		"max_coins": max_coins.to_dict(),
		"run_sec": run_sec,
		"total_sec": total_sec,
		"clicks": clicks,
		"manual_clicks": manual_clicks,
		"b": b,
		"b_up": b_up,
		"cu": cu,
		"infection": infection,
		"shards": shards,
		"free_shards": free_shards,
		"reinc": reinc
	}
	var f := FileAccess.open(GameData.SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(GameData.SAVE_PATH):
		return
	var f := FileAccess.open(GameData.SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	coins = BigNum.from_dict(parsed.get("coins"))
	run_earned = BigNum.from_dict(parsed.get("run_earned"))
	life_earned = BigNum.from_dict(parsed.get("life_earned"))
	max_coins = BigNum.from_dict(parsed.get("max_coins"))
	run_sec = float(parsed.get("run_sec", 0.0))
	total_sec = float(parsed.get("total_sec", 0.0))
	clicks = int(parsed.get("clicks", 0))
	manual_clicks = int(parsed.get("manual_clicks", 0))
	infection = int(parsed.get("infection", 0))
	shards = int(parsed.get("shards", 0))
	free_shards = int(parsed.get("free_shards", 0))
	reinc = int(parsed.get("reinc", 0))
	var saved_b: Array = parsed.get("b", [])
	for i: int in range(mini(b.size(), saved_b.size())):
		b[i] = int(saved_b[i])
	var saved_cu: Dictionary = parsed.get("cu", {})
	for k: String in cu.keys():
		cu[k] = bool(saved_cu.get(k, false))
