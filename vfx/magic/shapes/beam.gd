extends "res://vfx/magic/shapes/shape.gd"
## 光束 beam — one beam of a volley (`index`): it gathers at the start, then shoots out
## along its path — a line of its own material down the middle, the mixed ones braided
## round it — and holds there `hold` s, surging as it strikes, before it thins away. Motes
## shed off it, light at both ends.

## Half-width at size 1, px.
const HALF := 7.0
const FADE := 0.35

func _ready() -> void:
	super._ready()
	life = land(index) + maxf(hold, linger) + FADE + 0.4
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	cv.begin(age)
	var t0 := born(index)
	var t1 := launch(index)
	var t2 := land(index)
	var key := seed_id + index * 31
	var from := start_point(index)
	if age >= t0 and age < t1:
		var k := clampf((age - t0) / maxf(charge, 0.01), 0.0, 1.0)
		gather(from, k, key)
		body(from, 12.0 * size * (0.25 + 0.75 * ease_out(k, 2.0)), Vector2.RIGHT, 1.0, 0.5 + 0.5 * k, key)
	var fade := clampf(1.0 - (age - t2 - maxf(hold, linger)) / FADE, 0.0, 1.0)
	if age >= t1 and fade > 0.0:
		undarken(age - t1)
		var reach := ease_out((age - t1) / maxf(travel, 0.01), 1.6)
		var points := PackedVector2Array()
		for k in 41: points.append(path_at(index, reach * k / 40.0))
		# It surges as it strikes, then settles to a steady pulse.
		var strike := exp(-maxf(age - t2, 0.0) / 0.12) if age >= t2 else 0.0
		var pulse := 0.85 + 0.15 * sin(age * 38.0 + index)
		var power := fade * pulse
		var half := HALF * size * (1.0 + 0.8 * strike) * (0.6 + 0.4 * fade)
		braid(points, half, power, half * 1.8, key)
		var tint: Color = mat(0).TINT
		for k in range(0, 41, 8):
			cv.light.append([Art.glow(), points[k], Vector2.ONE * half * 9.0, 0.0, Color(tint, 0.22 * power)])
		cv.light.append([Art.glow(), points[-1], Vector2.ONE * half * (8.0 + 18.0 * strike), 0.0, Color(1, 1, 1, 0.8 * power)])
		cv.light.append([Art.glow(), from, Vector2.ONE * half * 10.0, 0.0, Color(tint, 0.6 * power)])
		body(from, 10.0 * size * fade, (points[1] - points[0]).normalized(), 1.0, power, key)
		_shed(points, power, key)
	cv.finish()

## Motes thrown off along it, drifting outwards.
func _shed(points: PackedVector2Array, power: float, key: int) -> void:
	for j in roundi(36 * Art.density() * sqrt(size)):
		var at := points[int(rnd(key + j) * (points.size() - 1))]
		var a := fposmod(age * 1.6 + rnd(key + j + 1), 1.0)
		var drift := Vector2(rnd2(key + j + 2), rnd2(key + j + 3)) * 60.0 * a * size
		mat(j).mote(cv, at + drift, 2.2 * sqrt(size), (1.0 - a) * power, key + j, drift * 4.0)
