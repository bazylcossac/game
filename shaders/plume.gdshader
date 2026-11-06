shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Thruster plume on an open cone: UV.y runs along it. The rim fades so the cone has no outline.

instance uniform vec3 plume_color = vec3(0.3, 0.6, 2.0);
instance uniform float thrust = 0.0;

void fragment() {
	float along = 1.0 - UV.y;
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float pulse = 0.86 + 0.14 * sin(TIME * 41.0 + along * 9.0);
	float body = pow(along, 1.5) * edge * pulse * thrust;
	ALBEDO = (plume_color * 1.6 + vec3(along * along * 1.4)) * body;
	ALPHA = clamp(body, 0.0, 1.0);
}
