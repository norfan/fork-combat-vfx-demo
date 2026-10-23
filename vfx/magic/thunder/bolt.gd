extends "res://vfx/magic/magic_fx.gd"
## One lightning strike of a thunder cast (strike `index` of the volley).
## Body: the trunk, a jagged channel along the spell's path (its shape holds through the
## strike, only the fine crackle re-rolls). It charges, reaches out and strikes:
##   charge — a crackling orb gathers at the start, sparks drawn into it, small arcs
##            spitting off it and now and then lashing out; the air darkens around the
##            caster, and from the sky a storm cloud rolls in, lit from inside
##   leader — a thin stepped leader feels its way down the path, a spark at its head and
##            short feelers probing off it, faster or slower on the speed curve
##   strike — the return stroke: the whole channel at full power with branches, pulsing
##            through a few re-strikes, small arcs crawling along it (thick at the first
##            stroke, thinning out), its light on everything, the screen whiting out
##   after  — a faint violet afterimage of the channel, fading.
## Lands at the start of the strike; `hold` is how long it keeps pulsing.

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
## Small arcs and feelers re-rolled per second.
const ROLL := 30.0
## The trunk's glow half-width at size 1, px.
const HALF := 13.0
## Re-strikes, seconds into the strike.
const PULSES := [0.0, 0.05, 0.11, 0.18]
const AFTERIMAGE := 0.35

var jag := 0.28
var _shade: Node2D
var _lights: Node2D
var _bolt: MeshInstance2D
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	life = land(index) + hold + AFTERIMAGE
	_shade = Art.drawer(false)
	add_child(_shade)
	_lights = Art.drawer(true)
	add_child(_lights)
	_bolt = Arcs.node()
	add_child(_bolt)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

## From the sky a bolt comes almost straight down out of its cloud.
func start_point(i: int) -> Vector2:
	if start == "sky": return Vector2(aim().x - 70.0 + (float(i) - _middle()) * spread, 80.0)
	return super.start_point(i)

## The channel: the path kinked into a fractal zigzag; its shape is fixed per strike, with
## a pixel or two of crackle re-rolled every frame.
func _channel(crackle: int) -> PackedVector2Array:
	var backbone := PackedVector2Array()
	for k in 9: backbone.append(path_at(index, k / 8.0))
	var length := 0.0
	for k in range(1, backbone.size()): length += backbone[k].distance_to(backbone[k - 1])
	var depth := clampi(ceili(log(maxf(length / 8.0, 1.0) / 6.0) / log(2.0)), 1, 6)
	var points := Arcs.jag(backbone, seed_id * 31 + index * 7, jag, depth)
	for k in range(1, points.size() - 1):
		var side := (points[k + 1] - points[k - 1]).normalized().orthogonal()
		points[k] += side * Arcs.hash11(crackle * 1009 + k) * 1.5 * size
	return points

func _update() -> void:
	var t0 := born(index)
	var t1 := launch(index)
	var t2 := land(index)
	var frame := floori(maxf(age, 0.0) * ROLL)
	var shade: Array = []
	var lights: Array = []
	var sparks: Array = []
	var mesh := Arcs.data()
	var from := start_point(index)
	var sky := start == "sky"
	var glow := Art.glow()
	var blue := Color(0.55, 0.7, 1.0)
	var e := age - t2
	# How dark the air is: it darkens through the charge, holds while the leader runs, and
	# clears as the strike lights everything up.
	var dark := 0.0
	if age >= t0 and age < t1: dark = ease_out((age - t0) / maxf(charge, 0.01), 1.6)
	elif age >= t1 and e < 0.0: dark = 1.0
	elif e >= 0.0: dark = clampf(1.0 - e / 0.12, 0.0, 1.0)
	if dark > 0.0: shade.append([null, Vector2(640, 360), Vector2(1600, 1100), 0.0, Color(0.02, 0.03, 0.08, (0.42 if sky else 0.22) * dark)])
	if sky: _cloud(shade, lights, from, frame, e)
	if age >= t0 and age < t1:
		_charge(mesh, lights, sparks, from, clampf((age - t0) / maxf(charge, 0.01), 0.0, 1.0), frame)
	elif age >= t1 and e < 0.0:
		# The stepped leader: jumps down the channel, a spark at its head.
		var u := (age - t1) / maxf(travel, 0.001)
		var reach := floorf(pow(u, ease) * 9.0) / 9.0 + 0.04
		var channel := _channel(frame)
		Arcs.strip(mesh, channel, 5.0 * size, 0.55, 0.3, reach)
		var head := channel[mini(int(reach * (channel.size() - 1)), channel.size() - 1)]
		lights.append(Arcs.light(head, Vector2.ONE * 70.0 * size, Color(0.75, 0.85, 1.0, 0.8)))
		lights.append(Arcs.light(from, Vector2.ONE * 110.0 * size, Color(blue, 0.5)))
		for feeler: Array in Arcs.branches(PackedVector2Array(channel.slice(0, maxi(int(reach * channel.size()), 2))), frame + seed_id, 2, 50.0 * size):
			Arcs.strip(mesh, feeler[0], 3.0 * size, 0.5, 0.35)
	elif e >= 0.0 and e < hold:
		_strike(mesh, lights, sparks, from, e, frame)
	elif e >= hold and e < hold + AFTERIMAGE:
		var x := (e - hold) / AFTERIMAGE
		Arcs.strip(mesh, _channel(0), HALF * 0.55 * size, 0.28 * (1.0 - x) * (1.0 - x), 0.0)
	_bolt.mesh = Arcs.mesh(mesh)
	(_bolt.material as ShaderMaterial).set_shader_parameter("time", age)
	for pair in [[_shade, shade], [_lights, lights], [_sparks, sparks]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()

## The orb gathering at the start: its light swells, arcs spit off it and sparks stream in.
func _charge(mesh: Dictionary, lights: Array, sparks: Array, at: Vector2, k: float, frame: int) -> void:
	var r := 22.0 * size * (0.45 + 0.55 * k)
	lights.append(Arcs.light(at, Vector2.ONE * r * (5.0 + 2.0 * k), Color(0.5, 0.65, 1.0, 0.35 + 0.45 * k)))
	lights.append(Arcs.light(at, Vector2.ONE * r * 1.6, Color(0.9, 0.95, 1.0, 0.6 + 0.4 * k)))
	var arcs := roundi((4.0 + 5.0 * k) * Art.density()) + 1
	for j in arcs:
		var key := frame * 97 + j * 13 + seed_id
		var a := Vector2.from_angle(Arcs.hash01(key) * TAU)
		var b := Vector2.from_angle(Arcs.hash01(key + 1) * TAU)
		Arcs.strip(mesh, Arcs.bolt(at + a * r * 0.35, at + b * r * (0.9 + 0.9 * Arcs.hash01(key + 2)), key, 0.4, 5.0), 3.2 * size, 0.85, 0.35)
	# Now and then it lashes out at the air (or the floor, when it is low).
	if Arcs.hash01(frame * 7 + seed_id) < 0.25 + 0.5 * k:
		var key := frame * 53 + seed_id
		var reach := Vector2.from_angle(Arcs.hash01(key) * TAU) * (60.0 + 70.0 * Arcs.hash01(key + 1)) * size
		var end := at + reach
		if GROUND_Y - at.y < 140.0: end = Vector2(at.x + reach.x, GROUND_Y)
		Arcs.strip(mesh, Arcs.bolt(at, end, key, 0.35, 6.0), 4.0 * size, 0.8, 0.3)
	for j in roundi(14 * Art.density()):
		var phase := fposmod(k * 1.8 + rnd(j), 1.0)
		var dir := Vector2.from_angle(rnd(j + 20) * TAU)
		var p := at + dir * (130.0 * (1.0 - phase) + 12.0) * size
		sparks.append([Art.glow(), p, Vector2(8.0 + 22.0 * (1.0 - phase), 3.0) * size, dir.angle(), Color(0.7, 0.85, 1.0, phase * (0.4 + 0.6 * k))])

## The return stroke and its re-strikes.
func _strike(mesh: Dictionary, lights: Array, sparks: Array, from: Vector2, e: float, frame: int) -> void:
	var power := 0.0
	var pulse := 0
	for i in PULSES.size():
		var since := e - float(PULSES[i])
		if since >= 0.0:
			power = maxf(power, exp(-since / 0.03))
			pulse = i
	# Between re-strikes it flickers low; it dies out over the end of the hold.
	power = maxf(power, 0.22 + 0.18 * rnd(frame * 3 + 1)) * clampf((hold - e) / 0.08, 0.0, 1.0)
	var channel := _channel(frame)
	var length := channel[0].distance_to(channel[-1])
	Arcs.strip(mesh, channel, HALF * size * (0.75 + 0.6 * power), power, 0.2 + 0.08 * power)
	for branch: Array in Arcs.branches(channel, seed_id * 5 + pulse * 17, roundi(7 * Art.density()) + 1, length * 0.24):
		Arcs.strip(mesh, branch[0], HALF * 0.42 * size, power * 0.75, 0.3)
		for twig: Array in Arcs.branches(branch[0], seed_id * 11 + pulse * 7 + int(float(branch[1]) * 100.0), 1, length * 0.08):
			Arcs.strip(mesh, twig[0], HALF * 0.25 * size, power * 0.6, 0.35)
	# Small arcs crawling along the trunk: thick at the stroke, thinning out after.
	var crawl := roundi((3.0 + 12.0 * power) * Art.density())
	for j in crawl:
		var key := frame * 131 + j * 17 + seed_id
		var at := int(Arcs.hash01(key) * (channel.size() - 2)) + 1
		var p := channel[at]
		var side := (channel[at + 1] - channel[at - 1]).normalized().orthogonal()
		var q := p + side.rotated(Arcs.hash11(key + 1) * 1.2) * (14.0 + 30.0 * Arcs.hash01(key + 2)) * size * (1.0 if Arcs.hash01(key + 3) > 0.5 else -1.0)
		Arcs.strip(mesh, Arcs.bolt(p, q, key, 0.45, 5.0), 3.0 * size, 0.9 * (0.4 + 0.6 * power), 0.35)
	# Its light: on the start, the end and along the channel, and the screen whiting out.
	var blue := Color(0.6, 0.75, 1.0)
	lights.append(Arcs.light(channel[-1], Vector2.ONE * (radius * 3.0 + 70.0 * power), Color(blue, 0.5 * power + 0.1)))
	lights.append(Arcs.light(from, Vector2.ONE * 150.0 * size, Color(blue, 0.5 * power + 0.1)))
	for j in 3:
		var p := channel[int((j + 1) / 4.0 * (channel.size() - 1))]
		lights.append(Arcs.light(p, Vector2.ONE * 220.0 * size, Color(blue, 0.3 * power)))
	if GROUND_Y - channel[-1].y < 80.0:
		lights.append(Arcs.light(Vector2(channel[-1].x, GROUND_Y + 2.0), Vector2(radius * 12.0, radius * 1.6), Color(blue, 0.8 * power)))
	var flash := flash_left(index, 0.09)
	if flash > 0.0: lights.append([null, Vector2(640, 360), Vector2(1600, 1100), 0.0, Color(0.75, 0.85, 1.0, (0.3 if start == "sky" else 0.06) * flash)])
	# A spray of sparks where it leaves the hand.
	if start != "sky" and e < 0.2:
		for j in roundi(10 * Art.density()):
			var dir := Vector2.from_angle((channel[1] - channel[0]).angle() + PI + rnd2(j + 400) * 1.6)
			var q := from + dir * (300.0 + 400.0 * rnd(j + 401)) * e
			sparks.append([Art.glow(), q, Vector2(14.0, 3.0) * size, dir.angle(), Color(0.8, 0.9, 1.0, 1.0 - e / 0.2)])

## A storm cloud rolling in over the strike, lit from inside, flaring with every stroke.
func _cloud(shade: Array, lights: Array, centre: Vector2, frame: int, e: float) -> void:
	var gather := ease_out(age / 0.3, 2.0) * clampf((life - age) / 0.35, 0.0, 1.0)
	if gather <= 0.0: return
	var smoke := Art.smoke()
	for j in 16:
		var p := centre + Vector2(rnd2(j + 600) * 300.0 + noise(j, age * 0.6) * 20.0, -70.0 + rnd(j + 601) * 80.0)
		var s := (170.0 + 130.0 * rnd(j + 602)) * gather
		# Slate against the night, a paler underside where the light catches it.
		shade.append([smoke, p, Vector2(s * 1.4, s), rnd(j + 603) * TAU + age * 0.2, Color(0.14, 0.15, 0.24, 0.9)])
		shade.append([smoke, p + Vector2(0, s * 0.18), Vector2(s * 1.1, s * 0.6), rnd(j + 604) * TAU, Color(0.22, 0.24, 0.36, 0.5)])
		var lit := e >= 0.0 and e < hold
		if Arcs.hash01(frame * 11 + j) > (0.55 if lit else 0.93):
			lights.append(Arcs.light(p + Vector2(0, 10), Vector2(s * 0.9, s * 0.6), Color(0.5, 0.6, 1.0, 0.45 if lit else 0.25)))
