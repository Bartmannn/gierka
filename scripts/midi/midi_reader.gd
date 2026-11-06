class_name MidiReader
extends RefCounted
## Czyta pliki MIDI (Standard MIDI File, format 0 i 1), np. wyeksportowane z LMMS.
##
## Użycie:  var tracks := MidiReader.load_file("res://music/prototyp.mid")
## Każda ścieżka ma nazwę i listę nut z czasami w sekundach (zmiany tempa są uwzględnione).

const DEFAULT_TEMPO_US_PER_BEAT := 500000  # 120 BPM, gdy plik nie podaje tempa

var _data := PackedByteArray()
var _pos: int = 0


## Wczytuje plik z dysku. Przy błędzie zwraca pustą listę i wypisuje błąd.
static func load_file(path: String) -> Array[MidiTrack]:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("MidiReader: nie można wczytać %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return []
	return MidiReader.new().parse(bytes)


## Rozbiera zawartość pliku MIDI podaną jako bajty.
func parse(bytes: PackedByteArray) -> Array[MidiTrack]:
	_data = bytes
	_pos = 0
	var result: Array[MidiTrack] = []

	if _read_chunk_id() != "MThd":
		push_error("MidiReader: to nie jest plik MIDI (brak nagłówka MThd)")
		return result
	var header_length := _read_u32()
	var header_start := _pos
	_read_u16()  # format (0 lub 1) - obsługujemy oba tak samo
	var track_count := _read_u16()
	var division := _read_u16()
	_pos = header_start + header_length
	if division & 0x8000:
		push_error("MidiReader: czas SMPTE nie jest obsługiwany, wyeksportuj plik z tempem w BPM")
		return result

	var tempo_changes: Array[Vector2i] = []  # (tyknięcie, mikrosekundy na ćwierćnutę)
	var raw_tracks: Array[Dictionary] = []
	for i in track_count:
		if _pos + 8 > _data.size():
			break
		var chunk_id := _read_chunk_id()
		var chunk_end := _pos + _read_u32()
		if chunk_id == "MTrk":
			raw_tracks.append(_parse_track(mini(chunk_end, _data.size()), tempo_changes))
		_pos = chunk_end

	var tempo_map := _TempoMap.new(tempo_changes, division)
	for raw in raw_tracks:
		var track := MidiTrack.new()
		track.name = raw["name"]
		for n: PackedInt32Array in raw["notes"]:
			var start := tempo_map.seconds_at(n[0])
			track.notes.append(MidiNote.new(start, tempo_map.seconds_at(n[1]) - start, n[2], n[3], n[4]))
		track.notes.sort_custom(func(a: MidiNote, b: MidiNote) -> bool: return a.time < b.time)
		result.append(track)
	return result


## Czyta zdarzenia jednej ścieżki. Nuty zwraca w tyknięciach: [początek, koniec, wysokość, głośność, kanał].
func _parse_track(end: int, tempo_changes: Array[Vector2i]) -> Dictionary:
	var track_name := ""
	var notes: Array[PackedInt32Array] = []
	var open_notes := {}  # kanał * 128 + wysokość -> lista [tyknięcie początku, głośność]
	var tick := 0
	var running_status := 0

	while _pos < end:
		tick += _read_varlen()
		var status := _data[_pos] if _pos < _data.size() else 0
		if status >= 0x80:
			_pos += 1
		elif running_status != 0:
			status = running_status  # "running status": powtórzony poprzedni typ zdarzenia
		else:
			push_warning("MidiReader: uszkodzona ścieżka, pomijam resztę")
			break

		if status == 0xFF:  # meta-zdarzenie
			var meta_type := _read_u8()
			var length := _read_varlen()
			var meta_start := _pos
			if meta_type == 0x03 and track_name.is_empty():
				track_name = _data.slice(_pos, _pos + length).get_string_from_utf8().strip_edges()
			elif meta_type == 0x51 and length >= 3:
				tempo_changes.append(Vector2i(tick, (_data[_pos] << 16) | (_data[_pos + 1] << 8) | _data[_pos + 2]))
			_pos = meta_start + length
			if meta_type == 0x2F:
				break
		elif status == 0xF0 or status == 0xF7:  # sysex - pomijamy
			_pos += _read_varlen()
		else:
			running_status = status
			var kind := status & 0xF0
			var channel := status & 0x0F
			var data1 := _read_u8()
			var data2 := 0
			if kind != 0xC0 and kind != 0xD0:
				data2 = _read_u8()
			var key := channel * 128 + data1
			if kind == 0x90 and data2 > 0:
				if not open_notes.has(key):
					open_notes[key] = []
				open_notes[key].append(Vector2i(tick, data2))
			elif kind == 0x80 or kind == 0x90:
				if open_notes.has(key) and not open_notes[key].is_empty():
					var started: Vector2i = open_notes[key].pop_front()
					notes.append(PackedInt32Array([started.x, tick, data1, started.y, channel]))

	# Nuty bez zakończenia kończą się z końcem ścieżki.
	for key: int in open_notes:
		for started: Vector2i in open_notes[key]:
			notes.append(PackedInt32Array([started.x, maxi(tick, started.x + 1), key % 128, started.y, key >> 7]))

	return {"name": track_name, "notes": notes}


func _read_u8() -> int:
	var value := _data[_pos] if _pos < _data.size() else 0
	_pos += 1
	return value


func _read_u16() -> int:
	return (_read_u8() << 8) | _read_u8()


func _read_u32() -> int:
	return (_read_u16() << 16) | _read_u16()


## Liczba o zmiennej długości (7 bitów na bajt, najwyższy bit = "czytaj dalej").
func _read_varlen() -> int:
	var value := 0
	for i in 4:
		var byte := _read_u8()
		value = (value << 7) | (byte & 0x7F)
		if byte & 0x80 == 0:
			break
	return value


func _read_chunk_id() -> String:
	var id := _data.slice(_pos, _pos + 4).get_string_from_ascii()
	_pos += 4
	return id


## Przelicza tyknięcia na sekundy z uwzględnieniem wszystkich zmian tempa.
class _TempoMap:
	var _ticks := PackedInt64Array()
	var _seconds := PackedFloat64Array()
	var _us_per_beat := PackedInt64Array()
	var _division: int

	func _init(changes: Array[Vector2i], division: int) -> void:
		_division = maxi(division, 1)
		var sorted := changes.duplicate()
		sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		_ticks.append(0)
		_seconds.append(0.0)
		_us_per_beat.append(MidiReader.DEFAULT_TEMPO_US_PER_BEAT)
		for change: Vector2i in sorted:
			var last := _ticks.size() - 1
			if change.x == _ticks[last]:
				_us_per_beat[last] = change.y  # zmiana w tym samym miejscu nadpisuje poprzednią
			else:
				_seconds.append(_seconds[last] + _span(change.x - _ticks[last], _us_per_beat[last]))
				_ticks.append(change.x)
				_us_per_beat.append(change.y)

	func seconds_at(tick: int) -> float:
		var i := _ticks.size() - 1
		while i > 0 and _ticks[i] > tick:
			i -= 1
		return _seconds[i] + _span(tick - _ticks[i], _us_per_beat[i])

	func _span(ticks: int, us_per_beat: int) -> float:
		return float(ticks) * float(us_per_beat) / float(_division) / 1_000_000.0
