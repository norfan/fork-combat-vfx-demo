extends "res://vfx/magic/magic_fx.gd"
## Where a fire spell lands, sized by its blast `radius`. The body turns into the blast:
##   a white-hot flash (and the whole screen flaring for an instant, on real time so a long
##   hit-stop does not hold it), a churning fireball that swells, lifts, cools and burns out
##   from the inside (shader), a shockwave ring bending the air outwards, embers thrown up
##   that fall and bounce once, dark debris, smoke billowing up into a column, and — when it
##   goes off near the floor — a flare of light on the ground, flames left licking the
##   ground and a scorch mark (under the target) with embers glowing in it as it cools.

const Art = preload("res://vfx/magic/magic_art.gd")
const EMBERS := 34
const DEBRIS := 9
const PUFFS := 16
const FLAMES := 5

var _scorch: MeshInstance2D
var _smoke: Node2D
var _core: MeshInstance2D
var _shock: MeshInstance2D
var _copy: BackBufferCopy
var _flames: Array[MeshInstance2D] = []
var _debris: Node2D
var _lights: Node2D
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	life = 1.9 + radius / 300.0
	if _near_ground():
		_scorch = Art.quad("scorch")
		var under: Node2D = stage.get("under")
		under.add_child(_scorch)
	_smoke = Art.drawer(false)
	add_child(_smoke)
	_lights = Art.drawer(true)
	add_child(_lights)
	# Debris under the fireball: while it is inside the blast the fire covers it.
	_debris = Art.drawer(false)
	add_child(_debris)
	_core = Art.quad("explosion")
	add_child(_core)
	if _near_ground():
		for i in FLAMES:
			var flame := Art.quad("flame_tongue")
			_flames.append(flame)
			add_child(flame)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_copy = Art.backbuffer()
	add_child(_copy)
	_shock = Art.quad("shockwave")
	add_child(_shock)
	_update()

func _exit_tree() -> void:
	if is_instance_valid(_scorch): _scorch.queue_free()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

## Only a blast that goes off at the floor scorches it and leaves flames on it.
func _near_ground() -> bool: return GROUND_Y - at.y < radius * 0.7

## The blast's scale against a radius-70 blast.
func _k() -> float: return radius / 70.0

func _update() -> void:
	var k := _k()
	var glow := Art.glow()
	var lights: Array = []
	var sparks: Array = []
	var smoke: Array = []
	var debris: Array = []
	# The flash (on real time: a hit-stop holds the blast, not the glare) with a wide streak
	# of light through it, and for a finisher the whole screen flaring.
	var flash := clampf(flash_left(1, 0.14), 0.0, 1.0)
	if flash > 0.0:
		var big := 1.0 if finisher else 0.6
		lights.append([glow, at, Vector2.ONE * radius * 5.0 * big * (0.6 + 0.4 * flash), 0.0, Color(1.0, 0.85, 0.6, flash)])
		lights.append([glow, at, Vector2(radius * 16.0 * big, radius * 0.35), 0.0, Color(1.0, 0.75, 0.45, flash)])
	var screen := flash_left(0, 0.18) if finisher else 0.0
	if screen > 0.0: lights.append([null, Vector2(640, 360), Vector2(1600, 1100), 0.0, Color(1.0, 0.55, 0.2, 0.3 * screen)])
	# The fireball.
	var burn := 0.55 + radius / 260.0
	var p := age / burn
	_core.visible = p < 1.0
	if _core.visible:
		var side := radius * 3.4
		Art.place(_core, Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side))
		var m: ShaderMaterial = _core.material
		m.set_shader_parameter("floor_v", (GROUND_Y + 2.0 - (at.y - side * 0.5)) / side)
		m.set_shader_parameter("progress", p)
		m.set_shader_parameter("time", age)
		m.set_shader_parameter("seed", float(seed_id % 41))
		# Its light on everything around, fading as it cools.
		lights.append([glow, at, Vector2.ONE * radius * 8.0, 0.0, Color(1.0, 0.45, 0.15, 0.45 * (1.0 - p))])
	# The shockwave.
	var wave := age / 0.3
	_shock.visible = wave < 1.0 and Art.full()
	if _shock.visible:
		var side := radius * 7.0
		Art.place(_shock, Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side))
		_copy.rect = Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		var sm: ShaderMaterial = _shock.material
		sm.set_shader_parameter("radius", ease_out(wave, 2.2) * 0.95)
		sm.set_shader_parameter("strength", 0.035)
	elif wave < 1.0:
		# Without the warp the shockwave is a ring of light.
		var ring := radius * 3.5 * ease_out(wave, 2.2)
		lights.append([glow, at, Vector2.ONE * ring * 2.0, 0.0, Color(1.0, 0.7, 0.4, 0.25 * (1.0 - wave))])
	# Near the floor: a flare along it, flames left on it, the scorch under the target.
	if _near_ground():
		var flare := clampf(1.0 - age / 0.6, 0.0, 1.0)
		if flare > 0.0: lights.append([glow, Vector2(at.x, GROUND_Y + 2.0), Vector2(radius * 11.0, radius * 1.8), 0.0, Color(1.0, 0.5, 0.15, 0.8 * flare)])
		for i in _flames.size():
			var flame := _flames[i]
			var lit := age - 0.06 - 0.08 * rnd(i + 70)
			var dying := 1.15 + 0.4 * rnd(i + 71)
			var tall := radius * (0.6 + 0.5 * rnd(i + 72)) * pow(clampf(1.0 - lit / dying, 0.0, 1.0), 0.6) * ease_out(lit / 0.12)
			flame.visible = lit > 0.0 and tall > 3.0
			if flame.visible:
				var x := at.x + rnd2(i + 73) * radius * 1.1
				var wide := radius * (0.55 + 0.3 * rnd(i + 74))
				Art.place(flame, Rect2(x - wide * 0.5, GROUND_Y - tall, wide, tall + 3.0))
				var fm: ShaderMaterial = flame.material
				fm.set_shader_parameter("time", age)
				fm.set_shader_parameter("seed", float(i) * 5.3 + seed_id % 13)
		if is_instance_valid(_scorch):
			var fade := clampf(1.0 - (age - 0.3) / (life - 0.3), 0.0, 1.0) * ease_out(age / 0.08)
			Art.place(_scorch, Rect2(Vector2(at.x - radius * 1.7, GROUND_Y - radius * 0.22), Vector2(radius * 3.4, radius * 0.55)))
			var cm: ShaderMaterial = _scorch.material
			cm.set_shader_parameter("fade", fade)
			cm.set_shader_parameter("seed", float(seed_id % 23))
	# Embers thrown up and out; they fall and bounce once off the floor.
	for j in ceili(EMBERS * Art.density()):
		var span := 0.6 + 0.6 * rnd(j + 100)
		if age >= span: continue
		var v := Vector2.from_angle(-PI * 0.5 + rnd2(j + 101) * 1.4) * (300.0 + 650.0 * rnd(j + 102)) * sqrt(k)
		var state := ballistic(at + v.normalized() * radius * 0.3, v, age)
		var x := age / span
		var tone := Color(1.0, 0.95, 0.7).lerp(Color(1.0, 0.25, 0.04), x)
		tone.a = 1.0 - x * x
		sparks.append([glow, state[0], Vector2(5.0 + (state[1] as Vector2).length() * 0.03, 4.0), (state[1] as Vector2).angle(), tone])
	# Debris: dark chunks tumbling.
	for j in ceili(DEBRIS * Art.density()):
		var span := 0.9 + 0.4 * rnd(j + 200)
		if age >= span: continue
		var v := Vector2.from_angle(-PI * 0.5 + rnd2(j + 201) * 1.2) * (250.0 + 400.0 * rnd(j + 202)) * sqrt(k)
		var state := ballistic(at + v.normalized() * radius * 0.35, v, age)
		var bit := (3.0 + 4.0 * rnd(j + 203)) * sqrt(k)
		debris.append([null, state[0], Vector2(bit, bit * 0.8), age * (8.0 + 10.0 * rnd(j + 204)), Color(0.1, 0.07, 0.06, clampf((span - age) / 0.2, 0.0, 1.0))])
	# Smoke billowing up into a column, lit warm while it is young.
	var smoke_texture := Art.smoke()
	for j in ceili(PUFFS * Art.density()):
		var a := age - 0.04 - 0.02 * j
		var span := 1.3 + 0.6 * rnd(j + 300)
		if a < 0.0 or a >= span: continue
		var x := a / span
		var offset := Vector2(rnd2(j + 301), rnd2(j + 302) * 0.6) * radius * 0.7
		var rise := Vector2(rnd2(j + 303) * 50.0, -(70.0 + 120.0 * rnd(j + 304))) * sqrt(k)
		var p0 := at + offset + rise * a + Vector2(0, -60.0) * a * a
		var young := clampf(1.0 - a / 0.45, 0.0, 1.0)
		var tone := Color(0.12, 0.09, 0.09).lerp(Color(0.6, 0.27, 0.1), young)
		tone.a = 0.75 * pow(1.0 - x, 1.2) * smoothstep(0.0, 0.1, a)
		smoke.append([smoke_texture, p0, Vector2.ONE * radius * (0.7 + 1.4 * sqrt(x)) * (0.8 + 0.4 * rnd(j + 305)), rnd(j + 306) * TAU + x * 0.7, tone])
	for pair in [[_lights, lights], [_sparks, sparks], [_smoke, smoke], [_debris, debris]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()
