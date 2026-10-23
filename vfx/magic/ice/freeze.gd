extends "res://vfx/magic/magic_fx.gd"
## The target is frozen after an ice hit: clear crystals shoot up from under its feet and
## close round it — it shows through them (bent, on the 炸裂 tier) — glints twinkle over
## them, frost and cold air cling to its feet, and it really is held: it cannot slide (a
## launch still carries it up and down). When the time is up the crystals crack and burst
## into chips. A new ice hit restarts it; a finisher shatters it at once (and the target
## flies).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Crystal = preload("res://vfx/magic/ice/crystal.gd")
const CRACK := 0.15
const BURST := 0.6
## The shell: crystals rooted at the target's feet, each [x offset, lean (degrees), length,
## radius] at size 1, back ones first.
const SHELL := [[-34.0, -38.0, 62.0, 11.0], [36.0, 40.0, 58.0, 10.0], [-22.0, -18.0, 104.0, 16.0],
	[24.0, 20.0, 96.0, 15.0], [-4.0, -5.0, 124.0, 19.0], [10.0, 8.0, 84.0, 14.0], [-12.0, -26.0, 70.0, 12.0]]

var _mist: Node2D
var _ice: Array
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	life = _held() + BURST
	if finisher: age = _held()
	_mist = Art.drawer(false)
	add_child(_mist)
	_ice = Crystal.node(float(seed_id % 19))
	for node in _ice: if node != null: add_child(node)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_update()

## How long the shell holds.
func _held() -> float: return 0.95

func renew(longer: bool) -> void:
	super.renew(longer)
	life = _held() + BURST
	if longer: age = _held()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var held := _held()
	var feet := stage.target.position + Vector2(0, 4)
	var ice := Crystal.data()
	var sparks: Array = []
	var mist: Array = []
	if age < held:
		# Frozen in place.
		stage.set("_target_velocity", Vector2(0.0, (stage.get("_target_velocity") as Vector2).y))
		for j in SHELL.size():
			var c: Array = SHELL[j]
			var grow := ease_out((age - 0.012 * j) / 0.09, 2.5)
			if grow <= 0.0: continue
			var dir := Vector2.from_angle(deg_to_rad(-90.0 + float(c[1])))
			Crystal.prism(ice, feet + Vector2(float(c[0]), 0.0), dir, float(c[2]) * grow, float(c[3]), j * 1.3 + 0.5, 0.8, Crystal.ROOTED)
			var tip := feet + Vector2(float(c[0]), 0.0) + dir * float(c[2]) * grow
			var twinkle := sin(age * 8.0 + j * 2.1)
			if twinkle > 0.5: Crystal.sparkle(sparks, tip, 12.0, twinkle)
		mist.append([Art.smoke(), feet + Vector2(0, -10), Vector2(150, 34), 0.0, Color(0.86, 0.95, 1.0, 0.16)])
		# It cracks just before it bursts.
		var crack := clampf((age - (held - CRACK)) / CRACK, 0.0, 1.0)
		for i in roundi(crack * 6.0):
			var a := Vector2.from_angle(rnd(i + 60) * TAU)
			var mid := feet + Vector2(rnd2(i + 62) * 20.0, -30.0 - 60.0 * rnd(i + 63))
			sparks.append([Art.glow(), mid, Vector2(44.0 * crack, 2.0), a.angle(), Color(0.92, 0.98, 1.0, 0.95)])
	else:
		# The shell bursts into chips, tumbling and rolling (the small ones fastest).
		var e := age - held
		for j in ceili(16 * Art.density()):
			var v := Vector2.from_angle(-PI * 0.5 + rnd2(j + 100) * 1.7) * (180.0 + 380.0 * rnd(j + 101))
			var state := ballistic(feet + Vector2(rnd2(j + 104) * 24.0, -20.0 - 70.0 * rnd(j + 105)), v, e, 1500.0)
			var length := 12.0 + 22.0 * rnd(j + 102)
			var turn := Crystal.roll_speed(length / 30.0)
			Crystal.prism_at(ice, state[0], Vector2.from_angle(e * turn * 0.6 * rnd2(j + 103) + j), length, length * 0.22, e * turn + j, clampf((BURST - e) / 0.25, 0.0, 1.0) * 0.9, Crystal.CHIP)
		if e < 0.1: Crystal.sparkle(sparks, feet + Vector2(0, -50), 60.0, 1.0 - e / 0.1)
	Crystal.show(_ice, ice, age)
	(_sparks as Art.Drawer).items = sparks
	_sparks.queue_redraw()
	(_mist as Art.Drawer).items = mist
	_mist.queue_redraw()
