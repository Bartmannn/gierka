class_name Song
extends RefCounted
## Utwór jednej walki, zbudowany z pliku MIDI.
##
## Rolę ścieżki rozpoznajemy po jej nazwie nadanej w LMMS (wielkość liter bez znaczenia):
##   "gracz" / "player" / "odpowiedz" - nuty, które gracz wybija; słychać je tylko po trafieniu
##   "boss"                            - pytania bossa, grają same
##   "serce" / "heart" / "puls"       - puls w tle, gra sam
##   każda inna nazwa                 - tło (harmonia, plamy dźwięku), gra samo

enum Role { PLAYER, BOSS, HEART, BACKGROUND }

const ROLE_KEYWORDS := {
	Role.PLAYER: ["gracz", "player", "odpowiedz", "odpowiedź"],
	Role.BOSS: ["boss"],
	Role.HEART: ["serce", "heart", "puls"],
}

## Nuty z odstępem mniejszym niż ten traktujemy jako zagrane razem (jeden cios).
const CHORD_TOLERANCE := 0.015

var player_notes: Array[MidiNote] = []
var boss_notes: Array[MidiNote] = []
var heart_notes: Array[MidiNote] = []
var background_notes: Array[MidiNote] = []
var player_cues: Array[Cue] = []
var length: float = 0.0  ## koniec ostatniej nuty (s)


static func from_midi_file(path: String) -> Song:
	return Song.from_tracks(MidiReader.load_file(path))


static func from_tracks(tracks: Array[MidiTrack]) -> Song:
	var song := Song.new()
	for track in tracks:
		var target: Array[MidiNote]
		match role_for_track_name(track.name):
			Role.PLAYER: target = song.player_notes
			Role.BOSS: target = song.boss_notes
			Role.HEART: target = song.heart_notes
			_: target = song.background_notes
		target.append_array(track.notes)
		for note in track.notes:
			song.length = maxf(song.length, note.end_time())
	for list: Array[MidiNote] in [song.player_notes, song.boss_notes, song.heart_notes, song.background_notes]:
		list.sort_custom(func(a: MidiNote, b: MidiNote) -> bool: return a.time < b.time)
	song.player_cues = group_into_cues(song.player_notes)
	if song.player_cues.is_empty():
		push_warning("Song: brak ścieżki gracza - nazwij ścieżkę w LMMS np. \"gracz\"")
	return song


static func role_for_track_name(track_name: String) -> Role:
	var lower := track_name.to_lower()
	for role: Role in ROLE_KEYWORDS:
		for keyword: String in ROLE_KEYWORDS[role]:
			if lower.contains(keyword):
				return role
	return Role.BACKGROUND


## Łączy nuty zagrane (prawie) jednocześnie w jeden Cue.
static func group_into_cues(notes: Array[MidiNote]) -> Array[Cue]:
	var cues: Array[Cue] = []
	for note in notes:
		if cues.is_empty() or note.time - cues[-1].time > CHORD_TOLERANCE:
			var cue := Cue.new()
			cue.time = note.time
			cues.append(cue)
		cues[-1].notes.append(note)
	return cues
