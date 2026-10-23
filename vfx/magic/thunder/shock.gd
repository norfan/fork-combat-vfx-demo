extends "res://vfx/magic/magic_fx.gd"
## The target stays electrified after a lightning hit: arcs jump across its body and now
## and then down to the floor, it flashes white in jolts and sparks pop off it, all riding
## its knockback and dying down over `life`. A new lightning hit restarts it.

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const ROLL := 25.0

var _lights: Node2D
var _arcs: MeshInstance2D
var _sparks: Node2D

func _ready() -> void:
	super._ready()
	life = _span()
	_lights = Art.drawer(true)
	add_child(_lights)
	_arcs = Arcs.node()
	add_child(_arcs)
	_sparks = Art.drawer(true)
	add_child(_sparks)
	_update()

func _span() -> float: return 1.1 if finisher else 0.7

func renew(longer: bool) -> void:
	super.renew(longer)
	life = _span()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _update() -> void:
	var body := stage.target.position
	var dying := clampf(1.0 - age / life, 0.0, 1.0)
	var frame := floori(age * ROLL)
	var mesh := Arcs.data()
	var lights: Array = []
	var sparks: Array = []
	var jolt := Arcs.hash01(frame * 3 + seed_id) < 0.35 * dying + 0.1
	lights.append(Arcs.light(body + Vector2(0, -50), Vector2(150, 190), Color(0.55, 0.7, 1.0, (0.45 if jolt else 0.15) * dying)))
	if jolt and dying > 0.25: stage.set("_target_flash", maxf(float(stage.get("_target_flash")), 0.02))
	var arcs := roundi((3.0 if finisher else 2.0) * Art.density()) + 1
	for j in arcs:
		var key := frame * 41 + j * 7 + seed_id
		if Arcs.hash01(key) > dying + 0.2: continue
		var a := body + Vector2(Arcs.hash11(key + 1) * 22.0, -Arcs.hash01(key + 2) * 94.0)
		var b := body + Vector2(Arcs.hash11(key + 3) * 22.0, -Arcs.hash01(key + 4) * 94.0)
		if a.distance_to(b) < 30.0: b = a + Vector2(0, 36 if a.y < body.y - 48.0 else -36)
		# Now and then one jumps to the floor.
		if Arcs.hash01(key + 5) < 0.2: b = Vector2(body.x + Arcs.hash11(key + 6) * 60.0, GROUND_Y)
		Arcs.strip(mesh, Arcs.bolt(a, b, key, 0.4, 5.0), 3.5, 0.85 * (0.4 + 0.6 * dying), 0.35)
	if Arcs.hash01(frame * 5 + 99) < dying * 0.7:
		var p := body + Vector2(Arcs.hash11(frame) * 24.0, -Arcs.hash01(frame + 5) * 96.0)
		for j in 3:
			var dir := Vector2.from_angle(Arcs.hash01(frame * 3 + j) * TAU)
			sparks.append([Art.glow(), p + dir * 8.0, Vector2(12, 3), dir.angle(), Color(0.85, 0.92, 1.0, 0.9)])
	_arcs.mesh = Arcs.mesh(mesh)
	(_arcs.material as ShaderMaterial).set_shader_parameter("time", age)
	(_lights as Art.Drawer).items = lights
	_lights.queue_redraw()
	(_sparks as Art.Drawer).items = sparks
	_sparks.queue_redraw()
