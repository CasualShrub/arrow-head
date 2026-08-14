shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_steps : hint_range(4.0, 32.0) = 16.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.25;
uniform float pixel_size : hint_range(1.0, 16.0) = 2.0;

const float bayer[16] = float[](
    0.0, 8.0, 2.0, 10.0,
    12.0,4.0,14.0,6.0,
    3.0,11.0,1.0,9.0,
    15.0,7.0,13.0,5.0
);

float dither(vec2 p) {
    ivec2 ip = ivec2(mod(p, 4.0));
    return bayer[ip.x + ip.y * 4] / 16.0 - 0.5;
}

vec3 quant(vec3 c, float steps) {
    return floor(c * steps + 0.5) / steps;
}

void fragment() {
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 block = floor(SCREEN_UV * resolution / pixel_size);
    vec2 pixelToGrab = (block * pixel_size + pixel_size * 0.2) * SCREEN_PIXEL_SIZE;

    vec3 col = texture(screen_tex, pixelToGrab).rgb;

    col += dither(block) *
           (1.0 / color_steps) *
           dither_strength;

    col = quant(col, color_steps);

    COLOR = vec4(col, 1.0);
}
