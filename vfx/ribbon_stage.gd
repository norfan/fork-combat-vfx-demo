@tool
extends ComboStage
## The normal event player and combat feedback, with sampled blade ribbons for slashes.
const Ribbon = preload("res://vfx/trajectory_ribbon.gd")
var caption: Label
var rhythm: Label
var contact_checks := 0
var contact_misses := 0
var pending_contacts: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	caption = Label.new()
	caption.position = Vector2(70, 100)
	caption.add_theme_font_size_override("font_size", 32)
	caption.modulate = ComboStyle.c("blade")
	add_child(caption)
	rhythm = Label.new()
	rhythm.position = Vector2(70, 585)
	rhythm.text = "蓄 —— 斩 —— 返 —— 疾 · 疾 · 疾 —— 旋升 —— 空切 —— 断空"
	rhythm.add_theme_font_size_override("font_size", 22)
	rhythm.modulate = Color("819db5")
	add_child(rhythm)

func reset() -> void:
	contact_checks = 0
	contact_misses = 0
	pending_contacts.clear()
	super.reset()

func _refresh() -> void:
	super._refresh()
	if not is_instance_valid(caption): return
	var names := ["一 · 蓄势 / 霜刃", "二 · 交锋 / 双向斩", "三 · 疾雨 / 三连切", "四 · 旋升 / 挑空", "五 · 悬锋 / 空中追切", "六 · 断空 / 金刃落地"]
	var index := 0
	for threshold in [0.45, 1.27, 1.96, 2.43, 3.12]:
		if clock >= threshold: index += 1
	caption.text = names[index]

func _fire(event: Dictionary) -> void:
	if event.do != "slash":
		super._fire(event)
		return
	var span := float(event.get("duration", 0.16))
	var breadth := float(event.width) * ComboStyle.thickness
	var flatten := float(event.get("squash", 1.0))
	var rotation_angle := deg_to_rad(float(event.get("tilt", 0.0)))
	var contact_delay := span * 0.5
	# Aim at the target's predicted centre when this stroke crosses its middle angle.
	var at := target.position + Vector2(-TARGET_SIZE.x * 0.3, -TARGET_SIZE.y * 0.55)
	at += _target_velocity * contact_delay
	if target.position.y < GROUND_Y or _target_velocity.y < 0.0:
		at.y += GRAVITY * contact_delay * contact_delay * 0.5
	var origin := attacker.position
	for move in _moves:
		origin = (move.from as Vector2).lerp(move.to, PixelSlash.ease_swing(minf(float(move.age) + contact_delay, move.time) / move.time))
	var aim := (at - origin).rotated(-rotation_angle) / Vector2(1, flatten)
	var middle_angle := (float(event.from) + float(event.to)) * 0.5
	var aim_angle := aim.angle() - deg_to_rad(middle_angle)
	var slash := Ribbon.new().configure({
		"duration": span, "tail": float(event.get("tail", 0.18)),
		"radius": aim.length() + breadth * 0.42, "width": breadth,
		"squash": flatten, "tilt": rotation_angle,
		"start_angle": deg_to_rad(float(event.from)) + aim_angle,
		"end_angle": deg_to_rad(float(event.to)) + aim_angle,
		"hilt_travel": 0.0, "swell": 0.0, "echo": true,
		"pixel": ComboStyle.pixel, "palette": PixelSlash.palette_of(event.palette)})
	attacker.add_child(slash)

func _hit(event: Dictionary) -> void:
	# The base stage moves actors and advances effects after firing events this frame.
	# Check that final rendered geometry against the impact's original world position.
	pending_contacts.append({"at": target.position + Vector2(-TARGET_SIZE.x * 0.3, -TARGET_SIZE.y * 0.55), "hit": hits + 1})
	super._hit(event)

func advance(delta: float) -> void:
	super.advance(delta)
	for contact in pending_contacts:
		_check_contact(contact)
	pending_contacts.clear()

func _check_contact(contact: Dictionary) -> void:
	var point: Vector2 = contact.at
	var covered := false
	for child in attacker.get_children():
		if child.get_script() != Ribbon or child.samples.size() < 2: continue
		for i in range(1, child.samples.size()):
			var a: Dictionary = child.samples[i - 1]
			var b: Dictionary = child.samples[i]
			var sa := pow(clampf(1.0 - (child.age - float(a.born)) / child.tail, 0.0, 1.0), 1.4)
			var sb := pow(clampf(1.0 - (child.age - float(b.born)) / child.tail, 0.0, 1.0), 1.4)
			var polygon := PackedVector2Array([a.tip, b.tip, (b.tip as Vector2).lerp(b.inner, sb), (a.tip as Vector2).lerp(a.inner, sa)])
			if Geometry2D.is_point_in_polygon(point - attacker.position, polygon): covered = true
	contact_checks += 1
	if not covered:
		contact_misses += 1
		push_error("Ribbon missed target at hit %d (clock %.3f)" % [contact.hit, clock])

func is_settled() -> bool:
	var settled := super.is_settled()
	if settled and hits > 0:
		if contact_checks != hits or contact_misses != 0:
			if "--verify" in OS.get_cmdline_user_args(): get_tree().quit(1)
			return false
	return settled
