class_name HitboxDebug
extends Node2D
## Podgląd hitboxów do sprawdzania walki - klawisz F1 włącza i wyłącza ramki:
##   jasnoniebieska: ciało przyjaciela,     biała: jego cięcie (gdy rani),
##   szara: ciało bestii (gdzie trafia ostrze), pomarańczowa: ataki bestii (gdy ranią).
## Działa tylko w wersji roboczej (uruchomionej z edytora); w wydanej grze nie da się go włączyć.

## Walka, której prostokąty rysujemy (ustawia ją forest_lake.gd).
var fight: ForestFight
var shown := false


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hitboxes") and OS.is_debug_build():
		shown = not shown
		visible = shown


func _process(_delta: float) -> void:
	if shown:
		queue_redraw()


func _draw() -> void:
	if fight == null:
		return
	_frame(fight.friend_body(), Palette.MOON_GLOW)
	_frame(fight.friend_slash(), Palette.MOON)
	_frame(fight.beast.hurtbox(), Palette.MIST)
	for box in fight.beast.attack_boxes():
		_frame(box, Palette.ACCENT)


func _frame(r: Rect2, color: Color) -> void:
	if not r.has_area():
		return
	var a := r.position.round()
	var b := r.end.round() - Vector2.ONE
	draw_rect(Rect2(a.x, a.y, b.x - a.x + 1, 1), color)
	draw_rect(Rect2(a.x, b.y, b.x - a.x + 1, 1), color)
	draw_rect(Rect2(a.x, a.y, 1, b.y - a.y + 1), color)
	draw_rect(Rect2(b.x, a.y, 1, b.y - a.y + 1), color)
