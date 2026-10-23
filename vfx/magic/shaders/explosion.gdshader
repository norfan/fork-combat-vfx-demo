// A fire explosion on a unit quad centred on the blast: a churning fireball that swells
// fast, rises, cools band by band and burns out from the inside. `progress` runs 0 → 1.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float progress = 0.0;
uniform float time = 0.0;
uniform float seed = 0.0;
// UV.y of the floor line (above 1: no floor in the quad); nothing burns below it.
uniform float floor_v = 2.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float k = clamp(progress, 0.0, 1.0);
	float radius = mix(0.16, 0.74, 1.0 - pow(1.0 - k, 3.0));
	// The whole ball lifts as it burns.
	p.y += k * 0.22;
	float r = length(p * vec2(1.0, 1.1));
	vec2 np = p * 2.6 + vec2(0.0, k * 1.6);
	float n = m_fbm(np + seed);
	float n2 = m_fbm(np * 2.3 + seed + 4.0 - vec2(0.0, time * 1.5));
	float f = 1.0 - r / radius + (n - 0.5) * 1.1 + (n2 - 0.5) * 0.35;
	// Burns out from the inside as it cools.
	f -= smoothstep(0.35, 1.0, k) * smoothstep(radius * 0.9, 0.0, r) * 0.9;
	float heat = clamp(f * 1.8, 0.0, 1.0) * (1.0 - 0.72 * k);
	// White-hot for the first instant.
	heat = clamp(heat + smoothstep(0.14, 0.0, k) * smoothstep(radius, 0.0, r), 0.0, 1.0);
	float above = smoothstep(floor_v + 0.01, floor_v - 0.015, UV.y);
	COLOR = vec4(m_fire(heat), smoothstep(0.02, 0.2, heat) * (1.0 - smoothstep(0.82, 1.0, k)) * above);
}
