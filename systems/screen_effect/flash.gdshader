shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 0.55, 0.3, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float edge_boost : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 centered = (SCREEN_UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.2, 1.3, length(centered));
	float amount = intensity * (0.55 + edge * edge_boost);
	COLOR = vec4(flash_color.rgb, clamp(amount, 0.0, 1.0));
}
