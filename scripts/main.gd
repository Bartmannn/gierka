extends Node
## Scena główna prototypu: jedna walka, która jest jednocześnie jednym utworem.
##
## Przebieg:
##   INTRO   - bohater otwiera oczy, słychać tylko ciszę
##   FIGHT   - gra utwór z MIDI; gracz wybija nuty ścieżki "gracz"
##   SILENCE - po wygranej chwila ciszy
##   REWARD  - pierwszy raz słychać pełny utwór, ze wszystkimi nutami gracza
##   END     - spokój; cios albo R zaczyna od nowa
##   FAINTED - utrata przytomności; po chwili walka zaczyna się od nowa
##
## Gra nie ma żadnego interfejsu. Rytm i zdrowie widać wyłącznie w otoczeniu
## (PuddleView) i w powiekach bohatera (Eyelids).
##
## Opcje wiersza poleceń (po "--"):
##   --autoplay        gra sama trafia każdą nutę (do sprawdzania przebiegu)
##   --exit-when-done  zamyka grę po nagrodzie albo omdleniu (do testów automatycznych)

enum State { INTRO, FIGHT, SILENCE, REWARD, END, FAINTED }

const WORLD_BUS := "World"

@export_file("*.mid") var song_path := "res://music/prototyp.mid"

@export_group("Ocena trafień (ms)")
@export var perfect_window_ms := 50.0
@export var good_window_ms := 100.0
@export var early_miss_window_ms := 250.0
## Cios lekko przed nutą zabrzmi dokładnie w rytm (gra "dociąga" dźwięk do nuty).
@export var snap_early_hits_ms := 40.0
## Kalibracja opóźnienia sprzętu: dodatnia wartość, gdy gracz trafia systematycznie za późno.
@export var input_offset_ms := 0.0

@export_group("Przytomność")
@export_range(0.0, 1.0) var miss_damage := 0.12
@export_range(0.0, 1.0) var perfect_heal := 0.04
@export_range(0.0, 1.0) var good_heal := 0.02

@export_group("Przebieg (s)")
@export var intro_seconds := 2.0
@export var silence_before_reward := 2.5
@export var faint_seconds := 3.0

@export_group("Test")
@export var autoplay := false

@onready var view: PuddleView = $View
@onready var eyelids: Eyelids = $Eyelids
@onready var heart_player: AudioStreamPlayer = $HeartPlayer
@onready var world_player: AudioStreamPlayer = $WorldPlayer
@onready var hit_player: AudioStreamPlayer = $HitPlayer
@onready var reward_player: AudioStreamPlayer = $RewardPlayer

var song: Song
var judge: Judge
var state := State.INTRO
var consciousness := 1.0  ## 0..1 - "zdrowie" rannego bohatera

var _felt_consciousness := 1.0  # wygładzona wartość, którą widać i słychać
var _state_time := 0.0
var _song_time := 0.0
var _heart_cursor: NoteCursor
var _boss_cursor: NoteCursor
var _reward_cursor: NoteCursor
var _delayed_hits: Array[Cue] = []  # trafienia odrobinę za wcześnie, czekające na swoją nutę
var _clash_sounds := {}             # Vector2i(wysokość, głośność) -> AudioStreamWAV
var _world_lowpass: AudioEffectLowPassFilter
var _exit_when_done := false
var _eyes_at_faint := 1.0
var _fade: Tween


func _ready() -> void:
	# Prototyp rytmu rysuje na siatce 320x180, a reszta gry ma 480x270.
	get_window().content_scale_size = PuddleView.SCREEN
	_read_command_line()
	InputSetup.ensure_actions()
	_setup_audio_buses()
	song = Song.from_midi_file(song_path)
	judge = Judge.new(song.player_cues)
	judge.perfect_window = perfect_window_ms / 1000.0
	judge.good_window = good_window_ms / 1000.0
	judge.early_miss_window = early_miss_window_ms / 1000.0
	_render_audio()
	_start_attempt()


func _read_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	autoplay = autoplay or args.has("--autoplay")
	_exit_when_done = args.has("--exit-when-done")


# --- Przebieg walki ----------------------------------------------------------

func _start_attempt() -> void:
	if _fade:
		_fade.kill()
	for player in [heart_player, world_player, hit_player, reward_player]:
		player.stop()
	heart_player.volume_db = 0.0
	world_player.volume_db = 0.0
	consciousness = 1.0
	_felt_consciousness = 1.0
	judge.reset()
	_heart_cursor = NoteCursor.new(song.heart_notes)
	_boss_cursor = NoteCursor.new(song.boss_notes)
	_delayed_hits.clear()
	view.reset()
	_song_time = -intro_seconds
	_enter(State.INTRO)


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	print("[stan] ", State.keys()[state], "  przytomność=%.2f" % consciousness)
	match state:
		State.FIGHT:
			heart_player.play()
			world_player.play()
			hit_player.play()
		State.SILENCE:
			heart_player.stop()
			world_player.stop()
		State.REWARD:
			_heart_cursor = NoteCursor.new(song.heart_notes)
			_boss_cursor = NoteCursor.new(song.boss_notes)
			_reward_cursor = NoteCursor.new(song.player_cues)
			reward_player.play()
		State.FAINTED:
			_eyes_at_faint = eyelids.openness
			_fade = create_tween().set_parallel()
			_fade.tween_property(heart_player, "volume_db", -40.0, faint_seconds * 0.6)
			_fade.tween_property(world_player, "volume_db", -40.0, faint_seconds * 0.4)
		State.END:
			if _exit_when_done:
				_quit(0)


func _process(delta: float) -> void:
	_state_time += delta
	match state:
		State.INTRO:
			_song_time = _state_time - intro_seconds
			if _state_time >= intro_seconds:
				_enter(State.FIGHT)
		State.FIGHT:
			_process_fight()
		State.SILENCE:
			if _state_time >= silence_before_reward:
				_enter(State.REWARD)
		State.REWARD:
			_process_reward(delta)
		State.FAINTED:
			if _state_time >= faint_seconds:
				if _exit_when_done:
					_quit(1)
				else:
					_start_attempt()
	_update_senses(delta)


func _process_fight() -> void:
	_song_time = maxf(_song_time, _playback_time(heart_player))
	if autoplay and not judge.upcoming(_song_time, 0.0).is_empty():
		_strike()
	for cue in judge.collect_missed(_song_time):
		_on_miss(cue)
	_play_delayed_hits()
	for note: MidiNote in _heart_cursor.advance(_song_time):
		view.on_heartbeat(note)
	for note: MidiNote in _boss_cursor.advance(_song_time):
		view.on_boss_note(note)
	view.song_time = _song_time
	view.upcoming_cues = judge.upcoming(_song_time, view.glint_lead)

	if consciousness <= 0.0:
		_enter(State.FAINTED)
	elif _song_time > song.length + 0.5 or not heart_player.playing:
		_enter(State.SILENCE)


func _process_reward(delta: float) -> void:
	consciousness = move_toward(consciousness, 1.0, delta * 0.05)
	var time := _playback_time(reward_player)
	for note: MidiNote in _heart_cursor.advance(time):
		view.on_heartbeat(note)
	for note: MidiNote in _boss_cursor.advance(time):
		view.on_boss_note(note)
	for cue: Cue in _reward_cursor.advance(time):
		view.on_hit(cue, true)
	if not reward_player.playing:
		_enter(State.END)


## Zatrzymuje dźwięk przed wyjściem, żeby silnik mógł wszystko posprzątać.
func _quit(exit_code: int) -> void:
	set_process(false)
	for player in [heart_player, world_player, hit_player, reward_player]:
		player.stop()
	await get_tree().create_timer(0.1).timeout  # serwer dźwięku zwalnia strumienie przy następnym miksowaniu
	get_tree().quit(exit_code)


# --- Wejście gracza ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		_quit(0)
	elif event.is_action_pressed("restart"):
		_start_attempt()
	elif event.is_action_pressed("strike", false, true):
		match state:
			State.FIGHT:
				_song_time = maxf(_song_time, _playback_time(heart_player))
				_strike()
			State.END:
				_start_attempt()


func _strike() -> void:
	var result := judge.strike(_song_time - input_offset_ms / 1000.0)
	match result.kind:
		Judge.Kind.PERFECT, Judge.Kind.GOOD:
			var perfect := result.kind == Judge.Kind.PERFECT
			consciousness = minf(1.0, consciousness + (perfect_heal if perfect else good_heal))
			if result.offset < 0.0 and -result.offset <= snap_early_hits_ms / 1000.0:
				_delayed_hits.append(result.cue)  # zabrzmi dokładnie na nucie
			else:
				_play_clash(result.cue)
			view.on_hit(result.cue, perfect)
		Judge.Kind.MISS:
			_on_miss(result.cue)
		Judge.Kind.EMPTY:
			view.on_empty_swing()


func _on_miss(cue: Cue) -> void:
	consciousness = maxf(0.0, consciousness - miss_damage)
	view.on_miss(cue)


# --- Dźwięk ------------------------------------------------------------------

## Czas utworu, który gracz właśnie słyszy (z poprawką na bufor karty dźwiękowej).
func _playback_time(player: AudioStreamPlayer) -> float:
	if not player.playing:
		return _song_time
	return player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


func _play_clash(cue: Cue) -> void:
	var playback := hit_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if playback == null:
		return
	for note in cue.notes:
		playback.play_stream(_clash_sounds[Vector2i(note.pitch, note.velocity)])


func _play_delayed_hits() -> void:
	while not _delayed_hits.is_empty() and _delayed_hits[0].time <= _song_time + 0.005:
		_play_clash(_delayed_hits.pop_front())


## Słabnąca przytomność: obraz ciemnieje, powieki opadają, świat cichnie i głuchnie, serce słychać mocniej.
func _update_senses(delta: float) -> void:
	_felt_consciousness = lerpf(_felt_consciousness, consciousness, 1.0 - exp(-delta * 4.0))
	var c := _felt_consciousness
	view.consciousness = c
	eyelids.darkness = (1.0 - c) * 0.45
	var droop := (1.0 - c) * (1.0 - c) * 0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 600.0))
	var awake := 0.55 + 0.45 * c - droop
	match state:
		State.INTRO:
			eyelids.openness = smoothstep(0.0, intro_seconds, _state_time) * awake
		State.FAINTED:
			eyelids.openness = lerpf(_eyes_at_faint, 0.0, minf(_state_time / 1.2, 1.0))
		_:
			eyelids.openness = awake
	if state == State.FIGHT:
		_world_lowpass.cutoff_hz = 500.0 * pow(40.0, c)  # 500 Hz (głucho) .. 20 kHz (wyraźnie)
		world_player.volume_db = lerpf(-8.0, 0.0, c)
		heart_player.volume_db = lerpf(3.0, 0.0, c)
	else:
		_world_lowpass.cutoff_hz = 20000.0


func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index(WORLD_BUS) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, WORLD_BUS)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.add_bus_effect(index, AudioEffectLowPassFilter.new())
	_world_lowpass = AudioServer.get_bus_effect(AudioServer.get_bus_index(WORLD_BUS), 0)
	world_player.bus = WORLD_BUS
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())  # chroni przed przesterowaniem


## Liczy cały dźwięk przed walką, żeby w trakcie gry nic nie obciążało komputera.
func _render_audio() -> void:
	var started := Time.get_ticks_msec()
	var length := song.length + 1.5
	var heart := Synth.render_track(song.heart_notes, Synth.Instrument.HEART, length, 0.7)
	var world := Synth.render_track(song.background_notes, Synth.Instrument.PAD, length, 0.7)
	Synth.render_track(song.boss_notes, Synth.Instrument.BOSS, length, 0.7, world)
	var melody := Synth.render_track(song.player_notes, Synth.Instrument.CLASH, length, 0.8)
	heart_player.stream = Synth.to_stream(heart)
	world_player.stream = Synth.to_stream(world)
	reward_player.stream = Synth.to_stream(Synth.mix(Synth.mix(heart, world), melody))

	for note in song.player_notes:
		var key := Vector2i(note.pitch, note.velocity)
		if not _clash_sounds.has(key):
			_clash_sounds[key] = Synth.to_stream(Synth.render_note(note, Synth.Instrument.CLASH))
	var polyphonic := AudioStreamPolyphonic.new()
	polyphonic.polyphony = 12
	hit_player.stream = polyphonic
	print("Dźwięk przygotowany w %d ms (utwór: %.1f s, nut gracza: %d)" % [
		Time.get_ticks_msec() - started, song.length, song.player_cues.size()])
