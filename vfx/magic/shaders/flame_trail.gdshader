// The flame streaming off behind a fireball, on a strip built along its recent path:
// UV.x runs 0 at the body … 1 at the end of the trail, UV.y across it.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float time = 0.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float n = m_fbm(vec2(UV.x * 6.0 - time * 2.5, UV.y * 2.5) + seed);
	float heat = (1.0 - across) * (1.0 - UV.x) * 1.35 + (n - 0.5) * 0.9 * (0.3 + UV.x) - UV.x * 0.15;
	heat = clamp(heat, 0.0, 1.0);
	COLOR = vec4(m_fire(heat), smoothstep(0.03, 0.3, heat) * intensity);
}
