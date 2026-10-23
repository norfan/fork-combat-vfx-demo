extends "res://vfx/magic/magic_fx.gd"
## One fireball of a fire cast (body `index` of the volley), from gathering to landing.
## Body: a churning ball of flame (shader) that forms at the start point, then flies the
## path stretched into a comet by its speed. Accessories, all driven by the body:
##   gathering — sparks spiral into it, its light swells, the air around it starts to warp
##   launch    — a muzzle flash and a burst of sparks and smoke where it leaves
##   flight    — a flame trail streaming off it, warped air behind it (longer the faster it
##               flies), embers shed backwards, smoke left hanging along the path, a glow
##               around it, and an orange pool of light on the ground that grows as it
##               comes low
##   landing   — the body is gone (the explosion takes over); the trail burns out into the
##               landing point and the smoke drifts up and thins.

const Art = preload("res://vfx/magic/magic_art.gd")
## Body radius at size 1, px.
const BODY := 21.0
## Seconds of path the flame trail covers.
const TRAIL := 0.17
const SMOKE_RATE := 46.0
const SMOKE_LIFE := 1.0
const EMBER_RATE := 75.0

var _smoke: Node2D
var _copy: BackBufferCopy
var _haze: MeshInstance2D
var _trail: MeshInstance2D
var _ground: Sprite2D
var _glow: Sprite2D
var _pivot: Node2D
var _body: MeshInstance2D
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	life = land(index) + SMOKE_LIFE
	_smoke = Art.drawer(false)
	add_child(_smoke)
	_copy = Art.backbuffer()
	add_child(_copy)
	_haze = Art.quad("heat_haze")
	add_child(_haze)
	_ground = Art.light()
	add_child(_ground)
	_trail = MeshInstance2D.new()
	var trail_material := ShaderMaterial.new()
	trail_material.shader = Art.shader("flame_trail")
	_trail.material = trail_material
	add_child(_trail)
	_glow = Art.light()
	add_child(_glow)
	_pivot = Node2D.new()
	add_child(_pivot)
	_body = Art.quad("fireball")
	_pivot.add_child(_body)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _r() -> float: return BODY * size

func _update() -> void:
	var smoke: Array = []
	var sparks: Array = []
	var t0 := born(index)
	var t1 := launch(index)
	var t2 := land(index)
	var r := _r()
	var pos := path_at(index, 0.0)
	var dir := (path_at(index, 0.05) - pos).normalized()
	var speed := 0.0
	var grow := 1.0
	var heat := 1.0
	var flying := false
	if age < t1:
		# Gathering: it swells from a spark to full size, sparks spiralling into it.
		var k := clampf((age - t0) / maxf(charge, 0.01), 0.0, 1.0)
		grow = 0.2 + 0.8 * ease_out(k, 2.5)
		heat = 0.55 + 0.45 * k
		_gather_sparks(sparks, pos, k)
	elif age < t2:
		var u := (age - t1) / travel
		pos = path_at(index, u)
		var v := velocity_at(index, u)
		speed = v.length()
		dir = v.normalized()
		flying = true
		_launch_burst(sparks, smoke)
	else:
		pos = path_at(index, 1.0)
		_launch_burst(sparks, smoke)
	var stretch := 1.0 + clampf(speed / 1100.0, 0.0, 1.6)
	var alive := age >= t0 and age < t2
	# The body.
	_body.visible = alive
	if alive:
		var g := r * grow
		_pivot.position = pos
		_pivot.rotation = dir.angle()
		var tail := 1.4 * stretch
		Art.place(_body, Rect2(-tail * g, -1.4 * g, (tail + 1.4) * g, 2.8 * g))
		var m: ShaderMaterial = _body.material
		m.set_shader_parameter("time", age)
		m.set_shader_parameter("stretch", stretch)
		m.set_shader_parameter("tail", tail)
		m.set_shader_parameter("seed", float(seed_id % 97) + index * 3.7)
		m.set_shader_parameter("intensity", heat)
	# Its light: a glow around it and a pool on the ground below, brighter the lower it is.
	var flicker := 1.0 + 0.12 * noise(seed_id + index, age * 18.0)
	Art.spread_light(_glow, pos, Vector2.ONE * r * grow * 9.0 * flicker, Color(1.0, 0.5, 0.18, 0.55 * heat) if alive else Color(0, 0, 0, 0))
	var low := clampf(1.0 - (GROUND_Y - pos.y) / 380.0, 0.0, 1.0)
	Art.spread_light(_ground, Vector2(pos.x, GROUND_Y + 2.0), Vector2(r * 14.0, r * 2.6) * (0.6 + 0.5 * low) * grow,
		Color(1.0, 0.45, 0.12, 0.6 * low * heat) if alive else Color(0, 0, 0, 0))
	# Warped air around it while it gathers, streaming out behind it in flight.
	_haze.visible = alive and Art.full()
	if _haze.visible:
		var length := r * (3.0 + 5.0 * (stretch - 1.0)) * grow
		_copy.rect = Rect2(pos - Vector2.ONE * (length + r * 3.0), Vector2.ONE * (length + r * 3.0) * 2.0)
		_haze.transform = Transform2D(dir.angle(), pos) * Transform2D(0.0, Vector2(length + r * 2.4, r * 4.2 * grow), 0.0, Vector2(-length, -r * 2.1 * grow))
		var hm: ShaderMaterial = _haze.material
		hm.set_shader_parameter("time", age)
		hm.set_shader_parameter("seed", float(seed_id % 31))
		hm.set_shader_parameter("strength", 0.006 + 0.008 * (stretch - 1.0))
	_build_trail(t1, t2)
	if age >= t1: _shed(sparks, smoke, t1, t2)
	(_smoke as Art.Drawer).items = smoke
	_smoke.queue_redraw()
	(_sparks as Art.Drawer).items = sparks
	_sparks.queue_redraw()

## Sparks spiralling into the gathering body.
func _gather_sparks(out: Array, centre: Vector2, k: float) -> void:
	var glow := Art.glow()
	for j in 16:
		var phase := fposmod(k * 1.7 + rnd(j), 1.0)
		var angle := rnd(j + 20) * TAU + phase * 2.4
		var reach := (120.0 * (1.0 - phase) + 10.0) * size
		var p := centre + Vector2.from_angle(angle) * reach
		var heading := (centre - p).normalized().rotated(0.7)
		out.append([glow, p, Vector2(10.0 + 26.0 * (1.0 - phase), 4.0) * size, heading.angle(), Color(1.0, 0.72, 0.35, 0.9 * phase * (0.4 + 0.6 * k))])

## Where it leaves: a flash and a ring of sparks for an instant, a puff of smoke.
func _launch_burst(sparks: Array, smoke: Array) -> void:
	var e := age - launch(index)
	var from := path_at(index, 0.0)
	var dir := path_at(index, 0.05) - from
	dir = dir.normalized()
	var glow := Art.glow()
	if e < 0.1:
		var f := 1.0 - e / 0.1
		sparks.append([glow, from, Vector2.ONE * _r() * 7.0 * f, 0.0, Color(1.0, 0.85, 0.55, f)])
	if e < 0.25:
		for j in 10:
			var a := dir.angle() + rnd2(j + 300) * 1.3
			var v := (260.0 + 380.0 * rnd(j + 310)) * size
			var p := from + Vector2.from_angle(a) * v * e * (1.0 - e * 2.0)
			out_streak(sparks, p, Vector2.from_angle(a), 14.0 * size, 1.0 - e / 0.25)
	if e < 0.7:
		var x := e / 0.7
		smoke.append([Art.smoke(), from + Vector2(-6, -40.0 * x) * size, Vector2.ONE * _r() * (1.6 + 2.2 * x), rnd(5) * TAU + x,
			Color(0.3, 0.22, 0.2, 0.35 * (1.0 - x))])

func out_streak(out: Array, p: Vector2, heading: Vector2, length: float, strength: float) -> void:
	out.append([Art.glow(), p, Vector2(length, 4.0 * size), heading.angle(), Color(1.0, 0.7, 0.3, strength)])

## Embers shed backwards off the body and smoke left hanging along the path.
func _shed(sparks: Array, smoke: Array, t1: float, t2: float) -> void:
	var smoke_texture := Art.smoke()
	var smoke_rate := SMOKE_RATE * Art.density()
	var first := maxi(ceili(t1 * smoke_rate), floori((age - SMOKE_LIFE) * smoke_rate))
	for j in range(first, floori(minf(age, t2) * smoke_rate) + 1):
		var tb := float(j) / smoke_rate
		var a := age - tb
		if a < 0.0 or a >= SMOKE_LIFE: continue
		var u := (tb - t1) / travel
		var x := a / SMOKE_LIFE
		var p := path_at(index, u) - velocity_at(index, u).normalized() * _r() * 0.8
		p += Vector2(rnd2(j) * 30.0, -30.0 - 40.0 * rnd(j + 1)) * a * size
		var young := clampf(1.0 - a / 0.25, 0.0, 1.0)
		var tone := Color(0.14, 0.11, 0.11).lerp(Color(0.55, 0.26, 0.1), young)
		tone.a = 0.5 * pow(1.0 - x, 1.4) * smoothstep(0.0, 0.12, a)
		smoke.append([smoke_texture, p, Vector2.ONE * _r() * (1.2 + 2.6 * sqrt(x)) * (0.8 + 0.4 * rnd(j + 2)), rnd(j + 3) * TAU + x * 0.9, tone])
	var glow := Art.glow()
	var ember_life := 0.5
	var ember_rate := EMBER_RATE * Art.density()
	var head := maxi(ceili(t1 * ember_rate), floori((age - ember_life) * ember_rate))
	for j in range(head, floori(minf(age, t2) * ember_rate) + 1):
		var tb := float(j) / ember_rate
		var a := age - tb
		var span := ember_life * (0.55 + 0.45 * rnd(j + 50))
		if a < 0.0 or a >= span: continue
		var u := (tb - t1) / travel
		var v0 := velocity_at(index, u)
		var back := -v0.normalized()
		var side := back.orthogonal() * rnd2(j + 51)
		var v := (back * (70.0 + 160.0 * rnd(j + 52)) + side * 120.0 + Vector2(0, -60)) * size
		var p := path_at(index, u) + side * _r() * 0.7 + v * a + Vector2(0, 260.0) * a * a * 0.5
		var heading := v + Vector2(0, 260.0) * a
		var x := a / span
		var tone := Color(1.0, 0.9, 0.55).lerp(Color(1.0, 0.3, 0.05), x)
		tone.a = 1.0 - x * x
		sparks.append([glow, p, Vector2(6.0 + heading.length() * 0.035, 3.5) * size, heading.angle(), tone])

## The flame trail: a strip over the last TRAIL seconds of path, widest at the body; after
## landing its tail catches up with the landing point and it is gone.
func _build_trail(t1: float, t2: float) -> void:
	var newest := minf(age, t2)
	var oldest := maxf(t1, age - TRAIL)
	if age < t1 or newest - oldest < 0.008:
		_trail.mesh = null
		return
	var samples := 16
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var r := _r()
	for k in samples + 1:
		var s := float(k) / samples
		var tk := lerpf(newest, oldest, s)
		var u := (tk - t1) / travel
		var p := path_at(index, u)
		var side := velocity_at(index, u).normalized().orthogonal()
		var half := r * 1.3 * pow(1.0 - s, 0.55) * (0.85 + 0.25 * noise(seed_id + 9, tk * 30.0))
		vertices.append(p + side * half)
		vertices.append(p - side * half)
		uvs.append(Vector2(s, 0.0))
		uvs.append(Vector2(s, 1.0))
		if k < samples:
			var n := k * 2
			indices.append_array(PackedInt32Array([n, n + 1, n + 2, n + 1, n + 3, n + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_trail.mesh = mesh
	var m: ShaderMaterial = _trail.material
	m.set_shader_parameter("time", age)
	m.set_shader_parameter("seed", float(seed_id % 53) + index)
	m.set_shader_parameter("intensity", 1.0 if age < t2 else clampf(1.0 - (age - t2) / TRAIL, 0.0, 1.0))
