extends Node

signal state_changed
signal phase_changed(new_phase: int)
signal phase_completed(finished_phase: int, elapsed_sec: float)
signal infection_step(step: int)
signal stall_detected
signal voice_logged(text: String)
signal deal_requested(deal: Dictionary)
signal glitch_spawn_requested(count: int)
signal screen_flash_requested(intensity: float, shake: bool)

const STALL_SECONDS := 180.0

const DEALS: Array[Dictionary] = [
	{ "id": "over",     "name": "Кровавый оверклокинг", "rew": "×4 к пассивному доходу на 4 мин.",            "cur": "Экран переходит в жёсткий 1-битный ч/б режим." },
	{ "id": "eater",    "name": "Пожиратель курсора",   "rew": "×10 к силе клика на 2 мин.",                  "cur": "Кнопки магазина убегают от курсора при наведении." },
	{ "id": "myc",      "name": "Мицелиевый шок",       "rew": "Мицелий мгновенно 100% на 3 мин.",            "cur": "Кнопка «Очищение» заблокирована на 5 мин." },
	{ "id": "sac",      "name": "Жертва паствы",        "rew": "Мгновенно: 15 минут текущего CPS.",            "cur": "Сжигает 20% самого дорогого купленного здания." },
	{ "id": "greed",    "name": "Слепая жадность",      "rew": "×3 ко всему доходу на 6 мин.",                "cur": "Все числа и цены заменены на ERR_0x00." },
	{ "id": "spam",     "name": "Вирусный спам",        "rew": "Мгновенно: 5 глитч-артефактов 146.",           "cur": "Штраф за пропуск глитча растёт с 5% до 15%." },
	{ "id": "rollback", "name": "Откат ядра",           "rew": "Стоимость всех зданий −35% на 3 мин.",        "cur": "Пассивный доход падает до 0 (только клики)." },
	{ "id": "phantom",  "name": "Фантомная боль",       "rew": "10% шанс критического удара ×250.",           "cur": "Каждый клик без крита сжигает 0.5% монет." },
	{ "id": "void",     "name": "Сделка с Пустотой",    "rew": "Мгновенно: +25% к монетам забега.",           "cur": "Улучшения заблокированы на 10 мин." },
	{ "id": "agony",    "name": "Агония Fox OS",        "rew": "×6.66 ко всему доходу на 66 сек.",            "cur": "После баффа: −50% ко всему доходу на 5 мин." }
]

var coins: BigNum = BigNum.zero()
var run_earned: BigNum = BigNum.zero()
var life_earned: BigNum = BigNum.zero()
var max_coins: BigNum = BigNum.zero()

var spores: int = 3
var shards: int = 0
var free_shards: int = 0
var spent: int = 0
var tree: Dictionary = {}
var reinc: int = 0

var run_sec: float = 0.0
var total_sec: float = 0.0
var phase_time: float = 0.0
var clicks: int = 0
var manual_clicks: int = 0
var fake_clicks: int = 0

var b: Array[int] = []
var b_up: Array = []
var cu: Dictionary = {}
var infection: int = 0
var infection_steps_done: int = 0

var fx: Dictionary = {}
var perks: Dictionary = {}
var buy_amt: String = "1"
var buff_until: float = 0.0
var last_phase: int = 1
var deal_timer: float = 0.0
var glitch_timer: float = 45.0
var click_win: Array[float] = []

var _stall_cd: float = 2.0
var _stall_offered: bool = false

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
	infection_steps_done = 0
	phase_time = 0.0
	fx.clear()
	click_win.clear()

func is_buff_active() -> bool:
	return Time.get_unix_time_from_system() < buff_until

func get_effective_cps() -> BigNum:
	if float(fx.get("rollback", 0.0)) > 0.0:
		return BigNum.zero()
	var base: BigNum = Economy.cps(self, is_buff_active())
	var mult := 1.0
	if float(fx.get("over", 0.0)) > 0.0:
		mult *= 4.0
	if float(fx.get("greed", 0.0)) > 0.0:
		mult *= 3.0
	if float(fx.get("agony", 0.0)) > 0.0:
		mult *= 6.66
	if float(fx.get("agonyDebuff", 0.0)) > 0.0:
		mult *= 0.5
	return base.mul_float(mult)

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
		var finished_p := last_phase
		var elapsed := phase_time
		last_phase = ph
		phase_time = 0.0
		spores += 3
		phase_completed.emit(finished_p, elapsed)
		phase_changed.emit(ph)
		var pdata: Dictionary = GameData.PHASES[ph - 1]
		voice_logged.emit(pdata["log"])
		screen_flash_requested.emit(1.0, true)
		if ph >= 5:
			Achievements.try_unlock_by_key("phase_5")
		if ph >= 10:
			Achievements.try_unlock_by_key("phase_10")
		if ph >= 16:
			Achievements.try_unlock_by_key("phase_16")

func do_click() -> Dictionary:
	var now: float = Time.get_unix_time_from_system()
	clicks += 1
	manual_clicks += 1
	if manual_clicks == 1:
		Achievements.try_unlock_by_key("first_click")
	if manual_clicks % 15 == 0:
		spores += 1

	var cap: int = GameData.CLICK_CAP + int(perks.get("clickCapAdd", 0))
	while not click_win.is_empty() and now - click_win[0] > 1.0:
		click_win.pop_front()

	var gain: BigNum = BigNum.from_float(Economy.click_base(self))
	var pct: float = Economy.click_pct(self)
	if pct > 0.0 and click_win.size() < cap:
		click_win.append(now)
		gain = gain.add(get_effective_cps().mul_float(pct))

	gain = gain.mul_float((1.0 + float(perks.get("clickMult", 0.0))) * Mutations.click_mult())
	if float(fx.get("eater", 0.0)) > 0.0:
		gain = gain.mul_float(10.0)
	if float(fx.get("greed", 0.0)) > 0.0:
		gain = gain.mul_float(3.0)
	if float(fx.get("agony", 0.0)) > 0.0:
		gain = gain.mul_float(6.66)
	if float(fx.get("agonyDebuff", 0.0)) > 0.0:
		gain = gain.mul_float(0.5)

	var is_crit := false
	var crit_mult := 1.0
	if float(fx.get("phantom", 0.0)) > 0.0 and randf() < 0.10:
		is_crit = true
		crit_mult = 250.0
		gain = gain.mul_float(crit_mult)
	else:
		var crit_chance: float = minf(0.75, float(perks.get("critChance", 0.0)))
		if crit_chance > 0.0 and randf() < crit_chance:
			is_crit = true
			crit_mult = GameData.CRIT_BASE + float(perks.get("critMultAdd", 0.0))
			gain = gain.mul_float(crit_mult)

	earn(gain)
	if float(fx.get("phantom", 0.0)) > 0.0 and not is_crit:
		coins = coins.mul_float(0.995)

	Audio.play_sfx("crit" if is_crit else "click")
	Fox.on_activity()
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
		Audio.play_sfx("error")
		return false
	coins = coins.sub(cost)
	b[i] += n
	_stall_offered = false
	if i == 0 and b[0] >= 1:
		Achievements.try_unlock_by_key("first_piggy")
	if i == 11 and b[11] >= 1:
		Achievements.try_unlock_by_key("singularity")
	Audio.play_sfx("buy")
	Fox.on_activity()
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
	if float(fx.get("voidLock", 0.0)) > 0.0:
		Audio.play_sfx("error")
		return false
	var cost: BigNum = up["cost"]
	if not coins.gte(cost):
		Audio.play_sfx("error")
		return false
	coins = coins.sub(cost)
	if up["type"] == "sys":
		cu[up["key"]] = true
	else:
		b_up[int(up["bld_idx"])].append(int(up["th"]))
	_stall_offered = false
	Audio.play_sfx("buy")
	Fox.on_activity()
	state_changed.emit()
	return true

func buy_spore() -> bool:
	if infection >= 100:
		return false
	var cost: BigNum = Economy.myc_cost(self)
	if not coins.gte(cost):
		Audio.play_sfx("error")
		return false
	coins = coins.sub(cost)
	infection = mini(100, infection + 20)
	spores += 2
	if infection >= 100:
		Achievements.try_unlock_by_key("full_inf")
	Audio.play_sfx("buy")
	Fox.on_activity()
	_check_infection_step()
	state_changed.emit()
	return true

func purify() -> bool:
	if float(fx.get("purLock", 0.0)) > 0.0 or infection <= 0:
		Audio.play_sfx("error")
		return false
	coins = coins.mul_float(1.0 - GameData.PURIFY_FRAC)
	infection = 0
	infection_steps_done = 0
	Mutations.purge()
	Audio.play_sfx("buy")
	state_changed.emit()
	return true

func _check_infection_step() -> void:
	var step := int(float(infection) / 20.0)
	while infection_steps_done < step:
		infection_steps_done += 1
		infection_step.emit(infection_steps_done)

func catch_glitch() -> BigNum:
	buff_until = Time.get_unix_time_from_system() + GameData.BUFF_SEC
	spores += 3
	var bonus: BigNum = get_effective_cps().mul_float(5.0)
	earn(bonus)
	Audio.play_sfx("win")
	voice_logged.emit("Переполнение буфера. Ешь. (+3 споры)")
	state_changed.emit()
	return bonus

func miss_glitch() -> void:
	var loss_rate := 0.15 if float(fx.get("spam", 0.0)) > 0.0 else 0.05
	var lost: BigNum = coins.mul_float(loss_rate)
	coins = coins.sub(lost)
	Audio.play_sfx("error")
	voice_logged.emit("Ты не успел. Я забрал своё: −%s" % lost.format_ru())
	screen_flash_requested.emit(0.85, true)
	state_changed.emit()

func apply_deal(deal: Dictionary) -> void:
	var id: String = deal["id"]
	match id:
		"over":
			fx["over"] = 240.0
		"eater":
			fx["eater"] = 120.0
		"myc":
			fx["myc"] = 180.0
			fx["purLock"] = 300.0
		"sac":
			earn(get_effective_cps().mul_float(900.0))
			for i in range(b.size() - 1, -1, -1):
				if b[i] > 0:
					b[i] = maxi(0, b[i] - maxi(1, int(floor(float(b[i]) * 0.2))))
					break
		"greed":
			fx["greed"] = 360.0
		"spam":
			fx["spam"] = 180.0
			glitch_spawn_requested.emit(5)
		"rollback":
			fx["rollback"] = 180.0
		"phantom":
			fx["phantom"] = 120.0
		"void":
			earn(run_earned.mul_float(0.25))
			fx["voidLock"] = 600.0
		"agony":
			fx["agony"] = 66.0
			fx.erase("agonyDebuff")
	Achievements.try_unlock_by_key("deal_signed")
	voice_logged.emit("Грех принят: %s." % deal["name"])
	screen_flash_requested.emit(0.9, true)
	state_changed.emit()

func _check_stall() -> void:
	if _stall_offered or spores <= 0:
		return
	var c_val := get_effective_cps().to_float()
	if c_val <= 0.0:
		return
	var cheapest: BigNum = BigNum.new(9.9, 999)
	for i in range(GameData.BUILDINGS.size()):
		var c := Economy.b_cost(self, i, b[i])
		if not c.gte(cheapest):
			cheapest = c
	var gap := cheapest.sub(coins).to_float()
	if gap > 0.0 and (gap / c_val) > STALL_SECONDS:
		_stall_offered = true
		stall_detected.emit()

func step(dt: float) -> void:
	run_sec += dt
	total_sec += dt
	phase_time += dt
	earn(get_effective_cps().mul_float(dt))

	for k: String in fx.keys():
		fx[k] = float(fx[k]) - dt
		if float(fx[k]) <= 0.0:
			fx.erase(k)
			if k == "agony":
				fx["agonyDebuff"] = 300.0

	_stall_cd -= dt
	if _stall_cd <= 0.0:
		_stall_cd = 2.0
		_check_stall()

	deal_timer += dt
	if deal_timer >= 900.0:
		deal_timer = 0.0
		deal_requested.emit(DEALS[randi() % DEALS.size()])

	glitch_timer -= dt
	if glitch_timer <= 0.0:
		glitch_timer = randf_range(55.0, 95.0)
		glitch_spawn_requested.emit(1)

	state_changed.emit()

func debug_set_phase(p: int) -> void:
	var idx := clampi(p, 1, GameData.PHASES.size()) - 1
	var edge := float(GameData.PHASES[idx]["edge"])
	var val := BigNum.from_float(0.0 if edge == 0.0 else edge * 1.001 + 10.0)
	run_earned = val.copy()
	if not coins.gte(val):
		coins = val.copy()
	if not life_earned.gte(val):
		life_earned = val.copy()
	last_phase = p
	phase_time = 0.0
	var pdata: Dictionary = GameData.PHASES[idx]
	voice_logged.emit(pdata["log"])
	phase_changed.emit(p)
	screen_flash_requested.emit(0.8, true)
	state_changed.emit()

func save_game() -> void:
	var data := {
		"ver": GameData.VERSION,
		"coins": coins.to_dict(),
		"run_earned": run_earned.to_dict(),
		"life_earned": life_earned.to_dict(),
		"max_coins": max_coins.to_dict(),
		"spores": spores,
		"run_sec": run_sec,
		"total_sec": total_sec,
		"phase_time": phase_time,
		"clicks": clicks,
		"manual_clicks": manual_clicks,
		"b": b,
		"b_up": b_up,
		"cu": cu,
		"infection": infection,
		"infection_steps_done": infection_steps_done,
		"shards": shards,
		"free_shards": free_shards,
		"reinc": reinc,
		"mutations": Mutations.active,
		"ach": Achievements.unlocked,
		"casino": Casino.get_state()
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
	spores = int(parsed.get("spores", 3))
	run_sec = float(parsed.get("run_sec", 0.0))
	total_sec = float(parsed.get("total_sec", 0.0))
	phase_time = float(parsed.get("phase_time", 0.0))
	clicks = int(parsed.get("clicks", 0))
	manual_clicks = int(parsed.get("manual_clicks", 0))
	infection = int(parsed.get("infection", 0))
	infection_steps_done = int(parsed.get("infection_steps_done", int(float(infection) / 20.0)))
	shards = int(parsed.get("shards", 0))
	free_shards = int(parsed.get("free_shards", 0))
	reinc = int(parsed.get("reinc", 0))
	var saved_b: Array = parsed.get("b", [])
	for i: int in range(mini(b.size(), saved_b.size())):
		b[i] = int(saved_b[i])
	var saved_cu: Dictionary = parsed.get("cu", {})
	for k: String in cu.keys():
		cu[k] = bool(saved_cu.get(k, false))
	var saved_muts: Array = parsed.get("mutations", [])
	Mutations.load_active(saved_muts)
	var saved_ach: Dictionary = parsed.get("ach", {})
	Achievements.load_unlocked(saved_ach)
	var saved_cas: Dictionary = parsed.get("casino", {})
	Casino.load_state(saved_cas)
