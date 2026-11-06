class_name AudioBuses
extends RefCounted
## Szyny dźwięku wspólne dla wszystkich scen.
## WORLD: dźwięki świata (las, bestia, oręż). Ma filtr, którym przy słabnącej przytomności
## świat robi się głuchy. Serce bohatera gra poza nią, więc słychać je wyraźnie.
## Na głównej szynie stoi ogranicznik, który chroni przed przesterowaniem.

const WORLD := "World"


## Tworzy szyny, jeśli ich jeszcze nie ma, i zwraca filtr szyny świata.
static func ensure_world_bus() -> AudioEffectLowPassFilter:
	if AudioServer.get_bus_index(WORLD) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, WORLD)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.add_bus_effect(index, AudioEffectLowPassFilter.new())
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	var lowpass := AudioServer.get_bus_effect(AudioServer.get_bus_index(WORLD), 0) as AudioEffectLowPassFilter
	lowpass.cutoff_hz = 20000.0
	return lowpass


## Częstotliwość filtra dla danej przytomności: 500 Hz (głucho) .. 20 kHz (wyraźnie).
static func muffle_cutoff(consciousness: float) -> float:
	return 500.0 * pow(40.0, clampf(consciousness, 0.0, 1.0))
