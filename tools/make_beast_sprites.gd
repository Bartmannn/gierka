extends SceneTree
## Rysuje klatki bestii (dzika ze szkicu w grafika/narzedzia/scena_las.py, funkcja bestia).
##
## Uruchom z katalogu projektu:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/make_beast_sprites.gd
## Wynik:
##   grafika/postacie/bestia_ruch.png        klatki 208x112, bestia zwrócona w prawo; rzędy:
##                                           0 oddech (4), 1 chód (8), 2 galop (6), 3 grzebanie racicą (4),
##                                           4 cios kłami (6), 5 tupnięcie (7), 6 drgnięcie (2) + upadek (6)
##   grafika/podglady/bestia_ruch_x2.png     powiększony podgląd
##   scripts/forest/beast_frame_data.gd      rozmiary klatek i położenie oka w każdej klatce
##
## Kształt pochodzi ze szkicu (odbity, bo w szkicu bestia patrzy w lewo). Pozy powstają przez
## przesuwanie i obracanie punktów kształtu (łeb w dół/w górę, stawanie dęba) i rysowanie od nowa,
## nigdy przez obracanie gotowego obrazka. Oka nie ma w klatkach - rysuje je gra (eye_glint.gd),
## bo to ono zapowiada ataki. Obrys od księżyca dokłada shader, tak jak u przyjaciela.

const PixelCanvas := preload("res://tools/pixel_canvas.gd")

const FRAME := Vector2i(208, 112)
const FEET := Vector2(104, 108)
const COLUMNS := 8
const ROWS := [
	["IDLE", 4], ["WALK", 8], ["GALLOP", 6], ["PAW", 4], ["TUSK", 6], ["STOMP", 7], ["HURT", 8],
]
const WALK_STRIDE := 16.0    # px drogi kopyta w fazie podparcia (chód)
const WALK_STANCE := 0.7
const GALLOP_STRIDE := 36.0
const GALLOP_STANCE := 0.35

const BODY := 1
const TUSK := 2
const TUSK_TIP := 3
const TUSK_EDGE := 4
const STEAM := 5
const COLORS := {
	BODY: Color("07080c"),       # Palette.NIGHT
	TUSK: Color("6a7f99"),       # Palette.MOON_GLOW
	TUSK_TIP: Color("d3dfea"),   # Palette.MOON
	TUSK_EDGE: Color("3b475a"),  # Palette.MIST
	STEAM: Color("3b475a"),      # Palette.MIST
}
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# --- kształt ze szkicu (x do przodu, y w górę ujemne, (0,0) = ziemia pod środkiem bestii) ---
const BODY_PTS: Array[Vector2] = [
	Vector2(89, -31), Vector2(88, -24), Vector2(81, -21), Vector2(71, -21), Vector2(61, -22),
	Vector2(46, -20), Vector2(26, -19), Vector2(1, -19), Vector2(-29, -20), Vector2(-49, -22),
	Vector2(-58, -27), Vector2(-62, -35), Vector2(-62, -45), Vector2(-58, -53), Vector2(-50, -60),
	Vector2(-39, -65), Vector2(-24, -68), Vector2(-7, -70), Vector2(9, -73), Vector2(23, -74),
	Vector2(37, -71), Vector2(49, -65), Vector2(59, -58), Vector2(67, -52), Vector2(74, -45),
	Vector2(81, -39), Vector2(86, -35),
]
const EAR: Array[Vector2] = [Vector2(62, -54), Vector2(57, -66), Vector2(51, -58)]
const EYE := Vector2(71, -42)
const TAIL: Array[Vector2] = [Vector2(-61, -49), Vector2(-67, -45), Vector2(-66, -38)]
## Kły: piksele od nasady do czubka.
const TUSK_PIXELS: Array[Vector2] = [
	Vector2(82, -24), Vector2(83, -25), Vector2(84, -26), Vector2(85, -27),
	Vector2(86, -29), Vector2(87, -30), Vector2(87, -31), Vector2(87, -32),
]
## Nogi: biodro, kopyto (stojąc), grubość uda i goleni, długości, w którą stronę zgina się kolano.
const LEGS := [
	{"hip": Vector2(40, -22), "hoof": Vector2(41, -2), "w": Vector2(6, 4), "len": Vector2(12.4, 8.9), "bend": 1.0},
	{"hip": Vector2(-49, -27), "hoof": Vector2(-53, -2), "w": Vector2(7, 4), "len": Vector2(15.7, 11.4), "bend": -1.0},
	{"hip": Vector2(55, -22), "hoof": Vector2(57, -2), "w": Vector2(7, 5), "len": Vector2(12.6, 8.2), "bend": 1.0},
	{"hip": Vector2(-33, -25), "hoof": Vector2(-38, -2), "w": Vector2(9, 5), "len": Vector2(15.8, 10.8), "bend": -1.0},
]
const FRONT_FAR := 0
const HIND_FAR := 1
const FRONT_NEAR := 2
const HIND_NEAR := 3
const HEAD_PIVOT := Vector2(42, -44)   # kark: tu obraca się łeb
const REAR_PIVOT := Vector2(-40, -22)  # biodra: wokół nich bestia staje dęba
const STEAM_CENTER := Vector2(97, -28)

const SHEET_PATH := "res://grafika/postacie/bestia_ruch.png"
const PREVIEW_PATH := "res://grafika/podglady/bestia_ruch_x2.png"
const DATA_PATH := "res://scripts/forest/beast_frame_data.gd"

var _c := PixelCanvas.new(FRAME, FEET)
var _eyes: Array = []  # [rząd][kolumna] -> Vector2i


func _init() -> void:
	var sheet := Image.create_empty(FRAME.x * COLUMNS, FRAME.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	for row in ROWS.size():
		var eyes_row: Array[Vector2i] = []
		for k: int in ROWS[row][1]:
			var pose := _pose_for(row, k)
			_draw_pose(pose)
			_c.blit(sheet, k, row, COLORS)
			eyes_row.append(_c.to_pixel(_transform(EYE, pose, 1.0)) - Vector2i(FEET))
		_eyes.append(eyes_row)
	var err := sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	var preview := Image.create_empty(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
	preview.fill(Color("1d2738"))
	preview.blend_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
	preview.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	preview.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
	_write_frame_data()
	print("Zapisano %s i %s (błąd: %d)" % [SHEET_PATH, DATA_PATH, err])
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------- pozy

## Opis pozy: shift (przesunięcie całości), head (obrót łba, + = w dół), rear (stawanie dęba,
## + = przód w górę), breath (grzbiet wyżej o 1 px), hooves (gdzie stoją kopyta, nil = jak stojąc),
## steam (gęstość pary z pyska 0..1), splay (nogi rozrzucone na boki przy leżeniu).
func _pose_for(row: int, k: int) -> Dictionary:
	var p := {"shift": Vector2.ZERO, "head": 0.0, "rear": 0.0, "breath": 0, "hooves": {}, "steam": 0.0}
	match ROWS[row][0]:
		"IDLE":
			p.breath = [0, 1, 1, 0][k]
			p.head = [0.0, 0.02, 0.03, 0.01][k]
			p.steam = [0.0, 0.0, 0.8, 0.45][k]
		"WALK":
			var phase := float(k) / 8.0
			p.shift = Vector2(0, -1 if k % 4 == 1 or k % 4 == 2 else 0)
			p.head = 0.04 * sin(TAU * phase * 2.0)
			p.hooves = _gait(phase, [0.25, 0.0, 0.75, 0.5], WALK_STANCE, WALK_STRIDE, 4.0)
		"GALLOP":
			var phase := float(k) / 6.0
			p.shift = Vector2(0, -roundf(2.0 * absf(sin(TAU * phase))))
			p.head = 0.2
			p.rear = 0.05 * sin(TAU * phase)
			p.hooves = _gait(phase, [0.1, 0.5, 0.0, 0.6], GALLOP_STANCE, GALLOP_STRIDE, 8.0)
		"PAW":
			p.head = 0.28
			p.shift = Vector2(-2, 1)
			var dx: float = [0.0, -6.0, -10.0, -4.0][k]
			var lift: float = [0.0, 3.0, 2.0, 0.0][k]
			p.hooves = {FRONT_NEAR: LEGS[FRONT_NEAR].hoof + Vector2(dx, -lift)}
			p.steam = [0.0, 1.0, 0.7, 0.0][k]
		"TUSK":
			p.head = [0.3, 0.38, 0.38, -0.5, -0.35, -0.1][k]
			p.shift = [Vector2(-3, 0), Vector2(-4, 1), Vector2(-4, 1), Vector2(5, -1), Vector2(4, 0), Vector2(2, 0)][k]
			p.rear = 0.04 if k == 3 else 0.0
			p.steam = 0.8 if k == 2 else 0.0
		"STOMP":
			p.rear = [0.08, 0.18, 0.28, 0.32, 0.0, 0.0, 0.0][k]
			p.head = [-0.1, -0.15, -0.2, -0.25, 0.15, 0.1, 0.03][k]
			p.shift = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2(2, 1), Vector2(1, 0), Vector2.ZERO][k]
			var near: Vector2 = [Vector2(60, -6), Vector2(64, -14), Vector2(66, -24), Vector2(66, -28),
					Vector2(64, -2), Vector2(62, -2), Vector2(59, -2)][k]
			var far: Vector2 = [Vector2(44, -4), Vector2(50, -10), Vector2(54, -20), Vector2(54, -24),
					Vector2(50, -2), Vector2(48, -2), Vector2(44, -2)][k]
			p.hooves = {FRONT_NEAR: near, FRONT_FAR: far}
		"HURT":
			match k:
				0:
					p.shift = Vector2(-2, 0)
					p.head = -0.08
				1:
					p.shift = Vector2(-1, 0)
					p.head = -0.03
				2:
					p.head = 0.3
					p.shift = Vector2(0, 2)
					p.rear = -0.05
					p.hooves = {FRONT_NEAR: Vector2(62, -2), FRONT_FAR: Vector2(46, -2)}
				3:
					p.head = 0.32
					p.shift = Vector2(0, 6)
					p.rear = -0.14
					p.hooves = {FRONT_NEAR: Vector2(50, -2), FRONT_FAR: Vector2(36, -2)}
				4:
					p.head = 0.28
					p.shift = Vector2(0, 11)
					p.rear = -0.08
					p.hooves = {FRONT_NEAR: Vector2(66, -2), FRONT_FAR: Vector2(52, -2),
							HIND_NEAR: Vector2(-50, -2), HIND_FAR: Vector2(-66, -2)}
				_:
					p.head = 0.25
					p.shift = Vector2(0, 15 if k == 5 else 16)
					p.hooves = {FRONT_NEAR: Vector2(80, -3), FRONT_FAR: Vector2(72, -2),
							HIND_NEAR: Vector2(-72, -3), HIND_FAR: Vector2(-64, -2)}
	return p


## Kopyta w cyklu kroku. offsets: przesunięcie fazy każdej nogi; stance: część cyklu na ziemi.
func _gait(phase: float, offsets: Array, stance: float, stride: float, lift: float) -> Dictionary:
	var hooves := {}
	for leg in 4:
		var p := fposmod(phase + offsets[leg], 1.0)
		var base: Vector2 = LEGS[leg].hoof
		if p < stance:
			hooves[leg] = base + Vector2(stride * 0.5 - stride * p / stance, 0)
		else:
			var s := (p - stance) / (1.0 - stance)
			hooves[leg] = base + Vector2(-stride * 0.5 + stride * smoothstep(0.0, 1.0, s), -lift * sin(PI * s))
	return hooves


## Punkt kształtu po zastosowaniu pozy. head_weight: jak bardzo punkt należy do łba (0..1).
func _transform(point: Vector2, pose: Dictionary, head_weight: float) -> Vector2:
	var p := point
	if head_weight > 0.0 and pose.head != 0.0:
		p = HEAD_PIVOT + (p - HEAD_PIVOT).rotated(pose.head * head_weight)
	if pose.breath and point.y < -60.0 and head_weight < 0.5:
		p.y -= pose.breath
	if pose.rear != 0.0:
		p = REAR_PIVOT + (p - REAR_PIVOT).rotated(-pose.rear)
	return p + pose.shift


func _head_weight(point: Vector2) -> float:
	return smoothstep(38.0, 52.0, point.x)


func _draw_pose(pose: Dictionary) -> void:
	_c.clear()
	var body: Array[Vector2] = []
	for p in BODY_PTS:
		body.append(_transform(p, pose, _head_weight(p)))
	_c.poly(body, BODY)
	var ear: Array[Vector2] = []
	for p in EAR:
		ear.append(_transform(p, pose, 1.0))
	_c.poly(ear, BODY)
	_bristles(pose)
	for leg in 4:
		_leg(leg, pose)
	var tail: Array[Vector2] = []
	for p in TAIL:
		tail.append(_transform(p, pose, 0.0))
	_c.thin_line(tail[0], tail[1], BODY)
	_c.thin_line(tail[1], tail[2], BODY)
	for i in TUSK_PIXELS.size():
		var px := _c.to_pixel(_transform(TUSK_PIXELS[i], pose, 1.0))
		_c.put(px, TUSK_TIP if i >= 6 else TUSK)
		if i < 6:
			_c.put(px + Vector2i(-1, 0), TUSK_EDGE)
	if pose.steam > 0.0:
		_steam(pose)


## Szczecina na grzbiecie (najgęstsza na karku) i krótkie włosy pod brzuchem.
## Każda kolumna ma stałe „losowe” wartości, więc szczecina nie skacze między klatkami.
func _bristles(pose: Dictionary) -> void:
	var shift: Vector2 = pose.shift
	for bx in range(-57, 72, 2):
		var rnd := RandomNumberGenerator.new()
		rnd.seed = 1000 + bx
		var px := _c.to_pixel(Vector2(bx, 0) + shift).x
		var top := _column_top(px)
		if top < 0:
			continue
		var hump := exp(-pow((bx - 31.0) / 32.0, 2.0))
		var h := 2.0 + 7.0 * hump * rnd.randf_range(0.5, 1.0) + rnd.randf_range(0.0, 2.0)
		var base := _c.center(px, top + 1)
		_c.thin_line(base, base + Vector2(-rnd.randf_range(1.0, 4.0), -h - 1.0), BODY)
	for bx in range(-57, 75, 3):
		var rnd := RandomNumberGenerator.new()
		rnd.seed = 2000 + bx
		var px := _c.to_pixel(Vector2(bx, 0) + shift).x
		var bottom := _column_bottom(px)
		if bottom < 0 or _c.center(px, bottom).y > -15.0:
			continue
		var base := _c.center(px, bottom - 1)
		_c.thin_line(base, base + Vector2(rnd.randf_range(0.0, 2.0), rnd.randf_range(1.0, 4.0) + 1.0), BODY)


func _column_top(px: int) -> int:
	for py in int(FEET.y):
		if _c.get_px(Vector2i(px, py)) == BODY:
			return py
	return -1


func _column_bottom(px: int) -> int:
	for py in range(int(FEET.y) - 1, -1, -1):
		if _c.get_px(Vector2i(px, py)) == BODY:
			return py
	return -1


func _leg(leg: int, pose: Dictionary) -> void:
	var data: Dictionary = LEGS[leg]
	var hip := _transform(data.hip, pose, 0.0)
	var hoof: Vector2 = pose.hooves.get(leg, data.hoof + Vector2(pose.shift.x, 0))
	var lengths: Vector2 = data.len
	var reach := lengths.x + lengths.y - 0.05
	if hip.distance_to(hoof) > reach:
		hoof = hip + (hoof - hip).normalized() * reach  # noga w powietrzu, wyprostowana
	var knee := _knee(hip, hoof, lengths, data.bend)
	var w: Vector2 = data.w
	_c.line(hip, knee, w.x, BODY)
	_c.line(knee, hoof, w.y, BODY)
	_c.poly([hoof + Vector2(-2.5, -1), hoof + Vector2(2.5, -1), hoof + Vector2(2.5, 2), hoof + Vector2(-2.5, 2)], BODY)


## Kolano z dwóch odcinków; bend: 1 = zgina się do przodu (przednie nogi), -1 = do tyłu (tylne).
func _knee(hip: Vector2, foot: Vector2, lengths: Vector2, bend: float) -> Vector2:
	var v := foot - hip
	var d := v.length()
	var a := (lengths.x * lengths.x - lengths.y * lengths.y + d * d) / (2.0 * d)
	var h := sqrt(maxf(lengths.x * lengths.x - a * a, 0.0))
	var dir := v / d
	var perp := Vector2(-dir.y, dir.x)
	if signf(perp.x) != bend:
		perp = -perp
	return hip + dir * a + perp * h


## Para z pyska: rzadki dithering przed ryjem, gęstszy przy samym ryju.
func _steam(pose: Dictionary) -> void:
	var center := _transform(STEAM_CENTER, pose, 1.0)
	var snout := _transform(BODY_PTS[0], pose, 1.0)
	for py in int(FEET.y):
		for px in FRAME.x:
			var c := _c.center(px, py)
			var d := c - center
			if d.x * d.x / 90.0 + d.y * d.y / 20.0 >= 1.0 or _c.get_px(Vector2i(px, py)) != 0:
				continue
			var near := clampf((snout.x + 20.0 - c.x) / 18.0, 0.0, 1.0)
			var threshold: float = (BAYER[(py % 4) * 4 + (px % 4)] + 0.5) / 16.0
			if threshold < 0.22 * near * pose.steam * 1.6:
				_c.put(Vector2i(px, py), STEAM)


# ---------------------------------------------------------------- dane dla gry

func _write_frame_data() -> void:
	var lines: Array[String] = [
		"class_name BeastFrameData",
		"extends RefCounted",
		"## Plik wygenerowany przez tools/make_beast_sprites.gd - nie poprawiaj go ręcznie.",
		"## Rozmiary klatek bestii i położenie oka w każdej klatce (względem stóp, bestia zwrócona w prawo).",
		"",
		"const FRAME_SIZE := Vector2i(%d, %d)" % [FRAME.x, FRAME.y],
		"const FEET := Vector2i(%d, %d)" % [int(FEET.x), int(FEET.y)],
		"const COLUMNS := %d" % COLUMNS,
	]
	for row in ROWS.size():
		lines.append("const ROW_%s := %d" % [ROWS[row][0], row])
	for row in ROWS.size():
		lines.append("const %s_FRAMES := %d" % [ROWS[row][0], ROWS[row][1]])
	lines.append("## Cykl chodu i galopu: ile pikseli drogi przypada na jedną klatkę.")
	lines.append("const WALK_STEP_PIXELS := %.3f" % (WALK_STRIDE / WALK_STANCE / 8.0))
	lines.append("const GALLOP_STEP_PIXELS := %.3f" % (GALLOP_STRIDE / GALLOP_STANCE / 6.0))
	lines.append("## EYES[rząd][kolumna]: piksel oka względem stóp.")
	var rows_text: Array[String] = []
	for row_eyes: Array in _eyes:
		var items: Array[String] = []
		for e: Vector2i in row_eyes:
			items.append("Vector2i(%d, %d)" % [e.x, e.y])
		rows_text.append("\t[%s]," % ", ".join(items))
	lines.append("const EYES := [\n%s\n]" % "\n".join(rows_text))
	var f := FileAccess.open(ProjectSettings.globalize_path(DATA_PATH), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
