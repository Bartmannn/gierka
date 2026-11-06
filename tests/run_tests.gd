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
