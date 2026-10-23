extends "res://vfx/magic/shapes/shape.gd"
## 法阵 circle — a magic circle standing upright at its start, `radius` px across the
## middle, drawn behind the caster and the target. Through the charge one emblem per
## material — a small circle of it with a glyph inside and its body at the heart — flies in
## from far off and slams into its place round the rim; then the rings draw themselves
## round, the arcs between the emblems each in its emblem's material, a star joining the
## emblems, and it flares as it locks. It stands, slowly turning, until the last landing
## (pulsing at each), then fades as it widens (with `burst`, it bursts there at its heart).

const FADE := 0.7

var _key := 0

func _ready() -> void:
	super._ready()
	one_body = false
	_key = seed_id
	# Behind everyone.
	remove_child(cv)
	(stage.get("under") as Node2D).add_child(cv)
	life = land(count - 1) + FADE + 0.1
	_update()

func _exit_tree() -> void:
	if is_instance_valid(cv): cv.queue_free()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

## 0 … 1: a pulse at each landing, dying away.
func _pulse() -> float:
	var p := 0.0
	for i in count:
		var e := age - land(i)
		if e >= 0.0: p = maxf(p, exp(-e / 0.18))
	return p

func _update() -> void:
	cv.begin(age)
	var n := materials.size()
	var centre := start_point(0)
	var stop := land(count - 1)
	var fade := clampf(1.0 - (age - stop) / FADE, 0.0, 1.0)
	var lock := maxf(age - charge, 0.0)
	var flare := exp(-lock / 0.25) if age >= charge else 0.0
	var pulse := maxf(_pulse(), flare)
	var r := radius * size * (1.0 + 0.04 * pulse + 0.15 * (1.0 - fade))
	var half := maxf(r * 0.016, 2.0)
	var turn := lock * 0.22
	var power := fade * (0.75 + 0.25 * pulse)
	var tint: Color = mat(0).TINT
	# Light behind it.
	var drawn := clampf((age - charge * 0.7) / maxf(charge * 0.3, 0.01), 0.0, 1.0)
	cv.light.append([Art.glow(), centre, Vector2.ONE * r * 3.2, 0.0, Color(tint, (0.12 + 0.25 * pulse) * fade * drawn)])
	# The emblems, flying in to their places.
	var slots: Array[Vector2] = []
	for k in n:
		var a := -PI * 0.5 + TAU * k / n + turn
		var slot := centre + Vector2.from_angle(a) * r
		slots.append(slot)
		var arrive := charge * (0.45 + 0.25 * k / maxf(n - 1, 1))
		var x := clampf(age / maxf(arrive, 0.01), 0.0, 1.0)
		var from := centre + Vector2.from_angle(a) * (r + 900.0)
		var at := from.lerp(slot, _back(x))
		_emblem(k, at, r * 0.26, x, power, turn)
		if x < 1.0:
			for j in roundi(10 * Art.density()):
				var behind := clampf(x - 0.04 * j, 0.0, 1.0)
				mat(k).mote(cv, from.lerp(slot, _back(behind)) + Vector2(rnd2(k * 50 + j), rnd2(k * 50 + j + 1)) * 14.0, 2.5, (1.0 - j / 10.0) * x, _key + k * 50 + j, slot - from)
	# The rings and the star, drawn round once every emblem is home.
	if drawn > 0.0:
		_ring(centre, r, -PI * 0.5 + turn, drawn, mat(0), half * 1.2, power, _key + 1)
		_ring(centre, r * 1.07, PI * 0.5 - turn * 1.5, drawn, mat(0), half * 0.6, power * 0.6, _key + 2)
		# Arcs between the emblems, each in its emblem's material.
		for k in n:
			var a0 := -PI * 0.5 + TAU * k / n + turn
			var points := PackedVector2Array()
			for s in 17:
				var a := a0 + TAU / n * drawn * s / 16.0
				points.append(centre + Vector2.from_angle(a) * r * 0.82)
			mat(k).line(cv, points, half * 0.9, power, _key + 20 + k, 0.0)
		# The star joining them.
		if n >= 3:
			var hop := 2 if n >= 5 else 1
			for k in n:
				var a := slots[k]
				var b := slots[(k + hop) % n]
				var points := PackedVector2Array()
				for s in 13: points.append(a.lerp(b, drawn * s / 12.0))
				mat(k).line(cv, points, half * 0.8, power * 0.85, _key + 40 + k, 0.0)
		_ring(centre, r * 0.3, turn * 2.0, drawn, mat(0), half * 0.8, power, _key + 3)
		_ticks(centre, r * 1.14, -turn * 0.6, drawn, tint, power)
	if flare > 0.0:
		cv.light.append([Art.glow(), centre, Vector2.ONE * r * 2.6 * (1.0 + flare), 0.0, Color(1, 1, 1, 0.45 * flare)])
	burst_once(stop, centre)
	cv.finish()

## Overshoots a little and settles: an emblem slamming home.
func _back(x: float) -> float:
	var c := 1.6
	var t := x - 1.0
	return 1.0 + (c + 1.0) * t * t * t + c * t * t

## An emblem: a small circle of material k, a triangle glyph turning inside, its body at
## the heart.
func _emblem(k: int, at: Vector2, r: float, x: float, power: float, turn: float) -> void:
	var m := mat(k)
	var key := _key + 100 + k * 9
	_ring(at, r, turn * 3.0 + k, 1.0, m, maxf(r * 0.05, 1.5), power * (0.4 + 0.6 * x), key)
	var glyph := PackedVector2Array()
	for s in 4: glyph.append(at + Vector2.from_angle(-PI * 0.5 - turn * 2.0 + TAU * s / 3.0) * r * 0.62)
	m.line(cv, glyph, maxf(r * 0.035, 1.2), power * x, key + 1, 0.0)
	m.blob(cv, at, r * 0.3, Vector2.RIGHT, 1.0, power, key + 2)

## A circle of material `m` round `centre`, drawn round from `from` as far as `drawn`.
func _ring(centre: Vector2, r: float, from: float, drawn: float, m: GDScript, half: float, power: float, key: int) -> void:
	var points := PackedVector2Array()
	var steps := 48
	for s in steps + 1: points.append(centre + Vector2.from_angle(from + TAU * drawn * s / steps) * r)
	m.line(cv, points, half, power, key, 0.0)

## Short marks round the outside, like a dial.
func _ticks(centre: Vector2, r: float, from: float, drawn: float, tint: Color, power: float) -> void:
	for j in 36:
		if float(j) / 36.0 > drawn: break
		var a := from + TAU * j / 36.0
		var long := 1.6 if j % 3 == 0 else 1.0
		cv.light.append([null, centre + Vector2.from_angle(a) * r, Vector2(r * 0.035 * long, 2.0), a, Color(tint.lerp(Color.WHITE, 0.5), 0.6 * power)])
