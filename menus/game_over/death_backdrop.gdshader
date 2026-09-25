shader_type canvas_item;
render_mode unshaded;

uniform sampler2D dots : source_color, filter_linear;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float dots_progress : hint_range(0.0, 1.0) = 0.0;
uniform float dot_opacity : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);
	vec2 dots_uv = (UV - 0.5) * vec2(aspect / (2627.0 / 2115.0), 1.0) / 1.5 + 0.5;
	vec4 dot = texture(dots, dots_uv);
	float inside = step(0.0, dots_uv.x) * step(dots_uv.x, 1.0);
	float distance_px = length((UV - 0.5) * viewport_size);
	float feather = viewport_size.y * (90.0 / 468.0);
	float radius = dots_progress * (length(viewport_size * 0.5) + feather);
	float mask = 1.0 - smoothstep(max(0.0, radius - feather), max(1.0, radius), distance_px);
	float dot_alpha = dot.a * dot_opacity * mask * inside * clamp(dots_progress * 6.0, 0.0, 1.0);
	float edge = clamp(length((UV - vec2(0.51, 0.52)) * vec2(1.0, 1.05)) / 0.72, 0.0, 1.0);
	vec4 vignette = mix(vec4(0.137, 0.071, 0.071, 0.133), vec4(0.098, 0.051, 0.063, 0.902), edge);
	vignette.a *= reveal;
	float alpha = vignette.a + dot_alpha * (1.0 - vignette.a);
	vec3 color = (vignette.rgb * vignette.a + dot.rgb * dot_alpha * (1.0 - vignette.a)) / max(alpha, 0.0001);
	COLOR = vec4(color, alpha);
}
