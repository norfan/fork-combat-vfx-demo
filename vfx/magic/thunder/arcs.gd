extends RefCounted
## Lightning geometry for the thunder effects: jagged paths by midpoint displacement, and
## strips along them gathered into one mesh drawn with bolt.gdshader (power and core width
## ride in the vertex colour, so trunk, branches and small arcs share one draw).

const Art = preload("res://vfx/magic/magic_art.gd")

## A hash in [0, 1) of an integer key.
static func hash01(k: int) -> float:
	var v := sin(float(k) * 0.0137 + 78.233) * 43758.5453
	return v - floorf(v)

static func hash11(k: int) -> float: return hash01(k) * 2.0 - 1.0

## Kinks `points` (a backbone) `depth` times: every segment's midpoint moves sideways by
## up to `amount` × the segment's length, so the zigzag is fractal and stays sharp.
static func jag(points: PackedVector2Array, key: int, amount: float, depth: int) -> PackedVector2Array:
	for d in depth:
		var next := PackedVector2Array()
		for i in points.size() - 1:
			var p := points[i]
			var q := points[i + 1]
			next.append(p)
			next.append((p + q) * 0.5 + (q - p).orthogonal() * hash11(key * 7919 + d * 1543 + i * 31) * amount)
		next.append(points[-1])
		points = next
	return points

## A jagged line a → b, detailed down to ~`grain` px segments.
static func bolt(a: Vector2, b: Vector2, key: int, amount := 0.3, grain := 7.0) -> PackedVector2Array:
	var depth := clampi(ceili(log(maxf(a.distance_to(b), 1.0) / grain) / log(2.0)), 1, 7)
	return jag(PackedVector2Array([a, b]), key, amount, depth)

## Mesh data being gathered: vertices, UVs, colours, indices.
static func data() -> Dictionary:
	return {"v": PackedVector2Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}

## A strip `half` px wide each side along `points` (the first `upto` fraction of them),
## of `power` (0 … 1) with a white core `core` of its width; it narrows to a point at the
## far end (the head).
static func strip(out: Dictionary, points: PackedVector2Array, half: float, power: float, core: float, upto := 1.0) -> void:
	var count := points.size()
	if count < 2 or power <= 0.0 or half <= 0.0: return
	var last := clampf(upto, 0.0, 1.0) * (count - 1)
	var whole := floori(last)
	var used := PackedVector2Array(points.slice(0, whole + 1))
	if last - whole > 0.001 and whole + 1 < count: used.append(points[whole].lerp(points[whole + 1], last - whole))
	if used.size() < 2: return
	# Packed arrays are values: fill local copies and put them back.
	var vertices: PackedVector2Array = out.v
	var uvs: PackedVector2Array = out.uv
	var colours: PackedColorArray = out.c
	var indices: PackedInt32Array = out.i
	var first := vertices.size()
	var n := used.size()
	var tone := Color(core, 0.0, 0.0, power)
	for k in n:
		var back := used[maxi(k - 1, 0)]
		var ahead := used[mini(k + 1, n - 1)]
		var side := (ahead - back).normalized().orthogonal()
		var s := float(k) / (n - 1)
		var w := half * (1.0 - smoothstep(0.88, 1.0, s) * 0.8)
		vertices.append(used[k] + side * w)
		vertices.append(used[k] - side * w)
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

static func mesh(out: Dictionary) -> ArrayMesh:
	if (out.i as PackedInt32Array).is_empty(): return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out.v
	arrays[Mesh.ARRAY_TEX_UV] = out.uv
	arrays[Mesh.ARRAY_COLOR] = out.c
	arrays[Mesh.ARRAY_INDEX] = out.i
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## A mesh node drawn with the bolt shader.
static func node() -> MeshInstance2D:
	var m := MeshInstance2D.new()
	var material := ShaderMaterial.new()
	material.shader = Art.shader("bolt")
	m.material = material
	return m

## Branches forking off `main`: [points, fraction along main where it forks].
static func branches(main: PackedVector2Array, key: int, count: int, reach: float, amount := 0.35) -> Array:
	var out := []
	if main.size() < 6: return out
	for j in count:
		var at := 0.12 + 0.76 * hash01(key * 13 + j)
		var index := int(at * (main.size() - 2)) + 1
		var dir := (main[mini(index + 2, main.size() - 1)] - main[maxi(index - 2, 0)]).normalized()
		var turn := (0.35 + 0.55 * hash01(key * 13 + j + 50)) * (1.0 if hash01(key * 13 + j + 90) > 0.5 else -1.0)
		var end := main[index] + dir.rotated(turn) * reach * (0.4 + 0.6 * hash01(key * 13 + j + 130))
		out.append([bolt(main[index], end, key * 13 + j + 200, amount, 6.0), at])
	return out

## A glow item for an Art.Drawer, scaled down for the lighter tiers like Art.spread_light.
static func light(at: Vector2, extent: Vector2, colour: Color) -> Array:
	if Art.quality == "retro":
		extent *= 0.7
		colour.a *= 0.6
	elif Art.quality == "balanced":
		extent *= 0.85
		colour.a *= 0.8
	return [Art.glow(), at, extent, 0.0, colour]
