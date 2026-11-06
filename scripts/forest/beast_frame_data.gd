class_name BeastFrameData
extends RefCounted
## Plik wygenerowany przez tools/make_beast_sprites.gd - nie poprawiaj go ręcznie.
## Rozmiary klatek bestii i położenie oka w każdej klatce (względem stóp, bestia zwrócona w prawo).

const FRAME_SIZE := Vector2i(208, 112)
const FEET := Vector2i(104, 108)
const COLUMNS := 8
const ROW_IDLE := 0
const ROW_WALK := 1
const ROW_GALLOP := 2
const ROW_PAW := 3
const ROW_TUSK := 4
const ROW_STOMP := 5
const ROW_HURT := 6
const IDLE_FRAMES := 4
const WALK_FRAMES := 8
const GALLOP_FRAMES := 6
const PAW_FRAMES := 4
const TUSK_FRAMES := 6
const STOMP_FRAMES := 7
const HURT_FRAMES := 8
## Cykl chodu i galopu: ile pikseli drogi przypada na jedną klatkę.
const WALK_STEP_PIXELS := 2.857
const GALLOP_STEP_PIXELS := 17.143
## EYES[rząd][kolumna]: piksel oka względem stóp.
const EYES := [
	[Vector2i(71, -42), Vector2i(70, -42), Vector2i(70, -42), Vector2i(70, -42)],
	[Vector2i(71, -42), Vector2i(70, -42), Vector2i(71, -43), Vector2i(71, -44), Vector2i(71, -42), Vector2i(70, -42), Vector2i(71, -43), Vector2i(71, -44)],
	[Vector2i(70, -37), Vector2i(69, -44), Vector2i(69, -44), Vector2i(70, -37), Vector2i(70, -34), Vector2i(70, -34)],
	[Vector2i(67, -34), Vector2i(67, -34), Vector2i(67, -34), Vector2i(67, -34)],
	[Vector2i(66, -34), Vector2i(64, -31), Vector2i(64, -31), Vector2i(71, -62), Vector2i(73, -53), Vector2i(73, -45)],
	[Vector2i(68, -54), Vector2i(64, -66), Vector2i(59, -78), Vector2i(56, -83), Vector2i(72, -37), Vector2i(71, -40), Vector2i(70, -42)],
	[Vector2i(69, -45), Vector2i(70, -43), Vector2i(69, -27), Vector2i(69, -12), Vector2i(69, -15), Vector2i(69, -20), Vector2i(69, -19), Vector2i(69, -19)],
]
