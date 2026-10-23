extends "res://vfx/magic/shapes/shape.gd"
## 柱 pillar — the spell erupts from the floor where its start is (start "below": under the
## target): the floor glows and motes seep up through the charge, then a column of its
## materials bursts up — lines of each writhing up it, motes streaming up inside — and
## stands until the last landing plus `hold`, surging at every landing (pair a hit with
## each), before it sinks away.

const HEIGHT := 300.0
const WIDTH := 46.0
const SINK := 0.4

var _x := 0.0

func _ready() -> void:
	super._ready()
	one_body = false
	_x = start_point(0).x
	life = _end() + SINK + 0.2
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _end() -> float: return land(count - 1) + hold

## 0 … 1: a surge at each landing, dying away.
func _surge() -> float:
	var s := 0.0
	for i in count:
		var e := age - land(i)
		if e >= 0.0: s = maxf(s, exp(-e / 0.15))
	return s

func _update() -> void:
	cv.begin(age)
	var key := seed_id
	var floor_y := GROUND_Y
	var tint: Color = mat(0).TINT
	var surge := _surge()
	var k := clampf(age / maxf(charge, 0.01), 0.0, 1.0)
	var up := ease_out((age - charge) / 0.15, 2.0) if age >= charge else 0.0
	var sink := clampf((age - _end()) / SINK, 0.0, 1.0)
	var height := HEIGHT * size * up * (1.0 + 0.2 * surge) * (1.0 - sink)
	var width := WIDTH * size * (1.0 + 0.5 * surge) * (1.0 - 0.6 * sink)
	var power := 1.0 - sink
	# The floor glowing where it will come up.
	cv.light.append([Art.glow(), Vector2(_x, floor_y), Vector2(width * (3.0 + 2.0 * k), width * 0.7), 0.0, Color(tint, (0.25 + 0.5 * k) * power)])
	if age < charge:
		for j in roundi(18 * Art.density()):
			var a := fposmod(age * 1.4 + rnd(j), 1.0)
			mat(j).mote(cv, Vector2(_x + rnd2(j + 1) * width * 1.5, floor_y - a * 60.0 * size), 2.0, k * (1.0 - a), key + j, Vector2(0, -60))
	if height > 1.0:
		var lines := 3 + materials.size()
		for l in lines:
			var points := PackedVector2Array()
			var off := (float(l) / (lines - 1) - 0.5) * width * 1.2
			for s in 21:
				var h := height * s / 20.0
				var wobble := sin(h * 0.022 - age * 7.0 + l * 1.9) * width * 0.35 * (0.3 + 0.7 * s / 20.0)
				points.append(Vector2(_x + off * (1.0 - 0.4 * s / 20.0) + wobble, floor_y - h))
			mat(l).line(cv, points, width * (0.22 if l % 2 == 0 else 0.14), power * (0.9 if l == lines / 2 else 0.65), key + l * 13, 0.7)
		for j in roundi(40 * Art.density()):
			var a := fposmod(age * (1.2 + 0.8 * rnd(j)) + rnd(j + 1), 1.0)
			var p := Vector2(_x + rnd2(j + 2) * width * 0.6 + sin(a * 6.0 + j) * 8.0, floor_y - a * height * 1.15)
			mat(j).mote(cv, p, 2.2 * sqrt(size), power * (1.0 - a), key + j, Vector2(0, -400))
		cv.light.append([Art.glow(), Vector2(_x, floor_y - height * 0.5), Vector2(width * 4.0, height * 1.3), 0.0, Color(tint, 0.3 * power * (1.0 + surge))])
	burst_once(land(count - 1), Vector2(_x, floor_y - height * 0.5))
	cv.finish()
