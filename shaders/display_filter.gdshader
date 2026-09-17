shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float grayscale : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), grayscale);
	c = (c - 0.5) * contrast + 0.5;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
