extends Node

signal unlocked_new(id: int, path: String, lore: String)

const TOTAL := 146

var unlocked: Dictionary = {}
var defs: Dictionary = {}
var keys: Dictionary = {}

func _ready() -> void:
	for i in range(1, TOTAL + 1):
		defs[i] = {
			"key": "ach_%03d" % i,
			"title": "sector_%03d.log" % i,
			"lore": "Запись %03d: стена между кодом и наблюдателем стала тоньше." % i
		}
	_reg(1, "clue", "ear_twitch.log", "Ты поймал Лиса за дёргающееся ухо во время блефа в Casino.exe.")
	_reg(2, "0333", "anomaly_0333.log", "03:33 ночи. Система зафиксировала взгляд с той стороны монитора.")
	_reg(3, "first_click", "pulse_001.log", "Первый импульс подан. Ядро Fox OS проснулось.")
	_reg(4, "first_piggy", "rust_piggy.log", "Первая ржавая копилка подключена к контуру добычи.")
	_reg(5, "full_inf", "mycelium_100.log", "100% заражения мицелием. Симбиоз необратим.")
	_reg(6, "deal_signed", "blood_pact.log", "Подпись поставлена. Первый грех внесён в реестр.")
	_reg(7, "phase_5", "botnet_core.log", "Фаза 5 достигнута. Вирус вышел за пределы локальной машины.")
	_reg(8, "phase_10", "apotheosis.log", "Фаза 10 достигнута. Шерсть сменилась оптоволокном.")
	_reg(9, "phase_16", "true_zero.log", "Фаза 16 достигнута. Остался только звенящий Истинный Ноль.")
	_reg(10, "singularity", "singularity.log", "Сингулярность запущена. Время течёт внутрь ядра.")
	defs[TOTAL]["title"] = "OMEGA_146.log"
	defs[TOTAL]["lore"] = "ФИНАЛ: Лис открывает дверь. Матрицы больше нет. Есть только ты."

	for i: int in defs.keys():
		keys[defs[i]["key"]] = i

func _reg(id: int, k: String, t: String, l: String) -> void:
	defs[id] = { "key": k, "title": t, "lore": l }

func path_of(id: int) -> String:
	return "/sys/146/%03d.log" % id

func try_unlock_by_key(k: String) -> void:
	if keys.has(k):
		unlock(int(keys[k]))

func unlock(id: int) -> void:
	if unlocked.has(id) or not defs.has(id):
		return
	unlocked[id] = true
	unlocked_new.emit(id, path_of(id), defs[id]["lore"])
	if unlocked.size() == TOTAL - 1 and not unlocked.has(TOTAL):
		unlock(TOTAL)

func load_unlocked(d: Dictionary) -> void:
	unlocked.clear()
	for k in d.keys():
		unlocked[int(k)] = true

func listing() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(1, TOTAL + 1):
		var ok := unlocked.has(i)
		out.append({
			"id": i,
			"ok": ok,
			"path": path_of(i) if ok else "/sys/146/???.log",
			"title": defs[i]["title"] if ok else "???",
			"lore": defs[i]["lore"] if ok else "[ДОСТУП ЗАКРЫТ — ДАННЫЕ ЗАШИФРОВАНЫ]"
		})
	return out
