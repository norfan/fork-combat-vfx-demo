extends SceneTree
## Run actual demo scenes through Godot Movie Maker, without changing their source.
var duration := 6.0
var elapsed := 0.0
var player: Node

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var combo := "ink_forms"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--combo="): combo = arg.trim_prefix("--combo=")
		if arg.begins_with("--movie-duration="): duration = float(arg.trim_prefix("--movie-duration="))
	player = load("res://combos/%s/%s.tscn" % [combo, combo]).instantiate()
	root.add_child(player)
	player.loop_pause = -1.0
	player.demo.help.hide()
	player._overlay.hide()
	# Promotional titles replace the in-demo labels so cropped text never touches an edge.
	if player.demo.get("caption") != null:
		player.demo.caption.hide()
		player.demo.rhythm.hide()

func _process(delta: float) -> bool:
	if player == null: return false
	elapsed += delta
	if elapsed >= duration: quit()
	return false
