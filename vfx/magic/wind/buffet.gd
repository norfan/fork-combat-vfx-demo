extends "res://vfx/magic/magic_fx.gd"
## The target is buffeted after a wind hit: gusts whip round it in quick curling streaks
## and a few leaves are caught circling it, riding along with it and dying down over
## `life`. A new wind hit restarts it.

const Art = preload("res://vfx/magic/magic_art.gd")
const Gusts = preload("res://vfx/magic/wind/gusts.gd")

var _air: Array
var _leaves: Node2D

func _ready() -> void:
	super._ready()
	life = _span()
	_air = Gusts.node(float(seed_id % 17), false)
	for node in _air: if node != null: add_child(node)
	_leaves = Art.drawer(false)
	add_child(_leaves)
	_update()

func _span() -> float: return 1.0 if finisher else 0.65

func renew(longer: bool) -> void:
	super.renew(longer)
	life = _span()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var centre := stage.target.position + Vector2(0, -50)
	var dying := clampf(1.0 - age / life, 0.0, 1.0)
	var air := Gusts.data()
	var leaves: Array = []
	for g in 3:
		var a0 := age * (9.0 + g * 2.0) + g * 2.1
		var points := PackedVector2Array()
		for s in 10:
			var a := a0 + s * 0.22
			points.append(centre + Vector2(cos(a) * (38.0 + g * 10.0), sin(a) * (58.0 - g * 12.0) + (g - 1) * 18.0))
		Gusts.band(air, points, 5.0, 0.7 * dying, 0.8)
	for j in 3:
		var a := age * 8.0 + TAU * j / 3.0
		var p := centre + Vector2(cos(a) * 46.0, sin(a) * 24.0 + (j - 1) * 25.0)
		leaves.append(Gusts.leaf_item(p, 12.0, a * 1.5, age * 10.0 + j, Gusts.leaf_tone(rnd(j), dying)))
	Gusts.show(_air, air, age)
	(_leaves as Art.Drawer).items = leaves
	_leaves.queue_redraw()
