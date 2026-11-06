shader_type spatial;
render_mode cull_disabled;
// Waving flag on a subdivided plane. UV.x = 0 at the pole.

uniform sampler2D flag_tex : source_color, filter_linear_mipmap;
uniform float wave = 0.32;

void vertex() {
	float x = UV.x;
	float t = TIME * 3.4;
	float w = sin(x * 8.0 - t) * 0.6 + sin(x * 15.0 - t * 1.6 + UV.y * 3.0) * 0.3;
	VERTEX.z += w * wave * x;
	VERTEX.y -= x * x * 0.22;
	NORMAL = normalize(vec3(-cos(x * 8.0 - t) * wave * x * 2.4, 0.0, 1.0));
}

void fragment() {
	ALBEDO = texture(flag_tex, UV).rgb;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.35);
}
