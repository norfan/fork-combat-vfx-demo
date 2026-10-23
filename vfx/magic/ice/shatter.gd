extends "res://vfx/magic/magic_fx.gd"
## Where ice lands, sized by the cast's blast `radius`: a cold flash (on real time), a
## cluster of clear crystals bursting out of the point and shattering a moment later, a
## spray of crystal chips tumbling end over end and rolling (the small ones fastest) that
## bounce and settle on the floor glinting before they fade, a breath of frost blowing
## outwards, a shockwave (a ring of light on the lighter tiers) and, near the floor, frost
## spreading over it.

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Crystal = preload("res://vfx/magic/ice/crystal.gd")
const SHARDS := 26
const SPIKES := 5
## When the burst of crystals shatters, seconds.
const BREAK := 0.32

var _frost: MeshInstance2D
var _mist: Node2D
var _lights: Node2D
var _ice: Array
var _sparks: Node2D
var _copy: BackBufferCopy
var _shock: MeshInstance2D

func _ready() -> void:
	super._ready()
	life = 1.6
	if _near_ground():
		_frost = Art.quad("frost")
		(stage.get("under") as Node2D).add_child(_frost)
	_mist = Art.drawer(false)
	add_child(_mist)
	_lights = Art.drawer(true)
	add_child(_lights)
	_ice = Crystal.node(float(seed_id % 31))
	for node in _ice: if node != null: add_child(node)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_copy = Art.backbuffer()
	add_child(_copy)
	_shock = Art.quad("shockwave")
	(_shock.material as ShaderMaterial).set_shader_parameter("tint", Vector3(0.7, 0.88, 1.0))
	add_child(_shock)
	_update()

func _exit_tree() -> void:
	if is_instance_valid(_frost): _frost.queue_free()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _near_ground() -> bool: return GROUND_Y - at.y < radius * 1.2 + 30.0

func _k() -> float: return radius / 60.0

func _update() -> void:
	var k := sqrt(_k())
	var mist: Array = []
	var lights: Array = []
	var sparks: Array = []
	var ice := Crystal.data()
	# Small blasts (a storm of needles) flash faintly, or two dozen of them white the target out.
	var flash := clampf(flash_left(1, 0.1), 0.0, 1.0) * clampf(radius / 60.0, 0.15, 1.0)
	if flash > 0.0:
		lights.append(Arcs.light(at, Vector2.ONE * radius * (3.6 if finisher else 2.4), Color(0.8, 0.93, 1.0, 0.9 * flash)))
		lights.append(Arcs.light(at, Vector2(radius * 9.0, radius * 0.22), Color(0.8, 0.93, 1.0, 0.8 * flash)))
	# The burst of crystals, then their shattering.
	if age < BREAK:
		var grow := ease_out(age / 0.06, 2.5)
		for j in SPIKES:
			var dir := Vector2.from_angle(-PI * 0.5 + (float(j) - (SPIKES - 1) * 0.5) * 0.6 + rnd2(j + 300) * 0.2)
			var length := radius * (0.9 + 0.7 * rnd(j + 301)) * k * grow
			Crystal.prism(ice, at - dir * length * 0.1, dir, length, length * 0.15, j * 1.1 + rnd(j + 302), 0.92, Crystal.ROOTED)
		lights.append(Arcs.light(at, Vector2.ONE * radius * 3.0, Color(0.6, 0.85, 1.0, 0.4)))
	# Shards: from the blast at once, and from the crystals when they break.
	var count := ceili(SHARDS * Art.density())
	for j in count:
		var late := j % 3 == 0
		var a := age - (BREAK if late else 0.0)
		var span := 0.9 + 0.5 * rnd(j + 100)
		if a < 0.0 or a >= span: continue
		var v := Vector2.from_angle(-PI * 0.5 + rnd2(j + 101) * 1.5) * (220.0 + 520.0 * rnd(j + 102)) * k * (0.6 if late else 1.0)
		var from := at + (Vector2.from_angle(-PI * 0.5 + rnd2(j + 103) * 1.1) * radius * 0.6 * k if late else Vector2.ZERO)
		var state := ballistic(from, v, a, 1500.0)
		# Chips tumble end over end and roll; the small ones fastest. On the floor they lie.
		var length := (12.0 + 20.0 * rnd(j + 106)) * k
		var turn := Crystal.roll_speed(length / 30.0)
		var landed := (state[0] as Vector2).y >= GROUND_Y - 2.5
		var tumble := (minf(a, 0.4) if landed else a) * turn * 0.6 * (1.0 if rnd(j + 105) > 0.5 else -1.0) + rnd(j + 104) * TAU
		var solid := clampf((span - a) / 0.25, 0.0, 1.0) * 0.9
		Crystal.prism_at(ice, state[0], Vector2.from_angle(0.0 if landed else tumble), length, length * 0.22, a * turn + j, solid, Crystal.CHIP)
		if rnd(j * 7 + floori(age * 14.0)) < 0.18: Crystal.sparkle(sparks, state[0], 9.0, solid)
	# Frost mist blown out in a ring, slowing and lifting.
	var smoke := Art.smoke()
	for j in 9:
		var a := age - 0.02
		if a < 0.0 or a > 1.1: continue
		var dir := Vector2.from_angle(TAU * j / 9.0 + rnd2(j + 200) * 0.3)
		var p := at + Vector2(dir.x, dir.y * 0.6) * radius * 1.4 * k * ease_out(a / 0.5, 2.5) + Vector2(0, -30.0 * a)
		var x := a / 1.1
		mist.append([smoke, p, Vector2(1.6, 0.7) * radius * k * (0.7 + 0.9 * x), dir.angle(), Color(0.86, 0.95, 1.0, 0.16 * (1.0 - x))])
	# The shockwave.
	var wave := age / 0.24
	_shock.visible = wave < 1.0 and Art.full()
	if _shock.visible:
		var side := radius * 6.0
		var rect := Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		Art.place(_shock, rect)
		_copy.rect = rect
		var sm: ShaderMaterial = _shock.material
		sm.set_shader_parameter("radius", ease_out(wave, 2.2) * 0.95)
		sm.set_shader_parameter("strength", 0.025)
	elif wave < 1.0:
		lights.append(Arcs.light(at, Vector2.ONE * radius * 6.0 * ease_out(wave, 2.2), Color(0.7, 0.88, 1.0, 0.22 * (1.0 - wave))))
	if is_instance_valid(_frost):
		var w := radius * 4.0 * ease_out(age / 0.15, 2.0)
		Art.place(_frost, Rect2(Vector2(at.x - w * 0.5, GROUND_Y - w * 0.07), Vector2(w, w * 0.17)))
		var fm: ShaderMaterial = _frost.material
		fm.set_shader_parameter("fade", clampf(1.0 - (age - 0.6) / (life - 0.6), 0.0, 1.0))
		fm.set_shader_parameter("seed", float(seed_id % 29))
		fm.set_shader_parameter("time", age)
	Crystal.show(_ice, ice, age)
	for pair in [[_mist, mist], [_lights, lights], [_sparks, sparks]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()
