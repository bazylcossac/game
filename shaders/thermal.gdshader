shader_type canvas_item;
// The rocket sight. The picture becomes cold grey, and anything painted with the marker colour by
// World.set_thermal comes out white hot, however bright the scene around it is.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength = 1.0;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float marked = smoothstep(0.32, 0.6, min(c.r, c.b) - c.g);
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	float cold = pow(clamp(lum, 0.0, 1.0), 0.8) * 0.5;
	vec3 base = mix(vec3(0.02, 0.04, 0.09), vec3(0.34, 0.42, 0.5), cold * 1.6);
	vec3 hot = mix(vec3(1.0, 0.55, 0.12), vec3(1.0, 0.98, 0.9), 0.75);
	vec3 col = mix(base, hot, marked);
	// Sensor grain and a slow roll of scan lines.
	col += (noise(SCREEN_UV * 900.0 + TIME) - 0.5) * 0.045;
	col *= 0.965 + 0.035 * sin(SCREEN_UV.y * 620.0 + TIME * 3.0);
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - dot(d, d) * 0.9;
	COLOR = vec4(mix(texture(screen, SCREEN_UV).rgb, col, strength), 1.0);
}
