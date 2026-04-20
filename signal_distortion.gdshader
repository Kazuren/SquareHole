shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// Per-effect max strengths (applied at intensity = 1.0).
uniform float chromatic_max : hint_range(0.0, 0.05) = 0.01;
uniform float scanline_max : hint_range(0.0, 1.0) = 0.35;
uniform float noise_max : hint_range(0.0, 1.0) = 0.25;
uniform float roll_max : hint_range(0.0, 0.05) = 0.015;
uniform float pixelation_max : hint_range(0.0, 0.02) = 0.006;

uniform float scanline_frequency = 420.0;
uniform float roll_frequency = 22.0;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Horizontal roll warp
	float roll = sin(uv.y * roll_frequency + TIME * 4.0) * roll_max * intensity;
	uv.x += roll;

	// Pixelation — snap UV to a grid whose cell size grows with intensity
	float pix = pixelation_max * intensity;
	if (pix > 0.0001) {
		uv = floor(uv / pix) * pix + pix * 0.5;
	}

	// Chromatic aberration
	float ca = chromatic_max * intensity;
	vec3 col;
	col.r = texture(screen_tex, vec2(uv.x + ca, uv.y)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, vec2(uv.x - ca, uv.y)).b;

	// Scanlines
	float scan = sin(uv.y * scanline_frequency + TIME * 10.0) * 0.5 + 0.5;
	col *= 1.0 - scan * scanline_max * intensity;

	// Static noise overlay
	float n = hash(uv * 500.0 + TIME);
	col = mix(col, vec3(n), noise_max * intensity * 0.6);

	COLOR = vec4(col, 1.0);
}
