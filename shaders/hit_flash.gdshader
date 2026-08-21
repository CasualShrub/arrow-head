shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    ALBEDO = mix(ALBEDO, vec3(1.0), flash_amount);
}