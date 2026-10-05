shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform vec4 rage_tint : source_color = vec4(1.0, 0.25, 0.15, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float center_tint : hint_range(0.0, 1.0) = 0.08;
uniform float edge_tint : hint_range(0.0, 1.0) = 0.4;
uniform float edge_desaturate : hint_range(0.0, 1.0) = 0.35;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.5;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.25;
uniform float wobble_amount : hint_range(0.0, 0.3) = 0.06;
uniform float wobble_speed = 1.2;
uniform float pulse_speed = 2.2;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	vec2 centered = (SCREEN_UV - vec2(0.5)) * 2.0;
	float angle = atan(centered.y, centered.x);
	float t = TIME * wobble_speed;
	float wobble = sin(angle * 3.0 + t) * 0.6 + sin(angle * 5.0 - t * 1.7) * 0.4;
	float dist = length(centered) + wobble * wobble_amount;
	float edge = smoothstep(inner_radius, outer_radius, dist);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	float luma = dot(scene, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(scene, vec3(luma), edge * edge_desaturate);
	vec3 tinted = desat * mix(vec3(1.0), rage_tint.rgb * 1.6, 1.0);
	float amount = (center_tint + edge * (edge_tint - center_tint) * pulse) * intensity;
	vec3 result = mix(desat, tinted, clamp(amount, 0.0, 1.0));
	COLOR = vec4(result, 1.0);
}
