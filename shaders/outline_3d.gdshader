shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;

uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0.0, 20.0) = 2.0;
uniform vec2 tex_pixel_size = vec2(0.005, 0.005);

const int SAMPLES = 64;
const int RINGS = 6;

void fragment() {
	vec4 color = texture(tex, UV);

	// -------------------------
	// Smooth the sprite itself
	// -------------------------

	float alpha = color.a;

	float aa = fwidth(alpha);

	// Make the alpha transition smoother.
	alpha = smoothstep(
		0.5 - aa,
		0.5 + aa,
		alpha
	);

	// -------------------------
	// Outline
	// -------------------------

	float outer = 0.0;

	for (int r = 1; r <= RINGS; r++) {
		float radius = float(r) / float(RINGS);

		for (int i = 0; i < SAMPLES; i++) {
			float angle =
				TAU * float(i) / float(SAMPLES);

			vec2 dir = vec2(
				cos(angle),
				sin(angle)
			);

			vec2 sample_uv =
				UV +
				dir *
				tex_pixel_size *
				line_thickness *
				radius;

			float a = 0.0;

			// Outside texture = transparent.
			if (sample_uv.x >= 0.0 &&
				sample_uv.x <= 1.0 &&
				sample_uv.y >= 0.0 &&
				sample_uv.y <= 1.0) {

				a = texture(tex, sample_uv).a;
			}

			outer = max(outer, a);
		}
	}

	// Outline only outside the sprite.
	float outline = outer * (1.0 - alpha);

	// Smooth outline.
	float outline_aa = fwidth(outline);

	outline = smoothstep(
		0.0 - outline_aa,
		1.0 + outline_aa,
		outline
	);

	// -------------------------
	// Final
	// -------------------------

	vec3 final_rgb = mix(
		color.rgb,
		line_color.rgb,
		outline
	);

	ALBEDO = final_rgb;

	ALPHA = max(
		alpha,
		outline * line_color.a
	);
}