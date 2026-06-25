shader_type spatial;

uniform sampler2D sprite_texture : source_color;
uniform float fade_height : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(sprite_texture, UV);

    if ((1.0 - UV.y) > fade_height) {
        discard;
    }

    ALBEDO = tex.rgb;
    ALPHA = tex.a;
}