shader_type canvas_item;

uniform float wave_speed = 0.3;
uniform vec2 wave_amount = vec2(0.012, 0.012);
uniform vec2 wave_frequency = vec2(2.7, 3.0);

void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * wave_frequency.x + TIME * wave_speed) * wave_amount.x;
	uv.y += cos(uv.x * wave_frequency.y + TIME * wave_speed * 0.85) * wave_amount.y;
	COLOR = texture(TEXTURE, uv);
}
