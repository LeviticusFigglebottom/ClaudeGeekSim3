// Slow dream water: two scrolling copies of a caustic texture, gentle vertex
// swell, translucent. Uses vertex snapping like the rest of the world.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx, blend_mix, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float uv_scale = 0.25;
uniform float speed = 0.02;
uniform float swell = 0.06;
uniform float swell_freq = 0.6;
uniform float snap = 200.0;
uniform float glow = 0.0;

void vertex() {
	VERTEX.y += sin(VERTEX.x * swell_freq + TIME * 0.8) * swell + cos(VERTEX.z * swell_freq * 0.7 + TIME * 0.6) * swell;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap > 0.0 && clip.w > 0.0) {
		vec2 grid = vec2(snap, snap * 0.5625);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec2 uv1 = UV * uv_scale + vec2(TIME * speed, TIME * speed * 0.6);
	vec2 uv2 = UV * uv_scale * 1.7 - vec2(TIME * speed * 0.8, -TIME * speed * 0.4);
	vec3 a = texture(albedo_tex, uv1).rgb;
	vec3 b = texture(albedo_tex, uv2).rgb;
	vec3 col = max(a, b) * tint.rgb;
	ALBEDO = col;
	ALPHA = tint.a;
	EMISSION = col * glow;
	ROUGHNESS = 0.2;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
