shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Holographic wall that marks a control point. On a CylinderMesh UV.y is 1 at the ground.

uniform vec3 ring_color : source_color = vec3(0.7);
uniform float strength = 1.0;
uniform float falloff = 3.0;

void fragment() {
	float fade = pow(UV.y, falloff);
	float bands = 0.72 + 0.28 * sin(UV.y * 40.0 - TIME * 2.6);
	float seg = smoothstep(0.08, 0.14, abs(fract(UV.x * 48.0) - 0.5));
	ALBEDO = ring_color * fade * bands * seg * 0.3 * strength;
	ALPHA = fade * 0.3;
}
