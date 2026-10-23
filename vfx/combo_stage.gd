@tool
class_name ComboStage
extends Node2D
## Fighting-game sword combo: an abstract attacker point strikes a target block. Every cut
## is a crescent smear grown from the attacker (it follows the attacker and never flies
## off); each hit lands on the target with a star spark, a white flash, a shared hit-stop
## with the target shaking in place, knockback / launch and a hit counter. The events
## come from combo.json. Keys: 1 / Space play, 2 slow motion, R reset. In the editor it
## draws the stage at rest, so a combo scene shows what it is before you run it.

const GROUND_Y := 520.0
const ATTACKER_START := Vector2(430, GROUND_Y - 70)
const TARGET_START := Vector2(575, GROUND_Y)
const TARGET_SIZE := Vector2(44, 96)
const GRAVITY := 1500.0
const SLOW_SPEED := 0.25
const COUNTER_POP := 0.14

## Timeline in combo seconds; the combo clock stops during hit-stop.
## slash: crescent anchored on the attacker (degrees, y down, facing right); a very flat
## one (squash ~0.16) through 0° is the thrust. move: attacker glides by `by`.
## hit: target reaction. charge: glint on the attacker. flash_step: instant move with a
## smear left behind. cut: a straight cut drawn across the target.
## Read from the combo's combo.json (references/combo_events.md), sorted by time.
var TIMELINE: Array = []
## The combo.json this stage plays (set by ComboPlayer before it enters the tree).
var combo_file := ""

## Values an event may leave out.
const EVENT_DEFAULTS := {
	"slash": {"radius": 140.0, "from": -70.0, "to": 70.0, "width": 44.0},
	"move": {"by": [0, 0], "time": 0.08},
	"hit": {"push": 60.0, "stop": 0.05, "shake": 2.5, "spark": 46.0},
	"flash_step": {"past": 140.0},
	"cut": {"angle": 0.0},
}

## Reads the events; `by` becomes a Vector2 and `palette` a StringName.
static func load_timeline(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary or not (parsed as Dictionary).get("events") is Array:
		push_error("combo.json needs an \"events\" array")
		return []
	return parse_events(parsed.events)

## The same for an events array already in memory (the manual editor's live preview).
static func parse_events(raw_events: Array) -> Array:
	var events: Array = []
	for raw: Variant in raw_events:
		var e: Dictionary = (raw as Dictionary).duplicate()
		e.t = float(e.get("t", 0.0))
		var defaults: Dictionary = EVENT_DEFAULTS.get(e.get("do", ""), {})
		for key: String in defaults: if not e.has(key): e[key] = defaults[key]
		if e.has("by"): e.by = Vector2(float(e.by[0]), float(e.by[1]))
		if e.has("palette"): e.palette = StringName(e.palette)
		elif e.get("do") in ["slash", "hit", "cut"]: e.palette = &"normal"
		events.append(e)
	events.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.t < y.t)
	return events

func expected_hits() -> int:
	return TIMELINE.filter(func(e: Dictionary) -> bool: return e.do == "hit").size()
## Combo seconds after the last event until everything has settled.
const SETTLE := 1.1

var attacker: Node2D
var target: Node2D
var fx: Node2D
var counter: Label
var help: Label
var speed := 1.0
var playing := false
var clock := 0.0
var hits := 0
var _next := 0
var _stop := 0.0
var _moves: Array[Dictionary] = []
var _target_velocity := Vector2.ZERO
var _target_flash := 0.0
var _counter_age := 99.0
var _camera: Camera2D

class Marker extends Node2D:
	## The abstract attacker: a diamond core with a ground shadow.
	var ground := 0.0
	func _draw() -> void:
		var shadow_y := ground - position.y
		draw_rect(Rect2(-14, shadow_y - 2, 28, 4), Color(0, 0, 0, 0.35))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(11, 0), Vector2(0, 16), Vector2(-11, 0)]), ComboStyle.c("outline"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(8, 0), Vector2(0, 12), Vector2(-8, 0)]), ComboStyle.c("blade"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(4, 0), Vector2(0, 6), Vector2(-4, 0)]), ComboStyle.c("marker_core"))

class Block extends Node2D:
	## The target: a padded block whose origin is its feet.
	var flash := 0.0
	var shake := 0.0
	func _draw() -> void:
		var size := ComboStage.TARGET_SIZE
		var at := Vector2(-size.x / 2.0 + shake, -size.y)
		draw_rect(Rect2(at - Vector2(3, 3), size + Vector2(6, 6)), ComboStyle.c("outline"))
		draw_rect(Rect2(at, size), ComboStyle.c("flash") if flash > 0.0 else ComboStyle.c("dummy"))
		if flash <= 0.0:
			draw_rect(Rect2(at + Vector2(0, size.y * 0.3), Vector2(size.x, 8)), ComboStyle.c("dummy_band"))
			draw_rect(Rect2(at + Vector2(0, size.y * 0.66), Vector2(size.x, 8)), ComboStyle.c("dummy_band"))

func _ready() -> void:
	# The manual editor builds stages without a file and fills TIMELINE itself.
	TIMELINE = load_timeline(combo_file) if not combo_file.is_empty() else []
	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	if not Engine.is_editor_hint(): _camera.make_current()
	target = Block.new()
	add_child(target)
	attacker = Marker.new()
	attacker.ground = GROUND_Y
	add_child(attacker)
	fx = Node2D.new()
	fx.z_index = 5
	add_child(fx)
	counter = Label.new()
	counter.add_theme_font_size_override("font_size", 40)
	counter.add_theme_color_override("font_outline_color", ComboStyle.c("outline"))
	counter.add_theme_constant_override("outline_size", 10)
	counter.z_index = 10
	add_child(counter)
	help = Label.new()
	help.text = ComboStyle.t("combo_help") % ComboStyle.t("slow_off")
	help.position = Vector2(24, 20)
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", ComboStyle.c("text"))
	add_child(help)
	reset()

func reset() -> void:
	playing = false
	clock = 0.0
	hits = 0
	_next = 0
	_stop = 0.0
	_moves.clear()
	_target_velocity = Vector2.ZERO
	_target_flash = 0.0
	_counter_age = 99.0
	for child in fx.get_children(): child.free()
	for child in attacker.get_children(): child.free()
	attacker.position = ATTACKER_START
	target.position = TARGET_START
	counter.visible = false
	_refresh()

func play() -> void:
	reset()
	playing = true

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1, KEY_KP_1, KEY_SPACE: play()
		KEY_2, KEY_KP_2:
			speed = SLOW_SPEED if speed == 1.0 else 1.0
			help.text = ComboStyle.t("combo_help") % ComboStyle.t("slow_on" if speed < 1.0 else "slow_off")
		KEY_R: reset()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	advance(delta * speed)

## Steps the whole demo; tests call this directly.
func advance(delta: float) -> void:
	if delta <= 0.0: return
	_counter_age += delta
	_target_flash = maxf(_target_flash - delta, 0.0)
	if _stop > 0.0:
		# Hit-stop: the combo, the attacker, every effect and the target hold still; the
		# target only shudders in place.
		_stop -= delta
		(target as Block).shake = 3.0 if int(_stop / 0.02) % 2 == 0 else -3.0
		_refresh()
		return
	(target as Block).shake = 0.0
	if playing:
		clock += delta
		while _next < TIMELINE.size() and TIMELINE[_next].t <= clock:
			_fire(TIMELINE[_next])
			_next += 1
			if _stop > 0.0: break
		if _next >= TIMELINE.size() and (TIMELINE.is_empty() or clock > TIMELINE[-1].t + SETTLE): playing = false
	_update_moves(delta)
	_update_target(delta)
	for holder in [fx, attacker]:
		for part in holder.get_children():
			if not part.has_method("advance"): continue
			part.advance(delta)
			if part.is_done(): part.queue_free()
	_refresh()

func is_settled() -> bool:
	if playing or target.position.y < GROUND_Y or not is_zero_approx(_target_velocity.x): return false
	for holder in [fx, attacker]:
		for part in holder.get_children():
			if not part.is_queued_for_deletion(): return false
	return true

func _fire(event: Dictionary) -> void:
	match event.do:
		"slash":
			attacker.add_child(PixelSlash.new().configure({"shape": &"crescent", "radius": float(event.radius),
				"squash": float(event.get("squash", 1.0)), "tilt": deg_to_rad(float(event.get("tilt", 0.0))),
				"start_angle": deg_to_rad(float(event.from)), "end_angle": deg_to_rad(float(event.to)),
				"width": float(event.width), "duration": 0.045, "hold": 0.04, "fade": 0.13,
				"line_gap": 6.0, "line_width": 5.0, "palette": event.palette}))
		"move":
			_moves.append({"from": attacker.position, "to": attacker.position + event.by, "age": 0.0, "time": float(event.time)})
		"hit": _hit(event)
		"charge":
			attacker.add_child(PixelSlash.new().configure({"shape": &"star", "radius": 80.0, "width": 14.0,
				"duration": 0.06, "hold": 0.16, "fade": 0.06, "burst_spikes": 4, "spark_dir": PI / 4.0, "palette": &"gold"}))
			attacker.add_child(PixelSlash.new().configure({"shape": &"sparks", "spark_count": 16, "spark_spread": PI,
				"spark_speed": Vector2(300, 480), "spark_life": Vector2(0.2, 0.2), "spark_gravity": 0.0, "spark_converge": true,
				"spark_seed": 3, "palette": &"gold"}))
		"flash_step":
			var from := attacker.position
			var to := Vector2(target.position.x + float(event.past), ATTACKER_START.y)
			attacker.position = to
			_moves.clear()
			fx.add_child(PixelSlash.new().configure({"shape": &"line", "from_point": from + Vector2(-40, 0),
				"to_point": to + Vector2(30, 0), "width": 30.0, "duration": 0.035, "tail": 0.3,
				"line_gap": 5.0, "line_width": 3.0, "palette": &"gold", "arrow_head": false}))
			_stop = 0.1  # the stillness after 一闪, before the cuts appear
			_shake(3.0, 0.08)
		"cut":
			var middle := target.position + Vector2(0, -TARGET_SIZE.y * 0.5)
			var along := Vector2.from_angle(deg_to_rad(float(event.angle))) * 95.0
			fx.add_child(PixelSlash.new().configure({"shape": &"line", "from_point": middle - along,
				"to_point": middle + along, "width": 22.0, "duration": 0.03, "tail": 0.16,
				"line_gap": 4.0, "line_width": 3.0, "palette": event.palette, "arrow_head": false}))

func _hit(event: Dictionary) -> void:
	hits += 1
	_counter_age = 0.0
	_target_flash = 0.06
	var finisher: bool = event.get("finisher", false)
	var at := target.position + Vector2(-TARGET_SIZE.x * 0.3, -TARGET_SIZE.y * 0.55)
	if finisher: at = target.position + Vector2(0, -TARGET_SIZE.y * 0.5)
	var spark := float(event.spark)
	fx.add_child(PixelSlash.new().configure({"shape": &"star", "center": at, "radius": spark, "width": spark * 0.22,
		"duration": 0.03, "hold": 0.03 if not finisher else 0.08, "fade": 0.12 if not finisher else 0.2,
		"burst_spikes": 8 if not finisher else 12, "spark_dir": deg_to_rad(15.0 * hits), "palette": event.palette}))
	fx.add_child(PixelSlash.new().configure({"shape": &"sparks", "center": at, "spark_count": 10 if not finisher else 28,
		"spark_dir": 0.0, "spark_spread": deg_to_rad(60.0) if not finisher else PI, "spark_speed": Vector2(260, 620) if not finisher else Vector2(300, 900),
		"spark_life": Vector2(0.16, 0.3), "spark_seed": hits, "palette": event.palette}))
	if finisher:
		fx.add_child(PixelSlash.new().configure({"shape": &"burst", "center": at, "radius": 170.0, "width": 12.0,
			"duration": 0.12, "tail": 0.2, "burst_spikes": 0, "palette": event.palette}))
		fx.add_child(PixelSlash.new().configure({"shape": &"burst", "center": Vector2(at.x, GROUND_Y), "radius": 240.0, "width": 8.0,
			"squash": 0.14, "duration": 0.22, "tail": 0.18, "burst_spikes": 0, "palette": event.palette}))
	_target_velocity.x += float(event.push)
	if event.has("launch"): _target_velocity.y = float(event.launch)
	_stop = float(event.stop)
	_shake(float(event.shake), 0.22 if finisher else 0.09)

func _shake(strength: float, duration: float) -> void:
	var feedback := get_parent()
	if feedback != null and feedback.has_method("request_screen_shake"):
		feedback.request_screen_shake(duration, strength)

func _update_moves(delta: float) -> void:
	for move in _moves:
		move.age = minf(move.age + delta, move.time)
		var t := PixelSlash.ease_swing(move.age / move.time)
		attacker.position = (move.from as Vector2).lerp(move.to, t)
	_moves = _moves.filter(func(m: Dictionary) -> bool: return m.age < m.time)

func _update_target(delta: float) -> void:
	var airborne := target.position.y < GROUND_Y - 0.5 or _target_velocity.y < 0.0
	if airborne:
		_target_velocity.y += GRAVITY * delta
	target.position += _target_velocity * delta
	if target.position.y >= GROUND_Y:
		target.position.y = GROUND_Y
		# Slammed targets bounce once; others settle.
		_target_velocity.y = -_target_velocity.y * 0.45 if _target_velocity.y > 500.0 else 0.0
	# Ground friction slides the target to a stop; air keeps its drift.
	if not airborne: _target_velocity.x = move_toward(_target_velocity.x, 0.0, 1600.0 * delta)
	target.position.x = clampf(target.position.x, 80.0, 1200.0)

func _refresh() -> void:
	(target as Block).flash = _target_flash
	target.queue_redraw()
	attacker.queue_redraw()
	counter.visible = hits > 0
	counter.text = ComboStyle.t("hits") % hits
	var finished := hits >= expected_hits()
	counter.add_theme_color_override("font_color", ComboStyle.c("text_gold") if finished else ComboStyle.c("blade"))
	var pop := 1.0 + 0.45 * clampf(1.0 - _counter_age / COUNTER_POP, 0.0, 1.0)
	counter.scale = Vector2.ONE * pop
	counter.position = Vector2(target.position.x + 40.0, 170.0)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), ComboStyle.c("background"))
	for x in range(0, 1281, 64): draw_line(Vector2(x, 0), Vector2(x, 720), Color(1, 1, 1, 0.04))
	for y in range(0, 721, 64): draw_line(Vector2(0, y), Vector2(1280, y), Color(1, 1, 1, 0.04))
	draw_line(Vector2(0, GROUND_Y), Vector2(1280, GROUND_Y), ComboStyle.c("ground"), 2.0)
