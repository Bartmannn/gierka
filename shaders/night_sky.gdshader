// Nocne niebo z księżycem, liczone na żywo według tego samego przepisu co grafika
// (grafika/narzedzia/scena_las.py, funkcja niebo). Dzięki temu księżyc może się ruszać:
// - poświata wokół księżyca powoli „oddycha”,
// - smuga chmur przesuwa się przez tarczę księżyca,
// - gwiazdy z rzadka mrugają.
// Tekstura węzła (0_niebo.png) wyznacza tylko rozmiar obrazu.
shader_type canvas_item;

#include "res://shaders/pixel_common.gdshaderinc"

uniform vec2 moon_center = vec2(238.0, 42.0);
uniform float moon_radius = 11.0;
// Ile sekund trwa jeden „oddech” poświaty i jak mocno się zmienia.
uniform float glow_period = 7.0;
uniform float glow_amount = 0.12;
// Prędkość chmur w pikselach na sekundę.
uniform float cloud_speed = 1.6;
// Jak często gwiazdy mrugają (część gwiazd przygasa naraz).
uniform float star_twinkle = 0.18;

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = floor(UV * size);
	float by = bayer4(p);
	float breath = sin(TAU * TIME / glow_period);

	// tło: ciemniej u góry, jaśniej przy horyzoncie i wokół księżyca
	float d = length(vec2(p.x - moon_center.x, (p.y - moon_center.y) * 1.25));
	float v = clamp(p.y / 135.0, 0.0, 1.0) * 1.7
			+ 2.4 * exp(-d / 34.0) * (1.0 + glow_amount * breath)
			+ 1.0 * exp(-d / 110.0);
	int idx = clamp(int(floor(v + (by - 0.5) * 0.9)), 0, 4);
	vec3 col = PAL[idx];

	// smuga chmur przecinająca dolną część tarczy, płynie z lewa na prawo
	float band = exp(-pow((p.y - (moon_center.y + 8.0 + 0.05 * (p.x - moon_center.x))) / 5.0, 2.0))
			* exp(-pow((p.x - moon_center.x) / 120.0, 2.0));
	float cloud = value_noise(vec2((p.x - TIME * cloud_speed) / 40.0, p.y / 6.0)) * band;
	if (cloud > 0.32 && by < (cloud - 0.32) * 4.0) {
		col = PAL[3];
	}

	vec2 m = p + 0.5 - moon_center;
	if (dot(m, m) < moon_radius * moon_radius) {
		// tarcza księżyca z kraterami; chmura przesłania ją ditheringiem
		col = PAL[6];
		bool crater = length(m - vec2(-3.0, -3.0)) < 3.2 || length(m - vec2(4.0, 2.0)) < 2.4
				|| length(m - vec2(-1.0, 5.0)) < 1.6;
		if ((crater && by < 0.6) || (cloud > 0.4 && by < 0.5)) {
			col = PAL[5];
		}
	} else if (p.y < 95.0 && idx <= 1 && length(p - moon_center) > 70.0) {
		// gwiazdy z dala od księżyca
		if (hash12(p) < 0.0009) {
			float kind = hash12(p + vec2(17.0, 5.0));
			int s = kind < 0.4 ? 3 : (kind < 0.8 ? 4 : 5);
			if (hash13(vec3(p, floor(TIME * 2.5 + kind * 10.0))) < star_twinkle) {
				s -= 1;
			}
			col = PAL[s];
		}
	}
	COLOR = vec4(col, 1.0);
}
