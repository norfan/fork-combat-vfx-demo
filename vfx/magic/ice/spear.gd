extends "res://vfx/magic/magic_fx.gd"
## One ice spear of an ice cast (spear `index` of the volley), from forming to landing.
## Ice never curves: whatever `path` says, it flies dead straight from its start to its
## mark. Cast from `self` with a volley, the spears form hovering in a cloud behind the
## caster, all aimed at the target, wait out the charge and then go — 暴雨梨花; the bigger
## the cloud (`spread`), the wider they hang.
## Body: a clear, double-pointed six-sided crystal, rolling about its long axis as it goes
## (the bigger, the slower) so the light slides from face to face; bright ridges, a glint,
## fractures glimmering inside, and on the 炸裂 tier the world seen bent through it.
## Accessories, all driven by the body:
##   forming — it grows in jumps, spinning up as it does; ice dust drifts into it, faint cold
##             air curls round it and frost creeps over the floor under the caster
##   launch  — a breath of frost where it leaves and a ring of glints
##   flight  — thin wisps of cold air trailing off it, glittering ice dust left hanging in
##             its wake, streaks of cold air behind it (longer the faster it flies), a cold
##             glow round it, and (炸裂 tier) the air behind it shimmering
##   landing — the spear is gone (the shatter takes over); its wake glitters away.

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Crystal = preload("res://vfx/magic/ice/crystal.gd")
## Spear length and radius at size 1, px.
const LENGTH := 92.0
const RADIUS := 13.0
const WAKE := 0.8

var _frost: MeshInstance2D
var _mist: Node2D
var _copy: BackBufferCopy
var _haze: MeshInstance2D
var _lights: Node2D
var _body: Array
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	life = gone(index) + WAKE
	if index == 0:
		_frost = Art.quad("frost")
		(stage.get("under") as Node2D).add_child(_frost)
	_mist = Art.drawer(false)
	add_child(_mist)
	_copy = Art.backbuffer()
	add_child(_copy)
	_haze = Art.quad("heat_haze")
	(_haze.material as ShaderMaterial).set_shader_parameter("warmth", 0.0)
	add_child(_haze)
	_lights = Art.drawer(true)
	add_child(_lights)
	_body = Crystal.node(float(seed_id % 37), not _swarm())
	for node in _body: if node != null: add_child(node)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_update()

func _exit_tree() -> void:
	if is_instance_valid(_frost): _frost.queue_free()

## A swarm (more than a handful at once) skips the costly extras.
func _swarm() -> bool: return count > 6

## Straight, always: start to mark. A swarm's spears each pick a spot on the target.
func path_at(i: int, u: float) -> Vector2:
	var s := pow(clampf(u, 0.0, 1.0), ease)
	var mark := end_point(i)
	if count > 1 and end != "at": mark += Vector2(rnd2(i * 3 + 500) * 14.0, rnd2(i * 3 + 501) * 34.0)
	return start_point(i).lerp(mark, s)

## From `self` a volley hangs in a cloud behind and above the caster, bobbing until it
## launches (then its start holds still, so the flight stays straight).
func start_point(i: int) -> Vector2:
	if start != "self" or count < 2: return super.start_point(i)
	var t := minf(maxf(age, 0.0), launch(i))
	var a := float(i) * 2.39996
	var r := sqrt((float(i) + 0.5) / count) * maxf(spread, 40.0) * 2.6
	return body_of_caster() + Vector2(-30.0, -60.0) + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.8) + Vector2(0, sin(t * 4.0 + i) * 4.0)

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var t0 := born(index)
	var t1 := launch(index)
	var t2 := land(index)
	var mist: Array = []
	var lights: Array = []
	var sparks: Array = []
	var crystal := Crystal.data()
	var pos := path_at(index, 0.0)
	var dir := (path_at(index, 0.05) - pos).normalized()
	var speed := 0.0
	var grow := 1.0
	var alive := age >= t0 and age < gone(index)
	# It rolls the whole time, spinning up as it forms; the bigger, the slower.
	var spin := Crystal.roll_speed(size)
	var roll := (age - t0) * spin * 0.5 + seed_id
	if age < t1:
		var k := clampf((age - t0) / maxf(charge, 0.01), 0.0, 1.0)
		grow = 0.15 + 0.85 * floorf(ease_out(k, 1.6) * 6.0) / 6.0
		roll = spin * 0.5 * (age - t0) * k + seed_id
		_gather(mist, sparks, pos, k)
	elif age < t2:
		var u := (age - t1) / maxf(travel, 0.01)
		pos = path_at(index, u)
		var v := velocity_at(index, u)
		speed = v.length()
		dir = v.normalized()
		roll = spin * (age - t1) + spin * 0.25 * charge + seed_id
	else:
		# Lingering: stuck where it landed, a third of it sunk in, still glinting.
		dir = velocity_at(index, 1.0).normalized()
		pos = path_at(index, 1.0) + dir * LENGTH * size * 0.3
		roll = spin * travel + spin * 0.25 * charge + seed_id
	if alive:
		var length := LENGTH * size * grow
		Crystal.prism_at(crystal, pos - dir * length * 0.1, dir, length, RADIUS * size * grow, roll, 0.95)
		lights.append(Arcs.light(pos, Vector2(length * 2.2, RADIUS * size * 6.0), Color(0.5, 0.85, 1.0, 0.3)))
		# The point flashes as the light crosses it.
		Crystal.sparkle(sparks, pos + dir * length * 0.4, 18.0 * size, 0.3 + 0.7 * maxf(cos(roll * 2.0), 0.0))
	# Cold air streaming off it, longer the faster it flies.
	var stretch := clampf(speed / 1400.0, 0.0, 1.6)
	if alive and stretch > 0.05:
		for j in 3:
			var off := dir.orthogonal() * (float(j) - 1.0) * RADIUS * size * 1.1
			var tail := pos - dir * LENGTH * size * (0.5 + 1.8 * stretch) * (0.7 + 0.3 * rnd(j + 40)) + off
			var head := pos - dir * LENGTH * size * 0.35 + off
			sparks.append([Art.glow(), (head + tail) * 0.5, Vector2(head.distance_to(tail), 2.5 * size), dir.angle(), Color(0.8, 0.95, 1.0, 0.3)])
	_haze.visible = alive and Art.full() and stretch > 0.05 and not _swarm()
	if _haze.visible:
		var length := LENGTH * size * (1.5 + 2.5 * stretch)
		_haze.transform = Transform2D(dir.angle(), pos) * Transform2D(0.0, Vector2(length + RADIUS * 4.0 * size, RADIUS * 6.0 * size), 0.0, Vector2(-length, -RADIUS * 3.0 * size))
		_copy.rect = Rect2(pos - Vector2.ONE * (length + 40.0), Vector2.ONE * (length + 40.0) * 2.0)
		var hm: ShaderMaterial = _haze.material
		hm.set_shader_parameter("time", age)
		hm.set_shader_parameter("strength", 0.005)
	if age >= t1: _wake(mist, sparks, t1, t2)
	_launch_breath(mist, sparks)
	_floor_frost()
	Crystal.show(_body, crystal, age + index * 0.3)
	for pair in [[_mist, mist], [_lights, lights], [_sparks, sparks]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()

## While it forms: ice dust drifting in, faint cold air curling round it.
func _gather(mist: Array, sparks: Array, at: Vector2, k: float) -> void:
	for j in roundi(14 * Art.density() / sqrt(float(count))):
		var phase := fposmod(k * 1.4 + rnd(j), 1.0)
		var dir := Vector2.from_angle(rnd(j + 20) * TAU + phase * 1.5)
		var p := at + dir * (110.0 * (1.0 - phase) + 8.0) * size
		sparks.append([Art.glow(), p, Vector2.ONE * 4.0 * size, 0.0, Color(0.85, 0.97, 1.0, phase * (0.4 + 0.6 * k))])
		if j % 4 == 0: Crystal.sparkle(sparks, p, 8.0 * size, phase * k)
	var smoke := Art.smoke()
	for j in 4:
		var a := rnd(j + 50) * TAU + age * 1.4
		var p := at + Vector2.from_angle(a) * 26.0 * size
		mist.append([smoke, p, Vector2(70.0, 26.0) * size * (0.5 + k), a + PI * 0.5, Color(0.85, 0.95, 1.0, 0.1 * k)])

## A breath of frost where it leaves, and a ring of glints.
func _launch_breath(mist: Array, sparks: Array) -> void:
	var e := age - launch(index)
	if e < 0.0 or e > 0.6: return
	var from := path_at(index, 0.0)
	var x := e / 0.6
	mist.append([Art.smoke(), from + Vector2(0, -16.0 * x), Vector2(90.0, 40.0) * size * (1.0 + x), rnd(3) * TAU, Color(0.88, 0.96, 1.0, 0.16 * (1.0 - x))])
	if e < 0.2:
		for j in 6:
			var p := from + Vector2.from_angle(TAU * j / 6.0) * (20.0 + 150.0 * e) * size
			Crystal.sparkle(sparks, p, 10.0 * size, 1.0 - e / 0.2)

## Its wake: thin wisps of cold air and ice dust left hanging, glittering as it thins.
func _wake(mist: Array, sparks: Array, t1: float, t2: float) -> void:
	var smoke := Art.smoke()
	var rate := 50.0 * Art.density() / sqrt(float(count))
	for j in range(maxi(ceili(t1 * rate), floori((age - WAKE) * rate)), floori(minf(age, t2) * rate) + 1):
		var tb := float(j) / rate
		var a := age - tb
		if a < 0.0 or a >= WAKE: continue
		var u := (tb - t1) / maxf(travel, 0.01)
		var x := a / WAKE
		var heading := velocity_at(index, u).normalized()
		var p := path_at(index, u) + Vector2(rnd2(j) * 8.0, 8.0 * a + rnd2(j + 1) * 6.0) * size
		# Long thin wisps lying along the path, not puffs.
		mist.append([smoke, p, Vector2(70.0 + 60.0 * x, 14.0 + 22.0 * x) * size, heading.angle(), Color(0.85, 0.95, 1.0, 0.13 * pow(1.0 - x, 1.4) * smoothstep(0.0, 0.08, a))])
	var dust_rate := 70.0 * Art.density() / sqrt(float(count))
	var dust_life := 0.75
	for j in range(maxi(ceili(t1 * dust_rate), floori((age - dust_life) * dust_rate)), floori(minf(age, t2) * dust_rate) + 1):
		var tb := float(j) / dust_rate
		var a := age - tb
		if a < 0.0 or a >= dust_life: continue
		var u := (tb - t1) / maxf(travel, 0.01)
		var p := path_at(index, u) + Vector2(rnd2(j + 10) * 20.0 + sin(a * 8.0 + j) * 5.0, rnd2(j + 11) * 12.0 + 40.0 * a) * size
		var x := a / dust_life
		var twinkle := 0.5 + 0.5 * sin(a * 26.0 + j * 1.3)
		sparks.append([Art.glow(), p, Vector2.ONE * 3.5 * size, 0.0, Color(0.88, 0.97, 1.0, (1.0 - x) * (0.4 + 0.6 * twinkle))])
		if rnd(j + 12) < 0.15: Crystal.sparkle(sparks, p, 8.0 * size, (1.0 - x) * twinkle)

## Frost spreading over the floor under the caster while it forms, thawing after.
func _floor_frost() -> void:
	if not is_instance_valid(_frost): return
	var spread_out := ease_out(age / maxf(charge, 0.05), 2.0)
	var thaw := clampf(1.0 - (age - launch(index)) / 0.9, 0.0, 1.0)
	var w := 150.0 * size * spread_out
	Art.place(_frost, Rect2(Vector2(feet().x - w * 0.5, GROUND_Y - w * 0.08), Vector2(w, w * 0.2)))
	var fm: ShaderMaterial = _frost.material
	fm.set_shader_parameter("fade", spread_out * thaw)
	fm.set_shader_parameter("seed", float(seed_id % 17))
	fm.set_shader_parameter("time", age)
