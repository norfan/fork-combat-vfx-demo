// Air warped by heat: whatever is behind the quad wobbles, strongest in the middle and
// fading to nothing at the edges, with a faint warm tint.
shader_type canvas_item;
render_mode unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float time = 0.0;
uniform float seed = 0.0;
// Screen-UV offset at the strongest point.
uniform float strength = 0.008;
uniform float warmth = 0.06;

void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float mask = smoothstep(1.0, 0.25, length(d));
	vec2 flow = UV * vec2(5.0, 3.0) + vec2(time * 4.0, -time * 1.5);
	vec2 warp = vec2(m_fbm(flow + seed), m_fbm(flow + seed + 7.3)) - 0.5;
	vec3 seen = texture(screen_texture, SCREEN_UV + warp * strength * mask).rgb;
	COLOR = vec4(seen + vec3(1.0, 0.45, 0.15) * warmth * mask, step(0.001, mask));
}
