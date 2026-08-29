shader_type spatial;

render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 color : source_color = vec4(0.1, 0.6, 1.0, 1.0);

//
// The actual gameplay dimensions.
//
uniform float outer_radius = 10.0;
uniform float thickness = 1.0;

//
// Edge rendering.
//
uniform float edge_softness : hint_range(0.0, 1.0) = 0.01;

//
// Boiling.
//
uniform float boil_amount : hint_range(0.0, 2.0) = 0.15;
uniform float boil_speed : hint_range(0.0, 5.0) = 0.7;
uniform float boil_frequency : hint_range(1.0, 30.0) = 6.0;

uniform float opacity : hint_range(0.0, 1.0) = 0.5;


// ------------------------------------------------------------
// Hash / value noise
// ------------------------------------------------------------

float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);

    return fract(p.x * p.y);
}


float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    // Smooth interpolation.
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(
        mix(a, b, f.x),
        mix(c, d, f.x),
        f.y
    );
}


// ------------------------------------------------------------
// Fragment
// ------------------------------------------------------------

void fragment()
{
    // UV centered at the middle of the quad.
    vec2 p = UV - vec2(0.5);

    //
    // IMPORTANT:
    //
    // The quad is intentionally larger than the visible circle.
    //
    // We assume the quad has been sized for:
    //
    //     outer_radius + boil_amount + edge_softness
    //
    // So the edge of the quad corresponds to "max_radius".
    //
    float max_radius =
        outer_radius +
        boil_amount +
        edge_softness * outer_radius;

    //
    // Convert UV distance into world-space radius.
    //
    float radius = length(p) * 2.0 * max_radius;


    // --------------------------------------------------------
    // Continuous angular coordinates
    // --------------------------------------------------------

    //
    // DO NOT use:
    //
    //     noise(vec2(angle, TIME))
    //
    // because atan() has a discontinuity at ±PI.
    //
    // Instead, map the angle onto the unit circle.
    //
    vec2 direction = normalize(p);

    //
    // At the exact center normalize() is undefined, although
    // it doesn't matter for the range ring. Give it a value
    // anyway.
    //
    if (length(p) < 0.0001)
    {
        direction = vec2(1.0, 0.0);
    }


    // --------------------------------------------------------
    // Boiling
    // --------------------------------------------------------

    //
    // Sampling around the unit circle means the beginning and
    // end of the circumference meet perfectly.
    //
    vec2 noise_pos =
        direction * boil_frequency;

    //
    // Move through noise continuously.
    //
    // Two moving samples in different directions gives a much
    // more organic motion.
    //
    float n1 = noise(
        noise_pos +
        vec2(
            TIME * boil_speed,
            TIME * boil_speed * 0.73
        )
    );

    float n2 = noise(
        noise_pos * 2.17 +
        vec2(
            -TIME * boil_speed * 0.61,
            TIME * boil_speed * 0.91
        )
    );

    float boil =
        (
            n1 * 0.65 +
            n2 * 0.35
        ) - 0.5;


    // --------------------------------------------------------
    // Animated radius
    // --------------------------------------------------------

    float animated_outer =
        outer_radius +
        boil * boil_amount;

    //
    // Keep thickness constant.
    //
    float animated_inner =
        animated_outer - thickness;


    // --------------------------------------------------------
    // Edge
    // --------------------------------------------------------

    //
    // edge_softness is expressed as a fraction of outer radius.
    //
    float softness =
        edge_softness * outer_radius;


    float outer_alpha =
        1.0 - smoothstep(
            animated_outer - softness,
            animated_outer + softness,
            radius
        );


    float inner_alpha =
        smoothstep(
            animated_inner - softness,
            animated_inner + softness,
            radius
        );


    float alpha =
        outer_alpha *
        inner_alpha;


    ALBEDO = color.rgb;
    ALPHA = color.a * opacity * alpha;
}
