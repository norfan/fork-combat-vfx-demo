extends "res://vfx/magic/magic_fx.gd"
## 沙 — one sand silk of a sand cast (silk `index` of the volley). Sand magic is light, not
## heaps: faint sand-gold motes hang shimmering in the air round the caster; at the cast
## they are drawn in from all round and gather at the start into a point of light, which
## draws out into a very fine thread — a hair-thin line of glittering grains packed close —
## that shoots out along the path and runs the target through. It holds taut a moment,
## then comes apart into motes that drift and fade.
## Accessories: the shimmering motes in the air; the gathering; two fainter threads weaving
## round the main one; motes shed off the thread as it runs; the bright point at its tip.

const Art = preload("res://vfx/magic/magic_art.gd")
const Silk = preload("res://vfx/magic/sand/threads.gd")
## The thread's half-width at size 1, px: hair-thin.
const HALF := 2.6
const MOTES := 70
const UNRAVEL := 0.55

var _glow: Node2D
var _silk: MeshInstance2D

func _ready() -> void:
	super._ready()
	life = land(index) + hold + UNRAVEL + 0.3
	_glow = Art.drawer(true)
	add_child(_glow)
	_silk = Silk.node()
	add_child(_silk)
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var t0 := born(index)
	var t1 := launch(index)
	var t2 := land(index)
	var glow: Array = []
	var silk := Silk.data()
	var from := start_point(index)
	var unravel := clampf((age - t2 - hold) / UNRAVEL, 0.0, 1.0)
	_air(glow, from, t0, t1)
	if age >= t1 and unravel < 1.0:
		var head := ease_out((age - t1) / maxf(travel, 0.01), 1.8)
		var points := PackedVector2Array()
		for k in 41: points.append(path_at(index, head * k / 40.0))
		var power := 1.0 - unravel
		Silk.thread(silk, points, HALF * size, power, index * 5)
		# Two fainter threads weaving round it.
		for w in 2:
			var weave := PackedVector2Array()
			var walked := 0.0
			for k in points.size():
				if k > 0: walked += points[k].distance_to(points[k - 1])
				var side := (points[mini(k + 1, 40)] - points[maxi(k - 1, 0)]).normalized().orthogonal()
				weave.append(points[k] + side * sin(walked * 0.045 + w * PI + age * 6.0) * 5.0 * size * minf(walked / 40.0, 1.0))
			Silk.thread(silk, weave, HALF * size * 0.7, power * 0.4, index * 5 + w + 1)
		# The bright point at its tip while it runs.
		if age < t2:
			glow.append([Art.glow(), points[-1], Vector2.ONE * 26.0 * size, 0.0, Color(1.0, 0.9, 0.6, 0.85)])
			glow.append([Art.glow(), points[-1], Vector2(60.0, 6.0) * size, (points[-1] - points[-2]).angle(), Color(1.0, 0.85, 0.5, 0.6)])
		_shed(glow, points, t1, unravel)
	Silk.show(_silk, silk, age, 0.9 * (1.0 - 0.8 * unravel))
	(_glow as Art.Drawer).items = glow
	_glow.queue_redraw()

## The motes in the air: drifting shimmering round the start, drawn in to it as it gathers.
func _air(glow: Array, at: Vector2, t0: float, t1: float) -> void:
	var gather := clampf((age - t0) / maxf(charge, 0.01), 0.0, 1.0)
	var spent := clampf((age - t1) / 0.3, 0.0, 1.0)
	for j in roundi(MOTES * Art.density()):
		var home := at + Vector2(rnd2(j) * 170.0, rnd2(j + 1) * 110.0 - 20.0) * size
		home += Vector2(noise(j, age * 0.6) * 14.0, noise(j + 50, age * 0.5) * 10.0 - age * 6.0)
		var drawn := ease_out(gather * (0.7 + 0.3 * rnd(j + 2)), 2.2)
		var p := home.lerp(at, drawn)
		var twinkle := 0.5 + 0.5 * sin(age * (8.0 + 6.0 * rnd(j + 3)) + j)
		Silk.mote(glow, p, 2.0, twinkle, 0.75 * (1.0 - spent))
	if age >= t0 and age < t1 + 0.05:
		var point := 8.0 + 18.0 * gather
		glow.append([Art.glow(), at, Vector2.ONE * point * size, 0.0, Color(1.0, 0.9, 0.6, 0.4 + 0.5 * gather)])

## Motes shed off the thread as it runs, and the thread coming apart into motes at the end.
func _shed(glow: Array, points: PackedVector2Array, t1: float, unravel: float) -> void:
	var count_motes := roundi((20.0 + 60.0 * unravel) * Art.density())
	for j in count_motes:
		var at := points[int(rnd(j + 100) * (points.size() - 1))]
		var a := fposmod(age * 1.3 + rnd(j + 101), 1.0)
		var drift := Vector2(rnd2(j + 102) * 18.0, -10.0 + 30.0 * unravel) * a * (1.0 + 3.0 * unravel)
		var twinkle := 0.5 + 0.5 * sin(age * 20.0 + j * 1.7)
		Silk.mote(glow, at + drift, 2.0, twinkle, (1.0 - a) * (0.6 if unravel > 0.0 else 0.35) * (1.0 - unravel * unravel))
