// Screen-space finish: ordered dithering + colour quantisation, soft vignette,
// faint scanlines. Reads the composited backbuffer (the low-res 3D upscale).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.55;
uniform float levels : hint_range(4.0, 64.0) = 32.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.3;
uniform float scanline : hint_range(0.0, 0.5) = 0.07;
uniform float pixel_size : hint_range(1.0, 6.0) = 3.0;
uniform vec3 tint : source_color = vec3(1.0, 0.98, 0.94);

const float bayer[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	vec2 pc = floor(FRAGCOORD.xy / pixel_size);
	int bx = int(mod(pc.x, 4.0));
	int by = int(mod(pc.y, 4.0));
	float b = (bayer[by * 4 + bx] / 16.0 - 0.5) * dither_strength / levels;
	col = floor((col + b) * levels + 0.5) / levels;
	vec2 d = uv - vec2(0.5);
	float v = 1.0 - dot(d, d) * vignette * 2.2;
	col *= clamp(v, 0.0, 1.0);
	float s = 1.0 - scanline * step(0.5, fract(pc.y * 0.5));
	col *= s * tint;
	COLOR = vec4(col, 1.0);
}
