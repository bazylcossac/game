// A whole soldier in one surface. The vertex colour carries the paint with its baked shadows,
// gamma-encoded so black cloth keeps its shading in eight bits, and its alpha names the kind of
// material, in the order of KINDS in tools/blender_char.py.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

const int GLOW = 9;
const int TINT = 10;
const int LAMP = 11;
// cloth, suit, leather, rubber, paint, metal, ceramic, glass, skin, glow, tint, lamp, satin
const int SKIN = 8;
const float ROUGH[13] = float[](0.92, 0.74, 0.52, 0.8, 0.46, 0.3, 0.3, 0.12, 0.62, 0.4, 0.44, 0.4, 0.38);
const float METAL[13] = float[](0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 0.0, 0.6, 0.0, 0.0, 0.0, 0.0, 0.1);
const float SHEEN[13] = float[](0.2, 0.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.2, 0.0, 0.2);
#ifdef WEAVE
const float GRAIN[13] = float[](1.0, 0.55, 0.3, 0.2, 0.12, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.25);
uniform sampler2D weave_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float weave_tiles = 3.0;
#endif

// The side's light: eyes, lamps, status marks.
uniform vec3 glow : source_color = vec3(1.0, 0.28, 0.2);
uniform float glow_energy = 2.4;
// The colour of whatever marks a class: Korpo's ties, and the skin of the Rebellion's people.
uniform vec3 tint : source_color = vec3(0.5, 0.5, 0.5);

varying flat int kind;

void vertex() {
	kind = clamp(int(COLOR.a * 16.0), 0, 12);
}

void fragment() {
	// With multisampling a pixel on a silhouette is shaded at its centre, which can lie outside
	// the triangle, so the colour is read past its ends and may dip below zero. The power of a
	// negative number is not a number, and the glow pass spreads that one pixel into a halo.
	vec3 paint = pow(clamp(COLOR.rgb, 0.0, 1.0), vec3(2.2));
	if (kind == TINT || kind == SKIN) {
		paint *= tint;
	}
	ALBEDO = paint;
	// Gloss gives way where the surface turns away from the eye, so a light from behind does not
	// flare along the silhouette.
	float facing = smoothstep(0.05, 0.45, dot(NORMAL, VIEW));
	ROUGHNESS = mix(0.95, ROUGH[kind], facing);
	SPECULAR = 0.5 * facing;
	METALLIC = METAL[kind] * mix(0.4, 1.0, facing);
	// A soft edge light on cloth, so a dark body still reads against a dark street.
	RIM = SHEEN[kind];
	RIM_TINT = 0.4;
	if (kind == GLOW) {
		ALBEDO = vec3(0.02);
		EMISSION = glow * glow_energy;
	} else if (kind == LAMP) {
		EMISSION = paint * 3.0;
	}
#ifdef WEAVE
	// The weave fades out before its threads get finer than a pixel. Past that point a normal map
	// only adds sparkle that crawls over the cloth as the body moves.
	vec2 at = UV * weave_tiles;
	float texels = max(length(dFdx(at)), length(dFdy(at))) * float(textureSize(weave_normal, 0).x);
	NORMAL_MAP = texture(weave_normal, at).rgb;
	NORMAL_MAP_DEPTH = GRAIN[kind] * 0.5 * (1.0 - smoothstep(0.6, 1.6, texels));
#endif
}
