shader_type spatial;
render_mode unshaded, fog_disabled;

void fragment() {
	ALBEDO = vec3(1.0, 0.0, 1.0);
	ALPHA = mix(0.5, 1.0, pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.4));
}
