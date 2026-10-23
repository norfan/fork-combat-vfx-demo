extends "res://vfx/magic/magic_fx.gd"
## 寒霜结界 — ice that stays (path "stay"): a ring of crystals hovering round its start —
## start "target" puts it round the target, following it wherever it is knocked. Heavy cold
## mist pours off the crystals and pools round it, frost creeps over the floor beneath, and
## while the ring holds the target is slowed: it is knocked back, flies and falls at a
## fraction of its speed. It holds until the last landing (`charge + travel + interval ×
## (count − 1)`), then the crystals burst outwards into chips (pair a hit with each landing;
## the last is the burst).
##   charge — the crystals condense out of the air round it, ice dust drawn in
##   hold   — they hover and revolve slowly, each rolling about its own axis, glinting

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Crystal = preload("res://vfx/magic/ice/crystal.gd")
const RING := 8
## How fast the target goes while held (1 = unslowed).
const SLOW := 0.3
const BURST := 0.7
const MIST_LIFE := 1.5

var _frost: MeshInstance2D
var _mist: Node2D
var _lights: Node2D
var _ice: Array
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	life = _end() + BURST + MIST_LIFE * 0.5
	_frost = Art.quad("frost")
	(stage.get("under") as Node2D).add_child(_frost)
	_mist = Art.drawer(false)
	add_child(_mist)
	_lights = Art.drawer(true)
	add_child(_lights)
	_ice = Crystal.node(float(seed_id % 41))
	for node in _ice: if node != null: add_child(node)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_update()

func _exit_tree() -> void:
	if is_instance_valid(_frost): _frost.queue_free()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _end() -> float: return land(count - 1)

## Crystal j's place round the centre at time t: a tilted ring, revolving slowly, bobbing.
func _spot(j: int, t: float, centre: Vector2, open: float) -> Vector2:
	var a := TAU * j / RING + t * 0.7
	return centre + Vector2(cos(a) * 82.0, sin(a) * 30.0) * size * open + Vector2(0, sin(t * 3.0 + j) * 5.0)

func _update() -> void:
	var stop := _end()
	var centre := start_point(0)
	var ice := Crystal.data()
	var mist: Array = []
	var lights: Array = []
	var sparks: Array = []
	var open := ease_out(age / maxf(charge, 0.05), 2.5)
	var spin := Crystal.roll_speed(size * 0.7)
	var length := 46.0 * size
	if age < stop:
		# Slowed: the stage moves the target at this fraction of its speed this step.
		stage.set("target_slow", SLOW)
		# Back half of the ring first, so the front crystals sit in front of the target.
		var order := range(RING)
		order.sort_custom(func(x: int, y: int) -> bool: return sin(TAU * x / RING + age * 0.7) < sin(TAU * y / RING + age * 0.7))
		for j: int in order:
			var p := _spot(j, age, centre, open)
			var a := TAU * j / RING + age * 0.7
			var axis := Vector2(cos(a) * 0.45, -1.0).normalized()
			Crystal.prism_at(ice, p, axis, length * open, length * 0.2 * open, age * spin + j * 0.8, 0.9)
			var twinkle := sin(age * 7.0 + j * 1.9)
			if twinkle > 0.55: Crystal.sparkle(sparks, p + axis * length * 0.5, 11.0 * size, twinkle)
		lights.append(Arcs.light(centre, Vector2(220.0, 140.0) * size, Color(0.55, 0.85, 1.0, 0.3 * open)))
		if age < charge:
			for j in roundi(12 * Art.density()):
				var phase := fposmod(age / maxf(charge, 0.05) * 1.3 + rnd(j), 1.0)
				var p := centre + Vector2.from_angle(rnd(j + 20) * TAU) * (150.0 * (1.0 - phase) + 20.0) * size
				sparks.append([Art.glow(), p, Vector2.ONE * 4.0, 0.0, Color(0.88, 0.97, 1.0, phase)])
	else:
		# The burst: every crystal flung outwards, tumbling, shattering.
		var e := age - stop
		var x := clampf(e / BURST, 0.0, 1.0)
		for j in RING:
			var from := _spot(j, stop, centre, 1.0)
			var out := (from - centre).normalized()
			var state := ballistic(from, out * 520.0 + Vector2(0, -160), e, 1300.0)
			Crystal.prism_at(ice, state[0], Vector2.from_angle(e * 14.0 + j), length * (1.0 - 0.5 * x), length * 0.18, e * spin * 2.0 + j, 0.9 * (1.0 - x))
		if e < 0.1: Crystal.sparkle(sparks, centre, 70.0 * size, 1.0 - e / 0.1)
	_pour_mist(mist, centre, stop)
	# Frost under the ring while it is near the floor.
	var near := clampf(1.0 - (GROUND_Y - centre.y - 50.0) / 140.0, 0.0, 1.0)
	var w := 280.0 * size * open
	Art.place(_frost, Rect2(Vector2(centre.x - w * 0.5, GROUND_Y - w * 0.07), Vector2(w, w * 0.17)))
	var fm: ShaderMaterial = _frost.material
	fm.set_shader_parameter("fade", open * near * clampf(1.0 - (age - stop) / 0.8, 0.0, 1.0))
	fm.set_shader_parameter("seed", float(seed_id % 11))
	fm.set_shader_parameter("time", age)
	Crystal.show(_ice, ice, age)
	for pair in [[_mist, mist], [_lights, lights], [_sparks, sparks]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()

## Heavy cold mist pouring off the crystals: it sinks, spreads and pools round the target.
func _pour_mist(out: Array, centre: Vector2, stop: float) -> void:
	var smoke := Art.smoke()
	var rate := 34.0 * Art.density()
	for j in range(maxi(0, floori((age - MIST_LIFE) * rate)), floori(minf(age, stop) * rate) + 1):
		var born := float(j) / rate
		var a := age - born
		if a < 0.0 or a >= MIST_LIFE: continue
		var x := a / MIST_LIFE
		var from := _spot(j % RING, born, start_point(0), ease_out(born / maxf(charge, 0.05), 2.5))
		var drift := Vector2(rnd2(j + 1) * 50.0, 40.0 + 30.0 * rnd(j + 2)) * a
		var p := from + drift
		p.y = minf(p.y, GROUND_Y - 12.0)
		var tone := Color(0.84, 0.94, 1.0, 0.32 * pow(1.0 - x, 1.2) * smoothstep(0.0, 0.15, a))
		out.append([smoke, p, Vector2(1.5, 0.9) * size * (40.0 + 90.0 * sqrt(x)), rnd(j + 3) * TAU + x * 0.6, tone])
	# A low bank of fog round its feet, while it holds.
	var bank := clampf(age / 0.6, 0.0, 1.0) * clampf(1.0 - (age - stop) / 0.8, 0.0, 1.0)
	if bank > 0.0:
		for j in 3:
			var p := Vector2(centre.x + (float(j) - 1.0) * 70.0 * size + noise(j, age * 0.5) * 12.0, minf(centre.y + 40.0, GROUND_Y - 14.0))
			out.append([smoke, p, Vector2(200.0, 60.0) * size, noise(j + 5, age * 0.3) * 0.2, Color(0.84, 0.94, 1.0, 0.26 * bank)])
