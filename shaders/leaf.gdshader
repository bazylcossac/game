shader_type spatial;
render_mode cull_disabled;
// Tree crowns. Cards are lit as if the crown were one soft ball, which hides that they are flat,
// and every leaf moves a little in the wind. COLOR is the tint of this copy of the tree.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float crown_y = 6.0;
uniform float sway = 0.09;

void vertex() {
	NORMAL = normalize(vec3(VERTEX.x, (VERTEX.y - crown_y) * 1.3 + 1.2, VERTEX.z));
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 1.1 + at.x * 0.13 + at.z * 0.09);
	float flutter = sin(TIME * 4.6 + at.x * 1.9 + at.y * 2.3 + at.z * 1.7);
	VERTEX += vec3(gust * 0.7 + flutter * 0.3, flutter * 0.35, gust * 0.5 - flutter * 0.2) * sway;
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	if (t.a < 0.45) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb;
	ROUGHNESS = 0.72;
	SPECULAR = 0.3;
	BACKLIGHT = vec3(0.35);
}
