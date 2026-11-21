shader_type canvas_item;

// Blurs and darkens everything drawn behind this node (the game, under the
// pause menu). `amount` goes from 0 (no effect) to 1 (full effect), so it can
// be animated when the menu opens.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
// Distance between samples, in screen pixels.
uniform float radius : hint_range(0.0, 16.0) = 5.0;
// Mipmap level read: higher is softer.
uniform float lod : hint_range(0.0, 5.0) = 2.5;
uniform vec4 tint : source_color = vec4(0.03, 0.03, 0.04, 0.45);

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * radius * amount;
	float level = lod * amount;
	vec3 color = vec3(0.0);
	float total = 0.0;
	// 5x5 Gaussian-weighted samples.
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float weight = exp(-float(x * x + y * y) / 4.0);
			color += textureLod(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_size, level).rgb * weight;
			total += weight;
		}
	}
	color /= total;
	COLOR = vec4(mix(color, tint.rgb, tint.a * amount), 1.0);
}
