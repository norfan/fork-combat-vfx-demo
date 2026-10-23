extends "res://vfx/magic/magic_fx.gd"
## Where sand silk lands, sized by the cast's blast `radius`: a sharp point of light where
## the thread runs the target through, fine threads flicking out from it like a burst of
## gold wire and drawing back, and a spray of glittering motes thrown out that slow, hang
## twinkling and drift down as they fade.

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Silk = preload("res://vfx/magic/sand/threads.gd")
const MOTES := 70
const WIRES := 8

var _glow: Node2D
var _silk: MeshInstance2D

func _ready() -> void:
	super._ready()
	life = 1.5
	_glow = Art.drawer(true)
	add_child(_glow)
	_silk = Silk.node()
	add_child(_silk)
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var k := sqrt(radius / 60.0)
	var glow: Array = []
	var silk := Silk.data()
	var flash := clampf(flash_left(1, 0.12), 0.0, 1.0)
	if flash > 0.0:
		glow.append(Arcs.light(at, Vector2.ONE * 70.0 * k, Color(1.0, 0.92, 0.65, flash)))
		glow.append(Arcs.light(at, Vector2(radius * 6.0 * k, 5.0), Color(1.0, 0.85, 0.5, 0.8 * flash)))
	# Fine wires flicking out of the point and drawing back.
	if age < 0.32:
		var out := ease_out(age / 0.07, 2.0) * clampf(1.0 - (age - 0.12) / 0.2, 0.0, 1.0)
		for j in WIRES:
			var dir := Vector2.from_angle(TAU * j / WIRES + rnd2(j) * 0.3)
			var reach := radius * (1.2 + 0.9 * rnd(j + 1)) * k * out
			var points := PackedVector2Array()
			for s in 9:
				var u := float(s) / 8.0
				points.append(at + dir * reach * u + dir.orthogonal() * sin(u * PI * 2.0 + j) * 6.0 * u)
			Silk.thread(silk, points, 2.2, 0.9, 300 + j)
	# Glittering motes thrown out, slowing, hanging, drifting down.
	for j in ceili(MOTES * Art.density()):
		var span := 0.9 + 0.6 * rnd(j + 10)
		if age >= span: continue
		var dir := Vector2.from_angle(rnd(j + 11) * TAU)
		var speed := (120.0 + 360.0 * rnd(j + 12)) * k
		var p := at + dir * speed * (1.0 - exp(-age * 5.0)) / 5.0 + Vector2(sin(age * 3.0 + j) * 6.0, 26.0 * age * age)
		var twinkle := 0.5 + 0.5 * sin(age * (16.0 + 8.0 * rnd(j + 13)) + j)
		Silk.mote(glow, p, 2.0 if j % 3 else 3.0, twinkle, 1.0 - age / span)
	Silk.show(_silk, silk, age)
	(_glow as Art.Drawer).items = glow
	_glow.queue_redraw()
