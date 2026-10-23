extends "res://vfx/magic/shapes/shape.gd"
## 漩涡 vortex — the spell whirls up into a funnel where its start is when cast (start
## "target": under the target, which it sweeps up and holds): helices of each of its
## materials wind up the funnel, near side bright and far side dim, its motes spiralling up
## between them. It holds until the last landing, drawing in tight at every landing, then
## flies apart (pair a hit with each landing). With `swell` it keeps widening as it holds.

const HEIGHT := 320.0
const TOP := 120.0
const HOLD_AT := 150.0
const SCATTER := 0.55

var _x := 0.0

func _ready() -> void:
	super._ready()
	one_body = false
	_x = start_point(0).x
	life = land(count - 1) + SCATTER + 0.2
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _tighten() -> float:
	var c := 0.0
	for i in count:
		var e := age - land(i)
		c = maxf(c, smoothstep(-0.2, 0.0, e) * clampf(1.0 - e / 0.25, 0.0, 1.0))
	return c

func _update() -> void:
	cv.begin(age)
	var stop := land(count - 1)
	swell_to(stop)
	var key := seed_id
	var rise := ease_out(age / maxf(charge, 0.05), 2.0)
	var scatter := clampf((age - stop) / SCATTER, 0.0, 1.0)
	var tight := _tighten()
	var height := HEIGHT * size * (0.3 + 0.7 * rise)
	var flare := (0.4 + 0.6 * rise) * (1.0 - 0.3 * tight) * (1.0 + 1.6 * scatter)
	var power := rise * (1.0 - scatter)
	var spin := age * 7.0 * (1.0 + 0.5 * tight)
	var helices := mini(2 * materials.size() + 1, 9)
	for hx in helices:
		var run := PackedVector2Array()
		var front_run := true
		for s in 37:
			var u := float(s) / 36.0
			var h := height * u
			var a := spin * 1.2 + u * 3.0 * TAU + TAU * hx / helices
			var front := sin(a) > 0.0
			var p := _at(h, height, flare, a, scatter)
			if s > 0 and front != front_run:
				run.append(p)
				_run(run, front_run, hx, power, key)
				run = PackedVector2Array([p])
			else:
				run.append(p)
			front_run = front
		_run(run, front_run, hx, power, key)
	for j in roundi(50 * Art.density()):
		var phase := fposmod(age / (1.0 + 0.5 * rnd(j)) + rnd(j + 1), 1.0)
		var a := spin * (0.9 + 0.3 * rnd(j + 2)) + rnd(j + 3) * TAU
		mat(j).mote(cv, _at(height * phase, height, flare * (0.8 + 0.4 * rnd(j + 4)), a, scatter), 2.2 * sqrt(size), power, key + j)
	if start == "target" and age < stop and age > charge * 0.6:
		var want := Vector2(_axis(HOLD_AT * size, height), GROUND_Y - HOLD_AT * size)
		stage.set("_target_velocity", (want - stage.target.position) * 5.0)
	burst_once(stop, Vector2(_x, GROUND_Y - height * 0.5))
	cv.finish()

func _axis(h: float, height: float) -> float:
	var up := clampf(h / maxf(height, 1.0), 0.0, 1.0)
	return _x + up * (26.0 * sin(h * 0.017 - age * 3.0) + 14.0 * sin(h * 0.04 + age * 5.0)) * size

func _at(h: float, height: float, flare: float, a: float, scatter: float) -> Vector2:
	var up := clampf(h / maxf(height, 1.0), 0.0, 1.0)
	var r := (20.0 + TOP * pow(up, 1.3)) * size * flare
	return Vector2(_axis(h, height) + cos(a) * r, GROUND_Y - h - 40.0 * scatter + sin(a) * r * 0.25)

func _run(run: PackedVector2Array, front: bool, hx: int, power: float, key: int) -> void:
	if run.size() < 2: return
	mat(hx).line(cv, run, (3.0 + 2.0 * (hx % 2)) * size, power * (0.95 if front else 0.3), key + hx * 13)
