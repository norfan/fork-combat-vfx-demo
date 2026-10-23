extends "res://vfx/magic/shapes/shape.gd"
## 环 ring — the spell stays round its start (path "stay"; it follows a live start, the
## caster or the target): small bodies of its materials circle it on a tilted ring, a ring
## of each material turning with them, motes swept round. It holds until the last landing
## (`charge + travel + interval × (count − 1)`); it draws in tight at every landing and at
## the last flies apart (pair a hit with each landing, or set `burst`).

const RING := 72.0
const BODIES := 6
const SCATTER := 0.5

func _ready() -> void:
	super._ready()
	one_body = false
	life = land(count - 1) + SCATTER + 0.2
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

## 0 … 1: how tight it is drawn (just before and at each landing).
func _tighten() -> float:
	var c := 0.0
	for i in count:
		var e := age - land(i)
		c = maxf(c, smoothstep(-0.15, 0.0, e) * clampf(1.0 - e / 0.25, 0.0, 1.0))
	return c

func _update() -> void:
	cv.begin(age)
	var stop := land(count - 1)
	var centre := start_point(0)
	var key := seed_id
	var rise := ease_out(age / maxf(charge, 0.05), 2.0)
	var scatter := clampf((age - stop) / SCATTER, 0.0, 1.0)
	var tight := _tighten()
	var r := RING * size * (0.5 + 0.5 * rise) * (1.0 - 0.3 * tight) * (1.0 + 1.8 * scatter)
	var power := rise * (1.0 - scatter)
	gather(centre, clampf(age / maxf(charge, 0.01), 0.0, 1.0), key)
	var spin := age * (2.2 + 2.0 * tight)
	for m in materials.size():
		var points := PackedVector2Array()
		var rr := r * (1.0 + 0.1 * m)
		for s in 49:
			var a := spin * (1.0 if m % 2 == 0 else -0.7) + TAU * s / 48.0
			points.append(centre + Vector2(cos(a) * rr, sin(a) * rr * 0.35 + cos(a) * rr * 0.12))
		mat(m).line(cv, points, 3.0 * size, power * 0.6, key + m * 13)
	for b in BODIES:
		var a := spin + TAU * b / BODIES
		var front := sin(a) > 0.0
		var p := centre + Vector2(cos(a) * r, sin(a) * r * 0.35 + cos(a) * r * 0.12)
		mat(b).blob(cv, p, 9.0 * size, Vector2(-sin(a), cos(a) * 0.35).normalized(), 1.3, power * (1.0 if front else 0.5), key + b * 7)
	for j in roundi(30 * Art.density()):
		var a := age * (3.0 + 2.0 * rnd(j)) + rnd(j + 1) * TAU
		var rr := r * (0.7 + 0.6 * rnd(j + 2))
		mat(j).mote(cv, centre + Vector2(cos(a) * rr, sin(a) * rr * 0.4 + rnd2(j + 3) * 20.0 * size), 2.0, power, key + j)
	burst_once(stop, centre)
	cv.finish()
