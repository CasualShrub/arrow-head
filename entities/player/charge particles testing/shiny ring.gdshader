shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform float thickness_cutoff : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(1.0, 10.0) = 4.0;
uniform vec4 ring_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);

void fragment() {
    // Torus UV.y goes seamlessly around the tube of the ring.
    // This centers the glow right in the middle of the tube.
    float tube_glow = smoothstep(0.0, 0.5, 0.5 - abs(UV.y - 0.5));
    
    // Custom modifier to dynamically shrink the tube thickness if needed
    float mask = smoothstep(1.0 - thickness_cutoff, 1.0, tube_glow);

    ALBEDO = ring_color.rgb;
    EMISSION = ring_color.rgb * mask * brightness;
    ALPHA = mask * ring_color.a;
}
