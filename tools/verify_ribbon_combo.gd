extends SceneTree
## Lifecycle checks for the sampled renderer, beyond the normal combo hit count.

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(false, message)

func _run() -> void:
	var player = load("res://combos/rift_dancer/rift_dancer.tscn").instantiate()
	root.add_child(player)
	player.set_process(false)
	var stage = player.demo
	stage.set_process(false)
	for step in [1.0 / 60.0, 1.0 / 240.0]:
		stage.play()
		var iterations := 0
		while stage.playing or not stage.is_settled():
			stage.advance(step)
			await process_frame
			iterations += 1
			_require(iterations < 2400, "Ribbon combo failed to settle")
		_require(stage.hits == 9 and stage.contact_checks == 9 and stage.contact_misses == 0,
			"Nine strikes must cover their targets at normal and quarter-speed steps")
		stage.reset()
		_require(stage.attacker.get_child_count() == 0 and stage.fx.get_child_count() == 0,
			"Reset must remove all ribbons and impact effects")
	# A live trail must hold exactly still during zero-delta pauses and hit-stop.
	stage.play()
	while stage.clock < 0.52:
		stage.advance(1.0 / 240.0)
		await process_frame
	var ribbon
	for child in stage.attacker.get_children():
		if child.get_script() == load("res://vfx/trajectory_ribbon.gd"): ribbon = child
	_require(ribbon != null, "Expected live ribbon before first contact")
	var age: float = ribbon.age
	var count: int = ribbon.samples.size()
	stage.advance(0.0)
	stage._stop = 0.1
	stage.advance(0.04)
	_require(ribbon.age == age and ribbon.samples.size() == count,
		"Hit-stop and zero delta must hold the blade trajectory")
	stage.reset()
	_require(stage.attacker.get_child_count() == 0, "Interrupted swing must clear")
	print("PASS: ribbon normal/quarter speed, 18 contacts, hit-stop, zero delta and reset")
	quit()
