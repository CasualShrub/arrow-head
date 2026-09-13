shader_type spatial;

render_mode unshaded, cull_back, depth_test_disabled, blend_mix;

uniform vec4 color : source_color = vec4(0.1, 0.6, 1.0, 1.0);

uniform float outer_radius = 10.0;
uniform float thickness = 1.0;

uniform float edge_softness : hint_range(0.0, 1.0) = 0.01;

uniform float boil_amount : hint_range(0.0, 2.0) = 0.15;
uniform float boil_speed : hint_range(0.0, 5.0) = 0.7;
uniform float boil_frequency : hint_range(1.0, 30.0) = 6.0;

uniform float opacity : hint_range(0.0, 1.0) = 0.5;


// ------------------------------------------------------------
// Hash
// ------------------------------------------------------------

float hash(vec2 p)
{
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);

	return fract(p.x * p.y);
}


// ------------------------------------------------------------
// Continuous value noise
// ------------------------------------------------------------

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
	vec2 p = UV - vec2(0.5);

	float max_radius =
		outer_radius +
		boil_amount +
		edge_softness * outer_radius;

	float radius = length(p) * 2.0 * max_radius;


	// --------------------------------------------------------
	// Direction around the circle
	// --------------------------------------------------------

	float p_length = length(p);

	vec2 direction;

	if (p_length < 0.0001)
	{
		direction = vec2(1.0, 0.0);
	}
	else
	{
		direction = p / p_length;
	}


	// --------------------------------------------------------
	// IMPORTANT:
	//
	// Instead of using:
	//
	//     direction * frequency
	//
	// we map the angle onto a unit circle.
	//
	// This makes the noise spatially continuous at the
	// -PI / +PI boundary.
	// --------------------------------------------------------

	float t = mod(TIME, 1000.0);

	vec2 circle_pos = direction;


	// --------------------------------------------------------
	// First noise layer
	// --------------------------------------------------------

	vec2 noise_pos_1 =
		circle_pos * boil_frequency;

	noise_pos_1 += vec2(
		t * boil_speed,
		t * boil_speed * 0.73
	);

	float n1 = noise(noise_pos_1);


	// --------------------------------------------------------
	// Second noise layer
	// --------------------------------------------------------

	vec2 noise_pos_2 =
		circle_pos * boil_frequency * 2.17;

	noise_pos_2 += vec2(
		-t * boil_speed * 0.61,
		t * boil_speed * 0.91
	);

	float n2 = noise(noise_pos_2);


	// --------------------------------------------------------
	// Combine noise
	// --------------------------------------------------------

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

	float animated_inner =
		animated_outer - thickness;


	// --------------------------------------------------------
	// Edge softness
	// --------------------------------------------------------

	float softness =
		edge_softness * outer_radius;


	// --------------------------------------------------------
	// Outer edge
	// --------------------------------------------------------

	float outer_alpha =
		1.0 - smoothstep(
			animated_outer - softness,
			animated_outer + softness,
			radius
		);


	// --------------------------------------------------------
	// Inner edge
	// --------------------------------------------------------

	float inner_alpha =
		smoothstep(
			animated_inner - softness,
			animated_inner + softness,
			radius
		);


	// --------------------------------------------------------
	// Final ring alpha
	// --------------------------------------------------------

	float alpha =
		outer_alpha *
		inner_alpha;


	ALBEDO = color.rgb;
	ALPHA = color.a * opacity * alpha;
}
