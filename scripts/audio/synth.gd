class_name Synth
extends RefCounted
## Prosty syntezator: zamienia nuty z MIDI na dźwięk przy starcie gry.
##
## Prototyp nie ma jeszcze próbek dźwięków, więc każdy instrument jest wyliczany wzorem.
## Gotowe brzmienia (np. nagrany szczęk oręża) można później podmienić w render_note().
## Cały podkład renderujemy raz, przed walką - w trakcie gry nic nie jest liczone.

enum Instrument {
	HEART,  ## głuche uderzenie serca
	BOSS,   ## niski, ciemny ton bossa
	PAD,    ## miękka plama tła
	CLASH,  ## metaliczne zderzenie oręża - melodia gracza
}

const SAMPLE_RATE := 44100

## Ile sekund dźwięku zostaje po końcu nuty (wybrzmienie).
const RELEASE := {
	Instrument.HEART: 0.0,
	Instrument.BOSS: 0.25,
	Instrument.PAD: 0.8,
	Instrument.CLASH: 0.0,
}

# Składowe metalicznego brzmienia: (mnożnik częstotliwości, głośność, szybkość wygasania).
const CLASH_PARTIALS: Array[Vector3] = [
	Vector3(1.0, 1.0, 3.0),
	Vector3(2.0, 0.35, 5.0),
	Vector3(2.76, 0.45, 6.5),
	Vector3(4.07, 0.22, 9.0),
	Vector3(5.40, 0.16, 12.0),
]

# Gotowe dźwięki nut, żeby powtarzające się nuty (np. bicie serca) liczyć tylko raz.
static var _cache := {}


static func midi_to_hz(pitch: float) -> float:
	return 440.0 * pow(2.0, (pitch - 69.0) / 12.0)


## Miksuje wszystkie nuty jednym instrumentem do bufora o podanej długości (s).
static func render_track(notes: Array[MidiNote], instrument: Instrument, length: float,
		gain: float = 1.0, into: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	var total := int(ceil(length * SAMPLE_RATE))
	if into.size() < total:
		into.resize(total)
	for note in notes:
		var sound := render_note(note, instrument)
		var offset := int(round(note.time * SAMPLE_RATE))
		var count := mini(sound.size(), into.size() - offset)
		for i in count:
			into[offset + i] += sound[i] * gain
	return into


## Dźwięk jednej nuty jako próbki w zakresie około -1..1. Wynik jest zapamiętywany - nie zmieniaj go.
static func render_note(note: MidiNote, instrument: Instrument) -> PackedFloat32Array:
	var uses_duration := instrument == Instrument.BOSS or instrument == Instrument.PAD
	var key := Vector4i(instrument, note.pitch, note.velocity, int(note.duration * 1000.0) if uses_duration else 0)
	if not _cache.has(key):
		_cache[key] = _render_uncached(note, instrument)
	return _cache[key]


static func _render_uncached(note: MidiNote, instrument: Instrument) -> PackedFloat32Array:
	var amp := note.velocity / 127.0
	var freq := midi_to_hz(note.pitch)
	match instrument:
		Instrument.HEART:
			return _heart(freq, amp)
		Instrument.BOSS:
			return _boss(freq, amp, note.duration)
		Instrument.PAD:
			return _pad(freq, amp, note.duration)
		_:
			return _clash(freq, amp)


static func _heart(freq: float, amp: float) -> PackedFloat32Array:
	var out := _buffer(0.35)
	var f_end := clampf(freq, 30.0, 120.0)
	var f_start := f_end * 1.8
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		phase += TAU * (f_end + (f_start - f_end) * exp(-t * 30.0)) / SAMPLE_RATE
		var env := (1.0 - exp(-t * 400.0)) * exp(-t * 14.0)
		out[i] = (sin(phase) + 0.35 * sin(2.0 * phase)) * env * amp * 0.8
	return out


static func _boss(freq: float, amp: float, duration: float) -> PackedFloat32Array:
	var release: float = RELEASE[Instrument.BOSS]
	var out := _buffer(duration + release)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0)
	var step := TAU * freq / SAMPLE_RATE
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var p := step * i
		var env := minf(t / 0.008, 1.0) * exp(-t * 1.2)
		if t > duration:
			env *= exp(-(t - duration) * 15.0)
		var tone := sin(p) + 0.5 * sin(2.0 * p) + 0.3 * sin(3.0 * p) + 0.15 * sin(5.0 * p)
		var breath := rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.6  # szorstki początek
		out[i] = (tone * 0.45 + breath) * env * amp
	return out


static func _pad(freq: float, amp: float, duration: float) -> PackedFloat32Array:
	var release: float = RELEASE[Instrument.PAD]
	var out := _buffer(duration + release)
	var step_a := TAU * freq * 0.998 / SAMPLE_RATE
	var step_b := TAU * freq * 1.002 / SAMPLE_RATE
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var env := minf(t / 0.4, 1.0)
		if t > duration:
			env *= maxf(1.0 - (t - duration) / release, 0.0)
		out[i] = (sin(step_a * i) + sin(step_b * i)) * 0.5 * env * amp * 0.4
	return out


static func _clash(freq: float, amp: float) -> PackedFloat32Array:
	var out := _buffer(1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0)
	for partial in CLASH_PARTIALS:
		var step := TAU * freq * partial.x / SAMPLE_RATE
		for i in out.size():
			out[i] += sin(step * i) * partial.y * exp(-float(i) / SAMPLE_RATE * partial.z)
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var hit := rng.randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.8  # trzask na początku
		out[i] = (out[i] * 0.4 + hit) * amp * minf(t / 0.001, 1.0)
	return out


static func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(ceil(seconds * SAMPLE_RATE)))
	return out


## Zamienia bufor na strumień, który odtwarza AudioStreamPlayer.
## Jeśli coś przekracza pełną głośność, cały bufor jest ściszany (bez przesterowania).
static func to_stream(buffer: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for sample in buffer:
		peak = maxf(peak, absf(sample))
	var scale := 32767.0
	if peak > 0.98:
		scale *= 0.98 / peak
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i in buffer.size():
		bytes.encode_s16(i * 2, int(buffer[i] * scale))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## Suma dwóch buforów (dłuższy wyznacza długość).
static func mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out
