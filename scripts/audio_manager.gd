extends Node

const RATE := 22050.0
# Тёмная синтвейв-прогрессия (Dm -> Bb -> Gm -> A) в слышимом басовом диапазоне
const BASS_NOTES: Array[float] = [73.42, 58.27, 49.00, 55.00]

var sound_on: bool = true
var twitch_duck: float = 0.0

var _amb: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _sub_phase: float = 0.0
var _arp_phase: float = 0.0
var _lfo: float = 0.0
var _bar_timer: float = 0.0
var _lp_state: float = 0.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _sfx_bank: Dictionary = {}

func _ready() -> void:
	_ensure_bus("SFX")
	_ensure_bus("Ambient")

	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambient"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	_amb.stream = gen
	add_child(_amb)
	_amb.play()
	_pb = _amb.get_stream_playback()

	for _i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	_sfx_bank["click"] = _bake_click()
	_sfx_bank["crit"] = _bake_crit()
	_sfx_bank["buy"] = _bake_buy()
	_sfx_bank["ui"] = _bake_ui_tick()
	_sfx_bank["error"] = _bake_error()
	_sfx_bank["win"] = _bake_win()
	_sfx_bank["twitch"] = _bake_twitch()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func set_sound(on: bool) -> void:
	sound_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)

func duck_for_twitch(sec: float = 0.45) -> void:
	twitch_duck = sec

func play_sfx(kind: String) -> void:
	if not sound_on or not _sfx_bank.has(kind):
		return
	var p := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = _sfx_bank[kind]
	if kind == "click":
		p.pitch_scale = randf_range(0.94, 1.08)
	elif kind == "ui":
		p.pitch_scale = randf_range(0.97, 1.03)
	else:
		p.pitch_scale = 1.0
	p.play()

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var s16 := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.data = data
	return wav

# 1. Тактильный механический клик + мягкий суб-удар (без противного писка)
func _bake_click() -> AudioStreamWAV:
	var dur := 0.052
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph_sub := 0.0
	var ph_hi := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 14601
	for i in range(n):
		var t := float(i) / RATE
		var nt := float(i) / float(n)
		# Низкий плотный удар (155 Гц -> 44 Гц)
		var f_sub := lerpf(155.0, 44.0, pow(nt, 0.45))
		ph_sub = fmod(ph_sub + f_sub / RATE, 1.0)
		var sub := sin(TAU * ph_sub) * exp(-t * 68.0) * 0.55

		# Короткий механический щелчок свитча (первые 12 мс)
		ph_hi = fmod(ph_hi + lerpf(1900.0, 820.0, nt) / RATE, 1.0)
		var snap := sin(TAU * ph_hi) * exp(-t * 240.0) * 0.28
		var grit := rng.randf_range(-1.0, 1.0) * exp(-t * 420.0) * 0.22
		buf[i] = sub + snap + grit
	return _make_wav(buf)

# 2. Критический удар: звонкий FM-колокольчик с металлической искрой
func _bake_crit() -> AudioStreamWAV:
	var dur := 0.28
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph_c := 0.0
	var ph_m := 0.0
	var ph_hi := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var env := exp(-t * 13.0) * minf(1.0, t * 250.0)
		ph_m = fmod(ph_m + 1318.5 / RATE, 1.0)
		var mod := sin(TAU * ph_m) * 1.4 * exp(-t * 22.0)
		ph_c = fmod(ph_c + 880.0 / RATE, 1.0)
		ph_hi = fmod(ph_hi + 1760.0 / RATE, 1.0)
		var bell := sin(TAU * ph_c + mod) * 0.42 + sin(TAU * ph_hi) * 0.22 * exp(-t * 18.0)
		buf[i] = bell * env
	return _make_wav(buf)

# 3. Покупка: приятный двухнотный кибер-отклик (A4 -> E5, чистая квинта)
func _bake_buy() -> AudioStreamWAV:
	var dur := 0.19
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes: Array[float] = [440.0, 659.25]
	var ph1 := 0.0
	var ph2 := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var step := 0 if t < 0.065 else 1
		var local_t := t if step == 0 else (t - 0.065)
		var f := notes[step]
		ph1 = fmod(ph1 + f / RATE, 1.0)
		ph2 = fmod(ph2 + (f * 2.0) / RATE, 1.0)
		var env := exp(-local_t * (24.0 if step == 0 else 16.0)) * minf(1.0, local_t * 300.0)
		var tri := 1.0 - absf(ph1 * 4.0 - 2.0)
		var tone := tri * 0.36 + sin(TAU * ph2) * 0.14
		buf[i] = tone * env
	return _make_wav(buf)

# 4. Щелчок механического замка / интерфейса
func _bake_ui_tick() -> AudioStreamWAV:
	var dur := 0.032
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / RATE
		ph = fmod(ph + 1280.0 / RATE, 1.0)
		buf[i] = sin(TAU * ph) * exp(-t * 150.0) * 0.32
	return _make_wav(buf)

# 5. Ошибка / ловушка: глухой двойной басовый отказ
func _bake_error() -> AudioStreamWAV:
	var dur := 0.24
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in range(n):
		var t := float(i) / RATE
		# Два коротких импульса с паузой посередине
		var pulse_env := 0.0
		if t < 0.085:
			pulse_env = sin((t / 0.085) * PI)
		elif t > 0.115 and t < 0.23:
			pulse_env = sin(((t - 0.115) / 0.115) * PI) * 0.85
		ph1 = fmod(ph1 + 108.0 / RATE, 1.0)
		ph2 = fmod(ph2 + 115.5 / RATE, 1.0)
		var raw := sin(TAU * ph1) + sin(TAU * ph2)
		var warm := clampf(raw * 1.35, -1.0, 1.0) * 0.32
		buf[i] = warm * pulse_env
	return _make_wav(buf)

# 6. Победа / переполнение буфера: 3-нотный синтвейв-аккорд (C5 - E5 - G5)
func _bake_win() -> AudioStreamWAV:
	var dur := 0.36
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var chord: Array[float] = [523.25, 659.25, 783.99]
	var phs: Array[float] = [0.0, 0.0, 0.0]
	for i in range(n):
		var t := float(i) / RATE
		var mix := 0.0
		for k in range(3):
			var start_t := float(k) * 0.055
			if t >= start_t:
				var lt := t - start_t
				phs[k] = fmod(phs[k] + chord[k] / RATE, 1.0)
				var env := exp(-lt * 9.5) * minf(1.0, lt * 200.0)
				var tri := 1.0 - absf(phs[k] * 4.0 - 2.0)
				mix += (tri * 0.22 + sin(TAU * phs[k]) * 0.18) * env
		buf[i] = mix
	return _make_wav(buf)

# 7. Нервный тик уха Лиса: острый двойной цифровой сигнал (не спутаешь ни с чем)
func _bake_twitch() -> AudioStreamWAV:
	var dur := 0.11
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var second := t >= 0.05
		var lt := (t - 0.05) if second else t
		var f := (2350.0 - lt * 14000.0) if second else (1450.0 + lt * 16000.0)
		ph = fmod(ph + maxf(300.0, f) / RATE, 1.0)
		var env := exp(-lt * 55.0) * minf(1.0, lt * 400.0)
		buf[i] = sin(TAU * ph) * env * 0.45
	return _make_wav(buf)

func _process(delta: float) -> void:
	if not _pb:
		return
	if twitch_duck > 0.0:
		twitch_duck -= delta
	_bar_timer += delta

	var cps_log := clampf(GameState.get_effective_cps().log10_val() / 12.0, 0.0, 1.0)
	var target_db := -44.0 if twitch_duck > 0.0 else lerpf(-26.0, -10.5, cps_log)
	_amb.volume_db = lerpf(_amb.volume_db, target_db, minf(1.0, delta * 9.0))

	# Смена басовой ноты каждые 2.4 секунды
	var note_idx := int(_bar_timer / 2.4) % BASS_NOTES.size()
	var inf_detune := float(Economy.inf_eff(GameState)) / 100.0 * 0.025
	var bass_f := BASS_NOTES[note_idx] * (1.0 + sin(_lfo * TAU) * inf_detune)
	var arp_step := int(_bar_timer * 6.0) % 4
	var arp_mults: Array[float] = [2.0, 3.0, 4.0, 3.0]
	var arp_f := bass_f * arp_mults[arp_step]

	# Фильтр низких частот раскрывается с ростом CPS (от глухого гула к чистому синтвейву)
	var cutoff := lerpf(0.06, 0.28, cps_log)

	var avail := _pb.get_frames_available()
	for _i in range(avail):
		_phase = fmod(_phase + bass_f / RATE, 1.0)
		_sub_phase = fmod(_sub_phase + (bass_f * 0.5) / RATE, 1.0)
		_arp_phase = fmod(_arp_phase + arp_f / RATE, 1.0)
		_lfo = fmod(_lfo + 0.18 / RATE, 1.0)

		var saw_bass := (_phase * 2.0 - 1.0) * 0.35 + sin(TAU * _sub_phase) * 0.45
		var arp_pulse := (0.16 * cps_log) * sin(TAU * _arp_phase)
		var raw := (saw_bass + arp_pulse) * (0.72 + 0.28 * sin(TAU * _lfo))

		# Программный 1-pole Low-Pass фильтр убирает резкий цифровой песок
		_lp_state += cutoff * (raw - _lp_state)
		_pb.push_frame(Vector2(_lp_state, _lp_state))
