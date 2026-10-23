extends Control
## Lists every combo scene in res://combos/ (one folder each) and opens the one you pick.
## Esc in a combo comes back here.

const COMBOS := "res://combos"

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("20262d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var list := VBoxContainer.new()
	list.position = Vector2(64, 56)
	list.add_theme_constant_override("separation", 10)
	add_child(list)
	var heading := Label.new()
	heading.text = "Combat VFX demo — pick a combo (Esc in a combo comes back here)"
	heading.add_theme_font_size_override("font_size", 26)
	list.add_child(heading)
	# Hand tuning: build a combo or fine-tune an existing one with a live preview.
	var editor := Button.new()
	editor.text = "手动精调 — 新建 / 修改连招"
	editor.alignment = HORIZONTAL_ALIGNMENT_LEFT
	editor.custom_minimum_size = Vector2(420, 44)
	editor.add_theme_font_size_override("font_size", 22)
	editor.pressed.connect(get_tree().change_scene_to_file.bind("res://editor.tscn"))
	list.add_child(editor)
	for path in find_combos():
		var button := Button.new()
		button.text = path.get_file().get_basename().capitalize()
		button.tooltip_text = path
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(420, 44)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(get_tree().change_scene_to_file.bind(path))
		list.add_child(button)
	if list.get_child_count() > 1: (list.get_child(1) as Button).grab_focus()

## Every res://combos/<name>/<name>.tscn, sorted.
static func find_combos() -> PackedStringArray:
	var found := PackedStringArray()
	for folder in DirAccess.get_directories_at(COMBOS):
		var scene := COMBOS.path_join(folder).path_join(folder + ".tscn")
		if ResourceLoader.exists(scene): found.append(scene)
	found.sort()
	return found
