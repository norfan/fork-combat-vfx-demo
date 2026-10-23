// Frosted ground: a pale, crystalline patch with feathered edges and glittering specks.
shader_type canvas_item;
render_mode unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float fade = 1.0;
uniform float seed = 0.0;
uniform float time = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float n = m_fbm(p * vec2(4.0, 2.0) + seed);
	float r = length(p);
	// Feathery frost fingers at the edge.
	float edge = r + (n - 0.5) * 0.7 + (m_noise(p * 14.0 + seed) - 0.5) * 0.25;
	float frost = smoothstep(1.0, 0.55, edge) * fade;
	vec3 c = mix(vec3(0.55, 0.75, 0.95), vec3(0.92, 0.97, 1.0), smoothstep(0.4, 0.8, n));
	float glitter = step(0.985, m_hash(floor(UV * vec2(160.0, 40.0)) + floor(time * 6.0))) * frost;
	COLOR = vec4(c + glitter, max(frost * 0.7, glitter));
}
