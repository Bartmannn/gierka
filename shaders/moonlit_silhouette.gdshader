// Sylwetka postaci oświetlona księżycem od tyłu: krawędzie zwrócone do księżyca i do nieba
// dostają jasny obrys, tak jak w grafice sceny (funkcje obrys i cieniuj_sylwetke w scena_las.py).
// Strona obrysu zmienia się, gdy postać przejdzie pod księżycem na drugą stronę.
// Kolory stali, kłów i pary zostają bez zmian; obrys dostają tylko piksele w kolorze nocy.
// Liczymy na współrzędnych sceny, więc wstrząs obrazu nie przesuwa wzoru ditheringu.
shader_type canvas_item;

#include "res://shaders/pixel_common.gdshaderinc"

uniform float moon_x = 238.0;
// -1, gdy postać jest odbita w poziomie (patrzy w lewo). Ustawia to skrypt postaci.
uniform float flip = 1.0;
// Chwilowe rozjaśnienie obrysu po trafieniu (0 = brak).
uniform float flash = 0.0;
// Przycinanie do linii ziemi: to, co wypadłoby pod ziemią, znika (nogi bestii na zboczu).
uniform bool clip_to_ground = false;
// Zbocze: (początek x, koniec x, ziemia wysoko, ziemia nisko) - jak ForestTerrain.
uniform vec4 slope = vec4(156.0, 246.0, 188.0, 205.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float ground_at(float x) {
	if (x < slope.x) {
		return slope.z;
	}
	if (x > slope.y) {
		return slope.w;
	}
	float t = (x - slope.x) / (slope.y - slope.x);
	return ceil(slope.z + (slope.w - slope.z) * t * t * (3.0 - 2.0 * t));
}

void fragment() {
	vec2 p = floor(world_pos);
	vec4 c = texture(TEXTURE, UV);
	if (clip_to_ground && p.y >= ground_at(p.x + 0.5)) {
		COLOR = vec4(0.0);
	} else if (c.a < 0.5 || palette_index(c.rgb) != 0) {
		COLOR = c;
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE;
		// po której stronie jest księżyc; tuż pod nim światło pada tylko z góry
		float side = abs(moon_x - p.x) > 12.0 ? sign(moon_x - p.x) : 0.0;
		vec2 toward = vec2(side * flip * px.x, 0.0);
		bool top = texture(TEXTURE, UV - vec2(0.0, px.y)).a < 0.5;
		bool lit = side != 0.0 && texture(TEXTURE, UV + toward).a < 0.5;
		bool near_top = texture(TEXTURE, UV - vec2(0.0, 2.0 * px.y)).a < 0.5;
		bool near_lit = side != 0.0 && texture(TEXTURE, UV + 2.0 * toward).a < 0.5;
		int idx = 0;
		if ((near_top || near_lit) && bayer4(p) < 0.5) {
			idx = 1;
		}
		if (top || lit) {
			idx = 4;
		}
		if (top && lit) {
			idx = 5;
		}
		if (flash > 0.0 && idx >= 4) {
			idx += 1;  // trafienie: obrys na moment jaśniejszy
		}
		COLOR = vec4(PAL[idx], 1.0);
	}
}
