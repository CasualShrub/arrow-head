shader_type canvas_item;

uniform sampler2D pattern : repeat_enable, filter_linear;
uniform vec2 pan_speed = vec2(0.03, 0.02);
uniform vec2 tiling = vec2(3.0, 2.0);

void fragment() {
	vec2 uv = UV * tiling + pan_speed * TIME;
	COLOR = texture(pattern, uv);
}
