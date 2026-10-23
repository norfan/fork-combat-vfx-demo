// One licking flame on a unit quad, standing on its bottom edge: narrow at the top,
// swaying and flickering upwards.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float time = 0.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 2.0, 1.0 - UV.y);
	float n = m_fbm(vec2(p.x * 2.5, p.y * 2.0 - time * 3.5) + seed);
	float sway = (m_noise(vec2(seed, time * 2.0)) - 0.5) * 0.5 * p.y;
	// A rounded body that narrows into a soft, licking tip.
	float width = pow(max(1.0 - p.y, 0.0), 0.55) * 0.9 + 0.04;
	float f = 1.0 - abs(p.x - sway + (n - 0.5) * 0.7 * p.y) / width - p.y * 0.45 + (n - 0.5) * 0.8;
	float heat = clamp(f * 1.3, 0.0, 1.0) * (1.0 - p.y * 0.5);
	float base = smoothstep(0.0, 0.08, p.y);
	COLOR = vec4(m_fire(heat), smoothstep(0.0, 0.45, heat) * intensity * base);
}
