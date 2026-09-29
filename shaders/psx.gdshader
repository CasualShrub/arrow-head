shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D mask_tex : filter_nearest;
uniform float target_height : hint_range(120.0, 1080.0) = 360.0;
uniform float color_depth : hint_range(4.0, 256.0) = 32.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

//actual PS1 graphics card chip info
const float psx_dither[16] = float[](
	-4.0, 0.0, -3.0, 1.0,
	2.0, -2.0, 3.0, -1.0,
	-3.0, 1.0, -4.0, 0.0,
	3.0, -1.0, 2.0, -2.0
);

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float block = max(screen_size.y / target_height, 1.0);
	vec2 low_res = screen_size / block;
	vec2 cell = floor(SCREEN_UV * low_res);
	vec3 c = texture(screen_tex, (cell + 0.5) / low_res).rgb;

	float levels = color_depth - 1.0;
	ivec2 d = ivec2(mod(cell, 4.0));
	c += psx_dither[d.x + d.y * 4] / 8.0 / levels * dither_strength;
	c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;

	vec3 sharp = texture(screen_tex, SCREEN_UV).rgb;
	float mask = texture(mask_tex, SCREEN_UV).a;
	COLOR = vec4(mix(c, sharp, mask), 1.0);
}
