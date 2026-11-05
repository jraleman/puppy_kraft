shader_type spatial;
render_mode unshaded;

uniform sampler2D tile_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Each opaque quad stores two exact 0-15 light levels in vertex alpha.
	float code = floor(COLOR.a * 255.0 + 0.5);
	float sky = floor(code / 16.0) / 15.0;
	float local_light = mod(code, 16.0) / 15.0;
	float strength = 0.2 + 0.8 * max(sky * daylight, local_light);
	vec3 tint = mix(vec3(0.64, 0.74, 1.0), vec3(1.0), daylight);
	ALBEDO = texture(tile_texture, UV).rgb * COLOR.rgb * tint * strength;
}
