class_name PuddleView
extends Node2D
## Obraz walki: odbicie nocnego lasu w kałuży, widziane oczami rannego bohatera.
##
## Prototyp nie ma jeszcze postaci. Wszystko, co ważne dla rytmu, pokazuje otoczenie:
##   - serce: księżyc w wodzie lekko pulsuje, od jego środka rozchodzi się słaba fala,
##   - boss: kroki bossa rozkołysują taflę z daleka,
##   - nadchodzący cios: na wodzie zbiega się fala, a ostrze błyska kolorem akcentu;
##     błysk jest najjaśniejszy dokładnie w chwili, w której trzeba uderzyć,
##   - trafienie: ciepła fala i iskry; chybienie: ciemna fala i wstrząs obrazu.
## Rysujemy w rozdzielczości 320x180, piksel po pikselu, bez wygładzania.

const SCREEN := Vector2i(320, 180)
const PUDDLE_CENTER := Vector2(160, 104)
const PUDDLE_RADIUS := Vector2(140, 58)
const MOON_CENTER := Vector2(160, 94)
const MOON_RADIUS := 11.0
const GLINT_Y := 74.0
const RIPPLE_FLATTEN := 0.38  ## fale są spłaszczone, bo patrzymy na taflę pod kątem
const SPARK_GRAVITY := -60.0  ## ujemna: w odbiciu iskry "spadają" do góry

## Odbite pnie drzew: (x, szerokość, długość odbicia w pikselach).
const TRUNKS: Array[Vector3i] = [
	Vector3i(34, 7, 70), Vector3i(66, 4, 52), Vector3i(97, 3, 30),
	Vector3i(226, 5, 44), Vector3i(258, 3, 60), Vector3i(284, 8, 80),
]

@export var glint_lead := 0.8  ## ile sekund przed ciosem widać zapowiedź

var song_time := 0.0
var upcoming_cues: Array[Cue] = []  ## ustawiane co klatkę przez scenę główną
var consciousness := 1.0            ## 0..1, przyciemnia księżyc

var _ripples: Array[Ripple] = []
var _sparks: Array[Spark] = []
var _clock := 0.0        # czas animacji, płynie także poza walką
var _disturbance := 0.0  # rozkołys tafli 0..1
var _moon_pulse := 0.0
var _flash := 0.0
var _flash_at := Vector2.ZERO
var _shake := 0.0


class Ripple:
	var center: Vector2
	var age := 0.0
	var life: float
	var speed: float      # px/s
	var color: Color
	var strength: float   # początkowa nieprzezroczystość

	func _init(p_center: Vector2, p_color: Color, p_strength: float, p_speed: float, p_life: float) -> void:
		center = p_center
		color = p_color
		strength = p_strength
		speed = p_speed
		life = p_life


class Spark:
	var position: Vector2
	var velocity: Vector2
	var age := 0.0
	var life: float


func reset() -> void:
	_ripples.clear()
	_sparks.clear()
	upcoming_cues.clear()
	_disturbance = 0.0
	_moon_pulse = 0.0
	_flash = 0.0
	_shake = 0.0


# --- Zdarzenia z walki -------------------------------------------------------

func on_heartbeat(note: MidiNote) -> void:
	var strength := note.velocity / 127.0
	_moon_pulse = maxf(_moon_pulse, strength)
	_ripples.append(Ripple.new(MOON_CENTER, Palette.MIST, 0.35 * strength, 26.0, 0.9))


func on_boss_note(note: MidiNote) -> void:
	var strength := note.velocity / 127.0
	_disturbance = minf(_disturbance + 0.25 * strength, 1.0)
	var x := clampf(160.0 + (note.pitch - 48) * 5.0, 60.0, 260.0)
	var origin := Vector2(x, PUDDLE_CENTER.y - PUDDLE_RADIUS.y * 0.75)
	_ripples.append(Ripple.new(origin, Palette.MIST, 0.5 * strength, 40.0, 1.4))


func on_hit(cue: Cue, perfect: bool) -> void:
	var at := glint_position(cue)
	_ripples.append(Ripple.new(at, Palette.ACCENT, 0.9, 70.0, 0.8))
	_flash = 1.0 if perfect else 0.6
	_flash_at = at
	_disturbance = minf(_disturbance + 0.2, 1.0)
	for i in (10 if perfect else 6):
		var spark := Spark.new()
		spark.position = at
		spark.velocity = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 60.0)
		spark.life = randf_range(0.25, 0.5)
		_sparks.append(spark)


func on_miss(cue: Cue) -> void:
	_ripples.append(Ripple.new(glint_position(cue), Palette.MIST, 0.7, 50.0, 1.0))
	_disturbance = minf(_disturbance + 0.5, 1.0)
	_shake = 1.0


func on_empty_swing() -> void:
	var at := Vector2(randf_range(110.0, 210.0), randf_range(120.0, 140.0))
	_ripples.append(Ripple.new(at, Palette.MIST, 0.3, 30.0, 0.6))


## Miejsce błysku zależy od wysokości nuty: wyższe dźwięki dalej w prawo.
func glint_position(cue: Cue) -> Vector2:
	var x := remap(clampf(cue.top_pitch(), 55.0, 91.0), 55.0, 91.0, 70.0, 250.0)
	return Vector2(roundf(x), GLINT_Y)


# --- Animacja ----------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	for ripple in _ripples:
		ripple.age += delta
	_ripples = _ripples.filter(func(r: Ripple) -> bool: return r.age < r.life)
	for spark in _sparks:
		spark.age += delta
		spark.velocity.y += SPARK_GRAVITY * delta
		spark.position += spark.velocity * delta
	_sparks = _sparks.filter(func(s: Spark) -> bool: return s.age < s.life)

	_disturbance *= exp(-delta * 1.5)
	_moon_pulse *= exp(-delta * 6.0)
	_flash *= exp(-delta * 8.0)
	_shake *= exp(-delta * 12.0)
	var amount := _shake * 3.0
	position = Vector2(roundf(randf_range(-amount, amount)), roundf(randf_range(-amount, amount)))
	queue_redraw()


# --- Rysowanie ---------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2(-8, -8), Vector2(SCREEN) + Vector2(16, 16)), Palette.GROUND)
	_draw_ellipse(PUDDLE_CENTER, PUDDLE_RADIUS, Palette.WATER_EDGE)
	_draw_ellipse(PUDDLE_CENTER + Vector2(0, 2), PUDDLE_RADIUS - Vector2(2, 2), Palette.WATER)
	_draw_trunks()
	_draw_moon()
	if _flash > 0.01:  # ciepłe światło ciosu odbite w wodzie wokół miejsca trafienia
		_draw_ellipse(_flash_at, Vector2(18, 6), Color(Palette.ACCENT, 0.18 * _flash))
		_draw_ellipse(_flash_at, Vector2(9, 3), Color(Palette.ACCENT, 0.25 * _flash))
	for ripple in _ripples:
		_draw_ripple(ripple)
	_draw_glints()
	for spark in _sparks:
		draw_rect(Rect2(spark.position.floor(), Vector2.ONE), Color(Palette.ACCENT, 1.0 - spark.age / spark.life))


func _draw_trunks() -> void:
	var top := PUDDLE_CENTER.y - PUDDLE_RADIUS.y
	for trunk in TRUNKS:
		for row in trunk.z:
			var y := top + row
			if not is_in_puddle(Vector2(trunk.x, y)) and not is_in_puddle(Vector2(trunk.x + trunk.y, y)):
				continue
			var wobble := roundf(sin(y * 0.7 + _clock * 1.8) * (0.3 + _disturbance * 1.5))
			var width := maxf(1.0, trunk.y - row / 25.0)  # pień zwęża się w odbiciu
			var x0 := trunk.x + wobble
			var span := _puddle_span(y)
			var left := maxf(x0, span.x)
			var right := minf(x0 + width, span.y)
			if right > left:
				draw_rect(Rect2(left, y, right - left, 1), Palette.NIGHT)


func _draw_moon() -> void:
	var pulse := _moon_pulse * 0.15
	var light := 0.45 + 0.55 * consciousness
	var amplitude := 0.4 + _disturbance * 2.5
	# Poświata w trzech stopniach (twarde progi zamiast gradientu - jak w pixel arcie).
	for layer in [[MOON_RADIUS * 2.2, Color(Palette.MOON_GLOW, (0.04 + pulse * 0.5) * light)],
			[MOON_RADIUS * 1.7, Color(Palette.MOON_GLOW, (0.05 + pulse * 0.5) * light)],
			[MOON_RADIUS * 1.3, Color(Palette.MOON_GLOW, (0.07 + pulse) * light)],
			[MOON_RADIUS, Color(Palette.MOON, (0.85 + pulse) * light)]]:
		var radius: float = layer[0]
		var color: Color = layer[1]
		for dy in range(-int(radius), int(radius) + 1):
			var half := roundf(radius * sqrt(maxf(0.0, 1.0 - float(dy * dy) / (radius * radius))))
			if half <= 0.0:
				continue
			var shift := roundf(sin(dy * 0.9 + _clock * 2.5) * amplitude)
			draw_rect(Rect2(MOON_CENTER.x - half + shift, MOON_CENTER.y + dy, half * 2.0, 1), color)


func _draw_ripple(ripple: Ripple) -> void:
	var t := ripple.age / ripple.life
	var radius := 2.0 + ripple.speed * ripple.age
	var color := Color(ripple.color, ripple.strength * pow(1.0 - t, 1.5))
	_draw_clipped_ellipse_outline(ripple.center, radius, color)


func _draw_glints() -> void:
	for cue in upcoming_cues:
		var remaining := cue.time - song_time
		if remaining < 0.0 or remaining > glint_lead:
			continue
		var p := 1.0 - remaining / glint_lead  # 0 = dopiero zapowiedź, 1 = teraz!
		var at := glint_position(cue)
		# Fala zbiegająca się do miejsca ciosu - pokazuje, ile zostało czasu.
		_draw_clipped_ellipse_outline(at, 3.0 + (1.0 - p) * 22.0, Color(Palette.MIST, 0.15 + 0.45 * p))
		# Błysk ostrza rośnie i jaśnieje.
		var color := Color(Palette.ACCENT, 0.3 + 0.7 * p)
		var arm := roundf(p * p * 6.0)
		draw_rect(Rect2(at.x - arm, at.y, arm * 2.0 + 1.0, 1), Color(color, color.a * 0.7))
		draw_rect(Rect2(at.x, at.y - arm, 1, arm * 2.0 + 1.0), Color(color, color.a * 0.7))
		draw_rect(Rect2(at, Vector2.ONE), color)
		if p > 0.8:
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_rect(Rect2(at + corner, Vector2.ONE), Color(Palette.MOON, (p - 0.8) * 4.0))


# --- Pomocnicze --------------------------------------------------------------

func is_in_puddle(point: Vector2) -> bool:
	var d := (point - PUDDLE_CENTER) / PUDDLE_RADIUS
	return d.length_squared() <= 1.0


## Lewy i prawy brzeg kałuży w danym wierszu (x = lewy, y = prawy).
func _puddle_span(y: float) -> Vector2:
	var dy := (y - PUDDLE_CENTER.y) / PUDDLE_RADIUS.y
	var half := PUDDLE_RADIUS.x * sqrt(maxf(0.0, 1.0 - dy * dy))
	return Vector2(PUDDLE_CENTER.x - half, PUDDLE_CENTER.x + half)


## Wypełniona elipsa rysowana wierszami - piksele zostają ostre.
func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	for dy in range(-int(radius.y), int(radius.y) + 1):
		var half := roundf(radius.x * sqrt(maxf(0.0, 1.0 - float(dy * dy) / (radius.y * radius.y))))
		if half > 0.0:
			draw_rect(Rect2(center.x - half, center.y + dy, half * 2.0, 1), color)


## Obrys spłaszczonej elipsy (fala na wodzie), przycięty do kałuży.
func _draw_clipped_ellipse_outline(center: Vector2, radius: float, color: Color) -> void:
	if color.a <= 0.01:
		return
	var steps := maxi(12, int(radius * 1.5))
	var segments := PackedVector2Array()
	var previous := Vector2.INF
	for i in steps + 1:
		var angle := TAU * i / steps
		var point := (center + Vector2(cos(angle) * radius, sin(angle) * radius * RIPPLE_FLATTEN)).floor() + Vector2(0.5, 0.5)
		var inside := is_in_puddle(point)
		if inside and previous != Vector2.INF:
			segments.append(previous)
			segments.append(point)
		previous = point if inside else Vector2.INF
	if not segments.is_empty():
		draw_multiline(segments, color)
