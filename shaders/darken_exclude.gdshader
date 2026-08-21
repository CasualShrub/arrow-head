shader_type canvas_item;

uniform sampler2D mask_tex;
uniform vec4 darken_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float darken_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    float excluded = texture(mask_tex, SCREEN_UV).a;
    COLOR = vec4(darken_color.rgb, darken_amount * (1.0 - excluded));
}