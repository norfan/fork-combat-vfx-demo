extends Node2D
## Claw marks: a set of torn crescent gashes raked along one path — an arc, a full loop or
## a spiral (大回环), a dive that slams into the ground (暴扣), a straight swipe.
## Each gash is a blade shape, not a tube: a long needle tail, a fat belly just behind the
## head and a razor tip, with ragged, uneven edges. The gashes fan out like an opening paw,
## differ in length, start one after another, and only the stretch just behind each head
## is visible: the marks run along the path and then erode from their tails. The heads
## flick off pixel debris. Drawn into a low-resolution SubViewport (pixel grain) and fully
## determined by `age`, so hit-stop, slow motion and big steps show exactly the same frame.

## Across a gash the ink runs edge → core → edge; the shader bands it dark → bright.
const EDGE_UV := 0.0
const CORE_UV := 1.0
## Sample spacing along a gash, px.
const STEP_PX := 3.0
## Uneven gaps between neighbouring gashes, so they never look ruled.
const GAP_SHAPE := [1.0, 0.82, 1.18, 0.9, 1.1, 0.86, 1.14, 0.95]

var path := PackedVector2Array()
## Seconds the heads take to run the path, and how long the marks take to erode after.
var duration := 0.16
var tail := 0.22
## Number of gashes, gap between neighbours where they open widest (px), gash thickness
## at its belly (px), and how torn the edges are (0 clean … 1 ragged).
var fingers := 3
var spread := 18.0
var width := 14.0
var jag := 0.45
## Length of the middle gash along the path, px; 0 picks a natural claw length from the
## thickness. Long paths (big loops) do not stretch the gash: the trail shows the travel.
var mark := 0.0
## Seconds of travel the thin trail behind each gash covers (0 = no trail).
var trail := 0.1
## Head start of each gash over the next one, seconds.
var stagger := 0.014
## Seconds before this rake starts (the second stroke of a cross slash).
var delay := 0.0
## Debris pixels flicked off the heads per second (0 = none).
var debris := 40.0
var pixel := 3.0
var palette: Array = [Color("fff0dd"), Color("ff9c66"), Color("e2412f"), Color("6e1222")]
var seed_id := 1
## Optional: keep the marks on a moving node (scratches on the target's body).
var follow: Node2D
var follow_offset := Vector2.ZERO

var age := 0.0
var particles: Array[Dictionary] = []
var _lengths := PackedFloat32Array()
var _total := 0.0
var _debris_due := 0.0
var _mesh_node: MeshInstance2D
var _material: ShaderMaterial
var _origin := Vector2.ZERO

func configure(preset: Dictionary) -> Node2D:
	for key: String in preset: set(key, preset[key])
	return self

func _ready() -> void:
	_lengths.resize(path.size())
	for i in range(1, path.size()):
		_total += path[i].distance_to(path[i - 1])
		_lengths[i] = _total
	_total = maxf(_total, 1.0)
	if mark <= 0.0: mark = clampf(width * 7.5, 50.0, 150.0)
	var box := Rect2(path[0], Vector2.ZERO)
	for p in path: box = box.expand(p)
	box = box.grow(spread * fingers * 1.4 + width * 2.0 + 64.0)
	_origin = box.position
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ceili(box.size.x / pixel) + 2, ceili(box.size.y / pixel) + 2)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	_mesh_node = MeshInstance2D.new()
	_material = ShaderMaterial.new()
	_material.shader = load("res://vfx/trajectory_ribbon.gdshader")
	for i in 4: _material.set_shader_parameter("ink_%d" % i, palette[i])
	_mesh_node.material = _material
	viewport.add_child(_mesh_node)
	var display := Sprite2D.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.centered = false
	display.position = _origin
	display.scale = Vector2.ONE * pixel
	add_child(display)
	if follow != null: position = follow.position + follow_offset
	age = -delay

## Deterministic noise in [-1, 1].
func _noise(k: int, x: float) -> float:
	var v := sin((x + float(k) * 7.31 + float(seed_id) * 3.17) * 12.9898) * 43758.5453
	var w := sin((x * 0.37 + float(k) * 1.7 + float(seed_id)) * 78.233) * 12345.678
	return (v - floorf(v) + w - floorf(w)) - 1.0

## Point and unit tangent at distance `d` along the path.
func _at(d: float) -> Array:
	d = clampf(d, 0.0, _total)
	var i := 1
	while i < path.size() - 1 and _lengths[i] < d: i += 1
	var span := maxf(_lengths[i] - _lengths[i - 1], 0.0001)
	var s := clampf((d - _lengths[i - 1]) / span, 0.0, 1.0)
	return [path[i - 1].lerp(path[i], s), (path[i] - path[i - 1]).normalized()]

## How far along the path (px) gash `k`'s head is at `time`, on the swing ease.
func _head(time: float, k: int) -> float:
	return PixelSlash.ease_swing(clampf((time - k * stagger) / duration, 0.0, 1.0)) * _total

## When the head of gash `k` passed distance `d` (the inverse of _head): its birth time.
func _born(d: float, k: int) -> float:
	var x := clampf(d / _total, 0.0, 1.0)
	return k * stagger + duration * (1.0 - pow(1.0 - x, 1.0 / 2.4))

func _middle() -> float: return (fingers - 1) * 0.5

func head_direction() -> Vector2:
	return (_at(_head(age, 0))[1] as Vector2)

## Where the front gash's head is, in the coordinates of the stage that owns the claw.
func head_point() -> Vector2:
	var point: Vector2 = _at(_head(maxf(age, 0.0), 0))[0]
	var transform := Transform2D.IDENTITY
	var node: Node = self
	while node != null and node is Node2D and not node is ComboStage:
		transform = (node as Node2D).transform * transform
		node = node.get_parent()
	return transform * point

## Shape of one gash along its length, s = 0 at the tail … 1 at the head: a long needle
## tail, the belly about three quarters along, a short razor tip.
static func _profile(s: float) -> float:
	if s <= 0.0 or s >= 1.0: return 0.0
	return pow(s, 1.25) * pow(1.0 - s, 0.42) / 0.3897

## Sideways offset of gash `k` at distance `d`: the paw opens as it travels, each gash
## bows a little its own way, and the gaps are uneven.
func _offset(k: int, d: float) -> float:
	var u := d / _total
	var opening := 0.45 + 0.75 * smoothstep(0.0, 0.7, u)
	var gap := 0.0
	for j in range(fingers):
		if j < k: gap += float(GAP_SHAPE[j % GAP_SHAPE.size()])
	var centre := 0.0
	for j in range(fingers - 1): centre += float(GAP_SHAPE[j % GAP_SHAPE.size()])
	return (gap - centre * 0.5) * spread * opening + spread * 0.22 * _noise(k, u * 2.0)

func advance(delta: float) -> void:
	if delta <= 0.0: return
	age += delta
	if follow != null and is_instance_valid(follow): position = follow.position + follow_offset
	var running := age >= 0.0 and age < duration + stagger * fingers
	_debris_due += delta * debris if running else 0.0
	while _debris_due >= 1.0:
		_debris_due -= 1.0
		var k := int(absf(_noise(1, age * 9.0)) * fingers) % fingers
		var d := _head(age, k)
		var pt := _at(d)
		var dir: Vector2 = pt[1]
		var side := Vector2(-dir.y, dir.x) * (1.0 if _noise(k, age * 13.0) > 0.0 else -1.0)
		var point: Vector2 = (pt[0] as Vector2) + Vector2(-dir.y, dir.x) * _offset(k, d)
		particles.append({"p": point, "v": dir * (220.0 + 200.0 * absf(_noise(k, age))) + side * (60.0 + 140.0 * absf(_noise(k + 3, age))), "born": age})
	for particle in particles:
		particle.v += Vector2(0, 1100.0) * delta
		particle.p += (particle.v as Vector2) * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return age - float(p.born) < 0.24)
	_material.set_shader_parameter("clock", age)
	_material.set_shader_parameter("lifetime", tail + duration)
	_material.set_shader_parameter("swinging", running)
	_rebuild()

func is_done() -> bool:
	return age >= duration + stagger * fingers + tail + 0.05

func _rebuild() -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var middle := _middle()
	for k in fingers:
		var outer := absf(k - middle) / maxf(middle, 1.0)
		var length := mark * (1.0 - 0.32 * outer) * (1.0 + 0.12 * _noise(k, 0.3))
		var thickness := width * (1.0 - 0.35 * outer) * (1.0 + 0.1 * _noise(k, 0.7))
		var head := _head(age, k)
		if head <= 0.0: continue
		# Once the head stops, the gash erodes from its tail towards the tip and thins.
		var end := duration + k * stagger
		var erosion := clampf((age - end) / tail, 0.0, 1.0)
		var full_tail := head - length
		var tail_d := lerpf(full_tail, head, pow(erosion, 0.75))
		var fade := 1.0 - 0.45 * erosion
		var start := maxf(tail_d, 0.0)
		if head - start < 2.0: continue
		# The trail: a thin, dimmer streak over where the head was `trail` seconds ago, up
		# into the gash's needle tail. It catches up and vanishes once the head stops.
		var trail_back := _head(age - trail, k)
		var trail_front := minf(start + length * 0.35, head)
		if trail > 0.0 and trail_front - trail_back > 4.0:
			# At least one pixel-art pixel wide, or it breaks into dots.
			var floor_half := pixel * 0.55
			_strip(vertices, uvs, indices, k, trail_back, trail_front, func(s: float) -> float:
				return maxf(thickness * 0.3 * s, floor_half * smoothstep(0.0, 0.25, s)) * fade, 0.62)
		var steps := maxi(3, ceili((head - start) / STEP_PX))
		var first := vertices.size()
		for i in steps + 1:
			var d := lerpf(start, head, float(i) / steps)
			var s := (d - full_tail) / maxf(length, 1.0)
			var pt := _at(d)
			var dir: Vector2 = pt[1]
			var normal := Vector2(-dir.y, dir.x)
			var centre: Vector2 = (pt[0] as Vector2) + normal * _offset(k, d)
			# Ragged edges: each side tears on its own, at two scales.
			var rough_a := 1.0 + jag * (0.5 * _noise(k, d * 0.06) + 0.1 * _noise(k + 11, d * 0.2))
			var rough_b := 1.0 + jag * (0.5 * _noise(k + 5, d * 0.07) + 0.1 * _noise(k + 17, d * 0.22))
			var half := thickness * 0.5 * _profile(s) * fade
			var born := _born(d, k)
			vertices.append(Vector3((centre.x + normal.x * half * rough_a - _origin.x) / pixel, (centre.y + normal.y * half * rough_a - _origin.y) / pixel, 0))
			vertices.append(Vector3((centre.x - _origin.x) / pixel, (centre.y - _origin.y) / pixel, 0))
			vertices.append(Vector3((centre.x - normal.x * half * rough_b - _origin.x) / pixel, (centre.y - normal.y * half * rough_b - _origin.y) / pixel, 0))
			uvs.append_array(PackedVector2Array([Vector2(EDGE_UV, born), Vector2(CORE_UV, born), Vector2(EDGE_UV, born)]))
		for i in steps:
			var n := first + i * 3
			indices.append_array(PackedInt32Array([n, n + 1, n + 3, n + 1, n + 4, n + 3, n + 1, n + 2, n + 4, n + 2, n + 5, n + 4]))
	_debris(vertices, uvs, indices)
	if indices.is_empty():
		_mesh_node.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_node.mesh = mesh

## A strip along gash `k`'s path from `back` to `front` (px), `half_at(s)` its half width
## with s = 0 at the back … 1 at the front, `core` the brightest ink across it (1 = white).
func _strip(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, k: int, back: float, front: float, half_at: Callable, core: float) -> void:
	var steps := maxi(2, ceili((front - back) / STEP_PX))
	var first := vertices.size()
	for i in steps + 1:
		var d := lerpf(back, front, float(i) / steps)
		var pt := _at(d)
		var dir: Vector2 = pt[1]
		var normal := Vector2(-dir.y, dir.x)
		var centre: Vector2 = (pt[0] as Vector2) + normal * _offset(k, d)
		var half: float = half_at.call(float(i) / steps)
		var born := _born(d, k)
		for v in [centre + normal * half, centre, centre - normal * half]:
			vertices.append(Vector3(((v as Vector2).x - _origin.x) / pixel, ((v as Vector2).y - _origin.y) / pixel, 0))
		uvs.append_array(PackedVector2Array([Vector2(EDGE_UV, born), Vector2(core, born), Vector2(EDGE_UV, born)]))
	for i in steps:
		var n := first + i * 3
		indices.append_array(PackedInt32Array([n, n + 1, n + 3, n + 1, n + 4, n + 3, n + 1, n + 2, n + 4, n + 2, n + 5, n + 4]))

func _debris(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	for particle in particles:
		var p: Vector2 = ((particle.p as Vector2) - _origin) / pixel
		var n := vertices.size()
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			vertices.append(Vector3(p.x + corner.x, p.y + corner.y, 0))
			uvs.append(Vector2(CORE_UV, particle.born))
		indices.append_array(PackedInt32Array([n, n + 1, n + 2, n, n + 2, n + 3]))
