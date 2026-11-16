class_name BigNum
extends RefCounted

var mantissa: float = 0.0
var exponent: int = 0

func _init(m: float = 0.0, e: int = 0) -> void:
	mantissa = m
	exponent = e
	normalize()

static func zero() -> BigNum:
	return BigNum.new(0.0, 0)

static func one() -> BigNum:
	return BigNum.new(1.0, 0)

static func from_float(val: float) -> BigNum:
	if is_zero_approx(val) or is_nan(val):
		return zero()
	return BigNum.new(val, 0)

static func pow_float(base: float, power: float) -> BigNum:
	if is_zero_approx(power):
		return one()
	if base <= 0.0:
		return zero()
	var log_val: float = power * (log(base) / log(10.0))
	var exp_part: int = int(floor(log_val))
	var man_part: float = pow(10.0, log_val - float(exp_part))
	return BigNum.new(man_part, exp_part)

func copy() -> BigNum:
	return BigNum.new(mantissa, exponent)

func normalize() -> void:
	if is_zero_approx(mantissa) or is_nan(mantissa):
		mantissa = 0.0
		exponent = 0
		return
	if is_inf(mantissa):
		mantissa = signf(mantissa)
		exponent = 999999999
		return
	while absf(mantissa) >= 10.0:
		mantissa /= 10.0
		exponent += 1
	while absf(mantissa) > 0.0 and absf(mantissa) < 1.0:
		mantissa *= 10.0
		exponent -= 1

func add(other: BigNum) -> BigNum:
	if is_zero_approx(mantissa):
		return other.copy()
	if is_zero_approx(other.mantissa):
		return copy()
	var diff: int = exponent - other.exponent
	if diff > 15:
		return copy()
	if diff < -15:
		return other.copy()
	if diff >= 0:
		return BigNum.new(mantissa + other.mantissa * pow(10.0, -diff), exponent)
	return BigNum.new(other.mantissa + mantissa * pow(10.0, diff), other.exponent)

func sub(other: BigNum) -> BigNum:
	return add(BigNum.new(-other.mantissa, other.exponent))

func mul(other: BigNum) -> BigNum:
	return BigNum.new(mantissa * other.mantissa, exponent + other.exponent)

func mul_float(f: float) -> BigNum:
	return mul(BigNum.from_float(f))

func div(other: BigNum) -> BigNum:
	if is_zero_approx(other.mantissa):
		return zero()
	return BigNum.new(mantissa / other.mantissa, exponent - other.exponent)

func log10_val() -> float:
	if mantissa <= 0.0:
		return -INF
	return float(exponent) + (log(mantissa) / log(10.0))

func gte(other: BigNum) -> bool:
	if is_zero_approx(mantissa) and is_zero_approx(other.mantissa):
		return true
	if mantissa >= 0.0 and other.mantissa < 0.0:
		return true
	if mantissa < 0.0 and other.mantissa >= 0.0:
		return false
	if exponent != other.exponent:
		return exponent > other.exponent if mantissa >= 0.0 else exponent < other.exponent
	return mantissa >= other.mantissa - 1e-12

func to_float() -> float:
	if exponent > 300:
		return INF
	return mantissa * pow(10.0, exponent)

func to_dict() -> Dictionary:
	return { "m": mantissa, "e": exponent }

static func from_dict(d: Variant) -> BigNum:
	if typeof(d) == TYPE_DICTIONARY:
		return BigNum.new(float(d.get("m", 0.0)), int(d.get("e", 0)))
	if typeof(d) == TYPE_FLOAT or typeof(d) == TYPE_INT:
		return BigNum.from_float(float(d))
	return zero()

func format_ru() -> String:
	if is_zero_approx(mantissa):
		return "0"
	if exponent < 3:
		var v: float = mantissa * pow(10.0, exponent)
		if is_equal_approx(v, round(v)):
			return "%d" % int(round(v))
		if v < 10.0:
			return str(snappedf(v, 0.01))
		if v < 100.0:
			return str(snappedf(v, 0.1))
		return str(int(floor(v)))
	var idx: int = int(floor(float(exponent) / 3.0))
	if idx >= GameData.SUF.size():
		return "%.2fe%d" % [mantissa, exponent]
	var rem: int = exponent % 3
	var scaled: float = mantissa * pow(10.0, rem)
	var num_str: String = "%.2f" % scaled if scaled < 10.0 else ("%.1f" % scaled if scaled < 100.0 else "%d" % int(round(scaled)))
	return "%s %s" % [num_str, GameData.SUF[idx]]
