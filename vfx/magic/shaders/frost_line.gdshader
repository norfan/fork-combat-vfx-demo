// A line of ice for the shared shapes (vfx/magic/ice.gd `line`): a thin streak of frozen
// light — a white core in a cold cyan haze — broken into facets that catch the light one
// after another, with a rime of tiny glints along it. Strips are built like the sand
// silk's (vfx/magic/sand/threads.gd): per vertex, COLOR.a is its strength, COLOR.g its
// length in 2000 px units, COLOR.b which line it is; UV.x runs along it, UV.y across.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float time = 0.0;

varying vec4 tone;

void vertex() {
	tone = COLOR;
}

void fragment() {
	float power = tone.a;
	float length_px = max(tone.g * 2000.0, 1.0);
	float across = abs(UV.y - 0.5) * 2.0;
	// Facets 9 px long, each lit as the light slides along the line.
	float cell = floor(UV.x * length_px / 9.0);
	float facet = m_hash(vec2(cell, tone.b * 53.0));
	float catch_light = pow(0.5 + 0.5 * sin(time * 5.0 - cell * 0.6 + facet * 6.0), 6.0);
	float core = smoothstep(0.4, 0.0, across);
	float haze = pow(max(1.0 - across, 0.0), 2.2);
	float glint = step(0.93, m_hash(vec2(floor(UV.x * length_px / 2.0), floor(time * 9.0) + tone.b))) * smoothstep(0.7, 0.0, across);
	vec3 c = vec3(0.35, 0.75, 1.0) * haze * 0.7 + vec3(0.85, 0.97, 1.0) * core * (0.55 + 0.45 * facet) + vec3(1.0) * (catch_light * core + glint);
	COLOR = vec4(c, clamp(haze * 0.6 + core * 0.8 + glint, 0.0, 1.0) * power);
}
