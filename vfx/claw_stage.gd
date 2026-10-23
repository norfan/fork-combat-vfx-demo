@tool
extends ComboStage
## Claw marks for `slash` events (`"renderer": "claw"` in style.json). Every slash becomes
## a rake of torn strands along one path, aimed so it crosses the target at
## `t + duration × contact`:
##   claw "arc"    — around the attacker like a sword arc; any sweep, so −90 → 270 is a full
##                   loop and −90 → 630 two (大回环). `spiral` grows the radius through it.
##   claw "slam"   — 暴扣: dives from high behind the target, through it, into the ground,
##                   and skids along the floor.
##   claw "rake"   — a straight swipe through the target at `angle` degrees.
##   claw "swipe"  — 横斩: a wide, shallow horizontal swipe through the target (`angle` 0
##                   forehand, 180 backhand), bowed by `bend`; the gashes stack vertically.
##   claw "dash"   — 突进: the attacker lunges at the target with the claws out (the body
##                   really moves, stopping just short of it) and the gashes pierce `past` px
##                   beyond it.
##   claw "cross"  — 交叉斩: two rakes crossing in an X through the target, the second
##                   `cross_delay` s later (pair it with two hits).
## Every hit also scratches the target along the claw's direction (the marks ride the
## target), and a slam finisher bites into the floor and cracks it to both sides. Other
## events play as usual.
## combo.json may carry "captions": [[t, "text"], ...] shown at the top left.
const Claw = preload("res://vfx/claw_rake.gd")
const DEFAULTS := {"duration": 0.16, "tail": 0.22, "fingers": 3, "spread": 18.0, "jag": 0.45,
	"contact": 0.5, "squash": 1.0, "tilt": 0.0, "spiral": 0.0, "angle": 40.0, "length": 230.0,
	"mark": 0.0, "trail": 0.1, "bend": 0.12, "past": 110.0, "cross_delay": 0.07}

var captions: Array = []
var caption: Label
var _last_claw: Node2D
var _last_kind := "arc"
## Rakes still on screen, for matching each hit's scratches to the claw that crossed it.
var _recent: Array[Node2D] = []

func _ready() -> void:
	super._ready()
	caption = Label.new()
	caption.position = Vector2(70, 100)
	caption.add_theme_font_size_override("font_size", 32)
	caption.modulate = ComboStyle.c("text")
	overlay.add_child(caption)
	if not combo_file.is_empty() and FileAccess.file_exists(combo_file):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(combo_file))
		if parsed is Dictionary: captions = (parsed as Dictionary).get("captions", [])

func reset() -> void:
	_last_claw = null
	_recent.clear()
	super.reset()

func _refresh() -> void:
	super._refresh()
	if not is_instance_valid(caption): return
	var text := ""
	for entry in captions:
		if clock + 0.000001 >= float(entry[0]): text = String(entry[1])
	caption.text = text

func _fire(event: Dictionary) -> void:
	if event.do != "slash":
		super._fire(event)
		return
	var spec := DEFAULTS.duplicate()
	for key in spec: if event.has(key): spec[key] = event[key]
	var kind := String(event.get("claw", "arc"))
	var span := float(spec.duration)
	var contact := clampf(float(spec.contact), 0.0, 1.0)
	var delay := span * contact
	# The path fraction the strand heads reach at the contact time (they run on the
	# swing ease), and where the target will be then.
	var reach_at := PixelSlash.ease_swing(contact)
	var aim := target.position + Vector2(-TARGET_SIZE.x * 0.3, -TARGET_SIZE.y * 0.55) + _target_velocity * delay
	if target.position.y < GROUND_Y or _target_velocity.y < 0.0:
		aim.y += GRAVITY * delay * delay * 0.5
	var breadth := float(event.width) * ComboStyle.thickness
	var make := func(seed_offset: int) -> Node2D:
		return Claw.new().configure({"duration": span, "tail": float(spec.tail), "fingers": int(spec.fingers),
			"spread": float(spec.spread) * ComboStyle.thickness, "width": breadth * 0.34, "jag": float(spec.jag),
			"mark": float(spec.mark), "trail": float(spec.trail),
			"pixel": ComboStyle.pixel, "palette": PixelSlash.palette_of(event.palette), "seed_id": hits + _next + seed_offset})
	var claw: Node2D = make.call(0)
	var angle := deg_to_rad(float(spec.angle))
	match kind:
		"slam":
			claw.path = _slam_path(aim, reach_at)
			fx.add_child(claw)
		"rake":
			claw.path = _rake_path(aim, angle, float(spec.length), reach_at)
			fx.add_child(claw)
		"swipe":
			# Forehand by default; any angle near 180 is a backhand. Shallow, so it reads
			# as horizontal however it is tilted.
			var swipe_angle := angle if event.has("angle") else 0.0
			claw.path = _bowed_path(aim, swipe_angle, float(spec.length) if event.has("length") else 320.0, reach_at, float(spec.bend))
			fx.add_child(claw)
		"dash":
			claw.path = _dash_path(aim, float(spec.past), reach_at)
			if claw.mark <= 0.0: claw.mark = clampf((aim.x - attacker.position.x) * 0.9, 90.0, 260.0)
			fx.add_child(claw)
			# The body lunges with the claws, stopping just short of the target.
			var by := maxf(0.0, aim.x - attacker.position.x - 70.0)
			_moves.append({"from": attacker.position, "to": attacker.position + Vector2(by, 0), "age": 0.0, "time": maxf(span * 0.8, 0.04)})
		"cross":
			claw.path = _rake_path(aim, angle, float(spec.length), reach_at)
			fx.add_child(claw)
			var second: Node2D = make.call(17)
			second.path = _rake_path(aim, PI - angle, float(spec.length), reach_at)
			second.delay = float(spec.cross_delay)
			fx.add_child(second)
			_recent.append(second)
		_:
			claw.path = _arc_path(event, spec, aim, delay, reach_at)
			attacker.add_child(claw)
	_last_claw = claw
	_last_kind = kind
	_recent.append(claw)
	# Drop rakes that have finished; freed ones cannot go through a typed lambda.
	for i in range(_recent.size() - 1, -1, -1):
		if not is_instance_valid(_recent[i]) or _recent[i].is_queued_for_deletion(): _recent.remove_at(i)

## Around the attacker (attacker-local), fitted so the swing angle at `reach_at` points at
## the aim with the radius at that point equal to the aim distance.
func _arc_path(event: Dictionary, spec: Dictionary, aim: Vector2, delay: float, reach_at: float) -> PackedVector2Array:
	var origin := attacker.position
	for move in _moves:
		origin = (move.from as Vector2).lerp(move.to, PixelSlash.ease_swing(minf(float(move.age) + delay, move.time) / move.time))
	var squash := float(spec.squash)
	var tilt := deg_to_rad(float(spec.tilt))
	var local := (aim - origin).rotated(-tilt) / Vector2(1, squash)
	var from := deg_to_rad(float(event.from))
	var to := deg_to_rad(float(event.to))
	var spiral := float(spec.spiral)
	var grow := func(u: float) -> float: return lerpf(1.0 - spiral, 1.0 + spiral, u)
	var radius: float = local.length() / float(grow.call(reach_at))
	var offset := local.angle() - lerpf(from, to, reach_at)
	var points := PackedVector2Array()
	var steps := clampi(ceili(absf(to - from) / deg_to_rad(2.0)), 24, 720)
	for i in steps + 1:
		var u := float(i) / steps
		var angle := lerpf(from, to, u) + offset
		points.append((Vector2(cos(angle), sin(angle) * squash) * radius * float(grow.call(u))).rotated(tilt))
	return points

## 暴扣: one stroke from high above, through the target and on into the ground (it digs a
## little below the floor line), all on one heading with only a slight bow — it never turns.
## The start is placed so the heads reach the target at `reach_at` of the stroke's length.
func _slam_path(aim: Vector2, reach_at: float) -> PackedVector2Array:
	var down := Vector2(0.24, 0.97).normalized()
	var after := maxf(24.0, (GROUND_Y + 10.0 - aim.y) / down.y)
	var before := after * reach_at / maxf(1.0 - reach_at, 0.05)
	var start := aim - down * before
	var impact := aim + down * after
	var bow := Vector2(-down.y, down.x) * (before + after) * 0.04
	return _curve(start, aim + bow, impact)

## 横斩: a long, shallow line through the aim, bowed upwards by `bend` × its length.
func _bowed_path(aim: Vector2, angle: float, length: float, reach_at: float, bend: float) -> PackedVector2Array:
	var dir := Vector2.from_angle(angle)
	var up := Vector2(0, -1) * length * bend
	return _curve(aim - dir * length * reach_at + up * 0.5, aim - up * 0.25, aim + dir * length * (1.0 - reach_at) + up * 0.5)

## 突进: from the attacker's reach straight through the target at its height, `past` beyond.
func _dash_path(aim: Vector2, past: float, reach_at: float) -> PackedVector2Array:
	var start := Vector2(attacker.position.x + 20.0, aim.y + 6.0)
	var after := past
	var before := aim.x - start.x
	# Keep the contact rule: the heads reach the aim at `reach_at` of the path.
	if before / maxf(before + after, 1.0) > reach_at: after = before * (1.0 - reach_at) / maxf(reach_at, 0.05)
	else: start.x = aim.x - after * reach_at / maxf(1.0 - reach_at, 0.05)
	return _curve(start, aim + Vector2(0, -4), aim + Vector2(after, 10))

func _rake_path(aim: Vector2, angle: float, length: float, reach_at: float) -> PackedVector2Array:
	var dir := Vector2.from_angle(angle)
	return _curve(aim - dir * length * reach_at, aim, aim + dir * length * (1.0 - reach_at))

## A quadratic curve a → b (control) → c, sampled every few px.
func _curve(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := maxi(8, ceili((a.distance_to(b) + b.distance_to(c)) / 6.0))
	for i in steps + 1:
		var u := float(i) / steps
		points.append(a.lerp(b, u).lerp(b.lerp(c, u), u))
	return points

func _hit(event: Dictionary) -> void:
	super._hit(event)
	var at := target.position + Vector2(-TARGET_SIZE.x * 0.3, -TARGET_SIZE.y * 0.55)
	if bool(event.get("finisher", false)): at = target.position + Vector2(0, -TARGET_SIZE.y * 0.5)
	var dir := Vector2.from_angle(deg_to_rad(40.0))
	var fingers := 3
	var spread := 12.0
	var palette: Array = PixelSlash.palette_of(event.palette)
	# The claw whose heads are nearest the target now is the one that struck.
	var striker: Node2D = null
	for claw in _recent:
		if not is_instance_valid(claw) or claw.age < 0.0: continue
		if striker == null or claw.head_point().distance_to(at) < striker.head_point().distance_to(at): striker = claw
	if striker != null:
		dir = striker.head_direction()
		if dir == Vector2.ZERO: dir = Vector2.RIGHT
		fingers = striker.fingers
		spread = striker.spread * 0.6
		palette = striker.palette
	# Scratches torn into the target along the claw's travel; they ride its knockback.
	var length := TARGET_SIZE.y * 1.15
	fx.add_child(Claw.new().configure({"path": _curve(at - dir * length * 0.5, at, at + dir * length * 0.5),
		"duration": 0.05, "tail": 0.75, "fingers": fingers, "spread": spread, "width": 11.0, "jag": 0.6, "mark": length * 0.9, "trail": 0.0,
		"stagger": 0.008, "debris": 0.0, "pixel": ComboStyle.pixel, "palette": palette, "seed_id": hits * 7,
		"follow": target, "follow_offset": -target.position}))
	if bool(event.get("finisher", false)) and _last_kind == "slam" and is_instance_valid(_last_claw):
		_ground_impact(_last_claw, palette)

## Where a slam meets the floor: the claws bite on into the ground along the dive and stop,
## flicking rubble, and thin jagged cracks spread from the impact to both sides. Nothing
## slides off sideways, so the stroke keeps reading as one blow straight down.
func _ground_impact(slam: Node2D, palette: Array) -> void:
	var path: PackedVector2Array = slam.path
	var impact := path[-1]
	for point in path:
		if point.y >= GROUND_Y - 2.0:
			impact = point
			break
	var dir := (path[-1] - path[-2]).normalized()
	fx.add_child(Claw.new().configure({"path": _curve(impact - dir * 26.0, impact + dir * 10.0, impact + dir * 46.0),
		"duration": 0.07, "tail": 0.7, "fingers": slam.fingers, "spread": slam.spread * 0.45, "width": 14.0, "jag": 0.5,
		"mark": 64.0, "trail": 0.0, "stagger": 0.01, "debris": 160.0, "pixel": ComboStyle.pixel, "palette": palette, "seed_id": 91}))
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var reach := 70.0 + 45.0 * float(i / 2) + 18.0 * sin(i * 2.3)
		var drop := 3.0 + 4.0 * float(i / 2)
		var points := PackedVector2Array([impact])
		var steps := 7
		for s in range(1, steps + 1):
			var u := float(s) / steps
			# Zigzag along the floor line, sinking a little as it runs out.
			var wobble := (4.0 + 3.0 * u) * (1.0 if (s + i) % 2 == 0 else -1.0)
			points.append(impact + Vector2(side * reach * u, drop * u + wobble * 0.6))
		fx.add_child(Claw.new().configure({"path": points, "duration": 0.09 + 0.02 * float(i / 2), "tail": 0.75,
			"fingers": 1, "spread": 0.0, "width": 6.0 - float(i / 2), "jag": 0.8, "mark": reach * 1.05, "trail": 0.0,
			"debris": 0.0, "pixel": ComboStyle.pixel, "palette": palette, "seed_id": 120 + i}))
