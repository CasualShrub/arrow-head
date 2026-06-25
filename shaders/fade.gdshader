shader_type spatial;

uniform float wall_height = 4.0;
uniform float fade_start = 0.5; // fraction of height

varying float height_factor;

void vertex() {
    height_factor = clamp(VERTEX.y / wall_height, 0.0, 1.0);
}

void fragment() {
    float fade = smoothstep(fade_start, 1.0, height_factor);

    ALBEDO *= (1.0 - fade);
}