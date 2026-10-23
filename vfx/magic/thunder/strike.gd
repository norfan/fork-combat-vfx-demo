extends "res://vfx/magic/magic_fx.gd"
## Where lightning lands, sized by the cast's blast `radius`: a blue-white flash (on real
## time), arcs bursting out of the point and flickering away, a fast spray of sparks that
## bounce off the floor, a shockwave cracking the air (a ring of light on the lighter
## tiers); at the floor a flare of light and a branching scar burnt into it — a Lichtenberg
## figure that spreads out in an instant, glows blue and cools to a dark mark under the
## target — with a wisp or two of smoke.

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const ROLL := 24.0
const SPARKS := 30

var _scar: MeshInstance2D
var _smoke: Node2D
var _lights: Node2D
var _arcs: MeshInstance2D
var _sparks: Node2D
var _copy: BackBufferCopy
var _shock: MeshInstance2D
## The scar's branches, each [points, width].
var _figure: Array = []

func _ready() -> void:
	super._ready()
	life = 1.5 if _near_ground() else 0.6
	if _near_ground():
		_grow_figure()
		_scar = MeshInstance2D.new()
		(stage.get("under") as Node2D).add_child(_scar)
	_smoke = Art.drawer(false)
	add_child(_smoke)
	_lights = Art.drawer(true)
	add_child(_lights)
	_arcs = Arcs.node()
	add_child(_arcs)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_copy = Art.backbuffer()
	add_child(_copy)
	_shock = Art.quad("shockwave")
	(_shock.material as ShaderMaterial).set_shader_parameter("tint", Vector3(0.6, 0.75, 1.0))
	add_child(_shock)
	_update()

func _exit_tree() -> void:
	if is_instance_valid(_scar): _scar.queue_free()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _near_ground() -> bool: return GROUND_Y - at.y < radius * 0.8 + 20.0

func _k() -> float: return radius / 60.0

## The Lichtenberg figure: branches random-walking out over the floor and forking, laid
## flat on it (squashed in depth).
func _grow_figure() -> void:
	var centre := Vector2(at.x, GROUND_Y + 1.0)
	var arms := 7
	for b in arms:
		var heading := TAU * b / arms + rnd2(b + 700) * 0.4
		_walk(centre, heading, radius * 1.7 * (0.7 + 0.5 * rnd(b + 701)), 4.0, b * 37, 2)

func _walk(from: Vector2, heading: float, length: float, width: float, key: int, forks: int) -> void:
	var points := PackedVector2Array([from])
	var steps := 9
	var p := from
	for s in steps:
		heading += rnd2(key + s * 3) * 0.55
		var step := Vector2.from_angle(heading) * length / steps
		p += Vector2(step.x, step.y * 0.2)
		points.append(p)
		if forks > 0 and s > 1 and rnd(key + s * 3 + 1) < 0.3:
			_walk(p, heading + rnd2(key + s * 3 + 2) * 1.0, length * 0.45, width * 0.6, key * 7 + s, forks - 1)
	_figure.append([points, width])

func _update() -> void:
	var k := _k()
	var frame := floori(age * ROLL)
	var lights: Array = []
	var sparks: Array = []
	var smoke: Array = []
	var mesh := Arcs.data()
	var blue := Color(0.6, 0.75, 1.0)
	var flash := clampf(flash_left(1, 0.12), 0.0, 1.0)
	if flash > 0.0:
		lights.append(Arcs.light(at, Vector2.ONE * radius * (4.0 if finisher else 2.4), Color(0.85, 0.92, 1.0, 0.85 * flash)))
		lights.append(Arcs.light(at, Vector2(radius * 10.0, radius * 0.25), Color(0.8, 0.9, 1.0, 0.8 * flash)))
	lights.append(Arcs.light(at, Vector2.ONE * radius * 4.0, Color(blue, 0.5 * clampf(1.0 - age / 0.3, 0.0, 1.0))))
	# Arcs bursting out of the point, flickering away.
	if age < 0.22:
		var count := roundi((8.0 if finisher else 6.0) * Art.density()) + 2
		for j in count:
			var key := frame * 71 + j * 13 + seed_id
			if age > 0.06 and Arcs.hash01(key + 5) < age / 0.22: continue
			var dir := Vector2.from_angle(rnd(j + 10) * TAU + Arcs.hash11(key) * 0.35)
			var reach := radius * (0.7 + 0.9 * rnd(j + 11)) * sqrt(k)
			var points := Arcs.bolt(at, at + dir * reach, key, 0.4, 6.0)
			Arcs.strip(mesh, points, 6.0 * sqrt(k), 0.9, 0.3)
			for twig: Array in Arcs.branches(points, key + 3, 1, reach * 0.4):
				Arcs.strip(mesh, twig[0], 3.5, 0.7, 0.35)
	# Sparks: fast, straight, bouncing off the floor.
	for j in ceili(SPARKS * Art.density()):
		var span := 0.3 + 0.35 * rnd(j + 100)
		if age >= span: continue
		var v := Vector2.from_angle(-PI * 0.5 + rnd2(j + 101) * 1.9) * (500.0 + 900.0 * rnd(j + 102)) * sqrt(k)
		var state := ballistic(at, v, age, 900.0)
		var x := age / span
		var tone := Color(0.95, 0.98, 1.0).lerp(Color(0.45, 0.35, 1.0), x)
		tone.a = 1.0 - x
		sparks.append([Art.glow(), state[0], Vector2(8.0 + (state[1] as Vector2).length() * 0.025, 3.0), (state[1] as Vector2).angle(), tone])
	# The air cracking.
	var wave := age / 0.2
	_shock.visible = wave < 1.0 and Art.full()
	if _shock.visible:
		var side := radius * 6.0
		var rect := Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		Art.place(_shock, rect)
		_copy.rect = rect
		var sm: ShaderMaterial = _shock.material
		sm.set_shader_parameter("radius", ease_out(wave, 2.5) * 0.95)
		sm.set_shader_parameter("strength", 0.03)
		sm.set_shader_parameter("width", 0.06)
	elif wave < 1.0:
		lights.append(Arcs.light(at, Vector2.ONE * radius * 6.0 * ease_out(wave, 2.5), Color(blue, 0.25 * (1.0 - wave))))
	if _near_ground(): _ground(mesh, lights, smoke)
	_arcs.mesh = Arcs.mesh(mesh)
	(_arcs.material as ShaderMaterial).set_shader_parameter("time", age)
	for pair in [[_lights, lights], [_sparks, sparks], [_smoke, smoke]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()

## At the floor: the flare, the scar glowing blue as it spreads and cooling to a dark mark,
## and smoke wisps off it.
func _ground(mesh: Dictionary, lights: Array, smoke: Array) -> void:
	var flare := clampf(1.0 - age / 0.5, 0.0, 1.0)
	if flare > 0.0: lights.append(Arcs.light(Vector2(at.x, GROUND_Y + 2.0), Vector2(radius * 12.0, radius * 1.5), Color(0.6, 0.75, 1.0, 0.8 * flare)))
	var spread_out := ease_out(age / 0.09, 2.0)
	var glow := clampf(1.0 - age / 0.7, 0.0, 1.0)
	var dark := Arcs.data()
	var fade := clampf(1.0 - (age - 0.4) / (life - 0.4), 0.0, 1.0)
	for branch: Array in _figure:
		var width: float = branch[1]
		if glow > 0.0: Arcs.strip(mesh, branch[0], width * 1.8, glow * 0.8, 0.35, spread_out)
		Arcs.strip(dark, branch[0], width * 0.6, fade, 1.0, spread_out)
	if is_instance_valid(_scar):
		_scar.mesh = Arcs.mesh(dark)
		# The vertex colour carries the fade in alpha; the mark itself is near black.
		_scar.modulate = Color(0.05, 0.05, 0.09)
	var texture := Art.smoke()
	for j in 4:
		var a := age - 0.15 - 0.12 * j
		if a < 0.0 or a > 1.0: continue
		var p := Vector2(at.x + rnd2(j + 800) * radius, GROUND_Y - 8.0 - 60.0 * a)
		smoke.append([texture, p, Vector2.ONE * radius * (0.5 + 0.8 * a), rnd(j + 801) * TAU, Color(0.2, 0.2, 0.26, 0.35 * (1.0 - a))])
