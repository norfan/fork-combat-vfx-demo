// Burnt ground: a dark, ragged mark with embers still glowing in it as it cools.
shader_type canvas_item;
render_mode unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float fade = 1.0;
uniform float seed = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float n = m_fbm(p * 3.0 + seed);
	float r = length(p);
	float mark = smoothstep(1.0, 0.45, r + (n - 0.5) * 0.55) * fade;
	float ember = smoothstep(0.6, 0.76, n) * smoothstep(0.75, 0.15, r) * fade * fade;
	COLOR = vec4(mix(vec3(0.06, 0.04, 0.03), vec3(1.0, 0.45, 0.1), ember), max(mark * 0.85, ember));
}
