// Wspólne klocki shaderów pixel artu: paleta gry, dithering Bayera i powtarzalny „los”.
// Każdy shader liczy kolor jednego piksela siatki 480x270 i zawsze wybiera go z palety,
// więc nie powstają żadne pośrednie odcienie ani wygładzenia.

// Te same kolory co w scripts/view/palette.gd (Palette), w tej samej kolejności co w grafice.
const vec3 PAL[8] = vec3[8](
	vec3(7.0, 8.0, 12.0) / 255.0,       // 0 NIGHT       noc
	vec3(13.0, 15.0, 21.0) / 255.0,     // 1 GROUND      ziemia
	vec3(18.0, 25.0, 38.0) / 255.0,     // 2 WATER       tafla
	vec3(29.0, 39.0, 56.0) / 255.0,     // 3 WATER_EDGE  brzeg
	vec3(59.0, 71.0, 90.0) / 255.0,     // 4 MIST        mgła
	vec3(106.0, 127.0, 153.0) / 255.0,  // 5 MOON_GLOW   poświata
	vec3(211.0, 223.0, 234.0) / 255.0,  // 6 MOON        księżyc
	vec3(255.0, 138.0, 61.0) / 255.0    // 7 ACCENT      akcent (tylko cios gracza)
);

const int BAYER4[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

// Próg ditheringu 4x4 dla piksela p (0..1), taki sam jak w generatorze grafiki.
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (float(BAYER4[y * 4 + x]) + 0.5) / 16.0;
}

// Numer najbliższego koloru palety.
int palette_index(vec3 c) {
	int best = 0;
	float best_d = 10.0;
	for (int i = 0; i < 8; i++) {
		vec3 d = c - PAL[i];
		float dd = dot(d, d);
		if (dd < best_d) {
			best_d = dd;
			best = i;
		}
	}
	return best;
}

uint pcg_hash(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// Liczba „losowa” 0..1, zawsze taka sama dla tych samych współrzędnych.
float hash12(vec2 p) {
	uvec2 q = uvec2(ivec2(p) + 8192);
	return float(pcg_hash(q.x + pcg_hash(q.y))) / 4294967295.0;
}

float hash13(vec3 p) {
	uvec3 q = uvec3(ivec3(p) + 8192);
	return float(pcg_hash(q.x + pcg_hash(q.y + pcg_hash(q.z)))) / 4294967295.0;
}

// Gładki szum (0..1) o oczkach 1x1: do chmur i mgieł.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
