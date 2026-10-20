shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float lifetime = 0.19;
uniform bool swinging = true;
uniform vec4 ink_0 : source_color = vec4(0.94, 0.98, 0.91, 1.0);
uniform vec4 ink_1 : source_color = vec4(0.64, 0.83, 0.88, 1.0);
uniform vec4 ink_2 : source_color = vec4(0.31, 0.56, 0.69, 1.0);
uniform vec4 ink_3 : source_color = vec4(0.18, 0.31, 0.43, 1.0);

void fragment() {
	float freshness = clamp(1.0 - (clock - UV.y) / lifetime, 0.0, 1.0);
	vec3 ink = ink_3.rgb;
	if (UV.x > 0.24) { ink = ink_2.rgb; }
	if (UV.x > 0.58) { ink = ink_1.rgb; }
	if (UV.x > 0.84) { ink = ink_0.rgb; }
	// Old samples lose their bright inks, without fading the entire ribbon's alpha.
	if (freshness < 0.65) { ink *= vec3(0.70, 0.80, 0.88); }
	if (freshness < 0.30) { ink = mix(ink_3.rgb, ink, 0.45); }
	if (swinging && clock - UV.y < 0.008) { ink = ink_0.rgb; }
	COLOR = vec4(ink, 1.0);
}
