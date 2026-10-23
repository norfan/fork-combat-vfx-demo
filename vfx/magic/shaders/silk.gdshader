// Sand silk: a very fine thread of glittering sand-gold grains, on strips built by
// vfx/magic/thunder/arcs.gd. Along the strip the thread is a row of tiny grains packed close
// (a gap here and there), each twinkling on its own; across it a hair-thin bright core in a
// faint golden haze. Per vertex, COLOR.a is the thread's strength, COLOR.g its length in
// 2000 px units (so grains keep their size however long it is), COLOR.b which thread it is.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform float time = 0.0;
// How many grains are present, 0 … 1 (a thread falling apart thins out).
uniform float present = 0.88;
uniform vec3 gold : source_color = vec3(0.95, 0.72, 0.32);
uniform vec3 pale : source_color = vec3(1.0, 0.95, 0.78);

varying vec4 tone;

void vertex() {
	tone = COLOR;
}

void fragment() {
	float power = tone.a;
	float length_px = max(tone.g * 2000.0, 1.0);
	float across = abs(UV.y - 0.5) * 2.0;
	float cell = floor(UV.x * length_px / 2.2);
	float grain = m_hash(vec2(cell, tone.b * 97.0 + 3.0));
	float here = step(grain, present * clamp(power * 1.3, 0.0, 1.0));
	float twinkle = 0.55 + 0.45 * sin(time * 22.0 + grain * 60.0);
	float core = smoothstep(0.45, 0.05, across);
	float haze = pow(max(1.0 - across, 0.0), 3.0) * 0.28;
	vec3 c = mix(gold, pale, core * twinkle);
	COLOR = vec4(c, (core * here * twinkle + haze) * power);
}
