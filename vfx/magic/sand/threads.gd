extends RefCounted
## Sand silk helpers for the sand effects: fine threads of glittering grains (strips drawn
## with silk.gdshader, gathered into one mesh; uses the lightning effects' mesh data) and
## the loose motes of sand-gold that shimmer in the air.

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")

const GOLD := Color(0.95, 0.74, 0.34)
const PALE := Color(1.0, 0.95, 0.78)

static func data() -> Dictionary: return Arcs.data()

## A mesh node drawn with the silk shader.
static func node() -> MeshInstance2D:
	var m := MeshInstance2D.new()
	var material := ShaderMaterial.new()
	material.shader = Art.shader("silk")
	m.material = material
	return m

## Sets a silk node's mesh, its time and how many of its grains are still there.
static func show(m: MeshInstance2D, out: Dictionary, time: float, present := 0.88) -> void:
	m.mesh = Arcs.mesh(out)
	var material: ShaderMaterial = m.material
	material.set_shader_parameter("time", time)
	material.set_shader_parameter("present", present)

## A thread along `points`, `half` px either side of its core, `power` 0 … 1, `id` telling
## its grains apart from other threads'.
static func thread(out: Dictionary, points: PackedVector2Array, half: float, power: float, id: int) -> void:
	var n := points.size()
	if n < 2 or power <= 0.0: return
	var length := 0.0
	for k in range(1, n): length += points[k].distance_to(points[k - 1])
	var vertices: PackedVector2Array = out.v
	var uvs: PackedVector2Array = out.uv
	var colours: PackedColorArray = out.c
	var indices: PackedInt32Array = out.i
	var first := vertices.size()
	var tone := Color(0.0, length / 2000.0, fposmod(id * 0.137, 1.0), power)
	for k in n:
		var side := (points[mini(k + 1, n - 1)] - points[maxi(k - 1, 0)]).normalized().orthogonal()
		var s := float(k) / (n - 1)
		vertices.append(points[k] + side * half)
		vertices.append(points[k] - side * half)
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

## A shimmering mote for an additive Art.Drawer: a tiny grain of light, twinkling.
static func mote(out: Array, at: Vector2, px: float, twinkle: float, alpha: float) -> void:
	if alpha <= 0.0: return
	var c := GOLD.lerp(PALE, twinkle)
	c.a = alpha * (0.35 + 0.65 * twinkle)
	out.append([Art.glow(), at, Vector2.ONE * px * 2.6, 0.0, Color(c, c.a * 0.35)])
	out.append([null, at.round(), Vector2.ONE * px, 0.0, c])
