// Television static / the Static realm: animated hash noise with rolling bars.
shader_type spatial;
render_mode unshaded, cull_back;

uniform float scale = 120.0;
uniform float speed = 24.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float bar_strength : hint_range(0.0, 1.0) = 0.25;
uniform float brightness = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = floor(UV * scale) / scale;
	float t = floor(TIME * speed);
	float n = hash(uv + vec2(t * 0.013, t * 0.071));
	n = n * 0.75 + hash(uv * 3.1 + t) * 0.25;
	float bar = 1.0 - bar_strength * smoothstep(0.0, 0.15, abs(fract(UV.y - TIME * 0.15) - 0.5));
	ALBEDO = vec3(n) * tint.rgb * bar * brightness;
}
