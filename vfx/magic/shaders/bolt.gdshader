// Lightning on strips built along jagged paths (vfx/magic/thunder/arcs.gd): UV.x along a
// strip, UV.y across it. Per vertex, COLOR.a is the strip's power and COLOR.r the width of
// its white-hot core as a fraction of the strip; around the core a cold glow fades out to
// violet at the edges, and the current crawls along it.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float time = 0.0;
uniform vec3 glow_colour : source_color = vec3(0.45, 0.65, 1.0);
uniform vec3 edge_colour : source_color = vec3(0.5, 0.28, 1.0);

// The strip's vertex colour, taken in the vertex stage (the fragment's COLOR is already
// multiplied by the node's texture).
varying vec4 tone;

void vertex() {
	tone = COLOR;
}

void fragment() {
	float power = tone.a;
	float core_width = max(tone.r, 0.02);
	float across = abs(UV.y - 0.5) * 2.0;
	float core = 1.0 - smoothstep(core_width * 0.45, core_width, across);
	float glow = pow(max(1.0 - across, 0.0), 2.4);
	float live = 0.7 + 0.6 * m_noise(vec2(UV.x * 40.0 - time * 60.0, time * 13.0));
	vec3 tint = mix(edge_colour, glow_colour, glow);
	vec3 c = tint * glow * 0.9 * live + vec3(0.9, 0.96, 1.0) * core;
	COLOR = vec4(c, clamp(max(glow * 0.85 * live, core), 0.0, 1.0) * power);
}
