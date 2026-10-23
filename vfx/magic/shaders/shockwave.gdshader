// A blast's shockwave: a ring that bends what is behind it outwards and glows faintly.
// `radius` runs 0 → 1 (the quad's edge).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float radius = 0.0;
uniform float width = 0.08;
uniform float strength = 0.03;
uniform float glow = 0.35;
uniform vec3 tint = vec3(1.0, 0.75, 0.45);

void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r = length(d);
	float ring = smoothstep(width, 0.0, abs(r - radius)) * (1.0 - radius);
	vec2 push = normalize(d + vec2(0.00001)) * ring * strength;
	vec3 seen = texture(screen_texture, SCREEN_UV - push).rgb;
	COLOR = vec4(seen + tint * ring * glow, step(0.001, ring));
}
