shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform sampler2D albedo_texture : source_color;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float opacity: hint_range(0.0, 1.0) = 0.1;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);

    // Original brightness
    float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

    // Desired color, retaining the sprite's brightness
    vec3 colored = tint.rgb * luminance;

    // Blend original and colored versions
    vec3 final_color = mix(tex.rgb, colored, strength);

    ALBEDO = final_color;
    ALPHA = tex.a * opacity;
}