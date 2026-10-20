extends Node2D
## A retained blade trajectory: two vertices per sample, connected as triangles.
## UV.x is distance across the blade; UV.y is sample birth time.
## advance() accepts an action clock, including pauses and slow motion.
const STEP := 1.0 / 240.0
const LIFE := 0.19
const SWING := 0.24
const PIXEL := 3.0
var duration := SWING
var tail := LIFE
var pixel := PIXEL
var radius := 230.0
var width := 88.0
var squash := 0.82
var tilt := 0.0
var start_angle := deg_to_rad(-146.0)
var end_angle := deg_to_rad(66.0)
var hilt_travel := 30.0
var swell := 24.0
var echo := false
var palette: Array = [Color("f0fae8"), Color("a3d4e0"), Color("4f8fb0"), Color("2e4f6e")]
var age := 0.0
var next_sample := 0.0
var samples: Array[Dictionary] = []
var blade: MeshInstance2D
var shader_material: ShaderMaterial

func configure(preset: Dictionary) -> Node2D:
	for key: String in preset: set(key, preset[key])
	return self

func _ready() -> void:
	var viewport := SubViewport.new()
	var reach := radius * maxf(1.0, squash) + absf(swell) + absf(hilt_travel) + 32.0
	var half_size := ceili(reach / pixel) + 2
	viewport.size = Vector2i.ONE * half_size * 2
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	blade = MeshInstance2D.new()
	blade.position = Vector2.ONE * half_size
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://vfx/trajectory_ribbon.gdshader")
	for i in 4: shader_material.set_shader_parameter("ink_%d" % i, palette[i])
	blade.material = shader_material
	viewport.add_child(blade)
	var display := Sprite2D.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.centered = false
	display.position = -blade.position * pixel
	display.scale = Vector2.ONE * pixel
	add_child(display)

func reset() -> void:
	age = 0.0
	next_sample = 0.0
	samples.clear()
	if blade != null: blade.mesh = null

func blade_pose(time: float) -> Dictionary:
	var t := clampf(time / duration, 0.0, 1.0)
	# An accelerating overhead cut followed by a short follow-through.
	var progress := smoothstep(0.0, 1.0, t)
	var angle := lerpf(start_angle, end_angle, progress)
	var direction := Vector2.from_angle(angle)
	var hilt := Vector2(hilt_travel * progress, hilt_travel * 0.4 * sin(progress * PI))
	var reach := radius + swell * sin(progress * PI)
	var tip := (hilt + direction * Vector2(reach, reach * squash)).rotated(tilt)
	hilt = hilt.rotated(tilt)
	var breadth := width * (0.273 + 0.727 * pow(maxf(sin(t * PI), 0.0), 0.8))
	return {"tip": tip, "inner": tip - (tip - hilt).normalized() * breadth, "hilt": hilt}

func advance(delta: float) -> void:
	if delta <= 0.0: return
	age += delta
	while next_sample <= minf(age, duration):
		var pose := blade_pose(next_sample)
		pose["born"] = next_sample
		samples.append(pose)
		next_sample += STEP
	while not samples.is_empty() and age - float(samples[0].born) >= tail:
		samples.pop_front()
	shader_material.set_shader_parameter("clock", age)
	shader_material.set_shader_parameter("lifetime", tail)
	shader_material.set_shader_parameter("swinging", age < duration)
	_rebuild()

func is_done() -> bool:
	return age >= duration + tail

func _rebuild() -> void:
	if samples.size() < 2:
		blade.mesh = null
		return
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for sample in samples:
		var strength := pow(clampf(1.0 - (age - float(sample.born)) / tail, 0.0, 1.0), 1.4)
		var tip: Vector2 = sample.tip
		var inner: Vector2 = tip.lerp(sample.inner, strength)
		vertices.append(Vector3(inner.x / pixel, inner.y / pixel, 0))
		vertices.append(Vector3(tip.x / pixel, tip.y / pixel, 0))
		uvs.append(Vector2(0, sample.born))
		uvs.append(Vector2(1, sample.born))
		if echo:
			var outward: Vector2 = (tip - sample.inner).normalized()
			for distance in [7.0, 7.0 + 2.5 * strength]:
				var point: Vector2 = (tip + outward * distance) / pixel
				vertices.append(Vector3(point.x, point.y, 0))
				uvs.append(Vector2(0.72, sample.born))
	for i in samples.size() - 1:
		var stride := 4 if echo else 2
		var n := i * stride
		indices.append_array(PackedInt32Array([n, n + 1, n + stride, n + 1, n + stride + 1, n + stride]))
		if echo:
			indices.append_array(PackedInt32Array([n + 2, n + 3, n + stride + 2, n + 3, n + stride + 3, n + stride + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	blade.mesh = mesh
