// Jeziorko: odbicie drży (wiersze przesuwają się o 1 piksel), a księżycowa ścieżka na wodzie skrzy się.
shader_type canvas_item;

#include "res://shaders/pixel_common.gdshaderinc"

uniform float moon_x = 238.0;
// Wiersz linii dalekiego brzegu (od niego zaczyna się ścieżka księżyca).
uniform float horizon = 131.0;
// Jak szybko faluje odbicie.
uniform float ripple_speed = 1.1;
// Ile razy na sekundę zmieniają się iskry na ścieżce księżyca i jak dużo ich jest.
uniform float sparkle_rate = 6.0;
uniform float sparkle_amount = 0.22;

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = floor(UV * size);
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		COLOR = vec4(0.0);
	} else {
		// co drugi wiersz faluje mocniej - jak drobne zmarszczki na tafli
		float amp = mod(p.y, 2.0) > 0.5 ? 1.4 : 0.6;
		float shift = round(amp * sin(TIME * ripple_speed + p.y * 0.9));
		vec4 s = texture(TEXTURE, (p + vec2(shift, 0.0) + 0.5) * TEXTURE_PIXEL_SIZE);
		if (s.a > 0.5) {
			c = s;
		}
		int idx = palette_index(c.rgb);
		float half_width = 3.0 + (p.y - horizon) * 0.42;
		if (idx >= 4 && idx <= 6 && abs(p.x + 0.5 - moon_x) < half_width + 1.0) {
			float h = hash13(vec3(p, floor(TIME * sparkle_rate)));
			if (h < sparkle_amount) {
				idx -= 1;
			} else if (h > 1.0 - sparkle_amount * 0.3 && idx < 6) {
				idx += 1;
			}
		}
		COLOR = vec4(PAL[idx], 1.0);
	}
}
