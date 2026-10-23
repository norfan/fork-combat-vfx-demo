extends RefCounted
## Ice geometry for the ice effects: crystals as six-sided prisms seen side-on, rolling
## about their long axis. Only the faces turned towards the viewer are built (they never
## overlap), each carrying its normal in the vertex colour so ice.gdshader can light it —
## so as a crystal rolls, the light slides from face to face and it visibly turns. Uses the
## lightning effects' mesh data (thunder/arcs.gd).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")

## Radius along a crystal (fraction of its length → fraction of its radius): pointed at
## both ends, like a quartz point.
const SPEAR := [[0.0, 0.12], [0.2, 1.0], [0.62, 1.0], [1.0, 0.0]]
const CHIP := [[0.0, 0.35], [0.28, 1.0], [0.7, 0.9], [1.0, 0.15]]
const ROOTED := [[0.0, 1.0], [0.7, 0.92], [1.0, 0.0]]

static func data() -> Dictionary: return Arcs.data()
static func mesh(out: Dictionary) -> ArrayMesh: return Arcs.mesh(out)

## A crystal mesh node; with a BackBufferCopy in front of it when it shows the screen
## behind (the 炸裂 tier, unless `clear` is off — swarms of needles skip it). Returns
## [copy or null, node]; add both in that order.
static func node(seed: float, clear := true) -> Array:
	var m := MeshInstance2D.new()
	var material := ShaderMaterial.new()
	material.shader = Art.shader("ice")
	clear = clear and Art.full()
	material.set_shader_parameter("see_through", 1.0 if clear else 0.0)
	material.set_shader_parameter("seed", seed)
	m.material = material
	return [Art.backbuffer() if clear else null, m]

## Roll speed (radians a second) of a crystal of this size: the bigger, the slower.
static func roll_speed(scale: float) -> float:
	return 15.0 / pow(maxf(scale, 0.2), 1.3)

## A prism from `tail` along unit `axis`, `length` long and `radius` at its widest, rolled
## by `roll`, `solid` its alpha, its width along it by `profile`.
static func prism(out: Dictionary, tail: Vector2, axis: Vector2, length: float, radius: float, roll: float, solid: float, profile: Array = SPEAR) -> void:
	if solid <= 0.0 or length < 1.0: return
	var vertices: PackedVector2Array = out.v
	var uvs: PackedVector2Array = out.uv
	var colours: PackedColorArray = out.c
	var indices: PackedInt32Array = out.i
	var side := axis.orthogonal()
	for k in 6:
		var face := roll + TAU * k / 6.0
		var facing := cos(face)
		if facing < -0.02: continue
		var low := sin(face - PI / 6.0)
		var high := sin(face + PI / 6.0)
		var tone := Color(facing * 0.5 + 0.5, sin(face) * 0.5 + 0.5, float(k) / 6.0, solid)
		var first := vertices.size()
		for step: Array in profile:
			var along := tail + axis * length * float(step[0])
			var r := radius * float(step[1])
			vertices.append(along + side * r * low)
			vertices.append(along + side * r * high)
			uvs.append(Vector2(float(step[0]), 0.0))
			uvs.append(Vector2(float(step[0]), 1.0))
			colours.append(tone)
			colours.append(tone)
		for s in profile.size() - 1:
			var m := first + s * 2
			indices.append_array(PackedInt32Array([m, m + 1, m + 2, m + 1, m + 3, m + 2]))
	out.v = vertices
	out.uv = uvs
	out.c = colours
	out.i = indices

## The same, centred on `centre` instead of starting at a tail.
static func prism_at(out: Dictionary, centre: Vector2, axis: Vector2, length: float, radius: float, roll: float, solid: float, profile: Array = SPEAR) -> void:
	prism(out, centre - axis * length * 0.5, axis, length, radius, roll, solid, profile)

## The screen area the gathered crystals cover (for the screen copy), grown a little.
static func bounds(out: Dictionary) -> Rect2:
	var vertices: PackedVector2Array = out.v
	if vertices.is_empty(): return Rect2()
	var box := Rect2(vertices[0], Vector2.ZERO)
	for p in vertices: box = box.expand(p)
	return box.grow(24.0)

## Sets a crystal node's mesh and time, and its screen copy over what it covers.
static func show(pair: Array, out: Dictionary, time: float) -> void:
	var m: MeshInstance2D = pair[1]
	m.mesh = mesh(out)
	(m.material as ShaderMaterial).set_shader_parameter("time", time)
	if pair[0] != null: (pair[0] as BackBufferCopy).rect = bounds(out)

## A star glint (two crossed streaks and a dot) for an additive Art.Drawer.
static func sparkle(out: Array, at: Vector2, reach: float, strength: float) -> void:
	if strength <= 0.0: return
	var glow := Art.glow()
	var tone := Color(0.85, 0.97, 1.0, strength)
	out.append([glow, at, Vector2(reach * 2.0, reach * 0.14), 0.0, tone])
	out.append([glow, at, Vector2(reach * 0.14, reach * 2.0), 0.0, tone])
	out.append([glow, at, Vector2.ONE * reach * 0.45, 0.0, tone])
