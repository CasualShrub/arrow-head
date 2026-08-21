shader_type spatial;

render_mode unshaded, blend_mix, cull_back;

uniform float concavity : hint_range(0.0, 0.5) = 0.25;
uniform vec4 fill_color : source_color =
    vec4(0.9, 0.35, 0.15, 0.50);
uniform vec4 line_color : source_color =
    vec4(0.95, 0.45, 0.25, 0.7);
uniform float line_width = 0.02;

void fragment() {
    vec2 p = UV;

    float x = abs(p.x - 0.5) * 2.0;

    // Curved rear edge
    float rear_curve = concavity * (1.0 - pow(x, 2.0));

    // Shape exists above rear curve
    if (p.y < rear_curve) {
        discard;
    }

    // Triangle sides
    float width = (1.0 - p.y) / (1.0 - rear_curve);

    if (x > width) {
        discard;
    }
	
	vec4 color = fill_color;
    float edge_dist = width - x;

	float rear_dist = p.y - rear_curve;

    if (
		(edge_dist >= 0.0 && edge_dist < line_width) ||
		(rear_dist >= 0.0 && rear_dist < line_width)
	) {
        color = line_color;
    }

    ALBEDO = color.rgb;
    ALPHA = color.a;
}