// Moving air on strips built by vfx/magic/wind/gusts.gd (wind blades, streaks, funnel
// bands): UV.x runs along a strip, UV.y across it (0 at the leading edge). Per vertex,
// COLOR.a is its strength and COLOR.r how much of it is a crisp edge (1) or a soft band
// (0). Air is drawn by its streaks: fine flow lines running along it, a bright leading
// edge, all fading out at its ends. With `see_through` it also bends the screen behind it
// (the 炸裂 tier); without, it is a pale, translucent sheen.
shader_type canvas_item;
render_mode unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float see_through = 1.0;
uniform float time = 0.0;
uniform float seed = 0.0;
uniform vec3 tint : source_color = vec3(0.96, 0.99, 1.0);

varying vec4 tone;

void vertex() {
	tone = COLOR;
}

void fragment() {
	float power = tone.a;
	float ends = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float edge = mix(0.0, smoothstep(0.35, 0.0, UV.y), tone.r);
	float body = pow(max(1.0 - abs(UV.y - 0.35) * 1.6, 0.0), 1.5);
	// Flow lines: thin streaks running along the strip, drifting.
	float lines = smoothstep(0.55, 0.9, m_noise(vec2(UV.x * 3.0 - time * 6.0 + seed, UV.y * 13.0)));
	// A milky body of moving air, threaded with brighter flow lines and a crisp edge.
	float streak = (edge * 1.0 + lines * 0.85 * body + body * 0.3) * ends * power;
	if (see_through > 0.5) {
		float bend = body * ends * power;
		vec3 behind = texture(screen_texture, SCREEN_UV + vec2(0.0, (UV.y - 0.35)) * 0.03 * bend).rgb;
		COLOR = vec4(behind + tint * streak * 1.05, step(0.002, bend + streak));
	} else {
		COLOR = vec4(tint, clamp(streak * 0.9, 0.0, 1.0));
	}
}
