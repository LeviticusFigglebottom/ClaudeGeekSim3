// A mirror that does not reflect you: a dim, slowly shifting version of a
// texture with a faint moving highlight. Used for mirrors and still pools.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(0.6, 0.7, 0.75, 1.0);
uniform float shimmer = 0.15;

void fragment() {
	vec2 uv = UV + vec2(sin(TIME * 0.3 + UV.y * 6.0) * 0.01, 0.0);
	vec3 col = texture(albedo_tex, uv).rgb * tint.rgb;
	float hl = smoothstep(0.02, 0.0, abs(fract(UV.x + UV.y * 0.5 - TIME * 0.05) - 0.5)) * shimmer;
	ALBEDO = col + vec3(hl);
}
