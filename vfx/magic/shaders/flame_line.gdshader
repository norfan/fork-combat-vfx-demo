// A line of fire for the shared shapes (vfx/magic/fire.gd `line`): a ribbon of flame on a
// strip built like the sand silk's (vfx/magic/sand/threads.gd), churning and licking at its
// edges, white-hot along its core. Per vertex, COLOR.a is its strength, COLOR.g its length
// in 2000 px units (so the flames keep their size however long it is), COLOR.b which line
// it is; UV.x runs along it, UV.y across.
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
	float along = UV.x * max(tone.g * 2000.0, 1.0) / 60.0;
	float across = abs(UV.y - 0.5) * 2.0;
	float n = m_fbm(vec2(along * 1.6 - time * 3.0, UV.y * 2.2 + tone.b * 31.0 + time * 0.7));
	float heat = (1.0 - across) * 1.25 + (n - 0.5) * 1.1 - 0.12;
	heat = clamp(heat * (0.55 + 0.45 * power), 0.0, 1.0);
	COLOR = vec4(m_fire(heat), smoothstep(0.04, 0.32, heat) * min(power * 1.4, 1.0));
}
