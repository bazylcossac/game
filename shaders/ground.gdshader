shader_type spatial;
// Terrain splat. Vertex colour: R = cobblestone, G = grass, B = scorch.
// "dirt" may be mud, whose alpha says where water stands. Rain soaks it all, see world.gdshader.

uniform sampler2D dirt_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;
uniform float dirt_tile = 6.0;
uniform float wet = 0.0;
uniform float water_in_dirt = 0.0;
// How black burnt ground gets, and how much of the low ground holds a film of water.
uniform float scorch_dark = 0.12;
uniform float puddles = 1.0;
uniform float gain = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv_dirt = p / dirt_tile;
	vec2 uv_cobble = p / 3.0;
	vec2 uv_grass = p / 5.5;

	vec4 big = texture(macro_tex, p / 83.0);
	vec4 mid = texture(macro_tex, p / 17.0);

	vec4 dirt4 = texture(dirt_a, uv_dirt);
	vec3 dirt = dirt4.rgb;
	vec3 cobble = texture(cobble_a, uv_cobble).rgb;
	vec3 grass = texture(grass_a, uv_grass).rgb;
	// Far away the same texture at a much larger scale hides the repeat of the tile.
	float far = smoothstep(16.0, 95.0, length(world_pos - CAMERA_POSITION_WORLD));
	grass = mix(grass, texture(grass_a, p / 37.0).rgb * 0.5 + texture(grass_a, p / 11.0).rgb * 0.5, far * 0.85);
	dirt = mix(dirt, texture(dirt_a, p / (dirt_tile * 5.3)).rgb, far * 0.7);

	// Sharpen blends using the cobble height so mud settles between stones.
	float cob_h = texture(cobble_n, uv_cobble).b;
	float wc = smoothstep(0.35, 0.65, COLOR.r + (cob_h - 0.75) * 0.8);
	// Grass thins out in patches rather than along a straight edge.
	float wg = smoothstep(0.3, 0.7, COLOR.g + (mid.g - 0.5) * 0.5) * (1.0 - wc);

	vec3 col = mix(dirt, grass, wg);
	col = mix(col, cobble, wc);
	col *= mix(0.74, 1.2, big.r) * mix(0.9, 1.08, mid.a);
	col *= mix(vec3(1.08, 1.0, 0.86), vec3(0.9, 1.0, 1.04), big.b);
	col *= mix(1.0, scorch_dark, smoothstep(0.1, 0.9, COLOR.b));

	vec3 nm = mix(texture(dirt_n, uv_dirt).rgb, texture(grass_n, uv_grass).rgb, wg);
	nm = mix(nm, texture(cobble_n, uv_cobble).rgb, wc);
	float roughness = mix(0.95, 0.72, wc);
	float depth = mix(0.7, 0.25, far);

	if (wet > 0.001) {
		col *= mix(1.0, 0.6, wet);
		roughness *= mix(1.0, 0.45, wet);
		// Water stands in the low spots of the mud, and in the worn hollows of the stones.
		float hollow = smoothstep(0.5, 0.62, 1.0 - big.g * 0.6 - mid.a * 0.5);
		float standing = max(hollow * (1.0 - wg) * 0.9 * puddles, (1.0 - dirt4.a) * water_in_dirt * (1.0 - wg) * (1.0 - wc));
		standing = clamp(standing * wet, 0.0, 1.0);
		roughness = mix(roughness, 0.05, standing);
		depth = mix(depth, 0.08, standing);
		col *= mix(1.0, 0.5, standing);
	}

	ALBEDO = col * gain;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = depth;
	ROUGHNESS = roughness;
	SPECULAR = 0.4;
}
