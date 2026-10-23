extends Node2D
## What a shared shape (vfx/magic/shapes/) draws on, every step: a mist layer (normal
## blend: smoke, air, leaves), strip meshes by kind (flame, lightning, frost, wind, silk,
## crystal — one mesh each, made the first time a material asks for it), pooled shader
## quads (fireball bodies) and a light layer on top (additive: glows, sparks, motes). A
## shape calls begin(), has its materials (the element scripts) draw into it, then
## finish(); the materials' drawing is in each element script (fire.gd …).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")

## Items for the mist and light layers: [texture or null, centre, size, rotation, colour].
var mist: Array = []
var light: Array = []
## Seconds, for the shaders.
var time := 0.0
var _mist: Node2D
var _light: Node2D
## kind → {"nodes": [copy or null, mesh], "data": mesh data, "show": Callable}
var _strips := {}
## shader → {"nodes": [MeshInstance2D], "used": int}
var _quads := {}

func _init() -> void:
	_mist = Art.drawer(false)
	add_child(_mist)
	_light = Art.drawer(true)
	_light.z_index = 1
	add_child(_light)

func begin(seconds: float) -> void:
	time = seconds
	mist = []
	light = []
	for kind: String in _strips: _strips[kind].data = Arcs.data()
	for shader: String in _quads: _quads[shader].used = 0

## The mesh data of strip kind `kind`; `make` builds its nodes ([copy or null, mesh]) the
## first time, `show` (nodes, data, time) puts the gathered data on them every step.
func strip(kind: String, make: Callable, show: Callable) -> Dictionary:
	if not _strips.has(kind):
		var nodes: Array = make.call()
		for node: Node in nodes: if node != null: add_child(node)
		_strips[kind] = {"nodes": nodes, "data": Arcs.data(), "show": show}
	return _strips[kind].data

## The next unused quad drawn with `shader` this step (its material is its own).
func quad(shader: String) -> MeshInstance2D:
	if not _quads.has(shader): _quads[shader] = {"nodes": [], "used": 0}
	var pool: Dictionary = _quads[shader]
	if int(pool.used) >= (pool.nodes as Array).size():
		var node := Art.quad(shader)
		add_child(node)
		(pool.nodes as Array).append(node)
	var node: MeshInstance2D = pool.nodes[pool.used]
	pool.used = int(pool.used) + 1
	node.visible = true
	return node

## Nodes for a plain strip kind drawn with `shader` (vertex colours carry its strips).
static func plain(shader: String) -> Array:
	var m := MeshInstance2D.new()
	var material := ShaderMaterial.new()
	material.shader = Art.shader(shader)
	m.material = material
	return [null, m]

static func show_plain(nodes: Array, data: Dictionary, seconds: float) -> void:
	var m: MeshInstance2D = nodes[1]
	m.mesh = Arcs.mesh(data)
	(m.material as ShaderMaterial).set_shader_parameter("time", seconds)

## A ribbon along `points`, `half` px either side, `power` 0 … 1, narrowing by `taper` (0 …
## 1) to the far end; `id` tells its lines apart. Vertex colour as the silk shader reads
## it: a = power, g = length / 2000 px, b = id.
static func ribbon(out: Dictionary, points: PackedVector2Array, half: float, power: float, id: int, taper := 0.0) -> void:
	var n := points.size()
	if n < 2 or power <= 0.0 or half <= 0.0: return
	var length := 0.0
	for k in range(1, n): length += points[k].distance_to(points[k - 1])
	var vertices: PackedVector2Array = out.v
	var uvs: PackedVector2Array = out.uv
	var colours: PackedColorArray = out.c
	var indices: PackedInt32Array = out.i
	var first := vertices.size()
	var tone := Color(0.0, length / 2000.0, fposmod(id * 0.137, 1.0), clampf(power, 0.0, 1.0))
	for k in n:
		var side := (points[mini(k + 1, n - 1)] - points[maxi(k - 1, 0)]).normalized().orthogonal()
		var s := float(k) / (n - 1)
		var w := half * (1.0 - taper * s)
		vertices.append(points[k] + side * w)
		vertices.append(points[k] - side * w)
		uvs.append(Vector2(s, 0.0))
		uvs.append(Vector2(s, 1.0))
		colours.append(tone)
		colours.append(tone)
		if k < n - 1:
			var m := first + k * 2
			indices.append_array(PackedInt32Array([m, m + 1, m + 2, m + 1, m + 3, m + 2]))
	out.v = vertices
	out.uv = uvs
	out.c = colours
	out.i = indices

func finish() -> void:
	(_mist as Art.Drawer).items = mist
	_mist.queue_redraw()
	(_light as Art.Drawer).items = light
	_light.queue_redraw()
	for kind: String in _strips:
		var entry: Dictionary = _strips[kind]
		(entry.show as Callable).call(entry.nodes, entry.data, time)
	for shader: String in _quads:
		var pool: Dictionary = _quads[shader]
		for k in range(int(pool.used), (pool.nodes as Array).size()): (pool.nodes[k] as Node2D).visible = false
