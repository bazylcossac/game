shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
// Laser bolt on a unit quad that turns around its own axis to face the camera. A solid
// shape would vanish when seen end-on, and end-on is exactly how the shooter sees a shot.
// The model's Y axis is the beam (its length included); X scale is the radius.

instance uniform vec3 beam_color = vec3(0.3, 0.6, 2.0);
instance uniform float fade = 1.0;

void vertex() {
	vec3 axis = MODEL_MATRIX[1].xyz;
	float width = length(MODEL_MATRIX[0].xyz) * 2.2;
	vec3 along = MODEL_MATRIX[3].xyz + axis * VERTEX.y;
	vec3 to_camera = normalize(INV_VIEW_MATRIX[3].xyz - along);
	vec3 side = normalize(cross(normalize(axis), to_camera));
	vec3 world = along + side * VERTEX.x * width;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;
	float halo = pow(1.0 - d, 1.4);
	float core = pow(1.0 - d, 5.0);
	float ends = smoothstep(0.0, 0.12, UV.y) * smoothstep(0.0, 0.12, 1.0 - UV.y);
	ALBEDO = (beam_color * halo * 1.1 + vec3(core) * 1.8) * fade * ends;
	ALPHA = clamp(halo * fade, 0.0, 1.0);
}
