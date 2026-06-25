shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0, 10) = 2.0;
uniform vec2 tex_pixel_size = vec2(0.005, 0.005);   // 1.0 / texture size

const vec2 OFFSETS[8] = {
	vec2(-1, -1), vec2(-1, 0), vec2(-1, 1), vec2(0, -1), vec2(0, 1),
	vec2(1, -1), vec2(1, 0), vec2(1, 1)
};

void fragment() {
	vec2 size = tex_pixel_size * line_thickness;
	float outline = 0.0;
	for (int i = 0; i < OFFSETS.length(); i++) {
		outline += texture(tex, UV + size * OFFSETS[i]).a;
	}
	outline = min(outline, 1.0);

	vec4 color = texture(tex, UV);
	vec4 result = mix(color, line_color, outline - color.a);
	ALBEDO = result.rgb;
	ALPHA = result.a;
}
