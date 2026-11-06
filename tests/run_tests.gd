extends SceneTree
## Testy logiki gry, uruchamiane bez okna:
##   godot --headless --path . --script res://tests/run_tests.gd
## Kod wyjścia 0 = wszystko działa, 1 = coś się zepsuło (szczegóły w wypisanych liniach FAIL).

var _failures := 0
var _checks := 0


func _init() -> void:
	test_midi_reader_reads_demo_song()
	test_midi_reader_tempo_change_and_running_status()
	test_track_roles()
	test_chords_become_one_cue()
	test_judge_windows()
	test_judge_late_misses()
	test_note_cursor()
	test_synth_renders_sound()
	test_friend_stands_on_ground()
	test_friend_sprite_sheet()
	test_ambience_loops()
	test_motor_runs_fast()
	test_motor_roll()
	test_motor_attack_cooldown_and_buffer()
	test_motor_attack_keeps_facing()
	test_slash_hits_beast_once()
	test_roll_under_charge()
	test_hits_lower_consciousness()
	test_eye_glint_patterns()
	test_stomp_waves_and_bounds()
	test_beast_dies()
	print("%d sprawdzeń, %d błędów" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL: ", message)


func near(a: float, b: float, epsilon: float = 0.001) -> bool:
	return absf(a - b) <= epsilon


# --- MIDI ----------------------------------------------------------------------

func test_midi_reader_reads_demo_song() -> void:
	var tracks := MidiReader.load_file("res://music/prototyp.mid")
	var names := tracks.map(func(t: MidiTrack) -> String: return t.name)
	check(names == ["prototyp", "serce", "tlo", "boss", "gracz"], "nazwy ścieżek: %s" % [names])
	var song := Song.from_tracks(tracks)
	check(near(song.length, 20.0), "utwór trwa 20 s, a jest %.3f" % song.length)
	check(song.player_cues.size() == 13, "13 nut gracza, a jest %d" % song.player_cues.size())
	check(near(song.player_cues[0].time, 5.0), "pierwsza nuta gracza w 5. sekundzie (96 BPM, 8. ćwierćnuta)")
	check(song.player_cues[0].notes[0].pitch == 69, "pierwsza nuta gracza to A4")
	check(song.heart_notes.size() == 64, "64 uderzenia serca")


func test_midi_reader_tempo_change_and_running_status() -> void:
	# Ręcznie złożony plik: 1 ścieżka, 96 tyknięć na ćwierćnutę,
	# tempo 120 BPM, po 1 ćwierćnucie zmiana na 60 BPM, nuty zapisane z "running status".
	var track := PackedByteArray([
		0x00, 0xFF, 0x03, 0x05, 0x67, 0x72, 0x61, 0x63, 0x7A,  # nazwa "gracz"
		0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,              # 500000 us = 120 BPM
		0x00, 0x90, 0x3C, 0x64,                                # C4 on, t=0
		0x60, 0x3C, 0x00,                                      # running status: C4 off po 96 tyk.
		0x00, 0xFF, 0x51, 0x03, 0x0F, 0x42, 0x40,              # 1000000 us = 60 BPM
		0x60, 0x3E, 0x50,                                      # D4 on po kolejnych 96 tyk.
		0x81, 0x40, 0x80, 0x3E, 0x00,                          # D4 off po 192 tyk. (varlen 0x81 0x40)
		0x00, 0xFF, 0x2F, 0x00,
	])
	var header := PackedByteArray([0x4D, 0x54, 0x68, 0x64, 0, 0, 0, 6, 0, 0, 0, 1, 0, 96])
	var chunk := PackedByteArray([0x4D, 0x54, 0x72, 0x6B, 0, 0, 0, track.size()])
	var tracks := MidiReader.new().parse(header + chunk + track)
	check(tracks.size() == 1 and tracks[0].name == "gracz", "ścieżka z nazwą")
	var notes := tracks[0].notes
	check(notes.size() == 2, "dwie nuty, a jest %d" % notes.size())
	if notes.size() == 2:
		check(near(notes[0].time, 0.0) and near(notes[0].duration, 0.5), "C4: 0 s, 0.5 s (120 BPM)")
		check(near(notes[1].time, 1.5) and near(notes[1].duration, 2.0), "D4: 1.5 s, 2 s (po zmianie na 60 BPM)")
		check(notes[1].pitch == 62 and notes[1].velocity == 0x50, "D4 ma wysokość 62 i głośność 80")


func test_track_roles() -> void:
	check(Song.role_for_track_name("Gracz - miecz") == Song.Role.PLAYER, "gracz")
	check(Song.role_for_track_name("BOSS kroki") == Song.Role.BOSS, "boss")
	check(Song.role_for_track_name("Serce") == Song.Role.HEART, "serce")
	check(Song.role_for_track_name("TripleOscillator") == Song.Role.BACKGROUND, "inne = tło")


func test_chords_become_one_cue() -> void:
	var notes: Array[MidiNote] = [MidiNote.new(1.0, 0.5, 60), MidiNote.new(1.005, 0.5, 64), MidiNote.new(2.0, 0.5, 67)]
	var cues := Song.group_into_cues(notes)
	check(cues.size() == 2, "akord to jeden cios")
	check(cues[0].notes.size() == 2 and cues[0].top_pitch() == 64, "akord ma obie nuty")


# --- Ocena trafień -----------------------------------------------------------

func _make_judge(times: Array[float]) -> Judge:
	var notes: Array[MidiNote] = []
	for t in times:
		notes.append(MidiNote.new(t, 0.2, 60))
	return Judge.new(Song.group_into_cues(notes))


func test_judge_windows() -> void:
	var judge := _make_judge([1.0, 2.0, 3.0, 4.0])
	check(judge.strike(0.2).kind == Judge.Kind.EMPTY, "zamach daleko przed nutą jest pusty")
	check(judge.strike(1.03).kind == Judge.Kind.PERFECT, "30 ms po nucie = perfect")
	check(judge.strike(1.85).kind == Judge.Kind.MISS, "150 ms przed nutą psuje nutę (ochrona przed klepaniem)")
	check(judge.strike(2.92).kind == Judge.Kind.GOOD, "80 ms przed nutą = good")
	var late := judge.strike(4.09)
	check(late.kind == Judge.Kind.GOOD and near(late.offset, 0.09), "90 ms po nucie = good z przesunięciem 0.09")
	check(judge.is_finished(), "wszystkie nuty ocenione")


func test_judge_late_misses() -> void:
	var judge := _make_judge([1.0, 1.3])
	check(judge.collect_missed(1.05).is_empty(), "nuta jeszcze w oknie")
	# Spóźniony cios przy 1.25: pierwsza nuta przepadła, druga jest w oknie.
	var result := judge.strike(1.25)
	check(result.kind == Judge.Kind.GOOD and near(result.cue.time, 1.3), "cios trafia drugą nutę")
	check(judge.collect_missed(1.3).size() == 1, "pierwsza nuta zgłoszona jako chybiona dokładnie raz")
	check(judge.collect_missed(5.0).is_empty(), "nic więcej do zgłoszenia")


func test_note_cursor() -> void:
	var notes: Array[MidiNote] = [MidiNote.new(0.5), MidiNote.new(1.0), MidiNote.new(1.5)]
	var cursor := NoteCursor.new(notes)
	check(cursor.advance(0.4).is_empty(), "przed pierwszą nutą")
	check(cursor.advance(1.0).size() == 2, "dwie nuty do 1.0 s")
	check(cursor.advance(1.0).is_empty(), "żadna nuta nie wraca drugi raz")


# --- Dźwięk ------------------------------------------------------------------

func test_synth_renders_sound() -> void:
	var note := MidiNote.new(0.0, 0.5, 69, 127)
	for instrument: Synth.Instrument in Synth.Instrument.values():
		var sound := Synth.render_note(note, instrument)
		var peak := 0.0
		for s in sound:
			peak = maxf(peak, absf(s))
		check(sound.size() > 1000 and peak > 0.05 and peak < 2.0,
			"instrument %s brzmi (szczyt %.2f)" % [Synth.Instrument.keys()[instrument], peak])
	var stream := Synth.to_stream(PackedFloat32Array([0.0, 2.0, -2.0]))
	check(stream.data.decode_s16(2) > 30000 and stream.data.decode_s16(4) < -30000, "głośny bufor jest ściszany, nie przycinany")


# --- Scena lasu ----------------------------------------------------------------

func test_friend_stands_on_ground() -> void:
	# Wiersz pod stopami musi być ziemią w grafice, a kilka pikseli wyżej musi być już pusto
	# (poza trzcinami przy jeziorku, od x=196) - inaczej postać wisi w powietrzu albo tonie w gruncie.
	var ground := (load("res://grafika/sceny/las_jeziorko/warstwy/8_ziemia.png") as Texture2D).get_image()
	var bad: Array[int] = []
	for x in range(int(ForestTerrain.WALK_MIN_X), int(ForestTerrain.WALK_MAX_X) + 1):
		var y := ForestTerrain.ground_y(x)
		var solid_below := ground.get_pixel(x, y).a > 0.5 and ground.get_pixel(x, y + 3).a > 0.5
		var open_above := x >= 196 or ground.get_pixel(x, y - 7).a < 0.5
		if not (solid_below and open_above):
			bad.append(x)
	check(bad.is_empty(), "postać stoi na ziemi z grafiki (złe kolumny: %s)" % [bad.slice(0, 10)])


func test_friend_sprite_sheet() -> void:
	var sheet := (load("res://grafika/postacie/przyjaciel_ruch.png") as Texture2D).get_image()
	var size := Friend.FRAME_SIZE
	check(sheet.get_size() == Vector2i(size.x * Friend.COLUMNS, size.y * Friend.ROWS), "arkusz postaci ma 8x6 klatek 80x72")
	# Ostatni wiersz nad ziemią (68) musi dotykać: stanie, postawienie stopy w biegu, cały przewrót, cięcia.
	var grounded := {
		Friend.ROW_IDLE: range(Friend.IDLE_FRAMES),
		Friend.ROW_RUN: Friend.RUN_CONTACT_FRAMES,
		Friend.ROW_ROLL: range(Friend.ROLL_FRAMES),
		Friend.ROW_ATTACK_SIDE: range(Friend.ATTACK_FRAMES),
		Friend.ROW_ATTACK_UP: range(Friend.ATTACK_FRAMES),
		Friend.ROW_HURT: range(2),
	}
	for row: int in grounded:
		for k: int in grounded[row]:
			var touches := false
			for x in size.x:
				if sheet.get_pixel(k * size.x + x, row * size.y + 68).a > 0.5:
					touches = true
			check(touches, "klatka %d w rzędzie %d stoi na ziemi" % [k, row])
	var slash := (load("res://grafika/efekty/ciecie.png") as Texture2D).get_image()
	check(slash.get_size() == Vector2i(size.x * Friend.SLASH_FRAMES, size.y * 2), "arkusz smugi ma 5x2 klatek 80x72")


func test_ambience_loops() -> void:
	for path in ["wiatr", "woda", "swierszcz_lewy", "swierszcz_prawy"]:
		var stream := load("res://sounds/otoczenie/%s.wav" % path) as AudioStreamWAV
		check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"%s.wav gra w pętli" % path)


# --- Ruch przyjaciela (FriendMotor) ----------------------------------------------

const STEP := 1.0 / 60.0


## Przewija logikę o podany czas; zwraca wszystkie zdarzenia z czasem ich wystąpienia.
func _run_motor(motor: FriendMotor, seconds: float, axis: float = 0.0, up: bool = false) -> Array:
	var log := []
	var t := 0.0
	while t < seconds - 0.0001:
		for e in motor.update(STEP, axis, up, false, false):
			log.append([e, t])
		t += STEP
	return log


func test_motor_runs_fast() -> void:
	var motor := FriendMotor.new()
	motor.x = 200.0
	_run_motor(motor, 0.1, 1.0)
	check(near(motor.velocity, motor.run_speed), "pełna prędkość biegu po 0,1 s (jest %.1f)" % motor.velocity)
	check(motor.state == FriendMotor.State.RUN, "stan: bieg")
	_run_motor(motor, 0.1, 0.0)
	check(motor.velocity == 0.0 and motor.state == FriendMotor.State.IDLE, "zatrzymanie w 0,1 s")
	_run_motor(motor, 10.0, 1.0)
	check(motor.x == ForestTerrain.WALK_MAX_X, "bieg kończy się na krawędzi sceny")


func test_motor_roll() -> void:
	var motor := FriendMotor.new()
	motor.x = 200.0
	motor.update(STEP, 0.0, false, false, true)
	check(motor.state == FriendMotor.State.ROLL, "przewrót z miejsca")
	var time := STEP
	var protected := false
	while motor.state == FriendMotor.State.ROLL and time < 2.0:
		motor.update(STEP, 0.0, false, false, false)
		protected = protected or motor.is_invulnerable()
		time += STEP
	check(near(motor.x - 200.0, motor.roll_distance, 0.01), "przewrót pokonuje %.0f px (jest %.1f)" % [motor.roll_distance, motor.x - 200.0])
	check(absf(time - motor.roll_time) <= STEP * 1.5, "przewrót trwa %.2f s (jest %.2f)" % [motor.roll_time, time])
	check(protected and not motor.is_invulnerable(), "nietykalność tylko w trakcie przewrotu")
	# przy krawędzi sceny przewrót się zatrzymuje
	motor = FriendMotor.new()
	motor.x = ForestTerrain.WALK_MAX_X - 10.0
	motor.update(STEP, 1.0, false, false, true)
	_run_motor(motor, 1.0)
	check(motor.x == ForestTerrain.WALK_MAX_X, "przewrót nie wychodzi poza scenę")
	# przewrót przerywa cięcie
	motor = FriendMotor.new()
	motor.update(STEP, 0.0, false, true, false)
	motor.update(STEP, 0.0, false, false, true)
	check(motor.state == FriendMotor.State.ROLL, "przewrót przerywa cięcie")


func test_motor_attack_cooldown_and_buffer() -> void:
	var motor := FriendMotor.new()
	motor.x = 200.0
	var swings: Array[float] = []
	var t := 0.0
	# cios na starcie, drugi wciśnięty za wcześnie (0,1 s), trzeci tuż przed końcem przerwy (0,25 s)
	for press_at: float in [0.0, 0.1, 0.25]:
		while t < press_at - 0.0001:
			if motor.update(STEP, 0.0, false, false, false).has(&"swing"):
				swings.append(t)
			t += STEP
		if motor.update(STEP, 0.0, false, true, false).has(&"swing"):
			swings.append(t)
		t += STEP
	while t < 1.0:
		if motor.update(STEP, 0.0, false, false, false).has(&"swing"):
			swings.append(t)
		t += STEP
	check(swings.size() == 2, "zbyt wczesne wciśnięcie przepada, zapamiętane wchodzi (cięć: %d)" % swings.size())
	if swings.size() == 2:
		check(absf(swings[1] - motor.attack_cooldown) <= STEP * 1.5,
			"drugie cięcie zaraz po przerwie (%.2f s)" % swings[1])
	motor.update(STEP, 0.0, true, true, false)
	_run_motor(motor, 0.5)
	motor.update(STEP, 0.0, true, true, false)
	check(motor.state == FriendMotor.State.ATTACK_UP, "góra + atak = cięcie w górę")


func test_motor_attack_keeps_facing() -> void:
	var motor := FriendMotor.new()
	motor.x = 200.0
	motor.update(STEP, 0.0, false, true, false)
	_run_motor(motor, 0.1, -1.0)
	check(motor.facing == 1 and motor.is_attacking(), "w trakcie cięcia postać się nie odwraca")
	check(motor.x < 200.0, "w trakcie cięcia można się przesuwać")
	_run_motor(motor, 0.3, -1.0)
	check(motor.facing == -1 and motor.state == FriendMotor.State.RUN, "po cięciu odwraca się i biegnie")


# --- Walka z bestią (ForestFight, BeastBrain) --------------------------------------

## Walka z bestią, która sama nie atakuje ani nie chodzi (ataki wywołuje test).
func _quiet_fight() -> ForestFight:
	var fight := ForestFight.new()
	fight.beast.passive = true
	fight.beast.walk_speed = 0.0
	fight.beast.x = 380.0
	fight.beast.facing = -1
	fight.friend.x = 268.0
	return fight


func _step_fight(fight: ForestFight, seconds: float, axis: float = 0.0, up: bool = false,
		attack_at: float = -1.0) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var t := 0.0
	while t < seconds - 0.0001:
		var press := attack_at >= 0.0 and t <= attack_at and t + STEP > attack_at
		all.append_array(fight.step(STEP, axis, up, press, false))
		t += STEP
	return all


func _count(events: Array[Dictionary], type: StringName) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e.type == type).size()


func test_slash_hits_beast_once() -> void:
	var fight := _quiet_fight()
	var events := _step_fight(fight, 0.6, 0.0, false, 0.0)
	check(_count(events, &"beast_hit") == 1, "jedno cięcie trafia bestię dokładnie raz")
	check(fight.beast.health == fight.beast.max_health - 1, "bestia traci jeden punkt życia")
	fight.friend.x = 150.0
	events = _step_fight(fight, 0.6, 0.0, false, 0.0)
	check(_count(events, &"beast_hit") == 0, "cięcie z daleka nie trafia")
	fight.friend.x = 270.0
	events = _step_fight(fight, 0.6, 0.0, true, 0.0)
	check(_count(events, &"beast_hit") == 1, "cięcie w górę trafia łeb nad postacią")


func test_roll_under_charge() -> void:
	# stojący przyjaciel obrywa od szarży
	var fight := _quiet_fight()
	fight.friend.x = 230.0
	fight.beast.start_attack(BeastBrain.Attack.CHARGE)
	var events := _step_fight(fight, 2.5)
	check(_count(events, &"friend_hit") == 1, "szarża trafia stojącego")
	# przewrót w stronę bestii w dobrej chwili: przejście pod brzuchem
	fight = _quiet_fight()
	fight.friend.x = 230.0
	fight.beast.start_attack(BeastBrain.Attack.CHARGE)
	var hits := 0
	var rolled := false
	var t := 0.0
	while t < 2.5:
		var roll := false
		var boxes := fight.beast.attack_boxes()
		if not rolled and fight.beast.state == BeastBrain.State.ATTACK and not boxes.is_empty():
			var gap := boxes[0].position.x - fight.friend_body().end.x
			if gap < 28.0:
				roll = true
				rolled = true
		hits += _count(fight.step(STEP, 1.0 if roll else 0.0, false, false, roll), &"friend_hit")
		t += STEP
	check(rolled and hits == 0, "przewrót pod szarżą chroni przed ciosem (trafień: %d)" % hits)
	check(fight.friend.x > fight.beast.x, "po przewrocie przyjaciel jest za bestią")


func test_hits_lower_consciousness() -> void:
	var fight := _quiet_fight()
	fight.regen_delay = 999.0
	fight.heal_per_hit = 0.0
	var hit_times: Array[float] = []
	var t := 0.0
	while t < 20.0 and fight.outcome == ForestFight.Outcome.FIGHTING:
		if fight.beast.state == BeastBrain.State.IDLE and not fight.friend.is_invulnerable():
			fight.friend.x = 300.0
			fight.beast.start_attack(BeastBrain.Attack.TUSK)
		if _count(fight.step(STEP, 0.0, false, false, false), &"friend_hit") > 0:
			hit_times.append(t)
		t += STEP
	check(hit_times.size() == 4 and fight.outcome == ForestFight.Outcome.FAINTED,
		"4 trafienia = omdlenie (trafień: %d)" % hit_times.size())
	var shortest := 99.0
	for i in range(1, hit_times.size()):
		shortest = minf(shortest, hit_times[i] - hit_times[i - 1])
	check(shortest >= fight.friend.hurt_invulnerable, "po trafieniu chwila nietykalności (%.2f s)" % shortest)


## Poziomy błysku oczu w kolejnych chwilach zapowiedzi danego ataku.
func _glints(kind: BeastBrain.Attack) -> Array[int]:
	var beast := BeastBrain.new()
	beast.passive = true
	beast.start_attack(kind)
	var levels: Array[int] = []
	while beast.state == BeastBrain.State.TELEGRAPH:
		levels.append(beast.eye_glint())
		beast.update(STEP, 0.0)
	return levels


func test_eye_glint_patterns() -> void:
	var charge := _glints(BeastBrain.Attack.CHARGE)
	var rising := true
	for i in range(1, charge.size()):
		rising = rising and charge[i] >= charge[i - 1]
	check(rising and charge.front() == 1 and charge.back() == 3, "szarża: błysk narasta od 1 do 3")
	var tusk := _glints(BeastBrain.Attack.TUSK)
	var flashes := 0
	for i in tusk.size():
		if tusk[i] > 0 and (i == 0 or tusk[i - 1] == 0):
			flashes += 1
	check(flashes == 2, "cios kłami: dwa mrugnięcia (jest %d)" % flashes)
	var stomp := _glints(BeastBrain.Attack.STOMP)
	check(stomp.front() == -1 and stomp.back() == 3, "tupnięcie: oczy gasną, potem rozbłysk")
	var lengths := [charge.size(), tusk.size(), stomp.size()]
	check(lengths[0] > lengths[2] and lengths[2] > lengths[1], "zapowiedzi: szarża najdłuższa, kły najkrótsze")


func test_stomp_waves_and_bounds() -> void:
	var beast := BeastBrain.new()
	beast.passive = true
	beast.x = 300.0
	beast.start_attack(BeastBrain.Attack.STOMP)
	var t := 0.0
	var max_waves := 0
	var events: Array[StringName] = []
	while t < 0.9:
		events.append_array(beast.update(STEP, 100.0))
		max_waves = maxi(max_waves, beast.waves.size())
		t += STEP
	check(events.has(&"stomp") and max_waves == 2, "tupnięcie wypuszcza dwie fale")
	if beast.waves.size() == 2:
		var w := beast.waves
		check(w[0].y == 1.0 and w[1].y == -1.0 and w[0].x > w[1].x, "fale biegną w obie strony")
	while t < 5.0:
		beast.update(STEP, 100.0)
		t += STEP
	check(beast.waves.is_empty(), "fale znikają przy krawędziach sceny")
	# długa walka z przyjacielem skaczącym po scenie: bestia nie wychodzi poza arenę
	var brain := BeastBrain.new(7)
	var inside := true
	t = 0.0
	while t < 60.0:
		brain.update(STEP, 40.0 if fmod(t, 10.0) < 5.0 else 440.0)
		inside = inside and brain.x >= brain.min_x and brain.x <= brain.max_x
		t += STEP
	check(inside, "bestia zostaje na arenie")
	check(brain._history.size() >= 10, "bestia sama atakuje (ataków w minutę: %d)" % brain._history.size())


func test_beast_dies() -> void:
	var beast := BeastBrain.new()
	for i in beast.max_health:
		beast.take_hit()
	check(beast.state == BeastBrain.State.DYING, "po %d cięciach bestia pada" % beast.max_health)
	for i in 120:
		beast.update(STEP, 0.0)
	check(beast.state == BeastBrain.State.DEAD and beast.eye_glint() == -1, "martwa bestia, oko zgasło")
	check(not beast.start_attack(BeastBrain.Attack.CHARGE) and beast.attack_boxes().is_empty(),
		"martwa bestia nie atakuje")
