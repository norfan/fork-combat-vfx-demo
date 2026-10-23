// A fireball's body on a unit quad: +x is the direction of travel. The head is a ball of
// radius 1 (in body units) whose surface churns; behind it the flames stream back into a
// ragged tail `stretch` times as long, so a fast fireball reads as a comet.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float time = 0.0;
uniform float stretch = 1.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;
// Body units the quad covers behind the centre (the tail) and around it.
uniform float tail = 1.4;
uniform float reach = 1.4;

void fragment() {
	vec2 p = vec2(mix(-tail, reach, UV.x), mix(-reach, reach, UV.y));
	vec2 q = p;
	if (q.x < 0.0) q.x /= stretch;
	float r = length(q);
	// The pattern streams backwards along the body as it flies.
	vec2 flow = vec2(p.x * 2.0 + time * 7.0, p.y * 2.2);
	float n = m_fbm(flow + seed);
	float n2 = m_fbm(flow * 2.1 - vec2(time * 3.0, 0.0) + seed + 3.1);
	float ragged = mix(0.3, 1.0, smoothstep(0.2, -1.6, p.x));
	float f = 1.0 - r + (n - 0.5) * ragged * 1.6 + (n2 - 0.5) * 0.35;
	float heat = clamp(f * 1.5, 0.0, 1.0);
	// A white-hot heart just behind the leading edge.
	heat = max(heat, smoothstep(0.62, 0.0, length(p - vec2(0.18, 0.0))) * (0.75 + 0.25 * n2));
	COLOR = vec4(m_fire(heat), smoothstep(0.02, 0.25, heat) * intensity);
}
