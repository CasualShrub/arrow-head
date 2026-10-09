shader_type canvas_item;
render_mode unshaded;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float edge = clamp(length((UV - vec2(0.51, 0.52)) * vec2(1.0, 1.05)) / 0.72, 0.0, 1.0);
	vec4 vignette = mix(vec4(0.137, 0.071, 0.071, 0.133), vec4(0.098, 0.051, 0.063, 0.902), edge);
	vignette.a *= reveal;
	COLOR = vignette;
}
