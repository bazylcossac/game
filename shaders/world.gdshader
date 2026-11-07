shader_type spatial;
// Every wall, floor and prop built by MapBuilder. World-space triplanar mapping, so boxes need no
// UVs, plus what makes a flat texture look lived in:
//  - macro noise at two scales, so a wall never repeats the same patch twice
//  - grime that climbs from the ground, in uneven tongues
//  - rain: surfaces darken and shine, water runs down walls and collects in puddles
// Vertex colour carries the tint and the baked contact shadow from MapBuilder.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;
uniform float tile = 4.0;
uniform float base_roughness = 0.8;
uniform float base_metallic = 0.0;
uniform float normal_strength = 0.8;
uniform float emission_energy = 0.0;
uniform float wet = 0.0;
uniform float grime = 0.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

vec3 unpack(vec3 n) {
	return n * 2.0 - 1.0;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(8.0));
	w /= (w.x + w.y + w.z);
	vec2 ux = world_pos.zy / tile;
	vec2 uy = world_pos.xz / tile;
	vec2 uz = world_pos.xy / tile;
	// Gradients taken here, outside the branch below, so each projection keeps its proper mip
	// level even where neighbouring pixels of a box edge take different branches.
	vec3 gx = dFdx(world_pos) / tile;
	vec3 gy = dFdy(world_pos) / tile;
	vec3 tex;
	vec3 nx = vec3(0.0);
	vec3 ny = vec3(0.0);
	vec3 nz = vec3(0.0);
	float top = max(w.x, max(w.y, w.z));
	if (top > 0.97) {
		// Nearly every face here is a wall, floor or roof square to the world, and the other two
		// projections weigh nothing on it: read one, not three. Two texture reads instead of six.
		if (w.x >= top) {
			w = vec3(1.0, 0.0, 0.0);
			tex = textureGrad(albedo_tex, ux, gx.zy, gy.zy).rgb;
			nx = unpack(textureGrad(normal_tex, ux, gx.zy, gy.zy).rgb);
		} else if (w.y >= top) {
			w = vec3(0.0, 1.0, 0.0);
			tex = textureGrad(albedo_tex, uy, gx.xz, gy.xz).rgb;
			ny = unpack(textureGrad(normal_tex, uy, gx.xz, gy.xz).rgb);
		} else {
			w = vec3(0.0, 0.0, 1.0);
			tex = textureGrad(albedo_tex, uz, gx.xy, gy.xy).rgb;
			nz = unpack(textureGrad(normal_tex, uz, gx.xy, gy.xy).rgb);
		}
	} else {
		tex = textureGrad(albedo_tex, ux, gx.zy, gy.zy).rgb * w.x + textureGrad(albedo_tex, uy, gx.xz, gy.xz).rgb * w.y + textureGrad(albedo_tex, uz, gx.xy, gy.xy).rgb * w.z;
		nx = unpack(textureGrad(normal_tex, ux, gx.zy, gy.zy).rgb);
		ny = unpack(textureGrad(normal_tex, uy, gx.xz, gy.xz).rgb);
		nz = unpack(textureGrad(normal_tex, uz, gx.xy, gy.xy).rgb);
	}
	// Whiteout blend: each projection tilts the world normal about its own axis.
	vec3 tilted = normalize(vec3(
		n.x + (nz.x * w.z + ny.x * w.y) * normal_strength,
		n.y + (nx.y * w.x + nz.y * w.z) * normal_strength,
		n.z + (nx.x * w.x + ny.y * w.y) * normal_strength));

	vec2 flat_pos = world_pos.xz + world_pos.y * vec2(0.37, 0.23);
	vec4 big = texture(macro_tex, flat_pos / 61.0);
	vec4 mid = texture(macro_tex, flat_pos / 13.0);
	vec3 col = tex * COLOR.rgb;
	col *= mix(0.74, 1.16, big.r) * mix(0.9, 1.08, mid.g);

	float upright = 1.0 - abs(n.y);
	// Stains rising off the ground, and dark streaks where water has run down a wall.
	float rise = 1.0 - smoothstep(0.0, 0.9 + big.a * 2.6, world_pos.y);
	float streak = texture(macro_tex, vec2(world_pos.x + world_pos.z, world_pos.y * 0.09) / 9.0).b;
	float stain = (rise * 0.55 + smoothstep(0.55, 0.85, streak) * 0.3 * upright) * grime;
	col *= 1.0 - stain * 0.6;

	float roughness = base_roughness;
	float metallic = base_metallic;
	if (wet > 0.001) {
		float film = wet * (0.55 + 0.45 * upright * smoothstep(0.3, 0.7, streak) + (1.0 - upright) * 0.45);
		col *= mix(1.0, 0.58, film);
		roughness = mix(roughness, roughness * 0.32, film);
		// Puddles: only on flat ground, where the noise dips.
		float flatness = smoothstep(0.86, 0.98, n.y);
		float puddle = flatness * smoothstep(0.52 - wet * 0.2, 0.6 - wet * 0.2, 1.0 - mid.a * 0.6 - big.g * 0.55) * wet;
		roughness = mix(roughness, 0.04, puddle);
		metallic = mix(metallic, 0.0, puddle);
		col *= mix(1.0, 0.62, puddle);
		tilted = normalize(mix(tilted, n, puddle));
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	NORMAL = normalize((VIEW_MATRIX * vec4(tilted, 0.0)).xyz);
	if (emission_energy > 0.0) {
		EMISSION = tex * emission_energy;
	}
}
