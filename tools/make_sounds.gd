extends SceneTree
## Wylicza dźwięki nocnego lasu i postaci; zapisuje je jako pliki WAV:
##   sounds/otoczenie/  wiatr, woda, świerszcze, sowa, plusk, kroki
##   sounds/postac/     świst ostrza (3 warianty), przewrót, lądowanie po przewrocie, trafiony
##   sounds/bestia/     zapowiedzi ataków (parsknięcie, chrząknięcie, wdech), kopyta,
##                      tupnięcie, trafienie ostrzem (3 warianty), ryk przy upadku
##
## Uruchom z katalogu projektu:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/make_sounds.gd
##
## Pliki są gotowe do podmiany na prawdziwe nagrania: wystarczy zapisać nowy plik pod tą samą nazwą.
## Pętle (wiatr, woda, świerszcze) mają w pliku zapisany punkt zapętlenia, a ich koniec
## płynnie przechodzi w początek. Wszystko jest losowane z ustalonym ziarnem,
## więc ponowne uruchomienie daje te same pliki.

const RATE := 22050
const OUT_DIR := "res://sounds/"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	for sub in ["otoczenie", "postac", "bestia"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + sub))
	var started := Time.get_ticks_msec()
	_rng.seed = 7
	_save("otoczenie/wiatr.wav", [_wind(24.0, 0.0, 11), _wind(24.0, 1.7, 12)], true)
	_save("otoczenie/woda.wav", [_water(12.0)], true)
	_save("otoczenie/swierszcz_lewy.wav", [_crickets(7.0, 4300.0, 3, 0.43, 21)], true)
	_save("otoczenie/swierszcz_prawy.wav", [_crickets(9.0, 4900.0, 4, 0.57, 22)], true)
	_save("otoczenie/sowa.wav", [_owl()], false)
	_save("otoczenie/plusk.wav", [_splash()], false)
	for i in 4:
		_save("otoczenie/krok_%d.wav" % (i + 1), [_step(30 + i)], false)
	for i in 3:
		_save("postac/swist_%d.wav" % (i + 1), [_swing(60 + i)], false)
	_save("postac/przewrot.wav", [_roll_rustle()], false)
	_save("postac/ladowanie.wav", [_land()], false)
	_save("postac/trafiony.wav", [_friend_hurt()], false)
	_save("bestia/parskniecie.wav", [_snort()], false)
	_save("bestia/chrzakniecie.wav", [_normalize(_growl(115.0, 80.0, 0.32, 0.6, 520.0, 91), 0.7)], false)
	_save("bestia/wdech.wav", [_inhale()], false)
	for i in 3:
		_save("bestia/kopyto_%d.wav" % (i + 1), [_hoof(100 + i)], false)
	_save("bestia/tupniecie.wav", [_stomp_boom()], false)
	for i in 3:
		_save("bestia/trafienie_%d.wav" % (i + 1), [_blade_hit(110 + i)], false)
	_save("bestia/ryk.wav", [_roar()], false)
	print("Dźwięki zapisane w %s (%d ms)" % [OUT_DIR, Time.get_ticks_msec() - started])
	quit()


# ---------------------------------------------------------------- brzmienia

## Wiatr w koronach drzew: szum o zmiennej barwie, z porywami. Poryw powtarza się
## dokładnie co `length` sekund, dzięki czemu pętla nie ma szwu.
func _wind(length: float, phase: float, seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var fade := 2.0
	var total := int((length + fade) * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var low1 := 0.0
	var low2 := 0.0
	var rustle := Biquad.bandpass(3200.0, 0.7, RATE)
	var flutter := 0.0
	for i in total:
		var t := float(i) / RATE
		# poryw: suma wolnych fal, których okresy dzielą długość pętli
		var g := 0.5 + 0.5 * (0.55 * sin(TAU * t / length + phase)
				+ 0.3 * sin(TAU * 3.0 * t / length + 2.0 * phase + 1.0)
				+ 0.15 * sin(TAU * 7.0 * t / length + 0.5))
		g = clampf(g, 0.0, 1.0)
		var cutoff := 160.0 + 560.0 * g
		var a := 1.0 - exp(-TAU * cutoff / RATE)
		var white := _rng.randf_range(-1.0, 1.0)
		low1 += a * (white - low1)
		low2 += a * (low1 - low2)
		var whoosh := low2 * (0.35 + 1.1 * pow(g, 1.5)) * 3.0
		# szelest liści tylko w silniejszych porywach
		flutter += 0.002 * (absf(_rng.randf_range(-1.0, 1.0)) - flutter)
		var leaves := rustle.process(white) * maxf(0.0, g - 0.5) * 0.9 * (0.3 + flutter * 4.0)
		out[i] = whoosh + leaves
	return _loop_crossfade(_normalize(out, 0.5), length, fade)


## Woda przy brzegu: ciche chlupotanie i pojedyncze bąbelki.
func _water(length: float) -> PackedFloat32Array:
	_rng.seed = 31
	var total := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	# bardzo cichy, niski szum tafli
	var low := 0.0
	for i in total:
		low += 0.06 * (_rng.randf_range(-1.0, 1.0) - low)
		out[i] = low * 0.25
	# chlupnięcia fal o brzeg
	var t := 0.3
	while t < length:
		var lap := _noise_burst(_rng.randf_range(300.0, 650.0), 1.3, _rng.randf_range(0.06, 0.14),
				_rng.randf_range(0.25, 0.55))
		_mix_wrapped(out, lap, int(t * RATE), _rng.randf_range(0.35, 0.7))
		if _rng.randf() < 0.45:
			var bubble := _bubble(_rng.randf_range(450.0, 700.0), _rng.randf_range(1.4, 1.9), 0.05)
			_mix_wrapped(out, bubble, int((t + _rng.randf_range(0.1, 0.4)) * RATE), _rng.randf_range(0.08, 0.18))
		t += _rng.randf_range(0.7, 1.6)
	return _normalize(out, 0.45)


## Świerszcz: krótkie trele złożone z kilku impulsów wysokiego tonu.
func _crickets(length: float, freq: float, pulses: int, period: float, seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var total := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var pulse_len := int(0.016 * RATE)
	var gap := int(0.011 * RATE)
	var t := 0.1
	while t < length - 0.05:
		if _rng.randf() > 0.12:  # czasem świerszcz milknie na jeden takt
			var start := int(t * RATE)
			var f := freq * _rng.randf_range(0.99, 1.01)
			var amp := _rng.randf_range(0.6, 1.0)
			for p in pulses:
				for j in pulse_len:
					var env := sin(PI * float(j) / pulse_len)
					var ph := TAU * f * float(j) / RATE
					var s := (sin(ph) + 0.18 * sin(2.0 * ph)) * env * env * amp
					var idx := (start + p * (pulse_len + gap) + j) % total
					out[idx] += s
		t += period * _rng.randf_range(0.93, 1.07)
	return _normalize(out, 0.35)


## Puszczyk: „huuu… hu-huuuu”, z lekkim drżeniem i pogłosem lasu.
func _owl() -> PackedFloat32Array:
	_rng.seed = 41
	var total := int(3.4 * RATE)
	var dry := PackedFloat32Array()
	dry.resize(total)
	# (początek s, długość s, częstotliwość Hz, zmiana tonu do końca Hz)
	var hoots: Array[Vector4] = [
		Vector4(0.05, 0.55, 395.0, -15.0),
		Vector4(1.0, 0.12, 370.0, 0.0),
		Vector4(1.22, 0.95, 400.0, -30.0),
	]
	for h in hoots:
		var start := int(h.x * RATE)
		var n := int(h.y * RATE)
		var ph := 0.0
		var breath := Biquad.bandpass(h.z, 3.0, RATE)
		for j in n:
			var k := float(j) / n
			var t := float(j) / RATE
			var tremble := 1.0 + (0.012 * sin(TAU * 6.5 * t) if h.y > 0.5 and k > 0.4 else 0.0)
			ph += TAU * (h.z + h.w * k) * tremble / RATE
			var env := minf(1.0, t / 0.05) * minf(1.0, (h.y - t) / 0.12)
			var s := sin(ph) + 0.12 * sin(2.0 * ph) + breath.process(_rng.randf_range(-1.0, 1.0)) * 0.6
			dry[start + j] += s * env
	return _normalize(_forest_echo(dry), 0.6)


## Plusk ryby w jeziorku: krótki szum uderzenia i kilka bąbelków.
func _splash() -> PackedFloat32Array:
	_rng.seed = 51
	var total := int(1.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	_mix_wrapped(out, _noise_burst(1400.0, 0.6, 0.004, 0.09), int(0.02 * RATE), 1.0)
	_mix_wrapped(out, _noise_burst(500.0, 1.0, 0.01, 0.25), int(0.03 * RATE), 0.6)
	for b in 4:
		_mix_wrapped(out, _bubble(_rng.randf_range(600.0, 1100.0), 1.8, 0.04),
				int(_rng.randf_range(0.08, 0.6) * RATE), _rng.randf_range(0.15, 0.35))
	# opadające krople
	for d in 3:
		_mix_wrapped(out, _bubble(_rng.randf_range(1500.0, 2300.0), 1.3, 0.02),
				int(_rng.randf_range(0.3, 0.9) * RATE), 0.12)
	return _normalize(_forest_echo(out), 0.55)


## Krok po mchu i trawie: szelest źdźbeł i głuche stąpnięcie.
func _step(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var total := int(0.22 * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	_mix_wrapped(out, _noise_burst(_rng.randf_range(1800.0, 2800.0), 0.8, 0.004, _rng.randf_range(0.05, 0.08)), 0, 0.8)
	_mix_wrapped(out, _noise_burst(_rng.randf_range(4000.0, 5500.0), 1.0, 0.01, 0.04),
			int(_rng.randf_range(0.01, 0.03) * RATE), 0.3)
	var ph := 0.0
	for j in int(0.09 * RATE):
		var t := float(j) / RATE
		ph += TAU * (85.0 - 30.0 * t / 0.09) / RATE
		out[j] += sin(ph) * exp(-t / 0.025) * 0.9
	return _normalize(out, 0.7)


# ---------------------------------------------------------------- postać

## Świst ostrza: szum, którego pasmo szybko zjeżdża z wysokich w niskie (ruch powietrza),
## i cichy, krótki dźwięk stali. Bardzo szybkie narastanie - słychać go od razu po wciśnięciu.
func _swing(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var n := int(0.26 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var high := _rng.randf_range(3800.0, 4600.0)
	var low := _rng.randf_range(700.0, 1000.0)
	var filter := Biquad.bandpass(high, 1.4, RATE)
	for j in n:
		var t := float(j) / RATE
		if j % 32 == 0:
			filter.set_bandpass(high * pow(low / high, minf(1.0, t / 0.18)), 1.4, RATE)
		var env := smoothstep(0.0, 0.03, t) * exp(-maxf(0.0, t - 0.045) / 0.045)
		out[j] = filter.process(_rng.randf_range(-1.0, 1.0)) * env * 2.5
	for partial: Vector3 in [Vector3(2210.0, 0.5, 0.09), Vector3(3480.0, 0.35, 0.07), Vector3(5150.0, 0.25, 0.05)]:
		var f := partial.x * _rng.randf_range(0.97, 1.03)
		for j in n:
			var t := float(j) / RATE
			out[j] += sin(TAU * f * t) * partial.y * exp(-t / partial.z) * 0.16 * minf(1.0, t / 0.003)
	return _normalize(out, 0.7)


## Przewrót: szelest płaszcza i otarcie o ziemię w połowie obrotu.
func _roll_rustle() -> PackedFloat32Array:
	_rng.seed = 71
	var n := int(0.42 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var cloth := Biquad.bandpass(1600.0, 0.9, RATE)
	var low := 0.0
	var a := 1.0 - exp(-TAU * 400.0 / RATE)
	for j in n:
		var t := float(j) / RATE
		var flap := 0.6 + 0.4 * absf(sin(TAU * 17.0 * t + 1.3))
		var env := smoothstep(0.0, 0.04, t) * exp(-maxf(0.0, t - 0.12) / 0.12) * flap
		var white := _rng.randf_range(-1.0, 1.0)
		low += a * (white - low)
		var brush := exp(-pow((t - 0.17) / 0.07, 2.0))
		out[j] = cloth.process(white) * env * 1.6 + low * brush * 2.2
	return _normalize(out, 0.6)


## Lądowanie po przewrocie: głuche stuknięcie, chrzęst ściółki i trzepnięcie płaszcza.
func _land() -> PackedFloat32Array:
	_rng.seed = 81
	var out := PackedFloat32Array()
	out.resize(int(0.25 * RATE))
	_mix_wrapped(out, _noise_burst(2500.0, 0.9, 0.003, 0.03), 0, 0.5)
	_mix_wrapped(out, _noise_burst(1200.0, 0.8, 0.01, 0.06), int(0.015 * RATE), 0.35)
	var ph := 0.0
	for j in int(0.12 * RATE):
		var t := float(j) / RATE
		ph += TAU * (70.0 - 30.0 * t / 0.12) / RATE
		out[j] += sin(ph) * exp(-t / 0.035)
	return _normalize(out, 0.7)


## Trafiony przyjaciel: głuche uderzenie, szarpnięcie płaszcza i krótki, zduszony oddech.
func _friend_hurt() -> PackedFloat32Array:
	_rng.seed = 85
	var out := PackedFloat32Array()
	out.resize(int(0.35 * RATE))
	var ph := 0.0
	for j in int(0.1 * RATE):
		var t := float(j) / RATE
		ph += TAU * (95.0 - 35.0 * t / 0.1) / RATE
		out[j] += sin(ph) * exp(-t / 0.045)
	_mix_wrapped(out, _noise_burst(1500.0, 0.9, 0.005, 0.07), 0, 0.5)
	_mix_wrapped(out, _noise_burst(750.0, 2.0, 0.03, 0.06), int(0.04 * RATE), 0.45)
	return _normalize(out, 0.7)


# ---------------------------------------------------------------- bestia

## Pomruk: ton o kształcie piły przepuszczony przez „gardło” (filtr pasmowy), szorstki
## (głośność drga losowo), od wysokości f0 do f1.
func _growl(f0: float, f1: float, duration: float, rough: float, formant: float, seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var throat := Biquad.bandpass(formant, 1.2, RATE)
	var ph := 0.0
	var wobble := 0.0
	for j in n:
		var t := float(j) / RATE
		var f := lerpf(f0, f1, t / duration) * (1.0 + 0.03 * sin(TAU * 7.0 * t))
		ph += TAU * f / RATE
		var saw := 0.0
		for h in range(1, 9):
			saw += sin(h * ph) / h
		wobble += 0.08 * (_rng.randf_range(-1.0, 1.0) - wobble)
		var env := smoothstep(0.0, 0.04, t) * smoothstep(duration, duration - 0.12, t)
		out[j] = (throat.process(saw) * 1.5 + saw * 0.25) * (1.0 + rough * wobble * 4.0) * env
	return out


## Parsknięcie przed szarżą: dwa ostre wydmuchy przez ryj i pomruk pod spodem.
func _snort() -> PackedFloat32Array:
	_rng.seed = 92
	var out := _growl(75.0, 65.0, 0.55, 0.8, 380.0, 93)
	for k in out.size():
		out[k] *= 0.5
	for at: float in [0.0, 0.2]:
		var puff := _noise_burst(700.0, 0.8, 0.01, 0.07)
		for j in puff.size():
			puff[j] *= 0.7 + 0.3 * sin(TAU * 32.0 * float(j) / RATE)  # trzepot nozdrzy
		_mix_wrapped(out, puff, int(at * RATE), 1.0)
	return _normalize(out, 0.7)


## Głęboki wdech przed tupnięciem: szum, którego barwa rośnie, i narastający pomruk.
func _inhale() -> PackedFloat32Array:
	_rng.seed = 94
	var n := int(0.6 * RATE)
	var out := _growl(60.0, 78.0, 0.6, 0.5, 300.0, 95)
	var filter := Biquad.bandpass(400.0, 1.0, RATE)
	for j in n:
		var t := float(j) / RATE
		if j % 32 == 0:
			filter.set_bandpass(400.0 * pow(3.5, t / 0.6), 1.0, RATE)
		var env := smoothstep(0.0, 0.5, t) * smoothstep(0.6, 0.52, t)
		out[j] = out[j] * 0.4 * env + filter.process(_rng.randf_range(-1.0, 1.0)) * env * 2.0
	return _normalize(out, 0.6)


## Kopyto: ciężkie stąpnięcie i chrzęst ściółki.
func _hoof(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(int(0.18 * RATE))
	var ph := 0.0
	var f := _rng.randf_range(50.0, 62.0)
	for j in int(0.12 * RATE):
		var t := float(j) / RATE
		ph += TAU * (f - 20.0 * t / 0.12) / RATE
		out[j] += sin(ph) * exp(-t / 0.05)
	_mix_wrapped(out, _noise_burst(_rng.randf_range(1300.0, 1800.0), 0.9, 0.003, 0.04), 0, 0.45)
	return _normalize(out, 0.7)


## Tupnięcie: niski huk, dudnienie ziemi i trzask, z echem lasu.
func _stomp_boom() -> PackedFloat32Array:
	_rng.seed = 96
	var n := int(1.0 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var low := 0.0
	var a := 1.0 - exp(-TAU * 300.0 / RATE)
	for j in n:
		var t := float(j) / RATE
		ph += TAU * (55.0 - 25.0 * minf(1.0, t / 0.4)) / RATE
		low += a * (_rng.randf_range(-1.0, 1.0) - low)
		out[j] = sin(ph) * exp(-t / 0.25) + low * 2.5 * exp(-t / 0.35)
	_mix_wrapped(out, _noise_burst(2000.0, 0.7, 0.002, 0.02), 0, 0.5)
	return _normalize(_forest_echo(out), 0.85)


## Ostrze trafia bestię: mięsiste uderzenie, „chlap” i krótki dźwięk stali.
func _blade_hit(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(int(0.3 * RATE))
	var ph := 0.0
	var f := _rng.randf_range(125.0, 150.0)
	for j in int(0.1 * RATE):
		var t := float(j) / RATE
		ph += TAU * (f - 40.0 * t / 0.1) / RATE
		out[j] += sin(ph) * exp(-t / 0.05)
	_mix_wrapped(out, _noise_burst(_rng.randf_range(800.0, 1000.0), 1.0, 0.002, 0.05), 0, 0.6)
	_mix_wrapped(out, _noise_burst(4200.0, 1.2, 0.001, 0.012), 0, 0.35)
	for partial: Vector3 in [Vector3(1900.0, 0.5, 0.12), Vector3(3100.0, 0.35, 0.09), Vector3(4400.0, 0.25, 0.06)]:
		var pf := partial.x * _rng.randf_range(0.97, 1.03)
		for j in out.size():
			var t := float(j) / RATE
			out[j] += sin(TAU * pf * t) * partial.y * exp(-t / partial.z) * 0.22
	return _normalize(out, 0.75)


## Ryk przy upadku: długi, opadający pomruk z chrapliwym oddechem i echem lasu.
func _roar() -> PackedFloat32Array:
	var out := _growl(85.0, 40.0, 1.6, 0.9, 380.0, 97)
	_rng.seed = 98
	var breath := Biquad.bandpass(900.0, 0.8, RATE)
	for j in out.size():
		var t := float(j) / RATE
		out[j] += breath.process(_rng.randf_range(-1.0, 1.0)) * 0.6 * exp(-t / 0.8)
	var tail := PackedFloat32Array()
	tail.resize(int(0.6 * RATE))
	out.append_array(tail)
	return _normalize(_forest_echo(out), 0.75)


# ---------------------------------------------------------------- klocki

## Szum przepuszczony przez filtr pasmowy, z narastaniem i wygasaniem.
func _noise_burst(freq: float, q: float, attack: float, decay: float) -> PackedFloat32Array:
	var n := int((attack + decay * 5.0) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := Biquad.bandpass(freq, q, RATE)
	for j in n:
		var t := float(j) / RATE
		var env := t / attack if t < attack else exp(-(t - attack) / decay)
		out[j] = bp.process(_rng.randf_range(-1.0, 1.0)) * env * 2.0
	return out


## Bąbelek: krótki ton, który szybko idzie w górę i gaśnie.
func _bubble(freq: float, rise: float, decay: float) -> PackedFloat32Array:
	var n := int(decay * 5.0 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for j in n:
		var t := float(j) / RATE
		ph += TAU * freq * (1.0 + (rise - 1.0) * minf(1.0, t / (decay * 3.0))) / RATE
		out[j] = sin(ph) * exp(-t / decay) * minf(1.0, t / 0.002)
	return out


## Dodaje dźwięk do bufora; to, co wystaje poza koniec, wraca na początek (dla pętli).
func _mix_wrapped(into: PackedFloat32Array, sound: PackedFloat32Array, at: int, gain: float) -> void:
	var total := into.size()
	for j in sound.size():
		into[(at + j) % total] += sound[j] * gain


## Dwa przytłumione odbicia od drzew - las brzmi wtedy przestrzennie.
func _forest_echo(dry: PackedFloat32Array) -> PackedFloat32Array:
	var out := dry.duplicate()
	for echo: Vector2 in [Vector2(0.17, 0.28), Vector2(0.36, 0.14)]:
		var delay := int(echo.x * RATE)
		var low := 0.0
		for j in range(delay, out.size()):
			low += 0.25 * (dry[j - delay] - low)
			out[j] += low * echo.y
	return out


## Pętla bez szwu: ostatnie `fade` sekund nakładamy płynnie na początek i obcinamy.
func _loop_crossfade(buf: PackedFloat32Array, length: float, fade: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var f := int(fade * RATE)
	var out := buf.slice(0, n)
	for j in f:
		var k := float(j) / f
		out[j] = buf[j] * sqrt(k) + buf[n + j] * sqrt(1.0 - k)
	return out


func _normalize(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for s in buf:
		m = maxf(m, absf(s))
	var k := peak / m
	for j in buf.size():
		buf[j] *= k
	return buf


# ---------------------------------------------------------------- zapis WAV

## Zapisuje 16-bitowy WAV. Przy pętli dopisuje blok „smpl”, z którego Godot sam odczyta zapętlenie.
func _save(file_name: String, channels: Array, loop: bool) -> void:
	var frames: int = channels[0].size()
	var count := channels.size()
	var data := PackedByteArray()
	data.resize(frames * count * 2)
	for j in frames:
		for c in count:
			var v := clampi(int(round(channels[c][j] * 32767.0)), -32768, 32767)
			data.encode_s16((j * count + c) * 2, v)
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR + file_name), FileAccess.WRITE)
	var smpl_size := 36 + 24 if loop else 0
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(4 + 24 + 8 + data.size() + (8 + smpl_size if loop else 0))
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)  # PCM
	f.store_16(count)
	f.store_32(RATE)
	f.store_32(RATE * count * 2)
	f.store_16(count * 2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	if loop:
		f.store_buffer("smpl".to_ascii_buffer())
		f.store_32(smpl_size)
		for v in [0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0]:
			f.store_32(v)
		for v in [0, 0, 0, frames - 1, 0, 0]:  # pętla do przodu: od pierwszej do ostatniej próbki
			f.store_32(v)
	f.close()


## Filtr dwubiegunowy (pasmowy), wg wzorów R. Bristow-Johnsona.
class Biquad:
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	static func bandpass(freq: float, q: float, rate: int) -> Biquad:
		var f := Biquad.new()
		f.set_bandpass(freq, q, rate)
		return f

	## Zmienia pasmo filtra w trakcie pracy (bez kasowania jego pamięci).
	func set_bandpass(freq: float, q: float, rate: int) -> void:
		var w := TAU * freq / rate
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		b0 = alpha / a0
		b1 = 0.0
		b2 = -alpha / a0
		a1 = -2.0 * cos(w) / a0
		a2 = (1.0 - alpha) / a0

	func process(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y
