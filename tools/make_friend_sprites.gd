extends SceneTree
## Rysuje klatki ruchu przyjaciela i białą smugę cięcia.
##
## Uruchom z katalogu projektu:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/make_friend_sprites.gd
## Wynik:
##   grafika/postacie/przyjaciel_ruch.png   klatki 80x72; rzędy: 0 stanie (4), 1 bieg (8),
##                                          2 przewrót (8), 3 cięcie przed siebie (5), 4 cięcie w górę (5),
##                                          5 trafiony (2)
##   grafika/efekty/ciecie.png              smuga cięcia, klatki 80x72; rząd 0 przed siebie, 1 w górę (po 5)
##   grafika/podglady/*_x4.png              powiększone podglądy obu arkuszy
##
## Postać to jednolita sylwetka w kolorze nocy, w stylu szkicu `przyjaciel_szkic.png`.
## Poświatę od księżyca na krawędziach dokłada w grze shader `moonlit_silhouette.gdshader`.
## Każda klatka jest rysowana od nowa z prostych kształtów (bez obracania gotowego obrazka).
## Klatkę można podmienić na ręcznie narysowaną: wystarczy zachować rozmiar i miejsce stóp.

const FRAME := Vector2i(80, 72)
## Stopy stoją na granicy kolumn 39/40 i nad wierszem 69 (to już ziemia). Odbicie w poziomie
## jest więc dokładnie symetryczne i postać nie przeskakuje przy obrocie.
const FEET := Vector2(40, 69)
const COLUMNS := 8
const ROWS := 6
const IDLE_FRAMES := 4
const RUN_FRAMES := 8
const ROLL_FRAMES := 8
const ATTACK_FRAMES := 5
const SLASH_FRAMES := 5
const HURT_FRAMES := 2
## Bieg: na jeden cykl (dwa kroki) przypada RUN_CYCLE px drogi, stopa stoi na ziemi
## przez RUN_STANCE cyklu, a resztę czasu jest w powietrzu (faza lotu).
const RUN_CYCLE := 48.0
const RUN_STANCE := 0.38
const LEG := 10.0  # udo i łydka mają po tyle pikseli

const EMPTY := 0
const BODY := 1
const STEEL_DARK := 2
const STEEL := 3
const MIST := 4
const GLOW := 5
const WHITE := 6
const COLORS := {
	BODY: Color("07080c"),        # Palette.NIGHT
	STEEL_DARK: Color("3b475a"),  # Palette.MIST
	STEEL: Color("6a7f99"),       # Palette.MOON_GLOW
	MIST: Color("3b475a"),        # Palette.MIST
	GLOW: Color("6a7f99"),        # Palette.MOON_GLOW
	WHITE: Color("d3dfea"),       # Palette.MOON
}
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

const SHEET_PATH := "res://grafika/postacie/przyjaciel_ruch.png"
const SLASH_PATH := "res://grafika/efekty/ciecie.png"
const PREVIEW_DIR := "res://grafika/podglady/"

const PixelCanvas := preload("res://tools/pixel_canvas.gd")

var _c := PixelCanvas.new(FRAME, FEET)


func _init() -> void:
	var sheet := Image.create_empty(FRAME.x * COLUMNS, FRAME.y * ROWS, false, Image.FORMAT_RGBA8)
	for k in IDLE_FRAMES:
		_draw_idle(k)
		_c.blit(sheet, k, 0, COLORS)
	for k in RUN_FRAMES:
		_draw_run(k)
		_c.blit(sheet, k, 1, COLORS)
	for k in ROLL_FRAMES:
		_draw_roll(k)
		_c.blit(sheet, k, 2, COLORS)
	for k in ATTACK_FRAMES:
		_draw_attack_side(k)
		_c.blit(sheet, k, 3, COLORS)
		_draw_attack_up(k)
		_c.blit(sheet, k, 4, COLORS)
	for k in HURT_FRAMES:
		_draw_hurt(k)
		_c.blit(sheet, k, 5, COLORS)

	var slash := Image.create_empty(FRAME.x * SLASH_FRAMES, FRAME.y * 2, false, Image.FORMAT_RGBA8)
	for k in SLASH_FRAMES:
		# przed siebie: z góry (za głową) w dół przed postacią
		_draw_slash(k, Vector2(4, -29), 27.0, -115.0, 70.0)
		_c.blit(slash, k, 0, COLORS)
		# w górę: od przodu, nad głową, do tyłu
		_draw_slash(k, Vector2(1, -31), 26.0, -20.0, -165.0)
		_c.blit(slash, k, 1, COLORS)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://grafika/efekty"))
	var err := _save(sheet, SHEET_PATH, "przyjaciel_ruch_x4.png")
	err = maxi(err, _save(slash, SLASH_PATH, "ciecie_x4.png"))
	print("Zapisano %s i %s (błąd: %d)" % [SHEET_PATH, SLASH_PATH, err])
	quit(0 if err == OK else 1)


func _save(img: Image, path: String, preview_name: String) -> int:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	var preview := Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	preview.fill(Color("1d2738"))  # tło podglądu: brzeg wody, żeby było widać sylwetkę
	preview.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	preview.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	preview.save_png(ProjectSettings.globalize_path(PREVIEW_DIR + preview_name))
	return err


# ---------------------------------------------------------------- pozy

## Stanie: czujna poza - lekko ugięte kolana, ostrze przed sobą; oddech podnosi ramiona o 1 px.
func _draw_idle(k: int) -> PackedByteArray:
	_c.clear()
	var hip := Vector2(0, -18)
	var breath := Vector2(0, -1 if k >= 2 else 0)
	_figure({
		"hip": hip, "neck": hip + Vector2(2, -14) + breath,
		"near_foot": Vector2(5, 0), "far_foot": Vector2(-5, 0),
		"near_hand": Vector2(5, 8), "far_hand": Vector2(2, 9),
		"blade": Vector2(1, 0.35), "blade_len": 14,
		"stream": 0.0, "wave": float(k) / IDLE_FRAMES, "flutter": 0.6,
	})
	return _c.mask


## Bieg: mocne pochylenie, długi krok z fazą lotu, ręce pracują, płaszcz i szal powiewają.
## Klatki 0 i 4 to postawienie stopy.
func _draw_run(k: int) -> PackedByteArray:
	_c.clear()
	var phase := float(k) / RUN_FRAMES
	var hip := Vector2(0, -18 + roundf(cos(TAU * 2.0 * (phase - RUN_STANCE * 0.5))))
	var near := _run_foot(phase)
	var far := _run_foot(fposmod(phase + 0.5, 1.0))
	var swing := cos(TAU * phase)  # 1 = bliższa noga z przodu, więc bliższa ręka z tyłu
	var near_arm := -0.95 * swing
	var far_arm := 0.95 * swing
	_figure({
		"hip": hip, "neck": hip + Vector2(5, -13.5),
		"near_foot": near.pos, "near_lift": near.lifted,
		"far_foot": far.pos, "far_lift": far.lifted,
		"near_hand": Vector2(sin(near_arm), cos(near_arm)) * 10.0 + Vector2(0, -1.5 * maxf(0.0, near_arm)),
		"far_hand": Vector2(sin(far_arm), cos(far_arm)) * 10.0,
		"blade": Vector2(-0.9, 0.45), "blade_len": 14,
		"stream": 1.0, "wave": phase * 2.0, "flutter": 1.6,
	})
	return _c.mask


## Położenie stopy w cyklu biegu (względem bioder). Na ziemi stopa jedzie do tyłu
## z prędkością biegu; w powietrzu pięta podbija do tyłu, a kolano wychodzi wysoko do przodu.
func _run_foot(phase: float) -> Dictionary:
	var half := RUN_CYCLE * RUN_STANCE * 0.5
	if phase < RUN_STANCE:
		var t := phase / RUN_STANCE
		return {"pos": Vector2(half - 2.0 * half * t, 0), "lifted": false}
	var s := (phase - RUN_STANCE) / (1.0 - RUN_STANCE)
	var x := -half + 2.0 * half * smoothstep(0.0, 1.0, s) - 5.0 * sin(PI * s) * (1.0 - s)
	return {"pos": Vector2(x, -10.0 * sin(PI * s)), "lifted": true}


## Przewrót: przysiad, zwinięcie w kłębek, jeden pełny obrót (obwód kłębka to mniej więcej
## długość przewrotu), przyklęk i wstawanie.
func _draw_roll(k: int) -> PackedByteArray:
	_c.clear()
	match k:
		0:
			var hip := Vector2(1, -12)
			_figure({
				"hip": hip, "neck": hip + Vector2(8, -7),
				"near_foot": Vector2(6, 0), "far_foot": Vector2(-4, 0),
				"near_hand": Vector2(5, 6), "far_hand": Vector2(4, 7),
				"blade": Vector2(-1, 0.2), "blade_len": 10,
				"stream": 0.6, "wave": 0.0, "flutter": 1.2,
			})
		6:
			var hip := Vector2(-1, -12)
			_figure({
				"hip": hip, "neck": hip + Vector2(5, -11),
				"near_foot": Vector2(5, 0), "far_foot": Vector2(-8, 0), "far_knee": Vector2(-3, -2),
				"near_hand": Vector2(5, 5), "far_hand": Vector2(3, 7),
				"blade": Vector2(1, 0.6), "blade_len": 12,
				"stream": 0.7, "wave": 0.6, "flutter": 1.4,
			})
		7:
			var hip := Vector2(0, -16)
			_figure({
				"hip": hip, "neck": hip + Vector2(3, -14),
				"near_foot": Vector2(4, 0), "far_foot": Vector2(-5, 0),
				"near_hand": Vector2(5, 7), "far_hand": Vector2(2, 8),
				"blade": Vector2(1, 0.4), "blade_len": 14,
				"stream": 0.4, "wave": 0.8, "flutter": 1.0,
			})
		_:
			# klatki 1-5: kłębek obraca się o ćwierć obrotu na klatkę
			var center := Vector2(4 if k == 1 else 2, -9.0)
			_ball(center, (k - 1) * PI * 0.5, k)
	return _c.mask


## Zwinięta postać: kłębek z wystającą głową, kapturem, kolanami i powiewającym płaszczem.
func _ball(center: Vector2, angle: float, k: int) -> void:
	var head_dir := Vector2.from_angle(0.3 + angle)  # na starcie głowa z przodu, lekko w dole
	# płaszcz zawsze ciągnie się za kłębkiem
	var fl := roundf(1.5 * sin(k * 1.7))
	_c.poly([
		center + Vector2(-3, -8), center + Vector2(-13, -6 + fl), center + Vector2(-17, -2 + fl),
		center + Vector2(-12, -1), center + Vector2(-14, 3 - fl), center + Vector2(-6, 5),
	], BODY)
	_c.ellipse(center, Vector2(9.5, 9.0), BODY)
	var head := center + head_dir * 7.5
	_c.ellipse(head, Vector2(4.2, 4.2), BODY)
	var hood_dir := Vector2.from_angle(0.3 + angle - 2.3)
	_c.poly([head + hood_dir.orthogonal() * 2.0, head + hood_dir * 9.0, head - hood_dir.orthogonal() * 2.0], BODY)
	_c.ellipse(center - head_dir * 7.0, Vector2(3.5, 3.5), BODY)  # kolana
	_c.polyline([head, head + Vector2(-6, -1), head + Vector2(-11, fl)], 2.0, BODY)  # szal
	# ostrze błyska przy krawędzi kłębka
	var edge_dir := Vector2.from_angle(0.3 + angle + 1.4)
	_blade(center + edge_dir * 7.0, edge_dir.orthogonal() * -1.0, 7)


## Cięcie przed siebie: zamach nad głową, cios z wypadem w dół przed postacią, powrót.
func _draw_attack_side(k: int) -> PackedByteArray:
	_c.clear()
	var lunge: float = [0.0, 1.0, 3.0, 3.0, 2.0][k]
	var hip := Vector2(lunge * 0.6, -18)
	var neck_off: Vector2 = [Vector2(-1, -14), Vector2(2, -14), Vector2(5, -13), Vector2(5, -13), Vector2(3, -14)][k]
	var hand: Vector2 = [Vector2(-3, -10), Vector2(4, -9), Vector2(10, 0), Vector2(8, 6), Vector2(6, 7)][k]
	var angle: float = [-120.0, -50.0, 15.0, 65.0, 40.0][k]
	var stream: float = [0.3, 0.5, 0.9, 0.8, 0.5][k]
	_figure({
		"hip": hip, "neck": hip + neck_off,
		"near_foot": Vector2(8 + lunge, 0), "far_foot": Vector2(-7, 0),
		"near_hand": hand, "far_hand": Vector2(4, 6),
		"blade": Vector2.from_angle(deg_to_rad(angle)), "blade_len": 16 if k == 2 else 15,
		"stream": stream, "wave": k * 0.2, "flutter": 1.2,
	})
	return _c.mask


## Cięcie w górę: ostrze z dołu przed postacią przechodzi łukiem nad głową do tyłu.
func _draw_attack_up(k: int) -> PackedByteArray:
	_c.clear()
	var hip := Vector2(0, [-17.0, -18.0, -19.5, -19.0, -18.0][k])
	var neck_off: Vector2 = [Vector2(2, -13), Vector2(2, -14), Vector2(1, -15), Vector2(-1, -15), Vector2(1, -14)][k]
	var hand: Vector2 = [Vector2(7, 5), Vector2(8, -4), Vector2(2, -11), Vector2(-4, -9), Vector2(2, 4)][k]
	var angle: float = [35.0, -40.0, -95.0, -150.0, 80.0][k]
	_figure({
		"hip": hip, "neck": hip + neck_off,
		"near_foot": Vector2(5, 0), "far_foot": Vector2(-6, 0),
		"near_hand": hand, "far_hand": Vector2(3, 7),
		"blade": Vector2.from_angle(deg_to_rad(angle)), "blade_len": 16 if k == 2 else 15,
		"stream": 0.3 + 0.15 * k, "wave": k * 0.2, "flutter": 1.2,
	})
	return _c.mask


## Trafiony: odrzut z odchyleniem do tyłu i rękami w górze, potem zachwianie.
func _draw_hurt(k: int) -> PackedByteArray:
	_c.clear()
	var hip := Vector2(-1, -18 if k == 0 else -17)
	_figure({
		"hip": hip, "neck": hip + (Vector2(-4, -13) if k == 0 else Vector2(-2, -14)),
		"near_foot": Vector2(5, 0), "far_foot": Vector2(-6, 0),
		"near_hand": Vector2(6, -3) if k == 0 else Vector2(5, 6),
		"far_hand": Vector2(5, -5) if k == 0 else Vector2(3, 7),
		"blade": Vector2(0.4, -1.0) if k == 0 else Vector2(1.0, 0.6), "blade_len": 13,
		"stream": 0.0, "wave": 0.3 * k, "flutter": 1.6,
	})
	return _c.mask


## Cała postać w jednej pozie. Dłonie podaje się względem barku. Pola słownika:
## hip, neck - biodra i podstawa szyi; near_foot, far_foot (+ near_lift, far_lift, far_knee);
## near_hand, far_hand; blade - kierunek ostrza, blade_len; stream - jak mocno płaszcz
## powiewa do tyłu (0..1); wave, flutter - faza i siła falowania tkanin.
func _figure(p: Dictionary) -> void:
	var hip: Vector2 = p.hip
	var neck: Vector2 = p.neck
	var up := (neck - hip).normalized()
	var fwd := Vector2(-up.y, up.x)  # prostopadle do tułowia, do przodu
	var stream: float = p.stream
	var wave: float = p.wave
	var flutter: float = p.flutter
	var shoulder := neck + fwd * 0.5 - up * 1.5
	var far_shoulder := neck - fwd * 1.5 - up * 1.5

	# ręka za ciałem
	_c.line(far_shoulder, far_shoulder + (p.far_hand as Vector2), 2.5, BODY)

	# nogi
	_leg(hip, p.near_foot, p.get("near_lift", false))
	if p.has("far_knee"):
		var sole: Vector2 = p.far_foot + Vector2(0, -1)
		_c.line(hip, p.far_knee, 4.0, BODY)
		_c.line(p.far_knee, sole, 3.0, BODY)
	else:
		_leg(hip, p.far_foot, p.get("far_lift", false))

	# płaszcz: od ramion do tyłu, im szybciej, tym bardziej poziomo
	var cloak: Array[Vector2] = [neck + fwd * 1.0, neck - fwd * 3.0]
	for i in range(1, 5):
		var back := 3.0 + 2.8 * i * (0.75 + 0.9 * stream)
		var down := -1.0 + 5.0 * i * (1.0 - 0.55 * stream)
		cloak.append(neck + Vector2(-back, down + roundf(flutter * sin(wave * TAU + i * 0.9))))
	var hem_end := hip + Vector2(-1, 5.0 * (1.0 - stream))
	var last := cloak[cloak.size() - 1]
	var fl := roundf(flutter * sin(wave * TAU + 4.5))
	cloak.append(last.lerp(hem_end, 0.33) + Vector2(0, 2.0 + fl))
	cloak.append(last.lerp(hem_end, 0.55) + Vector2(0, -1.5))
	cloak.append(last.lerp(hem_end, 0.8) + Vector2(0, 1.5))
	cloak.append(hem_end)
	cloak.append(hip + Vector2(1, -2))
	_c.poly(cloak, BODY)

	# tułów i szyja
	_c.poly([hip - fwd * 4.0 - up, hip + fwd * 4.0 - up, neck + fwd * 4.0 + up, neck - fwd * 4.0 - up], BODY)
	_c.line(neck, neck + up * 3.0 + fwd, 3.0, BODY)

	# głowa i kaptur ze szpicem odchylonym do tyłu
	var head := neck + up * 6.5 + fwd * 1.5
	_c.ellipse(head, Vector2(4.6, 5.0), BODY)
	var tip := head + Vector2(-9.5 - 3.0 * stream + roundf(flutter * 0.6 * sin(wave * TAU + 2.0)), -9.5 + 4.0 * stream)
	_c.poly([head + Vector2(-0.5, -3.5), tip, head + Vector2(-3.5, -1.5)], BODY)

	# szal
	var w1 := roundf(flutter * sin(wave * TAU + 1.0))
	var w2 := roundf(flutter * 1.4 * sin(wave * TAU + 2.2))
	_c.polyline([
		neck + up * 0.5, neck + Vector2(-5, -1),
		neck + Vector2(-10 - 4 * stream, 1 + w1 - 2 * stream),
		neck + Vector2(-15 - 6 * stream, w2 - 3 * stream),
	], 2.0, BODY)

	# ręka z ostrzem (bliżej widza)
	var hand: Vector2 = shoulder + (p.near_hand as Vector2)
	_c.line(shoulder, hand, 2.5, BODY)
	var blade: Vector2 = p.blade
	if blade != Vector2.ZERO:
		_blade(hand, blade.normalized(), p.blade_len)


func _leg(hip: Vector2, foot: Vector2, lifted: bool) -> void:
	var sole := foot + Vector2(0, -1)  # podeszwa: 2 wiersze tuż nad ziemią
	var knee := _knee(hip, sole)
	_c.line(hip, knee, 4.0, BODY)
	_c.line(knee, sole, 3.0, BODY)
	_c.line(sole + Vector2(-1, 0), sole + Vector2(3, 1 if lifted else 0), 2.0, BODY)  # but


## Kolano z dwóch odcinków o długości LEG; zgina się zawsze do przodu.
func _knee(hip: Vector2, foot: Vector2) -> Vector2:
	var v := foot - hip
	var d := minf(v.length(), LEG * 2.0 - 0.05)
	var mid := hip + v.normalized() * d * 0.5
	var h := sqrt(maxf(LEG * LEG - d * d * 0.25, 0.0))
	var perp := Vector2(-v.y, v.x).normalized()
	if perp.x < 0.0:
		perp = -perp
	return mid + perp * h


## Ostrze: rękojeść w kolorze sylwetki, potem stal; pod stalą ciemny pasek, żeby miało grubość.
func _blade(hand: Vector2, dir: Vector2, length: int) -> void:
	for i in length + 1:
		var p := _c.to_pixel(hand + dir * float(i))
		if i < 2:
			_c.put(p, BODY)
			continue
		_c.put(p, STEEL_DARK if i < 4 else STEEL)
		if _c.get_px(p + Vector2i(0, 1)) == EMPTY:
			_c.put(p + Vector2i(0, 1), BODY)


# ---------------------------------------------------------------- smuga cięcia

## Biała smuga w kształcie sierpa wokół barku. Kąty w stopniach: 0 = przed postacią,
## dodatnie = w dół. Klatki 0-2: smuga narasta od `from` do `to` (najjaśniejsza jest jej
## czołowa krawędź), klatki 3-4: rozpada się ditheringiem. Tylko czubek smugi jest biały,
## żeby efekt był wyraźny, ale nie oślepiał.
func _draw_slash(k: int, pivot: Vector2, radius: float, from: float, to: float) -> PackedByteArray:
	_c.clear()
	var lead: float = [0.35, 0.7, 1.0, 1.0, 1.0][k]
	var tail: float = [0.0, 0.0, 0.1, 0.35, 0.6][k]
	var keep: float = [1.0, 1.0, 1.0, 0.55, 0.3][k]
	var span := absf(to - from)
	var middle := Vector2.from_angle(deg_to_rad((from + to) * 0.5))
	var inner_center := pivot - middle * 11.0  # przesunięte koło wycina środek: sierp
	for py in int(FEET.y):
		for px in FRAME.x:
			var c := _c.center(px, py)
			var r := c.distance_to(pivot)
			if r > radius or c.distance_to(inner_center) <= radius:
				continue
			var angle := rad_to_deg((c - pivot).angle())
			var u := (angle - from) / (to - from)
			if u < tail or u > lead:
				continue
			var behind := (lead - u) * span  # ile stopni za czołem smugi
			var edge := r > radius - 1.5    # sama zewnętrzna krawędź
			var outer := r > radius - 3.5   # zewnętrzny pas sierpa
			var threshold: float = (BAYER[(py % 4) * 4 + (px % 4)] + 0.5) / 16.0
			var value := EMPTY
			if k <= 2:
				# czoło smugi: biała krawędź; dalej biała jest tylko cienka zewnętrzna linia
				if behind < 30.0:
					value = WHITE if outer else GLOW
				elif behind < 80.0:
					value = WHITE if edge else (GLOW if outer else MIST)
				elif edge:
					value = GLOW
				elif threshold < 0.65:
					value = MIST
			elif threshold < keep:
				value = GLOW if outer and k == 3 else MIST
			if value != EMPTY:
				_c.put(Vector2i(px, py), value)
	return _c.mask
