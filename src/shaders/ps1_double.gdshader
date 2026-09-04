// PS1-flavoured lit surface: vertex snapping, affine texture warp, nearest
// sampling, optional alpha scissor, tint, emission and vertex colour.
// The engine still applies fog and lights (no custom light() function).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.0;
uniform float snap : hint_range(0.0, 512.0) = 200.0;
uniform float affine : hint_range(0.0, 1.0) = 0.35;
uniform float depth_bias : hint_range(0.0, 0.05) = 0.0;
uniform bool use_vertex_color = false;
uniform float specular_amt : hint_range(0.0, 1.0) = 0.05;
uniform float scroll_x = 0.0;
uniform float scroll_y = 0.0;

varying vec2 uv_affine;
varying float w_var;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (depth_bias > 0.0) {
		// a decal on a surface: drawn a little nearer the eye along its own
		// sight line, so it never flickers against what it lies on
		view.xyz *= (1.0 - depth_bias);
	}
	vec4 clip = PROJECTION_MATRIX * view;
	if (snap > 0.0 && clip.w > 0.0) {
		vec2 grid = vec2(snap, snap * 0.5625);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
	uv_affine = UV * clip.w;
	w_var = clip.w;
}

void fragment() {
	vec2 uv_a = uv_affine / max(w_var, 0.0001);
	vec2 uv = mix(UV, uv_a, affine) * uv_scale + uv_offset + vec2(scroll_x, scroll_y) * TIME;
	vec4 tex = texture(albedo_tex, uv) * tint;
	if (use_vertex_color) {
		tex *= COLOR;
	}
	if (alpha_scissor > 0.0 && tex.a < alpha_scissor) {
		discard;
	}
	ALBEDO = tex.rgb;
	EMISSION = emission.rgb * emission_energy;
	SPECULAR = specular_amt;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
