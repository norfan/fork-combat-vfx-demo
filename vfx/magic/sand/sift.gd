extends "res://vfx/magic/magic_fx.gd"
## After a sand silk hit, sand-gold motes cling to the target and sift slowly down it,
## twinkling, a fine thread or two still wound round it — and it is slowed a little (it
## moves at a fraction of its speed) until they have fallen away. A new sand hit restarts
## it; a finisher shakes it off at once.

const Art = preload("res://vfx/magic/magic_art.gd")
const Silk = preload("res://vfx/magic/sand/threads.gd")
const SLOW := 0.7
const FALL_AWAY := 0.3

var _glow: Node2D
var _silk: MeshInstance2D

func _ready() -> void:
	super._ready()
	life = _held() + FALL_AWAY
	if finisher: age = _held()
	_glow = Art.drawer(true)
	add_child(_glow)
	_silk = Silk.node()
	add_child(_silk)
	_update()

func _held() -> float: return 0.8

func renew(longer: bool) -> void:
	super.renew(longer)
	life = _held() + FALL_AWAY
	if longer: age = _held()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var held := _held()
	var feet := stage.target.position
	var glow: Array = []
	var silk := Silk.data()
	var left := clampf(1.0 - (age - held) / FALL_AWAY, 0.0, 1.0)
	if age < held: stage.set("target_slow", SLOW)
	for j in roundi(26 * Art.density()):
		var a := fposmod(age * 0.7 + rnd(j), 1.0)
		var p := feet + Vector2(rnd2(j + 1) * 24.0, -100.0 * rnd(j + 2) + 60.0 * a)
		var twinkle := 0.5 + 0.5 * sin(age * 14.0 + j * 2.1)
		if p.y < feet.y: Silk.mote(glow, p, 2.0, twinkle, left * (1.0 - a))
	# A fine thread wound round it.
	var points := PackedVector2Array()
	for k in 30:
		var s := float(k) / 29.0
		var a := s * 3.0 * TAU + age * 3.0
		points.append(feet + Vector2(cos(a) * 26.0, -10.0 - s * 80.0 + sin(a) * 5.0))
	Silk.thread(silk, points, 1.8, 0.45 * left, 500)
	Silk.show(_silk, silk, age, 0.7 * left)
	(_glow as Art.Drawer).items = glow
	_glow.queue_redraw()
