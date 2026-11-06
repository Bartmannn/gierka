// Mgła powoli dryfuje w lewo i w prawo, zawsze o całe piksele.
// To, co wysunie się za krawędź obrazu, wraca z drugiej strony.
shader_type canvas_item;

// O ile pikseli mgła odpływa i ile sekund trwa jeden pełny ruch tam i z powrotem.
uniform float amplitude = 3.0;
uniform float period = 40.0;
uniform float phase = 0.0;

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = floor(UV * size);
	float offset = round(amplitude * sin(TAU * TIME / period + phase));
	vec2 q = vec2(mod(p.x - offset, size.x), p.y);
	COLOR = texture(TEXTURE, (q + 0.5) * TEXTURE_PIXEL_SIZE);
}
