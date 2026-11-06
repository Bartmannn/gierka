// Przytomność rannego bohatera zamiast paska zdrowia: powieki z ditherowaną krawędzią
// i ciemnienie obrazu. Ciemnienie to czarne piksele rozłożone wzorem Bayera, nie półprzezroczystość.
// Węzeł to prostokąt na cały ekran (480x270) w osobnej warstwie, więc wstrząs obrazu go nie rusza.
shader_type canvas_item;

#include "res://shaders/pixel_common.gdshaderinc"

uniform vec2 screen = vec2(480.0, 270.0);
// 1 = oczy otwarte, 0 = zamknięte.
uniform float openness = 1.0;
// 0..1 - ile pikseli obrazu gaśnie.
uniform float darkness = 0.0;
// Jak bardzo powieki są wygięte (kształt oka) i szerokość miękkiej krawędzi.
uniform float curve = 40.0;
uniform float soft_edge = 4.0;

void fragment() {
	vec2 p = floor(UV * screen);
	float by = bayer4(p);
	float closed = 1.0 - clamp(openness, 0.0, 1.0);
	float u = (p.x + 0.5 - screen.x * 0.5) / (screen.x * 0.5);
	float lid = closed * (screen.y * 0.5 + curve * u * u);
	// odległość od krawędzi najbliższej powieki w głąb otwartego oka
	float inside = min(p.y + 0.5, screen.y - p.y - 0.5) - lid;
	bool black = closed > 0.002 && (inside < 0.0 || (inside < soft_edge && by < (soft_edge - inside) / (soft_edge + 1.0)));
	black = black || by < darkness;
	COLOR = black ? vec4(0.0, 0.0, 0.0, 1.0) : vec4(0.0);
}
