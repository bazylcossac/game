shader_type canvas_item;
// The title screen seen as one of Korpo's camera feeds: fine scan lines, a slow bright band
// rolling down, a dark vignette and a faint red cast at the edges. Drawn over everything, it
// only darkens and tints, so the menu stays readable.

uniform float lines = 360.0;
uniform float strength = 0.16;

void fragment() {
	vec2 uv = UV;
	float scan = 0.5 + 0.5 * sin(uv.y * lines * 3.14159);
	float roll = smoothstep(0.0, 0.08, fract(uv.y * 0.6 - TIME * 0.05)) * (1.0 - smoothstep(0.08, 0.2, fract(uv.y * 0.6 - TIME * 0.05)));
	vec2 c = uv - 0.5;
	float vignette = smoothstep(0.35, 0.95, length(c * vec2(1.1, 1.3)));
	float dark = strength * scan + vignette * 0.55 - roll * 0.05;
	COLOR = vec4(mix(vec3(0.0), vec3(0.35, 0.0, 0.0), vignette * 0.6), clamp(dark, 0.0, 0.85));
}
