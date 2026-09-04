// The faint breathing glow on anything you can use. A camera-facing quad with
// a soft body and a brighter rim, pulsing at a tempo that belongs to the
// object, brightened a little while you look straight at it. Additive, so it
// sits on the picture rather than in front of it; depth-tested, so walls hide it.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

global uniform float aura_opacity;
uniform vec4 color : source_color = vec4(0.95, 0.85, 0.6, 1.0);
uniform float strength = 1.0;
uniform float phase = 0.0;
uniform float speed = 1.0;
uniform float focus = 0.0;

void vertex() {
	mat4 m = MODEL_MATRIX;
	vec3 s = vec3(length(m[0].xyz), length(m[1].xyz), length(m[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * s.x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * s.y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * s.z, 0.0),
		m[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// a little nearer the eye than the thing it marks, so it never flickers
	// against a wall or a door face it lies on
	VERTEX.z += 0.05 / max(s.z, 0.001);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float body = smoothstep(1.0, 0.15, r);
	float rim = smoothstep(0.45, 0.78, r) * smoothstep(1.0, 0.84, r);
	float pulse = 0.62 + 0.38 * sin(TIME * speed + phase);
	float shimmer = 0.82 + 0.18 * sin(TIME * (4.0 + 3.0 * speed) + p.x * 11.0 + p.y * 7.0 + phase * 3.0);
	float a = (body * 0.16 + rim * 0.7) * pulse * shimmer * strength * (1.0 + focus * 1.6) * aura_opacity * 0.6;
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
