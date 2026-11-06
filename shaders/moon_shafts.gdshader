// Snopy księżycowego światła: przygasają i wracają razem z „oddechem” poświaty księżyca.
// Zamiast półprzezroczystości część pikseli znika według wzoru ditheringu.
shader_type canvas_item;

#include "res://shaders/pixel_common.gdshaderinc"

uniform float glow_period = 7.0;
// Jaka część snopów zostaje zawsze i o ile zmienia się w oddechu.
uniform float base = 0.75;
uniform float strength = 0.25;

void fragment() {
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE);
	vec4 c = texture(TEXTURE, UV);
	float keep = base + strength * sin(TAU * TIME / glow_period);
	COLOR = (c.a > 0.5 && bayer4(p) < keep) ? c : vec4(0.0);
}
