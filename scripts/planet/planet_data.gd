@tool
class_name PlanetData
extends Resource

const MIN_PLATEAU_AREA: float = 50.0  # minimum flat surface area in square meters

@export var biomes: Array[PlanetBiome]:
	set(val):
		biomes = val
		emit_changed()
		for n: PlanetBiome in biomes:
			if n != null and not n.changed.is_connected(emit_changed):
				n.changed.connect(emit_changed)
@export var biome_amplitude: float:
	set(val):
		biome_amplitude = val
		emit_changed()
@export var biome_noise_scale: float = 100.0:
	set(val):
		biome_noise_scale = val
		emit_changed()
@export var biome_blend: float:
	set(val):
		biome_blend = clamp(val, 0.0, 1.0)
		emit_changed()
@export var biome_noise: FastNoiseLite:
	set(val):
		biome_noise = val
		emit_changed()
		if biome_noise != null and not biome_noise.changed.is_connected(emit_changed):
			biome_noise.changed.connect(emit_changed)
@export var biome_offset: float:
	set(val):
		biome_offset = val
		emit_changed()
@export var radius: float = 1.0:
	set(val):
		radius = val
		emit_changed()
@export var resolution: int = 10:
	set(val):
		resolution = val
		emit_changed()
@export var planet_noise: Array[PlanetNoise]:
	set(val):
		planet_noise = val
		emit_changed()
		for n: PlanetNoise in planet_noise:
			if n != null and not n.changed.is_connected(emit_changed):
				n.changed.connect(emit_changed)
@export var plateau_count: int = 3:
	set(val):
		plateau_count = val
		emit_changed()
@export var plateau_seed: int = 0:
	set(val):
		plateau_seed = val
		emit_changed()
@export var plateau_radius: float = 20.0:
	set(val):
		plateau_radius = max(val, sqrt(MIN_PLATEAU_AREA / PI))
		emit_changed()
@export var plateau_slope_width: float = 8.0:
	set(val):
		plateau_slope_width = val
		emit_changed()
@export var plateau_warp_strength: float = 0.4:
	set(val):
		plateau_warp_strength = val
		emit_changed()
@export var plateau_dome_height: float = 40.0:
	set(val):
		plateau_dome_height = val
		emit_changed()
@export var gravity: float = 9.8:
	set(val):
		gravity = val
		emit_changed()
@export var hole: HoleData:
	set(val):
		hole = val
		emit_changed()
		if hole != null and not hole.is_connected("changed", emit_changed):
			hole.changed.connect(emit_changed)

var min_height: float = 99999.0
var max_height: float = 0.0
var plateaus: Array[PlanetPlateau] = []


func biome_percent_from_point(point_on_unit_sphere: Vector3) -> float:
	# y in [-1,1] maps to latitude [0,1]: 0 = south pole, 1 = north pole
	var height_percent: float = (point_on_unit_sphere.y + 1.0) / 2.0
	height_percent += (
			((biome_noise.get_noise_3dv(point_on_unit_sphere * biome_noise_scale)
			+ 1.0) / 2.0 - biome_offset) * biome_amplitude
	)
	var biome_index: float = 0.0
	var num_biome: float = biomes.size()
	# +0.0001 prevents a zero-width blend range when biome_blend is 0
	var blend_range: float = biome_blend / 2.0 + 0.0001

	# Soft blend: accumulate weighted biome index so transitions aren't hard cuts
	for i: int in range(num_biome):
		if biomes[i] != null:
			var dst: float = height_percent - biomes[i].start_height
			var lerp_val: float = clamp(inverse_lerp(-blend_range, blend_range, dst), 0.0, 1.0)
			var weight: float = lerp_val
			biome_index *= (1 - weight)
			biome_index += i * weight
		else:
			break

	# Normalize to [0,1] so it maps directly to UV.y on the biome texture
	return biome_index / max(1.0, num_biome - 1)


func plateau_normal_at(point_on_sphere: Vector3) -> Vector3:
	var plateau_chord: float = plateau_radius / radius
	for plateau: PlanetPlateau in plateaus:
		if point_on_sphere.distance_to(plateau.direction) < plateau_chord:
			return plateau.direction
	return point_on_sphere


func regenerate_plateaus() -> void:
	plateaus.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = plateau_seed
	for _i: int in range(plateau_count):
		# Uniform random direction on unit sphere via spherical coordinates
		var theta: float = rng.randf() * TAU
		var z: float = rng.randf_range(-1.0, 1.0)
		var r: float = sqrt(max(0.0, 1.0 - z * z))
		var dir: Vector3 = Vector3(r * cos(theta), z, r * sin(theta))
		var p: PlanetPlateau = PlanetPlateau.new()
		p.direction = dir
		p.flat_elevation = _noise_elevation(dir)
		plateaus.append(p)


func point_on_planet(point_on_sphere: Vector3) -> Vector3:
	var elevation: float = _noise_elevation(point_on_sphere)
	var pos: Vector3 = point_on_sphere * radius * (elevation + 1.0)

	var plateau_chord: float = plateau_radius / radius
	var slope_chord: float = plateau_slope_width / radius
	for plateau: PlanetPlateau in plateaus:
		var dist: float = point_on_sphere.distance_to(plateau.direction)
		# Warp the boundary using noise layer 0 for organic shape — no extra asset required
		if (
				planet_noise.size() > 0
				and planet_noise[0] != null
				and planet_noise[0].noise_map != null
		):
			var n0: PlanetNoise = planet_noise[0]
			var warp: float = n0.noise_map.get_noise_3dv(point_on_sphere * n0.noise_scale * 0.5)
			dist += warp * plateau_chord * plateau_warp_strength
		var blend: float = 1.0 - smoothstep(plateau_chord, plateau_chord + slope_chord, dist)
		if blend > 0.0:
			# Project this vertex direction onto the plateau's tangent plane to get a
			# genuinely flat surface. Intersection of ray (origin + t*d) with the plane
			# through plateau_center perpendicular to plateau.direction gives t = h / dot(d, N).
			var dot_dn: float = point_on_sphere.dot(plateau.direction)
			if dot_dn > 0.001:
				var plateau_height: float = radius * (plateau.flat_elevation + 1.0)
				var flat_pos: Vector3 = point_on_sphere * (plateau_height / dot_dn)
				pos = pos.lerp(flat_pos, blend)
	return pos


func update_biome_texture() -> ImageTexture:
	# Builds a 2D texture where each row is one biome's color gradient.
	# The shader samples it with UV = (height_along_gradient, biome_index),
	# so row count = biome count and all gradients must share the same width.
	var h: int = biomes.size()
	if h == 0:
		return ImageTexture.create_from_image(Image.new())

	var w: int = biomes[0].gradient.width
	var fmt: Image.Format = biomes[0].gradient.get_image().get_format()
	var data: PackedByteArray
	for b: PlanetBiome in biomes:
		var img: Image = b.gradient.get_image()
		if img.get_format() != fmt:
			img.convert(fmt)
		data.append_array(img.get_data())

	var dyn_image: Image = Image.create_from_data(w, h, false, fmt, data)
	var image_texture: ImageTexture = ImageTexture.create_from_image(dyn_image)
	image_texture.resource_name = "Biome Texture"
	return image_texture


func _noise_elevation(point_on_sphere: Vector3) -> float:
	# Layer 0 is the base layer — other layers can use it as a mask so detail
	# noise only appears where the base terrain already has height (e.g. no craters in oceans).
	# base_elevation is captured from layer 0's output during the loop to avoid sampling it twice.
	var elevation: float = 0.0
	var base_elevation: float = 0.0
	for i: int in range(planet_noise.size()):
		var n: PlanetNoise = planet_noise[i]
		if n != null and n.noise_map != null:
			var mask: float = 1.0
			if n.use_first_layer_as_mask:
				mask = base_elevation
			var level_elevation: float = n.noise_map.get_noise_3dv(point_on_sphere * n.noise_scale)
			level_elevation = (level_elevation + 1.0) / 2.0 * n.amplitude
			level_elevation = max(0.0, level_elevation - n.min_height) * mask
			if i == 0:
				base_elevation = level_elevation
			elevation += level_elevation
	return elevation
