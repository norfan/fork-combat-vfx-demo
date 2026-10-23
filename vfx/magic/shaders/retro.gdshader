// The retro tier: the magic layer, rendered at pixel grain, shown with its light and smoke
// in flat steps (glows become stepped rings), like hand-placed pixel art. Only the strength
// of each pixel is stepped — its hue and its colour-to-cover ratio stay — so a faint orange
// glow steps down in orange instead of turning into stray hues.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform float levels = 6.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float strength = max(max(c.r, max(c.g, c.b)), c.a);
	// The faintest step would be a flat wash over a wide area: drop it.
	if (strength < 1.4 / levels) discard;
	float stepped = floor(strength * levels + 0.5) / levels;
	COLOR = c * (stepped / strength);
}
