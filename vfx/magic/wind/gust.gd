extends "res://vfx/magic/magic_fx.gd"
## Where wind lands, sized by the cast's blast `radius`: the puff bursts — a ring of white
## air billowing outwards and thinning, a white swirl spinning open round the point, a
## blast of air streaking outwards and curling as it goes, a ripple through the air (炸裂
## tier; a pale ring on the others), leaves flung out that flutter down, and dust kicked up
## off the floor when it is near.

const Art = preload("res://vfx/magic/magic_art.gd")
const Gusts = preload("res://vfx/magic/wind/gusts.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const STREAKS := 14
const LEAVES := 12

var _dust: Node2D
var _air: Array
var _leaves: Node2D
var _lights: Node2D
var _copy: BackBufferCopy
var _shock: MeshInstance2D

func _ready() -> void:
	super._ready()
	life = 1.4
	_dust = Art.drawer(false)
	add_child(_dust)
	_lights = Art.drawer(true)
	add_child(_lights)
	_air = Gusts.node(float(seed_id % 23))
	for node in _air: if node != null: add_child(node)
	_leaves = Art.drawer(false)
	add_child(_leaves)
	_copy = Art.backbuffer()
	add_child(_copy)
	_shock = Art.quad("shockwave")
	(_shock.material as ShaderMaterial).set_shader_parameter("tint", Vector3(0.85, 1.0, 0.9))
	add_child(_shock)
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _k() -> float: return sqrt(radius / 70.0)

func _update() -> void:
	var k := _k()
	var air := Gusts.data()
	var dust: Array = []
	var leaves: Array = []
	var lights: Array = []
	# The puff bursting: billows of white air rolling out in a ring and thinning.
	var smoke := Art.smoke()
	var burst := age / 0.9
	if burst < 1.0:
		for j in 10:
			var dir := Vector2.from_angle(TAU * j / 10.0 + rnd2(j + 80) * 0.3)
			var p := at + Vector2(dir.x, dir.y * 0.8) * radius * k * (0.2 + 1.3 * ease_out(burst, 3.0))
			var s := radius * k * (0.6 + 0.9 * burst)
			dust.append([smoke, p, Vector2(s * 1.3, s), dir.angle(), Color(0.95, 0.98, 1.0, 0.6 * pow(1.0 - burst, 1.3))])
	# A white swirl spinning open round the point.
	if age < 0.35:
		for s in 3:
			var points := PackedVector2Array()
			var open := ease_out(age / 0.3, 2.0)
			var from := age * 14.0 + TAU * s / 3.0
			for q in 12:
				var a := from + q * 0.28
				points.append(at + Vector2.from_angle(a) * radius * k * (0.3 + 1.2 * open) * (0.6 + 0.4 * q / 11.0))
			Gusts.band(air, points, 10.0 * k, 1.0 - age / 0.35, 1.0)
	# The blast: streaks of air rushing out, curling as they go.
	if age < 0.4:
		for j in ceili(STREAKS * Art.density()):
			var dir := Vector2.from_angle(TAU * j / STREAKS + rnd2(j) * 0.25)
			var out := ease_out(age / 0.3, 2.0)
			var points := PackedVector2Array()
			for s in 8:
				var r := radius * k * (0.3 + 1.8 * out * (0.4 + 0.6 * s / 7.0))
				points.append(at + dir.rotated(0.35 * out * s / 7.0) * r)
			points.reverse()
			Gusts.band(air, points, 6.0 * k, 0.8 * (1.0 - age / 0.4), 0.8, func(s: float) -> float: return 1.0 - s * 0.8)
	if age < 0.1: lights.append(Arcs.light(at, Vector2.ONE * radius * 2.6, Color(0.95, 0.98, 1.0, 0.6 * (1.0 - age / 0.1))))
	# The ripple through the air.
	var wave := age / 0.28
	_shock.visible = wave < 1.0 and Art.full()
	if _shock.visible:
		var side := radius * 6.0 * k
		var rect := Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		Art.place(_shock, rect)
		_copy.rect = rect
		var sm: ShaderMaterial = _shock.material
		sm.set_shader_parameter("radius", ease_out(wave, 2.0) * 0.95)
		sm.set_shader_parameter("strength", 0.03)
		sm.set_shader_parameter("glow", 0.15)
	elif wave < 1.0:
		lights.append(Arcs.light(at, Vector2.ONE * radius * 5.0 * ease_out(wave, 2.0), Color(0.85, 1.0, 0.92, 0.18 * (1.0 - wave))))
	# Leaves flung out, then fluttering down.
	for j in ceili(LEAVES * Art.density()):
		var span := 0.9 + 0.5 * rnd(j + 50)
		if age >= span: continue
		var dir := Vector2.from_angle(rnd(j + 51) * TAU)
		var flung := dir * (180.0 + 260.0 * rnd(j + 52)) * k * (1.0 - exp(-age * 6.0)) / 6.0
		var p := at + flung + Vector2(sin(age * 7.0 + j) * 12.0, 40.0 * age * age)
		p.y = minf(p.y, GROUND_Y - 3.0)
		var x := age / span
		leaves.append(Gusts.leaf_item(p, (11.0 + 6.0 * rnd(j + 53)) * k, age * 9.0 + j, age * 11.0 + j, Gusts.leaf_tone(rnd(j + 54), 1.0 - x * x)))
	# Dust kicked up off the floor.
	if GROUND_Y - at.y < radius * 1.6:
		for j in 5:
			var a := age - 0.02 * j
			if a < 0.0 or a > 1.0: continue
			var side := 1.0 if j % 2 == 0 else -1.0
			var p := Vector2(at.x + side * (30.0 + 160.0 * ease_out(a / 0.6, 2.0)) * k * (0.6 + 0.4 * rnd(j + 60)), GROUND_Y - 12.0 - 30.0 * a)
			dust.append([Art.smoke(), p, Vector2(100.0, 62.0) * k * (0.6 + a), rnd2(j + 61) * 0.2, Color(0.5, 0.45, 0.37, 0.26 * (1.0 - a))])
	Gusts.show(_air, air, age)
	for pair in [[_dust, dust], [_leaves, leaves], [_lights, lights]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()
