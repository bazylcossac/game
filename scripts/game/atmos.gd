class_name Atmos
extends RefCounted
## Lighting and atmosphere shared by the game and the menu backdrop.

const SUN_YAW := 118.0
const SKY_ENERGY := 1.6


## Adds the environment and sun to `parent`, and returns the sun.
static func setup(parent: Node, map_id := "") -> DirectionalLight3D:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/textures/sky_evening.exr")
	sky_mat.energy_multiplier = SKY_ENERGY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# The photo has its sun straight ahead (-Z); this turns that side to face our light.
	env.sky_rotation.y = deg_to_rad(SUN_YAW - 180.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.52, 0.56, 0.66)
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 1.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0

	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.32
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.glow_hdr_scale = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.5)
	env.set_glow_level(5, 0.2)

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.74, 0.62, 0.52)
	env.fog_light_energy = 0.75
	env.fog_sun_scatter = 0.18
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.12
	env.volumetric_fog_density = 0.002
	env.volumetric_fog_albedo = Color(0.92, 0.86, 0.8)
	env.volumetric_fog_emission = Color(0.1, 0.06, 0.04)
	env.volumetric_fog_emission_energy = 0.25
	env.volumetric_fog_sky_affect = 0.2
	env.sdfgi_energy = 1.7
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 150.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_detail_spread = 2.0

	env.ssao_radius = 1.6
	env.ssao_intensity = 1.7
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.2
	env.ssil_intensity = 0.6
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_max_distance = 240.0
	env.sdfgi_energy = 0.8

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9

	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.8, 0.63)
	sun.light_energy = 2.3
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.rotation_degrees = Vector3(-27.0, SUN_YAW, 0.0)
	sun.light_angular_distance = 0.6
	parent.add_child(sun)

	Settings.apply_quality(env, sun)
	match map_id:
		"neonowa_dzielnica": _night(env, sun)
		"ziemia_niczyja": _storm(env, sun)
		"stacja_rdzen": _indoors(env, sun)
		"dolina_pancerna":
			# Evening: a low sun, long shadows over the ridges and haze in the valley.
			env.fog_density = .00062
			env.volumetric_fog_density = .00028
			env.volumetric_fog_albedo = Color(.86, .7, .54)
			env.fog_light_color = Color(.8, .62, .46)
			env.fog_light_energy = .75
			env.fog_aerial_perspective = .3
			env.ambient_light_energy = 1.1
			env.adjustment_saturation = 1.08
			env.adjustment_contrast = 1.08
			sun.light_color = Color(1.0, .86, .7)
			sun.light_energy = 1.9
			sun.rotation_degrees = Vector3(-16, SUN_YAW, 0)
		"pole_bitwy":
			# Hot and dry, with the air full of dust.
			env.fog_density = .0021
			env.fog_light_color = Color(.74, .62, .46)
			env.fog_light_energy = .8
			env.volumetric_fog_albedo = Color(.82, .7, .54)
			env.adjustment_saturation = .94
			env.adjustment_contrast = 1.1
			sun.light_color = Color(1.0, .84, .62)
			sun.light_energy = 2.2
			sun.rotation_degrees = Vector3(-21, SUN_YAW, 0)
	return sun


## Late evening under a storm: almost no sun, rain in the air and mist lying in the low ground.
static func _storm(env: Environment, sun: DirectionalLight3D) -> void:
	var clouds := ShaderMaterial.new()
	clouds.shader = load("res://shaders/storm_sky.gdshader")
	clouds.set_shader_parameter("macro_tex", Mats.tex("macro_noise"))
	env.sky.sky_material = clouds
	env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky_rotation = Vector3.ZERO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.6, 0.68)
	env.ambient_light_energy = 1.7
	env.fog_light_color = Color(0.3, 0.32, 0.37)
	env.fog_light_energy = 0.9
	env.fog_density = 0.0052
	env.fog_sun_scatter = 0.0
	env.fog_sky_affect = 0.75
	env.fog_height = 3.0
	env.fog_height_density = 0.05
	# On the higher settings fog gets its own volume: thin, lit from within, and kept off the sky.
	env.volumetric_fog_density = 0.0035
	env.volumetric_fog_albedo = Color(0.6, 0.64, 0.7)
	env.volumetric_fog_emission = Color(0.2, 0.22, 0.27)
	env.volumetric_fog_emission_energy = 0.32
	env.volumetric_fog_sky_affect = 0.0
	env.sdfgi_enabled = false
	env.ssr_enabled = Settings.quality >= 1
	env.ssr_max_steps = 40
	env.adjustment_saturation = 0.72
	env.adjustment_contrast = 1.12
	env.adjustment_brightness = 1.0
	env.tonemap_exposure = 1.3
	sun.light_color = Color(0.7, 0.74, 0.84)
	sun.light_energy = 0.85
	sun.rotation_degrees = Vector3(-38, 40, 0)


## A wet night in the city: low cloud lit from below by everything under it.
static func _night(env: Environment, sun: DirectionalLight3D) -> void:
	var glow := ProceduralSkyMaterial.new()
	glow.sky_top_color = Color(0.03, 0.03, 0.08)
	glow.sky_horizon_color = Color(0.34, 0.12, 0.36)
	glow.ground_horizon_color = Color(0.34, 0.12, 0.36)
	glow.ground_bottom_color = Color(0.02, 0.02, 0.05)
	glow.sky_curve = 0.22
	glow.sun_angle_max = 0.0
	env.sky.sky_material = glow
	env.sky_rotation = Vector3.ZERO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.58, 0.82)
	env.ambient_light_energy = 2.6
	env.fog_light_color = Color(0.2, 0.12, 0.3)
	env.fog_light_energy = 0.8
	env.fog_density = 0.004
	env.fog_sky_affect = 0.5
	env.volumetric_fog_albedo = Color(0.5, 0.45, 0.8)
	env.volumetric_fog_emission = Color(0.02, 0.015, 0.05)
	env.sdfgi_enabled = false
	env.ssr_enabled = Settings.quality >= 1
	env.ssr_max_steps = 32
	# Moonlight this weak under an ambient sky three times as bright leaves shadows nobody can see
	# (shots taken with and without them match), yet drawing the city a second time into the shadow
	# map and filtering it cost a quarter of the frame. The neon and the lamps light the night.
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 1.6
	env.adjustment_saturation = 1.15
	sun.light_color = Color(0.5, 0.6, 1.0)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-62, 32, 0)


## Sealed in: no sky at all, only what the station lights itself.
static func _indoors(env: Environment, sun: DirectionalLight3D) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.84)
	env.ambient_light_energy = 2.2
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.sdfgi_enabled = false
	sun.visible = false
