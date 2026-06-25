// Like fade.gdshader (fades ALBEDO to black toward the top) but samples a tiled
// texture via world-space triplanar mapping, so walls get a real texture (e.g.
// bricks) that fades out at the top edge.
shader_type spatial;

uniform sampler2D tex : source_color;
uniform float tex_scale = 0.5;       // matches a StandardMaterial uv1_scale
uniform float wall_height = 4.0;
uniform float fade_start = 0.5;      // fraction of height where the fade begins

varying vec3 w_pos;
varying vec3 w_norm;
varying float height_factor;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_norm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	height_factor = clamp(VERTEX.y / wall_height, 0.0, 1.0);
}

void fragment() {
	vec3 bw = abs(w_norm);
	bw /= (bw.x + bw.y + bw.z);
	vec3 cx = texture(tex, w_pos.zy * tex_scale).rgb;
	vec3 cy = texture(tex, w_pos.xz * tex_scale).rgb;
	vec3 cz = texture(tex, w_pos.xy * tex_scale).rgb;
	vec3 col = cx * bw.x + cy * bw.y + cz * bw.z;

	float fade = smoothstep(fade_start, 1.0, height_factor);
	ALBEDO = col * (1.0 - fade);
}
