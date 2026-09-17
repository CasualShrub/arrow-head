shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform float aspect_ratio = 5.256;
uniform vec4 color_left : source_color = vec4(1.0, 0.773, 0.322, 1.0);
uniform vec4 color_right : source_color = vec4(1.0, 0.667, 0.0, 1.0);
uniform int bubble_count = 15;
uniform float min_bubble_size = 0.02;
uniform float max_bubble_size = 0.08;
uniform float bubble_speed = 0.5;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec4 bar = texture(TEXTURE, UV);
	if (UV.x > fill_amount) {
		COLOR = bar;
	} else {
		vec2 corrected_uv = vec2(UV.x * aspect_ratio, UV.y);
		vec4 base = mix(color_left, color_right, UV.x);
		vec3 final_color = base.rgb;
		for (int i = 0; i < bubble_count; i++) {
			float index = float(i) + seed;
			float size = mix(min_bubble_size, max_bubble_size, hash(index + 123.45));
			float speed_mod = mix(0.5, 1.5, hash(index + 543.21));
			float start_y = hash(index + 987.65);
			float x_range = aspect_ratio + size * 2.0;
			float x_pos = fract(TIME * bubble_speed * speed_mod + hash(index)) * x_range - size;
			float y_pos = start_y + sin(TIME * 2.0 + index) * 0.03;
			float dist = distance(corrected_uv, vec2(x_pos, y_pos));
			if (dist < size) {
				float edge = smoothstep(size, size - 0.01, dist);
				float inner_glow = pow(dist / size, 3.0) * 0.4;
				final_color = mix(final_color, vec3(1.0), edge * (inner_glow + 0.2));
			}
		}
		COLOR = vec4(final_color, bar.a * base.a);
	}
}
