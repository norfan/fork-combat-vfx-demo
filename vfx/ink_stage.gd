@tool
extends ComboStage
const Brush = preload("res://vfx/ink_stroke.gd")
var caption: Label
var rhythm: Label

func _ready() -> void:
	super._ready()
	counter.add_theme_constant_override("outline_size", 0)
	caption = Label.new()
	caption.position = Vector2(80, 125)
	caption.add_theme_font_size_override("font_size", 32)
	caption.add_theme_color_override("font_color", Color("28382e"))
	add_child(caption)
	rhythm = Label.new()
	rhythm.position = Vector2(80, 590)
	rhythm.add_theme_font_size_override("font_size", 22)
	rhythm.add_theme_color_override("font_color", Color("64695d"))
	rhythm.text = "探 —— 折 —— 点 · 点 · 点 —— 绞 —— 悬笔留白 —— 断江"
	add_child(rhythm)

func _refresh() -> void:
	super._refresh()
	if not is_instance_valid(caption): return
	var names := ["一 · 探锋 / 干笔试切", "二 · 折枝 / 顿挫折腕", "三 · 三点雨 / 短促戳点", "四 · 绞云 / 回卷收束", "五 · 悬笔 / 收墨待发", "六 · 断江 / 落笔成势"]
	var index := 0
	for threshold in [1.14, 1.66, 2.49, 3.05, 4.08]:
		if clock >= threshold: index += 1
	caption.text = names[index] if playing or hits > 0 else "墨势六式 / 起笔"
	queue_redraw()

func _fire(event: Dictionary) -> void:
	if event.do == "slash":
		var mode := String(event.get("ink_kind", "dry"))
		var at := target.position + Vector2(0, -50)
		var start := attacker.position
		var path := PackedVector2Array()
		match mode:
			"dry": path = _polyline([start + Vector2(-35, 15), at + Vector2(-35, -3), at + Vector2(65, -8)])
			"elbow": path = _polyline([start + Vector2(-15, 45), at + Vector2(-50, -90), at + Vector2(30, 35)])
			"dot":
				var tilt := float(event.get("tilt", 0.0))
				path = _polyline([start + Vector2(15, tilt), at + Vector2(40, -tilt * 0.3)])
			"coil":
				for i in 90:
					var u := float(i) / 89.0
					var angle := lerpf(PI, TAU * 1.42, u)
					var r := lerpf(115, 4, u)
					path.append(at + Vector2(cos(angle) * r, sin(angle) * r * 0.75))
			"fall": path = _polyline([at + Vector2(-40, -230), at + Vector2(10, -100), Vector2(at.x, GROUND_Y), Vector2(at.x + 22, GROUND_Y + 8)])
		_spawn(path, float(event.width), mode, hits + 13)
	elif event.do == "charge":
		_spawn(PackedVector2Array([attacker.position + Vector2(20, -20)]), 20, "pool", 41)
	else:
		super._fire(event)

func _hit(event: Dictionary) -> void:
	hits += 1
	_counter_age = 0.0
	_target_flash = 0.0
	var heavy: bool = event.get("finisher", false)
	var at := target.position + Vector2(-5, -50)
	_spawn(PackedVector2Array([at]), 20, "impact", hits)
	if heavy:
		_spawn(PackedVector2Array([Vector2(at.x, GROUND_Y)]), 40, "impact_heavy", 77)
		_spawn(_polyline([Vector2(at.x - 145, GROUND_Y), Vector2(at.x, GROUND_Y - 3), Vector2(at.x + 190, GROUND_Y + 1)]), 25, "ground", 78)
	_target_velocity.x += float(event.push)
	_stop = float(event.stop)
	_shake(float(event.shake), 0.2 if heavy else 0.09)

func _spawn(path: PackedVector2Array, breadth: float, mode: String, seed_id: int) -> void:
	fx.add_child(Brush.new().setup(path, breadth, mode, seed_id))

func _polyline(knots: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(1, knots.size()):
		var a: Vector2 = knots[i - 1]
		var b: Vector2 = knots[i]
		var steps := maxi(2, ceili(a.distance_to(b) / 4.0))
		for j in steps: result.append(a.lerp(b, float(j) / steps))
	result.append(knots[-1])
	return result

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("eee8d8"))
	# Fixed paper fibres: they never swim or flicker with the animation.
	for i in 1600:
		var x := float((i * 719 + 37) % 1280)
		var y := float((i * 317 + 53) % 720)
		draw_line(Vector2(x, y), Vector2(x + 3 + i % 6, y + 1), Color(0.3, 0.3, 0.23, 0.035), 1)
	draw_line(Vector2(80, 205), Vector2(1200, 205), Color("c6c2af"), 1)
	draw_line(Vector2(120, GROUND_Y + 1), Vector2(1160, GROUND_Y + 1), Color("a6a894"), 1)
	draw_rect(Rect2(1140, 105, 37, 51), Color("9b4838"))
	draw_line(Vector2(1150, 115), Vector2(1166, 141), Color("eee8d8"), 2)
	draw_line(Vector2(1166, 115), Vector2(1150, 141), Color("eee8d8"), 2)
