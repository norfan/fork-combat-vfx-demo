extends "res://vfx/magic/magic_fx.gd"
## One air puff of a wind cast (puff `index` of the volley), from gathering to landing.
## Body: a small white mass of air — soft billows churning round a bright heart, wrapped in
## two white swirls spinning round it — squashed long along its flight the faster it goes.
## Wind curves freely (its default path is an arc).
## Accessories, all driven by the body:
##   gathering — air spirals in to the start in quick streaks and the puff winds itself
##               up out of nothing, a few leaves whirled in; dust lifts when it is low
##   flight    — small puffs of air shed off it that slow, swell and thin away, a couple of
##               faint streaks behind it (longer the faster it goes), a soft white glow, a
##               leaf or two caught in its wake, dust ripped off the floor when it skims low
##   landing   — the puff is gone (the gust takes over); its wake thins away.

const Art = preload("res://vfx/magic/magic_art.gd")
const Gusts = preload("res://vfx/magic/wind/gusts.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
## The puff's radius at size 1, px.
const RADIUS := 26.0
const WAKE := 0.7
const LEAF_LIFE := 1.2

var _dust: Node2D
var _air: Node2D
var _swirl: Array
var _glow: Node2D
var _leaves: Node2D

func _ready() -> void:
	super._ready()
	life = land(index) + LEAF_LIFE
	_dust = Art.drawer(false)
	add_child(_dust)
	_air = Art.drawer(false)
	add_child(_air)
	_glow = Art.drawer(true)
	add_child(_glow)
	_swirl = Gusts.node(float(seed_id % 29), false)
	for node in _swirl: if node != null: add_child(node)
	_leaves = Art.drawer(false)
	add_child(_leaves)
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var t0 := born(index)
	var t1 := launch(index)
	var t2 := land(index)
	var swirl := Gusts.data()
	var air: Array = []
	var glow: Array = []
	var dust: Array = []
	var leaves: Array = []
	if age >= t1: _wake(air, glow, swirl, leaves, dust, t1, t2)
	if age >= t0 and age < t1:
		var k := clampf((age - t0) / maxf(charge, 0.01), 0.0, 1.0)
		var at := start_point(index)
		_gather(swirl, leaves, dust, at, k)
		_body(air, glow, swirl, at, Vector2.RIGHT, 0.0, 0.2 + 0.8 * ease_out(k, 2.0))
	elif age >= t1 and age < t2:
		var u := (age - t1) / maxf(travel, 0.01)
		var v := velocity_at(index, u)
		_body(air, glow, swirl, path_at(index, u), v.normalized(), v.length(), 1.0)
	Gusts.show(_swirl, swirl, age)
	for pair in [[_dust, dust], [_air, air], [_glow, glow], [_leaves, leaves]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()

## The puff: billows churning round a bright heart, squashed along `dir` by its speed, two
## swirls spinning round it.
func _body(air: Array, glow: Array, swirl: Dictionary, at: Vector2, dir: Vector2, speed: float, grow: float) -> void:
	var r := RADIUS * size * grow
	var stretch := 1.0 + clampf(speed / 1300.0, 0.0, 0.9)
	var smoke := Art.smoke()
	var spin := age * 11.0
	var angle := dir.angle()
	glow.append(Arcs.light(at, Vector2(r * 5.5 * stretch, r * 4.5), Color(0.92, 0.97, 1.0, 0.35)))
	for k in 6:
		var a := spin + TAU * k / 6.0
		var off := Vector2(cos(a) * stretch, sin(a)) * r * 0.42
		air.append([smoke, at + off.rotated(angle), Vector2(r * 1.15 * stretch, r * 1.0), a + angle, Color(0.95, 0.98, 1.0, 0.55)])
	air.append([smoke, at, Vector2(r * 1.5 * stretch, r * 1.3), angle - spin * 0.5, Color(1.0, 1.0, 1.0, 0.75)])
	glow.append(Arcs.light(at, Vector2(r * 1.6 * stretch, r * 1.3), Color(1.0, 1.0, 1.0, 0.55)))
	# Two swirls wrapping it, spinning.
	for s in 2:
		var points := PackedVector2Array()
		var from := spin * 1.3 + PI * s
		for k in 12:
			var a := from + k * 0.3
			var rr := r * (1.05 + 0.25 * k / 11.0)
			points.append(at + (Vector2(cos(a) * stretch, sin(a)) * rr).rotated(angle))
		Gusts.band(swirl, points, r * 0.32, 0.9 * grow, 1.0)

## While it gathers: air spiralling in, a leaf or two whirled in, dust when it is low.
func _gather(swirl: Dictionary, leaves: Array, dust: Array, at: Vector2, k: float) -> void:
	for j in roundi(6 * Art.density()) + 2:
		var phase := fposmod(k * 1.6 + rnd(j), 1.0)
		var r := (120.0 * (1.0 - phase) + 20.0) * size
		var a0 := rnd(j + 10) * TAU + phase * 3.0
		var points := PackedVector2Array()
		for s in 9:
			var a := a0 + s * 0.14
			points.append(at + Vector2(cos(a), sin(a) * 0.75) * (r + s * 4.0 * size))
		Gusts.band(swirl, points, 8.0 * size, 0.75 * phase, 0.8)
	for j in 3:
		var phase := fposmod(k * 1.3 + rnd(j + 30), 1.0)
		var a := rnd(j + 31) * TAU + phase * 5.0
		var p := at + Vector2(cos(a), sin(a) * 0.6) * (100.0 * (1.0 - phase) + 14.0) * size
		leaves.append(Gusts.leaf_item(p, 11.0 * size, a * 2.0, age * 12.0 + j, Gusts.leaf_tone(rnd(j + 32), phase)))
	if GROUND_Y - at.y < 120.0:
		for j in 3:
			var p := Vector2(at.x + cos(age * 4.0 + j * 2.1) * 50.0 * size, GROUND_Y - 12.0)
			dust.append([Art.smoke(), p, Vector2(72.0, 44.0) * size * (0.5 + k), rnd2(j) * 0.2, Color(0.5, 0.45, 0.37, 0.18 * k)])

## Its wake: little puffs shed off it that slow, swell and thin; faint streaks; a leaf or
## two; dust off the floor when it skims low.
func _wake(air: Array, glow: Array, swirl: Dictionary, leaves: Array, dust: Array, t1: float, t2: float) -> void:
	var smoke := Art.smoke()
	var rate := 40.0 * Art.density() / sqrt(float(count))
	for j in range(maxi(ceili(t1 * rate), floori((age - WAKE) * rate)), floori(minf(age, t2) * rate) + 1):
		var tb := float(j) / rate
		var a := age - tb
		if a < 0.0 or a >= WAKE: continue
		var u := (tb - t1) / maxf(travel, 0.01)
		var x := a / WAKE
		var v := velocity_at(index, u)
		var p := path_at(index, u) + v * 0.08 * (1.0 - exp(-a * 8.0)) + Vector2(rnd2(j), rnd2(j + 1)) * RADIUS * size * 0.6
		var s := RADIUS * size * (0.5 + 1.2 * sqrt(x)) * (0.7 + 0.5 * rnd(j + 2))
		air.append([smoke, p, Vector2(s * 1.3, s), v.angle() + rnd2(j + 3) * 0.5, Color(0.92, 0.97, 1.0, 0.42 * pow(1.0 - x, 1.5) * smoothstep(0.0, 0.06, a))])
	# Faint streaks over the last stretch of path.
	var newest := minf(age, t2)
	var oldest := maxf(t1, age - 0.14)
	if newest - oldest > 0.01:
		for line in 3:
			var off := (float(line) - 1.0) * RADIUS * size * 0.7
			var stop := lerpf(newest, oldest, 0.5 + 0.5 * rnd(line + 70))
			var points := PackedVector2Array()
			for s in 10:
				var tk := lerpf(newest, stop, s / 9.0)
				var u := (tk - t1) / maxf(travel, 0.01)
				points.append(path_at(index, u) + velocity_at(index, u).normalized().orthogonal() * off)
			var fade := 1.0 if age < t2 else clampf(1.0 - (age - t2) / 0.14, 0.0, 1.0)
			Gusts.band(swirl, points, 3.0 * size, 0.45 * fade, 0.7, func(s: float) -> float: return 1.0 - s)
	var leaf_rate := 8.0 * Art.density()
	for j in range(maxi(ceili(t1 * leaf_rate), floori((age - LEAF_LIFE) * leaf_rate)), floori(minf(age, t2) * leaf_rate) + 1):
		var tb := float(j) / leaf_rate
		var a := age - tb
		if a < 0.0 or a >= LEAF_LIFE: continue
		var u := (tb - t1) / maxf(travel, 0.01)
		var drift := velocity_at(index, u) * 0.3 * (1.0 - exp(-a * 5.0)) / 5.0
		var p := path_at(index, u) + drift + Vector2(sin(a * 6.0 + j) * 12.0, 50.0 * a * a)
		p.y = minf(p.y, GROUND_Y - 3.0)
		var x := a / LEAF_LIFE
		leaves.append(Gusts.leaf_item(p, 10.0 * size, a * 8.0 + j, a * 9.0 + j, Gusts.leaf_tone(rnd(j + 4), 1.0 - x * x)))
	var dust_rate := 24.0 * Art.density()
	for j in range(maxi(ceili(t1 * dust_rate), floori((age - 0.8) * dust_rate)), floori(minf(age, t2) * dust_rate) + 1):
		var tb := float(j) / dust_rate
		var a := age - tb
		if a < 0.0 or a >= 0.8: continue
		var p0 := path_at(index, (tb - t1) / maxf(travel, 0.01))
		if GROUND_Y - p0.y > 110.0: continue
		var x := a / 0.8
		dust.append([smoke, Vector2(p0.x + rnd2(j) * 20.0 - 40.0 * a, GROUND_Y - 10.0 - 30.0 * a), Vector2(64.0, 40.0) * size * (0.6 + x), rnd2(j + 5) * 0.2, Color(0.5, 0.45, 0.37, 0.2 * (1.0 - x))])
