extends "res://vfx/magic/magic_fx.gd"
## 沙暴 — sand silk that stays (path "stay"): a storm of fine threads round its start
## (start "target": round the target, following it). Motes gather out of the air and spin
## up into dozens of very fine, very dense threads of glittering sand whirling round the
## target — each its own height, tilt and speed, the near ones bright, the far ones faint —
## with motes swept along between them; while it holds the target is slowed. At every
## landing (`charge + travel + interval × i`) the threads draw tight round it; at the last
## one they fly apart into motes (pair a hit with each landing).

const Art = preload("res://vfx/magic/magic_art.gd")
const Silk = preload("res://vfx/magic/sand/threads.gd")
const THREADS := 42
const SLOW := 0.45
const SCATTER := 0.6

var _glow: Node2D
var _silk: MeshInstance2D

func _ready() -> void:
	super._ready()
	life = _end() + SCATTER + 0.2
	_glow = Art.drawer(true)
	add_child(_glow)
	_silk = Silk.node()
	add_child(_silk)
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _end() -> float: return land(count - 1)

## 0 … 1: how tight the threads are drawn (just before and at each landing).
func _tighten() -> float:
	var c := 0.0
	for i in count:
		var e := age - land(i)
		c = maxf(c, smoothstep(-0.15, 0.0, e) * clampf(1.0 - e / 0.25, 0.0, 1.0))
	return c

func _update() -> void:
	var stop := _end()
	var centre := start_point(0) + Vector2(0, -10)
	var rise := ease_out(age / maxf(charge + travel * 0.3, 0.05), 2.0)
	var scatter := clampf((age - stop) / SCATTER, 0.0, 1.0)
	var tight := _tighten()
	var glow: Array = []
	var silk := Silk.data()
	if age < stop and age > charge: stage.set("target_slow", SLOW)
	var count_threads := roundi(THREADS * (0.55 + 0.45 * Art.density()))
	for t in count_threads:
		var r := (60.0 + 90.0 * rnd(t)) * size * (1.0 - 0.35 * tight) * (1.0 + 1.6 * scatter) * (0.4 + 0.6 * rise)
		var height := rnd2(t + 1) * 70.0 * size
		var tilt := rnd2(t + 2) * 0.35
		var speed := (4.0 + 4.0 * rnd(t + 3)) * (1.0 + 0.8 * tight)
		var from := age * speed + rnd(t + 4) * TAU
		var span := 1.6 + 1.4 * rnd(t + 5)
		var points := PackedVector2Array()
		for s in 25:
			var a := from - span * s / 24.0
			var p := centre + Vector2(cos(a) * r, height + sin(a) * r * 0.28 + cos(a) * r * tilt)
			p.y = minf(p.y, GROUND_Y - 3.0)
			points.append(p)
		# The near side of its circle bright, the far side faint.
		var near := 0.55 + 0.45 * sin(from - span * 0.5)
		Silk.thread(silk, points, 2.0 * size, near * rise * (1.0 - scatter), 700 + t)
	# Motes swept round between the threads.
	for j in roundi(70 * Art.density()):
		var a := age * (5.0 + 3.0 * rnd(j)) + rnd(j + 1) * TAU
		var r := (50.0 + 120.0 * rnd(j + 2)) * size * (1.0 + 1.6 * scatter)
		var p := centre + Vector2(cos(a) * r, rnd2(j + 3) * 80.0 * size + sin(a) * r * 0.28)
		var twinkle := 0.5 + 0.5 * sin(age * 18.0 + j)
		Silk.mote(glow, p, 2.0, twinkle, 0.8 * rise * (1.0 - scatter * scatter))
	Silk.show(_silk, silk, age, 0.9 * (1.0 - 0.7 * scatter))
	(_glow as Art.Drawer).items = glow
	_glow.queue_redraw()
