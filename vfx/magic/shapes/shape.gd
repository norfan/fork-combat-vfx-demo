extends "res://vfx/magic/magic_fx.gd"
## Base of the shared shapes: the form of a spell written once (comet, beam, ring, pillar,
## vortex, circle), drawn in whatever it is made of. `materials` are element scripts (fire.gd
## …): the first is the spell's own element — its body is drawn in it and its rules win (ice
## flies straight) — the rest are its `mix`, braided through it. Each material draws motes,
## lines and a body blob onto the shape's canvas (vfx/magic/canvas.gd).
## Every shape gathers at its start through the charge: motes of its materials stream in,
## from further off the longer the charge; a long charge (a second or more) also darkens
## the stage, deepening as it builds.

const Art = preload("res://vfx/magic/magic_art.gd")
const Canvas = preload("res://vfx/magic/canvas.gd")

## Size grows from `size` to `size × swell` over the spell's life (a vortex that keeps
## widening).
var swell := 1.0
var cv: Canvas
var _size := 1.0

func _ready() -> void:
	super._ready()
	_size = size
	cv = Canvas.new()
	add_child(cv)

## Material k of the spell, round and round.
func mat(k: int) -> GDScript: return materials[posmod(k, materials.size())]

## Whether the spell's own element says it flies straight (ice).
func straight() -> bool: return mat(0).get_script_constant_map().get("STRAIGHT", false)

func path_at(i: int, u: float) -> Vector2:
	if straight() and path != "stay": return start_point(i).lerp(end_point(i), pow(clampf(u, 0.0, 1.0), ease))
	return super.path_at(i, u)

## Grows the size towards `swell` over 0 … 1 of `span` seconds.
func swell_to(span: float) -> void:
	size = _size * lerpf(1.0, swell, clampf(age / maxf(span, 0.01), 0.0, 1.0))

## Motes of every material streaming in to `at` through the charge (`k` 0 … 1 of it).
func gather(at: Vector2, k: float, key: int) -> void:
	if k <= 0.0 or k >= 1.0: return
	var span := minf(charge, 3.0)
	var reach := (100.0 + 300.0 * span) * size
	var cycle := clampf(charge * 0.5, 0.3, 1.1)
	var many := mini(roundi((18.0 + 18.0 * span) * sqrt(float(materials.size())) * Art.density()), 140)
	for j in many:
		var phase := fposmod(age / cycle + rnd(key + j), 1.0)
		var a0 := rnd(key + j + 300) * TAU
		var from := reach * (0.35 + 0.65 * rnd(key + j + 600))
		var angle := a0 + phase * 2.2
		var dist := from * pow(1.0 - phase, 1.5) + 4.0 * size
		var p := at + Vector2(cos(angle), sin(angle) * 0.8) * dist
		var heading := Vector2(cos(angle + 2.0), sin(angle + 2.0) * 0.8) * from * 2.0
		mat(j).mote(cv, p, 2.0 * sqrt(size), phase * (0.3 + 0.7 * k), key + j, heading)
	darken(k)

## A long charge draws the light out of the stage (fading back fast after it).
func darken(k: float) -> void:
	if charge < 0.9: return
	cv.mist.append([null, Vector2(640, 360), Vector2(2200, 1500), 0.0, Color(0.01, 0.01, 0.03, 0.5 * k * k)])

## Darkness lifting just after the launch.
func undarken(since: float) -> void:
	if charge < 0.9 or since > 0.15: return
	cv.mist.append([null, Vector2(640, 360), Vector2(2200, 1500), 0.0, Color(0.01, 0.01, 0.03, 0.5 * (1.0 - since / 0.15))])

## The body: the spell's own material, the mixed ones as small blobs circling it.
func body(at: Vector2, r: float, dir: Vector2, stretch: float, power: float, key: int) -> void:
	mat(0).blob(cv, at, r, dir, stretch, power, key)
	var extra := materials.size() - 1
	for k in extra:
		var a := age * 7.0 + TAU * k / extra
		mat(k + 1).blob(cv, at + Vector2.from_angle(a) * r * 1.25, r * 0.38, dir, 1.0, power, key + 11 * (k + 1))

## Lines of every material along `points`: the spell's own down the middle, the mixed ones
## braided round it `weave` px out.
func braid(points: PackedVector2Array, half: float, power: float, weave: float, key: int, taper := 0.0) -> void:
	mat(0).line(cv, points, half, power, key, taper)
	var extra := materials.size() - 1
	if extra <= 0 or points.size() < 2: return
	for k in extra:
		var twist := PackedVector2Array()
		var walked := 0.0
		for n in points.size():
			if n > 0: walked += points[n].distance_to(points[n - 1])
			var side := (points[mini(n + 1, points.size() - 1)] - points[maxi(n - 1, 0)]).normalized().orthogonal()
			var ends := minf(walked / 40.0, 1.0)
			twist.append(points[n] + side * sin(walked * 0.035 - age * 9.0 + TAU * k / extra) * weave * ends)
		mat(k + 1).line(cv, twist, half * 0.5, power * 0.85, key + 17 * (k + 1), taper)
