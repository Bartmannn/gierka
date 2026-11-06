// Sylwetka postaci oświetlona księżycem od tyłu: krawędzie zwrócone do księżyca i do nieba
// dostają jasny obrys, tak jak w grafice sceny (funkcje obrys i cieniuj_sylwetke w scena_las.py).
// Strona obrysu zmienia się, gdy postać przejdzie pod księżycem na drugą stronę.
// Kolory stali (ostrze) zostają bez zmian; obrys dostają tylko piksele w kolorze nocy.
shader_type canvas_item;

#include "res://shaders/pixel_common.gdshaderinc"

uniform float moon_x = 238.0;
// -1, gdy postać jest odbita w poziomie (idzie w lewo). Ustawia to skrypt postaci.
uniform float flip = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5 || palette_index(c.rgb) != 0) {
		COLOR = c;
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float screen_x = FRAGCOORD.x;
		// po której stronie jest księżyc; tuż pod nim światło pada tylko z góry
		float side = abs(moon_x - screen_x) > 12.0 ? sign(moon_x - screen_x) : 0.0;
		vec2 toward = vec2(side * flip * px.x, 0.0);
		bool top = texture(TEXTURE, UV - vec2(0.0, px.y)).a < 0.5;
		bool lit = side != 0.0 && texture(TEXTURE, UV + toward).a < 0.5;
		bool near_top = texture(TEXTURE, UV - vec2(0.0, 2.0 * px.y)).a < 0.5;
		bool near_lit = side != 0.0 && texture(TEXTURE, UV + 2.0 * toward).a < 0.5;
		int idx = 0;
		if ((near_top || near_lit) && bayer4(floor(FRAGCOORD.xy)) < 0.5) {
			idx = 1;
		}
		if (top || lit) {
			idx = 4;
		}
		if (top && lit) {
			idx = 5;
		}
		COLOR = vec4(PAL[idx], 1.0);
	}
}
