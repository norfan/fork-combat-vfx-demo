extends SceneTree
## Lifecycle checks for the independent ink renderer, beyond the stock hit counter test.
func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var player = load("res://combos/ink_forms/ink_forms.tscn").instantiate()
	player.autoplay = false
	root.add_child(player)
	var stage: ComboStage = player.demo
	var durations: Array[float] = []
	var modes: Dictionary = {}
	for speed in [1.0, 0.25]:
		stage.play()
		var ticks := 0
		while not stage.is_settled() and ticks < 3000:
			var before := stage.clock
			var stopped := stage._stop > 0.0
			stage.advance(speed / 60.0)
			if stopped and stage.clock != before:
				fail("Action clock advanced during hit-stop")
				return
			for node in stage.fx.get_children():
				if node is PixelSlash:
					fail("Stock slash or spark leaked into ink renderer")
					return
				modes[node.kind] = true
			# Flush queued effects so is_settled observes the actual lifecycle.
			for node in stage.fx.get_children():
				if node.is_queued_for_deletion():
					stage.fx.remove_child(node)
					node.free()
			ticks += 1
		if stage.hits != 7 or not stage.is_settled():
			fail("Expected seven hits and settled effects at speed %s" % speed)
			return
		durations.append(float(ticks) / 60.0)
		stage.reset()
		if stage.hits != 0 or stage.fx.get_child_count() != 0 or stage.attacker.position != stage.ATTACKER_START or stage.target.position != stage.TARGET_START:
			fail("Reset left effects, hits or displaced actors")
			return
	for mode in ["dry", "elbow", "dot", "coil", "pool", "fall", "impact", "impact_heavy", "ground"]:
		if not modes.has(mode):
			fail("Missing ink form: %s" % mode)
			return
	if absf(durations[1] / durations[0] - 4.0) > 0.12:
		fail("Quarter-speed playback drifted")
		return
	print("PASS: ink forms, 7 hits, hit-stop, reset, replay, quarter-speed and effect cleanup")
	player.free()
	quit()

func fail(message: String) -> void:
	push_error(message)
	quit(1)
