shader_type spatial;

render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 cone_color : source_color = vec4(1.0, 0.8, 0.1, 0.35);

uniform float angle = 0.45;
uniform float edge_softness = 0.05;
uniform float distance_fade = 0.8;

void fragment()
{
    vec2 uv = UV;

    // Center cone around bottom middle
    vec2 pos = uv - vec2(0.5, 0.0);

    // Distance forward
    float depth = uv.y;

    // Width expands toward the end
    float width = depth * angle;

    float cone = smoothstep(
        width,
        width - edge_softness,
        abs(pos.x)
    );

    // Fade as it gets farther away
    float fade = 1.0 - smoothstep(
        distance_fade,
        1.0,
        depth
    );

    float alpha = cone * fade;

    ALBEDO = cone_color.rgb;
    ALPHA = alpha * cone_color.a;
}