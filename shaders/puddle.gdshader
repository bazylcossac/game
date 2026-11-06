shader_type spatial;
render_mode cull_back;
// Muddy water in a shell hole, pocked by rain. Round, with a ragged edge that sinks into the mud.

uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ring(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float start = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float age = fract(t + start);
	float r = length(f);
	return sin((r - age * 0.5) * 60.0) * smoothstep(0.1, 0.0, abs(r - age * 0.5)) * (1.0 - age);
}

void fragment() {
	float edge = length(UV - 0.5) * 2.0;
	float ragged = texture(macro_tex, world_pos.xz / 9.0).g * 0.45;
	if (edge > 0.98 - ragged) {
		discard;
	}
	vec2 p = world_pos.xz * 1.6;
	float a = ring(p, TIME * 1.3);
	float b = ring(p * 1.7 + 3.1, TIME * 1.7 + 0.4);
	vec3 n = normalize(vec3((a + b) * 0.12, 1.0, (a - b) * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = vec3(0.045, 0.04, 0.03);
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
