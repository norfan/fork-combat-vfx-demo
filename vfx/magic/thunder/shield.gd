extends "res://vfx/magic/thunder/bolt.gd"
## 雷盾 — lightning that stays (path "stay"): a shield of arcs around its start, riding
## along with it, that bursts when it lands. It is the strike's body bent into a sphere, so
## it keeps the strike's charge (the crackling orb, the darkening air):
##   charge — the orb gathers on the caster
##   hold   — for `travel` s a shell of arcs crackles over a sphere around the caster, a
##            few cutting across it, sparks flicking off; it does no harm. In its last
##            instant it draws in tight and brightens.
##   burst  — it lands: the shell blows outwards to the blast `radius` as a ring of arcs and
##            flashes (pair a hit with it; the strike's impact goes off around the caster).

const SHELL := 72.0
const SQUEEZE := 0.18
const BURST := 0.2

func _ready() -> void:
	super._ready()
	life = land(0) + BURST + 0.05

func _update() -> void:
	var t1 := launch(0)
	var t2 := land(0)
	var frame := floori(maxf(age, 0.0) * ROLL)
	var shade: Array = []
	var lights: Array = []
	var sparks: Array = []
	var mesh := Arcs.data()
	# Keep the same spherical shell when a ring is sent along a flight path.
	# path_at preserves the live caster anchor for the original stationary shield.
	var centre := path_at(0, clampf((age - t1) / maxf(travel, 0.001), 0.0, 1.0))
	var blue := Color(0.55, 0.72, 1.0)
	if age < t1:
		var k := clampf(age / maxf(charge, 0.01), 0.0, 1.0)
		shade.append([null, Vector2(640, 360), Vector2(1600, 1100), 0.0, Color(0.02, 0.03, 0.08, 0.18 * k)])
		_charge(mesh, lights, sparks, centre, k, frame)
	elif age < t2:
		var left := t2 - age
		var squeeze := clampf(1.0 - left / SQUEEZE, 0.0, 1.0)
		var r := SHELL * size * (1.0 + 0.04 * sin(age * 21.0)) * (1.0 - 0.18 * squeeze) * ease_out((age - t1) / 0.1, 2.0)
		var power := 0.75 + 0.25 * squeeze
		shade.append([null, Vector2(640, 360), Vector2(1600, 1100), 0.0, Color(0.02, 0.03, 0.08, 0.18 * clampf(1.0 - (age - t1) / 0.2, 0.0, 1.0))])
		_shell(mesh, centre, r, power, frame, roundi((8.0 + 6.0 * squeeze) * Art.density()) + 3)
		# A few arcs cutting across the inside.
		for j in roundi(2 * Art.density()) + 1:
			var key := frame * 37 + j * 11 + seed_id
			var a := centre + Vector2.from_angle(Arcs.hash01(key) * TAU) * r * 0.95
			var b := centre + Vector2.from_angle(Arcs.hash01(key + 1) * TAU) * r * 0.95
			Arcs.strip(mesh, Arcs.bolt(a, b, key, 0.3, 6.0), 2.5 * size, 0.5 * power, 0.35)
		lights.append(Arcs.light(centre, Vector2.ONE * r * 3.2, Color(blue, 0.3 + 0.35 * squeeze)))
		lights.append(Arcs.light(centre, Vector2.ONE * r * 1.4, Color(0.8, 0.9, 1.0, 0.15 + 0.4 * squeeze)))
		if GROUND_Y - centre.y < r * 1.6:
			lights.append(Arcs.light(Vector2(centre.x, GROUND_Y + 2.0), Vector2(r * 5.0, r * 0.7), Color(blue, 0.45 * power)))
		for j in roundi(5 * Art.density()):
			var key := frame * 19 + j * 3 + seed_id
			if Arcs.hash01(key) < 0.5: continue
			var a := Arcs.hash01(key + 1) * TAU
			var p := centre + Vector2.from_angle(a) * r
			var tangent := Vector2.from_angle(a + PI * 0.5 * (1.0 if Arcs.hash01(key + 2) > 0.5 else -1.0))
			sparks.append([Art.glow(), p + tangent * 6.0, Vector2(14, 3) * size, tangent.angle(), Color(0.85, 0.92, 1.0, 0.9)])
	else:
		# The burst: the shell blowing out to the blast radius.
		var e := age - t2
		var x := clampf(e / BURST, 0.0, 1.0)
		var r := lerpf(SHELL * size * 0.82, maxf(radius, SHELL * size) * 1.1, ease_out(e / 0.12, 2.5))
		_shell(mesh, centre, r, 1.0 - x, frame, roundi(14 * Art.density()) + 4)
		lights.append(Arcs.light(centre, Vector2.ONE * r * 2.6, Color(blue, 0.6 * (1.0 - x))))
		var flash := flash_left(0, 0.08)
		if flash > 0.0: lights.append([null, Vector2(640, 360), Vector2(1600, 1100), 0.0, Color(0.75, 0.85, 1.0, 0.12 * flash)])
	_bolt.mesh = Arcs.mesh(mesh)
	(_bolt.material as ShaderMaterial).set_shader_parameter("time", age)
	for pair in [[_shade, shade], [_lights, lights], [_sparks, sparks]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()

## `count` arcs crawling over a sphere of radius r: each a stretch of its rim, kinked.
func _shell(mesh: Dictionary, centre: Vector2, r: float, power: float, frame: int, count: int) -> void:
	for j in count:
		var key := frame * 61 + j * 17 + seed_id
		var from := Arcs.hash01(key) * TAU
		var span := 0.5 + 0.8 * Arcs.hash01(key + 1)
		var backbone := PackedVector2Array()
		for s in 5:
			var a := from + span * s / 4.0
			backbone.append(centre + Vector2(cos(a), sin(a) * 0.94) * r * (0.92 + 0.12 * Arcs.hash01(key + 3 + s)))
		Arcs.strip(mesh, Arcs.jag(backbone, key, 0.16, 2), 5.0 * size, power, 0.32)
