extends "res://vfx/magic/magic_fx.gd"
## The target keeps burning after a fire hit: flames lick up off its body and embers drift
## off it, riding its knockback, dying down over `life`. A new fire hit restarts it.

const Art = preload("res://vfx/magic/magic_art.gd")
const FLAMES := 4
const EMBER_RATE := 30.0

var _glow: Sprite2D
var _flames: Array[MeshInstance2D] = []
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	life = _span()
	_glow = Art.light()
	add_child(_glow)
	for i in FLAMES:
		var flame := Art.quad("flame_tongue")
		_flames.append(flame)
		add_child(flame)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_update()

func _span() -> float: return 1.4 if finisher else 0.9

func renew(longer: bool) -> void:
	super.renew(longer)
	life = _span()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var body := stage.target.position
	var dying := clampf(1.0 - age / life, 0.0, 1.0)
	Art.spread_light(_glow, body + Vector2(0, -50), Vector2(150, 190), Color(1.0, 0.45, 0.15, 0.4 * dying))
	for i in _flames.size():
		var flame := _flames[i]
		var tall := (34.0 + 26.0 * rnd(i + 10)) * pow(dying, 0.7) * (0.85 + 0.3 * noise(i + 11, age * 4.0))
		flame.visible = tall > 4.0
		if not flame.visible: continue
		var base := body + Vector2(rnd2(i + 12) * 16.0, -10.0 - 70.0 * rnd(i + 13))
		var wide := 18.0 + 10.0 * rnd(i + 14)
		Art.place(flame, Rect2(base.x - wide * 0.5, base.y - tall, wide, tall))
		var m: ShaderMaterial = flame.material
		m.set_shader_parameter("time", age)
		m.set_shader_parameter("seed", float(i) * 3.1 + seed_id % 7)
		m.set_shader_parameter("intensity", 0.9)
	var glow := Art.glow()
	var sparks: Array = []
	var span := 0.5
	var rate := EMBER_RATE * Art.density()
	for j in range(maxi(0, floori((age - span) * rate)), floori(minf(age, life - 0.2) * rate) + 1):
		var a := age - float(j) / rate
		if a < 0.0 or a >= span or rnd(j + 40) > dying + 0.2: continue
		var p := body + Vector2(rnd2(j + 41) * 20.0, -rnd(j + 42) * 90.0) + Vector2(rnd2(j + 43) * 30.0, -80.0) * a
		var tone := Color(1.0, 0.8, 0.4).lerp(Color(1.0, 0.25, 0.05), a / span)
		tone.a = 1.0 - a / span
		sparks.append([glow, p, Vector2(5, 5), 0.0, tone])
	(_sparks as Art.Drawer).items = sparks
	_sparks.queue_redraw()
