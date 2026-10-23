extends RefCounted
## Wind geometry for the wind effects: strips of moving air (blade crescents, streaks
## along a path, bands of a funnel) gathered into one mesh drawn with wind.gdshader, and
## the leaves the wind carries. Uses the lightning effects' mesh data (thunder/arcs.gd).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")

static var _leaf: Texture2D

static func data() -> Dictionary: return Arcs.data()
static func mesh(out: Dictionary) -> ArrayMesh: return Arcs.mesh(out)

## A wind mesh node, with a BackBufferCopy in front of it when it bends the screen (the
## 炸裂 tier). Returns [copy or null, node]; add both in that order.
static func node(seed: float, clear := true) -> Array:
	var m := MeshInstance2D.new()
	var material := ShaderMaterial.new()
	material.shader = Art.shader("wind")
	clear = clear and Art.full()
	material.set_shader_parameter("see_through", 1.0 if clear else 0.0)
	material.set_shader_parameter("seed", seed)
	m.material = material
	return [Art.backbuffer() if clear else null, m]

## Sets a wind node's mesh and time, and its screen copy over what it covers.
static func show(pair: Array, out: Dictionary, time: float) -> void:
	var m: MeshInstance2D = pair[1]
	m.mesh = mesh(out)
	(m.material as ShaderMaterial).set_shader_parameter("time", time)
	if pair[0] != null:
		var vertices: PackedVector2Array = out.v
		if vertices.is_empty(): return
		var box := Rect2(vertices[0], Vector2.ZERO)
		for p in vertices: box = box.expand(p)
		(pair[0] as BackBufferCopy).rect = box.grow(24.0)

## A strip of air along `points`: `width` px wide at its thickest (`shape` 0 … 1 along it
## → fraction of the width), leading edge on the first side, `power` its strength, `crisp`
## how sharp its leading edge is.
static func band(out: Dictionary, points: PackedVector2Array, width: float, power: float, crisp: float, shape := Callable()) -> void:
	var n := points.size()
	if n < 2 or power <= 0.0 or width <= 0.0: return
	var vertices: PackedVector2Array = out.v
	var uvs: PackedVector2Array = out.uv
	var colours: PackedColorArray = out.c
	var indices: PackedInt32Array = out.i
	var first := vertices.size()
	var tone := Color(crisp, 0.0, 0.0, power)
	for k in n:
		var s := float(k) / (n - 1)
		var side := (points[mini(k + 1, n - 1)] - points[maxi(k - 1, 0)]).normalized().orthogonal()
		var w := width * (float(shape.call(s)) if shape.is_valid() else sin(PI * s))
		vertices.append(points[k])
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

## A crescent of air: an arc `reach` px across, bulging along `forward`, around `centre`.
static func crescent(out: Dictionary, centre: Vector2, forward: Vector2, reach: float, width: float, power: float) -> void:
	var points := PackedVector2Array()
	var radius := reach * 0.62
	var hub := centre - forward * radius
	for k in 17:
		var a := lerpf(-1.1, 1.1, k / 16.0)
		points.append(hub + forward.rotated(a) * radius)
	band(out, points, width, power, 1.0, func(s: float) -> float: return pow(sin(PI * s), 0.8))

## A leaf: a pointed oval with a vein (white; tint it with the draw colour).
static func leaf() -> Texture2D:
	if _leaf == null:
		var w := 32
		var h := 14
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var u := (x + 0.5) / w * 2.0 - 1.0
				var v := (y + 0.5) / h * 2.0 - 1.0
				var half := pow(maxf(1.0 - u * u, 0.0), 0.8)
				var inside := 1.0 - smoothstep(half - 0.15, half, absf(v))
				var vein := 0.75 if absf(v) < 0.12 and absf(u) < 0.85 else 1.0
				image.set_pixel(x, y, Color(vein, vein, vein, inside))
		_leaf = ImageTexture.create_from_image(image)
	return _leaf

## Leaf colours: fresh green to yellowed.
static func leaf_tone(k: float, alpha: float) -> Color:
	var c := Color(0.35, 0.7, 0.28).lerp(Color(0.85, 0.78, 0.3), k)
	c.a = alpha
	return c

## A tumbling leaf for a normal Art.Drawer: flipping over (its width swings) as it spins.
static func leaf_item(at: Vector2, length: float, spin: float, flip: float, tone: Color) -> Array:
	return [leaf(), at, Vector2(length, length * 0.45 * maxf(absf(cos(flip)), 0.15)), spin, tone]
