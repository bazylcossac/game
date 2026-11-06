shader_type sky;
// Low storm cloud, drifting, lit from inside when lightning goes off.

uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;
uniform float flash = 0.0;

float clouds(vec2 p) {
	float a = texture(macro_tex, p).r;
	float b = texture(macro_tex, p * 2.3 + 0.4).a;
	float c = texture(macro_tex, p * 5.1 + 0.7).g;
	return a * 0.55 + b * 0.3 + c * 0.15;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = max(d.y, 0.0);
	vec2 p = d.xz / (up + 0.18) * 0.1 + vec2(TIME * 0.0035, TIME * 0.002);
	float c = clouds(p);
	float dense = smoothstep(0.3, 0.72, c);
	vec3 low = vec3(0.12, 0.13, 0.15);
	vec3 high = vec3(0.028, 0.032, 0.042);
	vec3 col = mix(low, high, dense);
	// A sick glow low on the horizon, from fires and from the guns.
	float horizon = exp(-up * 9.0);
	col += vec3(0.11, 0.075, 0.05) * horizon;
	col += vec3(0.8, 0.85, 1.0) * flash * (0.45 + (1.0 - dense) * 0.9);
	COLOR = col;
	if (d.y < 0.0) {
		COLOR = mix(col, vec3(0.03, 0.03, 0.035), clamp(-d.y * 6.0, 0.0, 1.0));
	}
}
