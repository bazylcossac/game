shader_type spatial;
// Every armoured machine: the mesh carries paint and surface kind per vertex, so a whole part
// is one draw call. Detail is mapped by triplanar projection in model space, because
// procedural meshes have no UVs and the pattern must stay on the hull as it moves.
//   COLOR  paint, already linear.
//   UV.x   edge wear: paint chips on chamfers first.
//   UV.y   kind: 0 paint, 1 bare metal, 2 rubber, 3 glass, 4+ light (fraction = brightness).

uniform sampler2D detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 0.36;
uniform vec3 patch_color : source_color = vec3(0.5);
uniform float patch_amount = 0.0;
uniform float paint_metal = 0.3;
uniform float paint_rough = 0.55;
uniform vec3 bare_color : source_color = vec3(0.46, 0.45, 0.44);

// 0 clean, 1 fully charred, above 1 still glowing hot.
instance uniform float burn = 0.0;
instance uniform float power = 1.0;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 ln = normalize(local_normal);
	vec3 w = pow(abs(ln), vec3(6.0));
	w /= w.x + w.y + w.z;
	vec4 tx = texture(detail, local_pos.zy * tile);
	vec4 ty = texture(detail, local_pos.xz * tile + vec2(0.37, 0.11));
	vec4 tz = texture(detail, local_pos.xy * tile + vec2(0.71, 0.53));
	vec4 d = tx * w.x + ty * w.y + tz * w.z;

	float kind = UV.y;
	float is_paint = 1.0 - step(0.5, kind);
	float is_metal = step(0.5, kind) * (1.0 - step(1.5, kind));
	float is_rubber = step(1.5, kind) * (1.0 - step(2.5, kind));
	float is_glass = step(2.5, kind) * (1.0 - step(3.5, kind));
	float is_light = step(3.5, kind);

	vec3 color = COLOR.rgb;
	float metal = 0.9;
	float rough = 0.36;
	float bump = 0.55;

	// Broad tonal patches, as if the paint had been touched up in the field.
	float broad = texture(detail, local_pos.xz * 0.09 + local_pos.y * 0.07).a;
	color = mix(color, color * patch_color * 2.0, is_paint * patch_amount * smoothstep(0.46, 0.54, broad));

	float chipped = UV.x * smoothstep(0.34, 0.58, d.a) + smoothstep(0.84, 0.9, d.a) * 0.7;
	chipped = clamp(chipped, 0.0, 1.0) * is_paint;
	color = mix(color, bare_color, chipped);
	metal = mix(metal, paint_metal, is_paint * (1.0 - chipped));
	rough = mix(rough, paint_rough + (d.a - 0.5) * 0.24, is_paint * (1.0 - chipped));
	bump = mix(bump, 1.0, is_paint);

	metal = mix(metal, 0.0, is_rubber);
	rough = mix(rough, 0.86, is_rubber);
	metal = mix(metal, 0.2, is_glass);
	rough = mix(rough, 0.07, is_glass);
	bump *= 1.0 - is_glass - is_light;

	// Seams hold dirt and shade.
	color *= mix(1.0, mix(0.3, 1.0, d.b), 1.0 - is_glass - is_light);

	vec2 nx = (tx.xy * 2.0 - 1.0) * w.x;
	vec2 ny = (ty.xy * 2.0 - 1.0) * w.y;
	vec2 nz = (tz.xy * 2.0 - 1.0) * w.z;
	vec3 n = ln + bump * vec3(ny.x + nz.x, nx.y + nz.y, nx.x + ny.y);
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(n, 0.0))).xyz);

	float char_mask = smoothstep(0.0, 0.5, burn + (d.a - 0.5) * 0.6) * min(burn * 1.6, 1.0);
	color = mix(color, vec3(0.012, 0.011, 0.01), char_mask);
	metal = mix(metal, 0.1, char_mask);
	rough = mix(rough, 0.92, char_mask);

	vec3 lit = COLOR.rgb * (kind - 4.0) * 10.0 * power * is_light;
	// Only some of the seams stay hot, in patches.
	vec3 embers = vec3(2.0, 0.5, 0.06) * max(burn - 1.0, 0.0) * (1.0 - d.b) * smoothstep(0.5, 0.66, broad);

	ALBEDO = mix(color, vec3(0.0), is_light);
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = lit + embers;
}
