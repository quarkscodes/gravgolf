@tool
class_name PlanetData
extends Resource

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
@export var plateau_lobe_radius_min: float = 5.0:
	set(val):
		plateau_lobe_radius_min = max(1.0, val)
		emit_changed()
@export var plateau_lobe_radius_max: float = 20.0:
	set(val):
		plateau_lobe_radius_max = max(plateau_lobe_radius_min, val)
		emit_changed()
@export var plateau_lobe_spread: float = 10.0:
	set(val):
		plateau_lobe_spread = max(0.0, val)
		emit_changed()
@export var plateau_smooth_k: float = 3.0:
	set(val):
		plateau_smooth_k = max(0.1, val)
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
	for plateau: PlanetPlateau in plateaus:
		if _plateau_sdf(point_on_sphere, plateau) < 0.0:
			return plateau.direction
	return point_on_sphere


func plateau_blend_at(point_on_sphere: Vector3) -> float:
	var slope_chord: float = plateau_slope_width / radius
	var max_blend: float = 0.0
	var warp_offset: float = 0.0
	if (
			planet_noise.size() > 0
			and planet_noise[0] != null
			and planet_noise[0].noise_map != null
	):
		var n0: PlanetNoise = planet_noise[0]
		warp_offset = (
				n0.noise_map.get_noise_3dv(point_on_sphere * n0.noise_scale * 0.5)
				* (plateau_smooth_k / radius)
				* plateau_warp_strength
		)
	for plateau: PlanetPlateau in plateaus:
		var sdf: float = _plateau_sdf(point_on_sphere, plateau) + warp_offset
		var blend: float = 1.0 - smoothstep(0.0, slope_chord, sdf)
		if blend > max_blend:
			max_blend = blend
	return max_blend


func regenerate_plateaus() -> void:
	plateaus.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = plateau_seed
	for _i: int in range(plateau_count):
		var theta: float = rng.randf() * TAU
		var z: float = rng.randf_range(-1.0, 1.0)
		var r: float = sqrt(max(0.0, 1.0 - z * z))
		var dir: Vector3 = Vector3(r * cos(theta), z, r * sin(theta))
		var p: PlanetPlateau = PlanetPlateau.new()
		p.direction = dir

		var right: Vector3 = dir.cross(Vector3.UP)
		if right.length_squared() < 0.001:
			right = dir.cross(Vector3.FORWARD)
		right = right.normalized()
		p.tangent_right = right
		p.tangent_fwd = dir.cross(right).normalized()

		var lobe_count: int = rng.randi_range(2, 4)
		for j: int in range(lobe_count):
			var lobe_r: float = rng.randf_range(plateau_lobe_radius_min, plateau_lobe_radius_max)
			var offset: Vector2
			if j == 0:
				offset = Vector2.ZERO
			else:
				var ox: float = rng.randf_range(-plateau_lobe_spread, plateau_lobe_spread)
				var oy: float = rng.randf_range(-plateau_lobe_spread, plateau_lobe_spread)
				offset = Vector2(ox, oy)
			p.lobe_offsets.append(offset)
			p.lobe_radii.append(lobe_r)

		p.flat_elevation = _max_elevation_in_plateau(p)
		plateaus.append(p)


func point_on_planet(point_on_sphere: Vector3) -> Vector3:
	var elevation: float = _noise_elevation(point_on_sphere)
	var pos: Vector3 = point_on_sphere * radius * (elevation + 1.0)

	var slope_chord: float = plateau_slope_width / radius
	var warp_offset: float = 0.0
	if (
			planet_noise.size() > 0
			and planet_noise[0] != null
			and planet_noise[0].noise_map != null
	):
		var n0: PlanetNoise = planet_noise[0]
		warp_offset = (
				n0.noise_map.get_noise_3dv(point_on_sphere * n0.noise_scale * 0.5)
				* (plateau_smooth_k / radius)
				* plateau_warp_strength
		)
	for plateau: PlanetPlateau in plateaus:
		var sdf: float = _plateau_sdf(point_on_sphere, plateau) + warp_offset
		var blend: float = 1.0 - smoothstep(0.0, slope_chord, sdf)
		if blend > 0.0:
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


# Samples the terrain elevation at the plateau center, each lobe center, and
# 8 boundary points per lobe, returning the maximum. Used so the flat surface
# is always at or above the highest terrain within the plateau area.
func _max_elevation_in_plateau(plateau: PlanetPlateau) -> float:
	var dir: Vector3 = plateau.direction
	var right: Vector3 = plateau.tangent_right
	var fwd: Vector3 = plateau.tangent_fwd

	var max_elev: float = _noise_elevation(dir)
	for i: int in range(plateau.lobe_offsets.size()):
		var offset: Vector2 = plateau.lobe_offsets[i]
		var lobe_r: float = plateau.lobe_radii[i]
		var center_dir: Vector3 = (
				dir + right * (offset.x / radius) + fwd * (offset.y / radius)
		).normalized()
		max_elev = max(max_elev, _noise_elevation(center_dir))
		for j: int in range(8):
			var a: float = float(j) / 8.0 * TAU
			var bx: float = offset.x + cos(a) * lobe_r
			var by: float = offset.y + sin(a) * lobe_r
			var boundary_dir: Vector3 = (
					dir + right * (bx / radius) + fwd * (by / radius)
			).normalized()
			max_elev = max(max_elev, _noise_elevation(boundary_dir))
	return max_elev


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


# Returns the smooth-union SDF of all plateau lobes in unit-sphere chord space.
# Negative = inside the plateau shape, positive = outside.
# Returns 1e9 for points on the opposite hemisphere, preventing antipodal ghost blends.
func _plateau_sdf(point_on_sphere: Vector3, plateau: PlanetPlateau) -> float:
	if point_on_sphere.dot(plateau.direction) <= 0.0:
		return 1e9

	var p_proj: Vector3 = (
			point_on_sphere - point_on_sphere.dot(plateau.direction) * plateau.direction
	)
	var p_2d: Vector2 = Vector2(
			p_proj.dot(plateau.tangent_right), p_proj.dot(plateau.tangent_fwd)
	)

	var smooth_k: float = plateau_smooth_k / radius
	var sdf: float = 1e9
	for i: int in range(plateau.lobe_offsets.size()):
		var lobe_center: Vector2 = plateau.lobe_offsets[i] / radius
		var lobe_r: float = plateau.lobe_radii[i] / radius
		var d: float = (p_2d - lobe_center).length() - lobe_r
		if i == 0:
			sdf = d
		else:
			sdf = _smin(sdf, d, smooth_k)
	return sdf


# Polynomial smooth minimum — blends two SDF values with C1 continuity.
func _smin(a: float, b: float, k: float) -> float:
	var h: float = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerp(b, a, h) - k * h * (1.0 - h)
