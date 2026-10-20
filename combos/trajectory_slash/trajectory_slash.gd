extends Node2D
## Single-cut algorithm study. Deliberately independent of the combo renderer.
const Ribbon = preload("res://vfx/trajectory_ribbon.gd")
var ribbon: Node2D
var elapsed := 0.0
var slow := false
var capture_dir := ""
var frame := 0
var status: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("141d28"))
	ribbon = Ribbon.new()
	ribbon.position = Vector2(610, 385)
	add_child(ribbon)
	var title := Label.new()
	title.text = "TRAJECTORY RIBBON / SINGLE CUT"
	title.position = Vector2(60, 42)
	title.add_theme_font_size_override("font_size", 26)
	add_child(title)
	status = Label.new()
	status.position = Vector2(60, 88)
	status.modulate = Color("9ab9c8")
	add_child(status)
	var help := Label.new()
	help.text = "SPACE  Replay     2  Half speed     ESC  Gallery\n240 Hz blade samples / UV bands / 0.19 s retained trail / 3 px texels"
	help.position = Vector2(60, 625)
	help.modulate = Color("9ab9c8")
	add_child(help)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-ribbon="):
			capture_dir = arg.trim_prefix("--capture-ribbon=")
			DirAccess.make_dir_recursive_absolute(capture_dir)

func _process(delta: float) -> void:
	var step := (1.0 / 60.0 if not capture_dir.is_empty() else delta) * (0.5 if slow else 1.0)
	var before := maxf(elapsed - 0.35, 0.0)
	elapsed += step
	var after := maxf(elapsed - 0.35, 0.0)
	ribbon.advance(after - before)
	status.text = "HALF SPEED" if slow else "REAL TIME"
	if after > 0 and after < Ribbon.SWING: status.text += " / GENERATING"
	elif after >= Ribbon.SWING and not ribbon.samples.is_empty(): status.text += " / OLD SEGMENTS THIN + DARKEN"
	elif after >= Ribbon.SWING: status.text += " / CLEARED"
	queue_redraw()
	if not capture_dir.is_empty():
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % frame))
		frame += 1
		if frame >= 90:
			assert(ribbon.samples.is_empty(), "Expired trajectory must be removed")
			print("PASS: single ribbon rendered; expired samples and mesh cleared")
			get_tree().quit()
			return
		set_process(true)
	elif elapsed > 1.65:
		_replay()

func _draw() -> void:
	draw_line(Vector2(170, 568), Vector2(1110, 568), Color("2b3c49"), 2)
	# Small pivot marker makes the swing's origin readable without a character asset.
	draw_circle(Vector2(610, 385), 5.0, Color("466779"))
	if elapsed >= 0.35 and ribbon.age < Ribbon.SWING:
		var pose: Dictionary = ribbon.blade_pose(ribbon.age)
		draw_line(ribbon.position + pose.hilt, ribbon.position + pose.tip, Color("70858c"), 2)

func _replay() -> void:
	elapsed = 0.0
	ribbon.reset()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("ui_cancel"): get_tree().change_scene_to_file("res://main.tscn")
	if event is InputEventKey:
		if event.keycode in [KEY_SPACE, KEY_1, KEY_R]: _replay()
		if event.keycode == KEY_2: slow = not slow
