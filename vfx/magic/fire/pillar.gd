extends "res://vfx/magic/magic_fx.gd"
## 地火 — fire from under the floor (start "below"): a pillar of fire that erupts under
## the target and keeps burning. One body; its `count` hits land `interval` apart while it
## burns, and it burns on `hold` s after the last.
##   charge — the floor cracks open where it will come up, the cracks glowing like magma,
##            smoke and embers seeping out, the ground lit from below
##   erupt  — over `travel` s the column shoots up out of the cracks to full height
##   burn   — a roaring column of licking flames, embers streaming up it, smoke rolling off
##            its top, warped air over it (炸裂 tier), the ground glowing around its foot
##   die    — it sinks back into the floor, leaving smoke and a scorch.
## It erupts where the target stands at the cast and stays there.

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
## Full height and width of the column at size 1, px.
const HEIGHT := 340.0
const WIDTH := 112.0
const SINK := 0.45
const FLAMES := 6

var _x := 0.0
var _scorch: MeshInstance2D
var _shade: Node2D
var _copy: BackBufferCopy
var _haze: MeshInstance2D
var _lights: Node2D
var _cracks: MeshInstance2D
var _flames: Array[MeshInstance2D] = []
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	_x = stage.target.position.x
	life = _burn_end() + SINK + 0.9
	_scorch = Art.quad("scorch")
	(stage.get("under") as Node2D).add_child(_scorch)
	_shade = Art.drawer(false)
	add_child(_shade)
	_copy = Art.backbuffer()
	add_child(_copy)
	_haze = Art.quad("heat_haze")
	add_child(_haze)
	_lights = Art.drawer(true)
	add_child(_lights)
	# The cracks are drawn with the lightning strips, tinted to magma.
	_cracks = Arcs.node()
	var crack_material: ShaderMaterial = _cracks.material
	crack_material.set_shader_parameter("glow_colour", Color(1.0, 0.55, 0.12))
	crack_material.set_shader_parameter("edge_colour", Color(0.8, 0.12, 0.04))
	add_child(_cracks)
	for i in FLAMES:
		var flame := Art.quad("flame_tongue")
		_flames.append(flame)
		add_child(flame)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_update()

func _exit_tree() -> void:
	if is_instance_valid(_scorch): _scorch.queue_free()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _burn_end() -> float: return land(count - 1) + hold

## How tall the column stands now, 0 … 1.
func _rise() -> float:
	var t1 := launch(0)
	if age < t1: return 0.0
	if age < land(0): return ease_out((age - t1) / maxf(travel, 0.01), 3.0)
	return clampf(1.0 - (age - _burn_end()) / SINK, 0.0, 1.0)

func _update() -> void:
	var t1 := launch(0)
	var rise := _rise()
	var foot := Vector2(_x, GROUND_Y)
	var height := HEIGHT * size * rise * (1.0 + 0.06 * noise(seed_id, age * 6.0))
	var width := WIDTH * size
	var lights: Array = []
	var shade: Array = []
	var sparks: Array = []
	var cracks := Arcs.data()
	var opening := clampf(age / maxf(charge, 0.01), 0.0, 1.0)
	var cooling := clampf(1.0 - (age - _burn_end() - SINK) / 0.6, 0.0, 1.0)
	# The cracks: opening through the charge, glowing while it burns, cooling after.
	var glow := opening * cooling
	if glow > 0.0:
		for j in 7:
			var heading := TAU * j / 7.0 + rnd2(j + 900) * 0.35
			var reach := width * (1.1 + 0.9 * rnd(j + 901)) * ease_out(opening, 2.0)
			var end := foot + Vector2(cos(heading), sin(heading) * 0.2) * reach
			Arcs.strip(cracks, Arcs.bolt(foot, end, seed_id * 13 + j, 0.35, 7.0), 4.0 * size, glow * (0.7 + 0.3 * noise(j, age * 8.0)), 0.12)
		lights.append(Arcs.light(foot + Vector2(0, -4), Vector2(width * 5.0, width * 1.0), Color(1.0, 0.45, 0.12, 0.7 * glow)))
	# The column of flames.
	for i in _flames.size():
		var flame := _flames[i]
		var tall: float = height * [1.0, 0.82, 0.78, 0.45, 0.4, 0.3][i]
		var wide: float = width * [0.9, 0.62, 0.62, 0.5, 0.5, 0.42][i]
		var shift: float = width * [0.0, -0.26, 0.26, -0.5, 0.5, 0.0][i] + noise(i + 30, age * 3.0) * width * 0.08
		flame.visible = tall > 4.0
		if flame.visible:
			Art.place(flame, Rect2(foot.x + shift - wide * 0.5, GROUND_Y - tall, wide, tall + 4.0))
			var m: ShaderMaterial = flame.material
			m.set_shader_parameter("time", age * 1.6)
			m.set_shader_parameter("seed", float(i) * 4.7 + seed_id % 11)
			m.set_shader_parameter("intensity", 1.0)
	if rise > 0.0:
		var middle := foot + Vector2(0, -height * 0.5)
		lights.append(Arcs.light(middle, Vector2(width * 5.0, height * 1.5), Color(1.0, 0.45, 0.14, 0.55 * rise)))
		lights.append(Arcs.light(foot, Vector2(width * 9.0, width * 1.4), Color(1.0, 0.5, 0.15, 0.7 * rise)))
		# The moment it bursts out of the floor: a flash.
		var burst := age - t1
		if burst >= 0.0 and burst < 0.12: lights.append(Arcs.light(foot + Vector2(0, -30), Vector2.ONE * width * 4.0, Color(1.0, 0.85, 0.6, 1.0 - burst / 0.12)))
	# Warped air over it.
	_haze.visible = rise > 0.05 and Art.full()
	if _haze.visible:
		var rect := Rect2(foot.x - width * 1.4, GROUND_Y - height * 1.35, width * 2.8, height * 1.35)
		Art.place(_haze, rect)
		_copy.rect = rect
		var hm: ShaderMaterial = _haze.material
		hm.set_shader_parameter("time", age)
		hm.set_shader_parameter("strength", 0.012)
	_embers(sparks, foot, width, height, rise, opening)
	_smoke(shade, foot, width, height)
	if is_instance_valid(_scorch):
		var mark := clampf(opening, 0.0, 1.0) * clampf(1.0 - (age - _burn_end() - SINK) / 0.9, 0.0, 1.0)
		Art.place(_scorch, Rect2(Vector2(foot.x - width * 1.6, GROUND_Y - width * 0.18), Vector2(width * 3.2, width * 0.5)))
		var sm: ShaderMaterial = _scorch.material
		sm.set_shader_parameter("fade", mark)
		sm.set_shader_parameter("seed", float(seed_id % 19))
	_cracks.mesh = Arcs.mesh(cracks)
	(_cracks.material as ShaderMaterial).set_shader_parameter("time", age)
	for pair in [[_lights, lights], [_shade, shade], [_sparks, sparks]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()

## Embers: seeping out of the cracks while it charges, streaming up the column as it burns.
func _embers(out: Array, foot: Vector2, width: float, height: float, rise: float, opening: float) -> void:
	var rate := 70.0 * Art.density()
	var span := 0.6
	for j in range(maxi(0, floori((age - span) * rate)), floori(minf(age, _burn_end() + SINK) * rate) + 1):
		var a := age - float(j) / rate
		if a < 0.0 or a >= span: continue
		var born_rise := clampf(height / maxf(HEIGHT * size, 1.0), 0.0, 1.0)
		var speed := lerpf(120.0, 650.0, born_rise) * (0.7 + 0.6 * rnd(j + 1))
		if born_rise < 0.05 and rnd(j + 2) > opening: continue
		var p := foot + Vector2(rnd2(j) * width * 0.45 + rnd2(j + 3) * 40.0 * a, -speed * a)
		var x := a / span
		var tone := Color(1.0, 0.9, 0.55).lerp(Color(1.0, 0.3, 0.05), x)
		tone.a = 1.0 - x
		out.append([Art.glow(), p, Vector2(4.0, 6.0 + speed * 0.02), PI * 0.5, tone])

## Smoke rolling off the top of the column (and seeping from the cracks before it erupts).
func _smoke(out: Array, foot: Vector2, width: float, height: float) -> void:
	var rate := 16.0 * Art.density()
	var span := 1.2
	var texture := Art.smoke()
	for j in range(maxi(0, floori((age - span) * rate)), floori(minf(age, _burn_end() + SINK) * rate) + 1):
		var born := float(j) / rate
		var a := age - born
		if a < 0.0 or a >= span: continue
		# Where the top of the column was when this puff left it.
		var top := foot.y - HEIGHT * size * _rise_at(born) * 0.95
		var p := Vector2(foot.x + rnd2(j) * width * 0.5 + rnd2(j + 1) * 60.0 * a, top - (80.0 + 60.0 * rnd(j + 2)) * a)
		var x := a / span
		var tone := Color(0.13, 0.1, 0.1).lerp(Color(0.55, 0.26, 0.1), clampf(1.0 - a / 0.35, 0.0, 1.0))
		tone.a = 0.55 * pow(1.0 - x, 1.3) * smoothstep(0.0, 0.1, a)
		out.append([texture, p, Vector2.ONE * width * (0.8 + 1.4 * sqrt(x)), rnd(j + 3) * TAU + x, tone])

func _rise_at(t: float) -> float:
	var keep := age
	age = t
	var r := _rise()
	age = keep
	return r
