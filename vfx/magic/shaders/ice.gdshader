// Clear crystal ice on the prism faces built by vfx/magic/ice/crystal.gd. Per vertex,
// COLOR.r and COLOR.g carry the face's normal (towards the viewer, and up/down the screen,
// both 0 … 1 for −1 … 1), COLOR.b which face it is and COLOR.a how solid; UV.x runs along
// the crystal, UV.y across the face. Lit from the upper front: faces turned to the light
// glow pale, faces turned away go deep teal, faces seen edge-on flash white (fresnel), the
// ridges between faces are bright lines, a specular glint rides the face that catches the
// light, and fine fractures glimmer inside. With `see_through` it also shows the screen
// behind it, bent — glass-clear ice (the 炸裂 tier); without, it is simply translucent.
shader_type canvas_item;
render_mode unshaded;
#include "res://vfx/magic/shaders/noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float see_through = 1.0;
uniform float time = 0.0;
uniform float seed = 0.0;

varying vec4 tone;

void vertex() {
	tone = COLOR;
}

void fragment() {
	float nz = tone.r * 2.0 - 1.0;
	float ny = tone.g * 2.0 - 1.0;
	vec3 n = normalize(vec3(0.0, ny, max(nz, 0.0) + 0.001));
	vec3 light = normalize(vec3(0.0, -0.72, 0.7));
	float lit = max(dot(n, light), 0.0);
	float fresnel = pow(1.0 - clamp(nz, 0.0, 1.0), 3.0);
	float spec = pow(max(dot(n, normalize(light + vec3(0.0, 0.0, 1.0))), 0.0), 36.0);
	float ridge = smoothstep(0.1, 0.0, UV.y) + smoothstep(0.9, 1.0, UV.y);
	float crack = smoothstep(0.035, 0.0, abs(m_noise(vec2(UV.x * 5.0 + seed, UV.y * 2.5 + tone.b * 9.0)) - 0.5));
	vec3 c = mix(vec3(0.04, 0.3, 0.5), vec3(0.55, 0.9, 1.0), lit);
	float alpha = tone.a * (0.55 + 0.45 * max(max(fresnel, ridge), spec));
	if (see_through > 0.5) {
		// The screen behind, bent by the facet and tinted cold.
		vec3 behind = texture(screen_texture, SCREEN_UV + vec2(nz * 0.5, ny) * 0.014).rgb;
		c = mix(c, behind * vec3(0.75, 1.0, 1.15) + c * 0.3, 0.55);
		alpha = tone.a;
	}
	c += vec3(0.88, 0.98, 1.0) * (fresnel * 0.5 + ridge * 0.7 + spec * 1.3 + crack * 0.45);
	COLOR = vec4(c, alpha);
}
