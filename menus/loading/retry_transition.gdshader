shader_type canvas_item;
render_mode unshaded;

uniform sampler2D pattern : source_color, repeat_enable, filter_linear;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform float offset : hint_range(-1.0, 1.0) = -1.0;

void fragment() {
	float diagonal = dot(UV * viewport_size, vec2(1.0)) / (viewport_size.x + viewport_size.y);
	float shift = offset * 1.3;
	float mask = step(-0.15 + shift, diagonal) * step(diagonal, 1.15 + shift);
	float tile_width = viewport_size.y * (460.0 / 468.0);
	vec2 pattern_uv = UV * viewport_size / vec2(tile_width, tile_width * (1984.0 / 2319.0));
	COLOR = vec4(texture(pattern, pattern_uv).rgb, mask);
}
