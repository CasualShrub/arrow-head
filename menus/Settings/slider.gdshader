shader_type canvas_item;

// all ai code, feel free to change
void vertex() {
	// Called for every vertex the material is visible on.
}

// Controls for the background gradient
uniform vec4 color_left : source_color = vec4(1.0, 0.773, 0.322, 1.0);
uniform vec4 color_right : source_color = vec4(1.0, 0.667, 0.0, 1.0);

// FIX: Controls the shape stretching. 
// Set this to (Width / Height) of your TextureRect.
//yeah based on the textureRect size is prob cap by ai, not sure why but ratio=2 works
uniform float aspect_ratio = 2; 
uniform float fill_amount : hint_range(0.0, 1.0) = 1;

// Controls for the bubbles
uniform int bubble_count = 15;
uniform float min_bubble_size = 0.02;
uniform float max_bubble_size = 0.08;
uniform float bubble_speed = 0.5;

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

void fragment() {
    // 1. Correct the UV coordinates for aspect ratio
    // This makes the math treat the space as perfectly square
    vec2 corrected_uv = UV;
    corrected_uv.x *= aspect_ratio;

    // 2. Get the shape mask from your custom image texture
    vec4 mask_color = texture(TEXTURE, UV);
    float mask = mask_color.a;
	
	if (UV.x > fill_amount) {
        mask = 0.0; 
    }

    // 3. Create the base background gradient (Left to Right)
    vec4 base_gradient = mix(color_left, color_right, UV.x);
    vec3 final_color = base_gradient.rgb;

    // 4. Generate moving bubbles
    for (int i = 0; i < bubble_count; i++) {
        float index = float(i);
        
        float size = mix(min_bubble_size, max_bubble_size, hash(index + 123.45));
        float speed_mod = mix(0.5, 1.5, hash(index + 543.21));
        float start_y = hash(index + 987.65);
        
        // Adjust the X movement bounds based on the aspect ratio
        float x_range = aspect_ratio + (size * 2.0);
        float x_pos = fract(TIME * bubble_speed * speed_mod + hash(index)) * x_range - size;
        
        float y_pos = start_y + sin(TIME * 2.0 + index) * 0.03;
        
        // Use corrected_uv for the distance calculation to ensure a perfect circle
        vec2 bubble_center = vec2(x_pos, y_pos);
        float dist = distance(corrected_uv, bubble_center);
        
        if (dist < size) {
            float edge = smoothstep(size, size - 0.01, dist);
            float inner_glow = pow(dist / size, 3.0) * 0.4;
            final_color = mix(final_color, vec3(1.0), edge * (inner_glow + 0.2));
        }
    }

    COLOR = vec4(final_color, mask * base_gradient.a);
}
