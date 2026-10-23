extends "res://vfx/magic/shapes/shape.gd"
## 彗星 comet — one body of a volley (`index`) flying its path: it gathers at the start,
## flies with a trail of its materials streaming off behind (the mixed ones braided round
## the spell's own), sheds motes along the way, hangs at its end while it lingers, and is
## gone when it lands (the impact takes over).

## Body radius at size 1, px.
const BODY := 18.0
## Seconds of path the trail covers, and how long shed motes last.
const TRAIL := 0.2
const SHED := 0.6
const SHED_RATE := 70.0

func _ready() -> void:
	super._ready()
	life = gone(index) + SHED + 0.1
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	cv.begin(age)
	var t0 := born(index)
	var t1 := launch(index)
	var t2 := land(index)
	var tg := gone(index)
	var r := BODY * size
	var key := seed_id + index * 31
	if age >= t0 and age < t1:
		var k := clampf((age - t0) / maxf(charge, 0.01), 0.0, 1.0)
		var at := start_point(index)
		gather(at, k, key)
		body(at, r * (0.2 + 0.8 * ease_out(k, 2.5)), Vector2.RIGHT, 1.0, 0.6 + 0.4 * k, key)
	elif age >= t1 and age < t2:
		var u := (age - t1) / maxf(travel, 0.01)
		var v := velocity_at(index, u)
		body(path_at(index, u), r, v.normalized(), 1.0 + clampf(v.length() / 1100.0, 0.0, 1.6), 1.0, key)
	elif age >= t2 and age < tg:
		var bob := Vector2(0, sin(age * 3.0 + index) * 4.0 * size)
		body(path_at(index, 1.0) + bob, r, velocity_at(index, 1.0).normalized(), 1.0, 1.0, key)
	if age >= t1:
		undarken(age - t1)
		_flash(age - t1, path_at(index, 0.0), r)
		_trail(t1, t2, r, key)
		_shed(t1, t2, r, key)
	cv.finish()

## Where it leaves: a flash of its colour.
func _flash(e: float, at: Vector2, r: float) -> void:
	if e > 0.12: return
	var f := 1.0 - e / 0.12
	cv.light.append([Art.glow(), at, Vector2.ONE * r * 6.0 * f, 0.0, Color(mat(0).TINT, f)])
	cv.light.append([Art.glow(), at, Vector2.ONE * r * 2.5 * f, 0.0, Color(1, 1, 1, f)])

## The trail over the last TRAIL seconds of path; after landing it catches up and is gone.
func _trail(t1: float, t2: float, r: float, key: int) -> void:
	var newest := minf(age, t2)
	var oldest := maxf(t1, age - TRAIL)
	if newest - oldest < 0.008: return
	var points := PackedVector2Array()
	for k in 15:
		var tk := lerpf(newest, oldest, k / 14.0)
		points.append(path_at(index, (tk - t1) / maxf(travel, 0.01)))
	var fade := 1.0 if age < t2 else clampf(1.0 - (age - t2) / TRAIL, 0.0, 1.0)
	braid(points, r * 0.7, fade, r * 0.7, key, 0.85)

## Motes shed backwards off it as it flies, drifting and fading.
func _shed(t1: float, t2: float, r: float, key: int) -> void:
	var rate := SHED_RATE * Art.density() / sqrt(float(count))
	for j in range(maxi(ceili(t1 * rate), floori((age - SHED) * rate)), floori(minf(age, t2) * rate) + 1):
		var tb := float(j) / rate
		var a := age - tb
		var span := SHED * (0.5 + 0.5 * rnd(j + 50))
		if a < 0.0 or a >= span: continue
		var u := (tb - t1) / maxf(travel, 0.01)
		var v0 := velocity_at(index, u)
		var side := v0.normalized().orthogonal() * rnd2(j + 51)
		var v := (-v0.normalized() * (60.0 + 140.0 * rnd(j + 52)) + side * 110.0 + Vector2(0, -40)) * size
		var p := path_at(index, u) + side * r * 0.7 + v * a
		mat(j).mote(cv, p, 2.2 * sqrt(size), 1.0 - a / span, key + j, v)
