// Shared by the magic shaders: value noise, fractal noise and the fire colour ramp.

float m_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float m_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(m_hash(i), m_hash(i + vec2(1.0, 0.0)), u.x),
		mix(m_hash(i + vec2(0.0, 1.0)), m_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float m_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * m_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Heat 0 (nothing) … 1 (white-hot) as fire colour: deep red, red, orange, yellow, white.
vec3 m_fire(float h) {
	vec3 c = mix(vec3(0.35, 0.03, 0.01), vec3(0.95, 0.2, 0.04), smoothstep(0.0, 0.35, h));
	c = mix(c, vec3(1.0, 0.52, 0.09), smoothstep(0.3, 0.6, h));
	c = mix(c, vec3(1.0, 0.85, 0.38), smoothstep(0.55, 0.82, h));
	return mix(c, vec3(1.0, 1.0, 0.94), smoothstep(0.8, 1.0, h));
}
