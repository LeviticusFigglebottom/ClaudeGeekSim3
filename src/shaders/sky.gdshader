// Sky dome: a gradient texture sampled by view elevation, plus a slowly
// drifting star/cloud layer. Drawn on the inside of a big sphere that follows
// the camera; never fogged, never lit.
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, depth_draw_never;

uniform sampler2D gradient_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D detail_tex : source_color, filter_nearest, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.0;
uniform float detail_scale = 6.0;
uniform float drift = 0.004;
uniform float band_speed = 0.0;
uniform float band_strength : hint_range(0.0, 0.5) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	float elev = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	// gradient texture is 256x128: top row = zenith. sample column by azimuth for subtle variation.
	float az = atan(dir.x, dir.z) / 6.2831853 + 0.5;
	vec3 col = texture(gradient_tex, vec2(az, 1.0 - elev)).rgb;
	if (detail_strength > 0.0) {
		vec2 duv = vec2(az * detail_scale + TIME * drift, (1.0 - elev) * detail_scale * 0.5);
		vec3 d = texture(detail_tex, duv).rgb;
		col = mix(col, max(col, d), detail_strength * smoothstep(0.35, 0.9, elev));
	}
	if (band_strength > 0.0) {
		col += band_strength * sin(elev * 60.0 + TIME * band_speed) * vec3(1.0, 0.8, 1.0);
	}
	ALBEDO = col * tint.rgb;
}
