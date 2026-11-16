class_name Economy
extends RefCounted

static func growth(s: Node) -> float:
	return maxf(GameData.GROWTH_FLOOR, GameData.BASE_GROWTH - float(s.perks.get("growthRed", 0.0)))

static func cost_mul(s: Node) -> float:
	var roll: float = 0.65 if float(s.fx.get("rollback", 0.0)) > 0.0 else 1.0
	return roll * (1.0 - minf(0.6, float(s.perks.get("costRed", 0.0))))

static func b_cost(s: Node, i: int, owned: int) -> BigNum:
	var base: float = GameData.BUILDINGS[i]["base"]
	return BigNum.from_float(base).mul(BigNum.pow_float(growth(s), owned)).mul_float(cost_mul(s))

static func b_cost_n(s: Node, i: int, owned: int, n: int) -> BigNum:
	var first: BigNum = b_cost(s, i, owned)
	if n <= 1:
		return first
	var g: float = growth(s)
	var geom: BigNum = BigNum.pow_float(g, n).sub(BigNum.one()).mul_float(1.0 / (g - 1.0))
	return first.mul(geom)

static func max_affordable(s: Node, i: int, owned: int, coins: BigNum) -> int:
	var first: BigNum = b_cost(s, i, owned)
	if not coins.gte(first):
		return 0
	var g: float = growth(s)
	var ratio: BigNum = coins.mul_float(g - 1.0).div(first).add(BigNum.one())
	var n: int = int(floor(ratio.log10_val() / (log(g) / log(10.0))))
	n = clampi(n, 1, 100000)
	while n > 1 and not coins.gte(b_cost_n(s, i, owned, n)):
		n -= 1
	while coins.gte(b_cost_n(s, i, owned, n + 1)):
		n += 1
	return n

static func up_cost(s: Node, i: int, th: int) -> BigNum:
	var base: float = GameData.BUILDINGS[i]["base"]
	var red: float = 1.0 - minf(0.6, float(s.perks.get("upCostRed", 0.0)))
	return BigNum.from_float(base * 10.0 * (float(th) / 5.0) * red)

static func overdrive_stacks(owned: int) -> int:
	return maxi(0, int(floor(float(owned - GameData.OVERDRIVE_START) / float(GameData.OVERDRIVE_STEP))))

static func b_mult(s: Node, i: int) -> float:
	var up_bonus: float = float(s.perks.get("upBonus", 0.0))
	var base_up: float = pow(2.0 + up_bonus, s.b_up[i].size())
	var od: float = pow(GameData.OVERDRIVE_MULT, overdrive_stacks(s.b[i]))
	return base_up * od

static func inf_eff(s: Node) -> int:
	return 100 if float(s.fx.get("myc", 0.0)) > 0.0 else s.infection

static func inf_stage(s: Node) -> int:
	return mini(5, int(floor(float(inf_eff(s)) / 20.0)))

static func inf_mult(s: Node) -> float:
	var myc_bonus: float = float(s.perks.get("mycBonus", 0.0))
	return GameData.INF_MULT[inf_stage(s)] * (1.0 + myc_bonus * float(inf_eff(s)) / 100.0)

static func shard_mult(s: Node) -> float:
	var add: float = float(s.perks.get("shardBonusAdd", 0.0))
	return 1.0 + (GameData.SHARD_BONUS + add) * float(s.shards + s.free_shards)

static func perk_mult(s: Node) -> float:
	var tb: int = 0
	var types: int = 0
	for cnt: int in s.b:
		tb += cnt
		if cnt > 0:
			types += 1
	var arch: float = 1.0 + float(tb) * GameData.ARCH_SYNERGY_PER_BLD
	return arch \
		* (1.0 + float(s.perks.get("incAdd", 0.0))) \
		* (1.0 + float(s.perks.get("perBld100", 0.0)) * float(tb) / 100.0) \
		* (1.0 + float(s.perks.get("diversity", 0.0)) * float(types)) \
		* (1.0 + float(s.perks.get("incPerInf", 0.0)) * float(inf_stage(s))) \
		* (1.0 + float(s.perks.get("perReinc", 0.0)) * float(s.reinc))

static func global_mult(s: Node) -> float:
	var sync: float = GameData.SYNC_MULT if bool(s.cu.get("sync", false)) else 1.0
	var mut_bld: float = Mutations.building_mult() if Engine.has_singleton("Mutations") or s.get_node_or_null("/root/Mutations") else 1.0
	return inf_mult(s) * shard_mult(s) * sync * perk_mult(s) * mut_bld

static func base_cps(s: Node) -> BigNum:
	var total: BigNum = BigNum.zero()
	for i: int in range(GameData.BUILDINGS.size()):
		if s.b[i] > 0:
			var row_cps: float = float(s.b[i]) * float(GameData.BUILDINGS[i]["cps"]) * b_mult(s, i)
			total = total.add(BigNum.from_float(row_cps))
	return total

static func cps(s: Node, buff_active: bool) -> BigNum:
	var mult: float = global_mult(s) * ((GameData.BUFF_MULT + float(s.perks.get("glitchBuffMultAdd", 0.0))) if buff_active else 1.0)
	return base_cps(s).mul_float(mult)

static func click_pct(s: Node) -> float:
	var base: float = 0.05 if bool(s.cu.get("rag", false)) else (0.01 if bool(s.cu.get("code", false)) else 0.0)
	return base + float(s.perks.get("clickPctAdd", 0.0))

static func click_base(s: Node) -> float:
	return 1.0 \
		+ (1.0 if bool(s.cu.get("claws", false)) else 0.0) \
		+ (4.0 if bool(s.cu.get("fang", false)) else 0.0) \
		+ float(s.perks.get("clickFlat", 0.0))

static func phase_of(s: Node) -> int:
	var p: int = 1
	for k: int in range(1, GameData.PHASES.size()):
		var edge: BigNum = BigNum.from_float(float(GameData.PHASES[k]["edge"]))
		if s.run_earned.gte(edge):
			p = k + 1
		else:
			break
	return p

static func tier_of(phase: int) -> int:
	return mini(4, int(ceil(float(phase) / 4.0)))

static func myc_cost(s: Node) -> BigNum:
	var idx: int = mini(int(floor(float(s.infection) / 20.0)), GameData.MYC_COSTS.size() - 1)
	var red: float = 1.0 - minf(0.8, float(s.perks.get("mycCostRed", 0.0)))
	return BigNum.from_float(GameData.MYC_COSTS[idx] * red)
