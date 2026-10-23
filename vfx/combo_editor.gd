extends Control
## 手动精调: build a combo by hand or fine-tune an existing one, with a live preview.
## Pick a combo (or start a blank one), select events in the list or on the timeline strip
## (drag a marker to retime it), edit their fields on the right, and the preview replays
## shortly after every change. Saving overwrites the combo's combo.json / style.json (a
## .bak copy is kept the first time per session) or writes a new combo folder and scene,
## exactly like tools/new_combo.py does. The agent tools are not involved.
## Keys: Space play, 2 slow motion, Ctrl+S save, Ctrl+Z undo, Ctrl+Y / Ctrl+Shift+Z redo,
## Delete remove event, Ctrl+D duplicate, ←/→ nudge time (Shift: ×5), Esc back.

const COMBOS := "res://combos"
const GALLERY := "res://main.tscn"
const RENDERERS := ["", "ribbon", "claw", "ink", "magic"]
const RENDERER_NAMES := ["月牙（默认）", "轨迹刀光", "爪痕", "水墨", "魔法"]
const DOS := ["slash", "hit", "move", "charge", "flash_step", "cut", "cast"]
const DO_NAMES := {"slash": "斩击", "hit": "命中", "move": "位移", "charge": "蓄力", "flash_step": "一闪", "cut": "刀痕", "cast": "施法"}
const DO_COLOURS := {"slash": Color("6fd6e8"), "hit": Color("ff6a6a"), "move": Color("9aa7b4"), "charge": Color("ffd166"), "flash_step": Color("c99bff"), "cut": Color("ffa14d"), "cast": Color("7dffb0")}
const MAGIC_STAGE := "res://vfx/magic_stage.gd"
const ELEMENTS := ["fire", "thunder", "ice", "wind"]
const ELEMENT_NAMES := ["火", "雷", "冰", "风"]
## A cast's skeleton choices (vfx/magic/magic_fx.gd) and their names.
const CAST_OPTIONS := {
	"start": [["hand", "above", "sky", "behind", "self", "below", "target"], ["手上", "头顶", "高空", "目标后上方", "自身", "目标脚下地底", "目标身上"]],
	"end": [["target", "ground", "self"], ["目标身上", "目标脚下地面", "自身周围"]],
	"path": [["straight", "arc", "wave", "spiral", "stay"], ["直线", "弧线", "蛇行", "螺旋", "原地（跟着起点）"]],
}
const PALETTES := ["normal", "violet", "red", "gold", "green"]
const CLAW_KINDS := ["arc", "swipe", "dash", "cross", "rake", "slam"]
const CLAW_NAMES := ["弧 / 回环", "横斩", "突进", "交叉斩", "直抓", "暴扣"]
## [key, label, min, max, step, default, shown for]. Shown for: "" always, "stock" only the
## default crescents, "timed" the ribbon and claw renderers, "claw" only claws, "k:a|b" only
## those claw kinds, "cast" every cast (left out, a cast field takes its element's default),
## "f:a|b" only casts on those paths, "e:a|b" only casts of those elements.
const FIELDS := {
	"slash": [["t", "时间", 0, 20, 0.005, 0.0, ""], ["from", "起始角", -1080, 1080, 1, -70, ""], ["to", "结束角", -1080, 1080, 1, 70, ""],
		["width", "宽度", 2, 240, 1, 44, ""], ["radius", "半径", 20, 600, 1, 140, "stock"], ["squash", "扁度", 0.05, 2, 0.01, 1.0, ""],
		["tilt", "倾斜", -180, 180, 1, 0, ""], ["palette", "颜色", 0, 0, 0, "normal", ""],
		["duration", "挥动时长", 0.03, 1.5, 0.005, 0.16, "timed"], ["tail", "拖尾", 0.02, 2, 0.005, 0.2, "timed"],
		["claw", "爪痕形状", 0, 0, 0, "arc", "claw"], ["contact", "命中点", 0, 1, 0.01, 0.5, "claw"],
		["spiral", "螺旋", -0.9, 0.9, 0.01, 0.0, "k:arc"], ["angle", "方向角度", -180, 180, 1, 40, "k:rake|swipe|cross"],
		["length", "长度", 40, 800, 1, 230, "k:rake|swipe|cross"], ["bend", "弯曲", -0.5, 0.5, 0.01, 0.12, "k:swipe"],
		["past", "穿过距离", 0, 500, 1, 110, "k:dash"], ["cross_delay", "第二刀延迟", 0, 0.4, 0.005, 0.07, "k:cross"],
		["fingers", "爪数", 1, 8, 1, 3, "claw"], ["spread", "爪距", 1, 90, 1, 18, "claw"],
		["jag", "撕裂感", 0, 1, 0.01, 0.45, "claw"], ["mark", "爪痕长度（0=自动）", 0, 400, 1, 0, "claw"],
		["trail", "拖尾时长", 0, 0.5, 0.005, 0.1, "claw"]],
	"hit": [["t", "时间", 0, 20, 0.005, 0.0, ""], ["push", "击退", -600, 1500, 1, 60, ""], ["launch", "挑飞 / 砸地", -2000, 2000, 10, -400, "optional"],
		["stop", "顿帧", 0, 0.5, 0.005, 0.05, ""], ["shake", "震屏", 0, 30, 0.5, 2.5, ""], ["spark", "火花", 0, 260, 1, 46, ""],
		["palette", "颜色", 0, 0, 0, "normal", ""], ["finisher", "终结技", 0, 0, 0, false, "bool"]],
	"move": [["t", "时间", 0, 20, 0.005, 0.0, ""], ["by_x", "横移", -600, 600, 1, 20, ""], ["by_y", "竖移（负=上）", -600, 600, 1, 0, ""],
		["time", "用时", 0.01, 1.5, 0.005, 0.08, ""]],
	"charge": [["t", "时间", 0, 20, 0.005, 0.0, ""]],
	"flash_step": [["t", "时间", 0, 20, 0.005, 0.0, ""], ["past", "穿过距离", 0, 600, 1, 140, ""]],
	"cut": [["t", "时间", 0, 20, 0.005, 0.0, ""], ["angle", "角度", -180, 180, 1, 0, ""], ["palette", "颜色", 0, 0, 0, "normal", ""]],
	"cast": [["t", "时间", 0, 20, 0.005, 0.0, ""], ["element", "元素", 0, 0, 0, "fire", ""],
		["start", "起点", 0, 0, 0, "hand", "cast"], ["end", "终点", 0, 0, 0, "target", "cast"], ["path", "路径", 0, 0, 0, "arc", "cast"],
		["arc", "弧度", -400, 400, 1, 70, "f:arc"], ["wave", "摆幅", 0, 300, 1, 40, "f:wave|spiral"], ["turns", "圈数 / 摆动次数", 0.5, 8, 0.1, 2, "f:wave|spiral"],
		["ease", "速度曲线（>1 越飞越快）", 0.3, 4, 0.05, 1.25, "cast"], ["charge", "凝聚时间", 0, 2, 0.005, 0.22, "cast"],
		["travel", "飞行时间（原地：维持多久）", 0.02, 5, 0.005, 0.36, "cast"], ["count", "数量", 1, 12, 1, 1, "cast"],
		["interval", "间隔", 0, 1, 0.005, 0.12, "cast"], ["spread", "散开", -400, 400, 1, 36, "cast"],
		["radius", "打击范围", 10, 400, 1, 70, "cast"], ["size", "本体大小", 0.3, 4, 0.05, 1.0, "cast"],
		["hold", "持续（雷：劈中后闪多久；火柱：最后一击后烧多久）", 0, 3, 0.005, 0.22, "cast"], ["jag", "折角（锯齿感）", 0, 0.8, 0.01, 0.28, "e:thunder"]],
}

class Host extends Node2D:
	## Parent of the preview stage: gives it the screen shake ComboPlayer normally provides.
	var left := 0.0
	var span := 0.0
	var strength := 0.0
	var clock := 0.0
	func request_screen_shake(duration: float, amount: float) -> void:
		left = duration
		span = duration
		strength = amount
	func _process(delta: float) -> void:
		clock += delta
		left = maxf(0.0, left - delta)
		var camera := get_viewport().get_camera_2d()
		if camera != null:
			camera.offset = Vector2(sin(clock * 137.0), cos(clock * 173.0)) * strength * left / maxf(span, 0.001)

class Strip extends Control:
	## The timeline: one lane per event kind, a marker per event, the playhead.
	signal picked(index: int)
	signal dragged(index: int, t: float)
	signal released
	var editor: Control
	var dragging := -1
	func _seconds() -> float:
		var last := 1.0
		for e: Dictionary in editor.data.events: last = maxf(last, float(e.get("t", 0.0)) + 0.4)
		return last
	func _x(t: float) -> float: return 8.0 + t / _seconds() * (size.x - 16.0)
	func _lane_y(kind: String) -> float: return 10.0 + DOS.find(kind) * (size.y - 20.0) / DOS.size()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("161b21"))
		var seconds := _seconds()
		var font := ThemeDB.fallback_font
		for i in int(seconds / 0.25) + 1:
			var x := _x(i * 0.25)
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.12 if i % 4 == 0 else 0.05))
			if i % 4 == 0: draw_string(font, Vector2(x + 2, size.y - 2), "%.0fs" % (i * 0.25), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("6b7785"))
		for kind in DOS:
			draw_string(font, Vector2(size.x - 52, _lane_y(kind) + 4), DO_NAMES[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("56626e"))
		var events: Array = editor.data.events
		for i in events.size():
			var e: Dictionary = events[i]
			var at := Vector2(_x(float(e.get("t", 0.0))), _lane_y(String(e.do)))
			var colour: Color = DO_COLOURS.get(String(e.do), Color.WHITE)
			if String(e.do) == "slash" and e.has("duration"):
				draw_rect(Rect2(at - Vector2(0, 3), Vector2(_x(float(e.t) + float(e.duration)) - at.x, 6)), colour * Color(1, 1, 1, 0.35))
			if String(e.do) == "cast":
				# A bar to the last landing, a tick at each.
				var landings: Array = load(MAGIC_STAGE).contact_times(e)
				draw_rect(Rect2(at - Vector2(0, 2), Vector2(_x(float(landings[-1])) - at.x, 4)), colour * Color(1, 1, 1, 0.35))
				for landing: float in landings: draw_line(Vector2(_x(landing), at.y - 6), Vector2(_x(landing), at.y + 6), colour, 1.5)
			draw_circle(at, 6.0 if i == editor.selected else 4.0, colour)
			if i == editor.selected: draw_arc(at, 9.0, 0, TAU, 20, Color.WHITE, 1.5)
		if editor.stage != null:
			var x := _x(editor.stage.clock)
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color("ffe36b"), 1.5)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var best := -1
				var best_distance := 14.0
				var events: Array = editor.data.events
				for i in events.size():
					var e: Dictionary = events[i]
					var d: float = (Vector2(_x(float(e.get("t", 0.0))), _lane_y(String(e.do))) - event.position).length()
					if d < best_distance:
						best = i
						best_distance = d
				dragging = best
				if best >= 0: picked.emit(best)
			elif dragging >= 0:
				dragging = -1
				released.emit()
		elif event is InputEventMouseMotion and dragging >= 0:
			var t := clampf((event.position.x - 8.0) / (size.x - 16.0) * _seconds(), 0.0, 20.0)
			dragged.emit(dragging, snappedf(t, 0.005))

var data: Dictionary = {"events": []}
var style: Dictionary = {}
var combo_path := ""
var selected := -1
var stage: Node2D
var dirty := false
var _paths: PackedStringArray = []
var _backed_up := {}
var _undo: Array[String] = []
var _redo: Array[String] = []
var _last_tag := ""
var _last_time := 0.0
var _rebuild_in := -1.0
var _leave_armed := false
var _filling := false

var _picker: OptionButton
var _list: ItemList
var _strip: Strip
var _inspector: VBoxContainer
var _style_box: VBoxContainer
var _status: Label
var _check: Label
var _viewport: SubViewport
var _host: Host
var _save_as: LineEdit
var _add_kind: OptionButton

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("1d242c")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_build_top_bar()
	_list = ItemList.new()
	_list.position = Vector2(8, 52)
	_list.size = Vector2(292, 470)
	_list.item_selected.connect(func(i: int) -> void: _select(int(_list.get_item_metadata(i))))
	add_child(_list)
	var row := HBoxContainer.new()
	row.position = Vector2(8, 528)
	add_child(row)
	_add_kind = OptionButton.new()
	for kind in DOS: _add_kind.add_item(DO_NAMES[kind])
	row.add_child(_add_kind)
	row.add_child(_button("添加", _add_event))
	row.add_child(_button("复制", _duplicate_event))
	row.add_child(_button("删除", _delete_event))
	# The stage is laid out for 1280 × 720; show it at half size.
	var container := SubViewportContainer.new()
	container.position = Vector2(308, 52)
	container.size = Vector2(1280, 720)
	container.scale = Vector2(0.5, 0.5)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	container.add_child(_viewport)
	_host = Host.new()
	_viewport.add_child(_host)
	_strip = Strip.new()
	_strip.editor = self
	_strip.position = Vector2(308, 418)
	_strip.size = Vector2(640, 150)
	_strip.picked.connect(_select)
	_strip.dragged.connect(_drag_event)
	_strip.released.connect(func() -> void: _schedule())
	add_child(_strip)
	_check = Label.new()
	_check.position = Vector2(308, 574)
	_check.size = Vector2(640, 140)
	_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_check.add_theme_font_size_override("font_size", 14)
	add_child(_check)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(956, 52)
	scroll.size = Vector2(316, 660)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_style_box = VBoxContainer.new()
	column.add_child(_style_box)
	column.add_child(HSeparator.new())
	_inspector = VBoxContainer.new()
	column.add_child(_inspector)
	_fill_picker()
	if _paths.size() > 0: _open(0)
	else: _new_blank()

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 8)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	var heading := Label.new()
	heading.text = "手动精调"
	heading.add_theme_font_size_override("font_size", 20)
	bar.add_child(heading)
	_picker = OptionButton.new()
	_picker.custom_minimum_size = Vector2(260, 0)
	_picker.item_selected.connect(func(i: int) -> void:
		if i < _paths.size(): _open(i)
		else: _new_blank())
	bar.add_child(_picker)
	bar.add_child(_button("播放", func() -> void: _rebuild(true)))
	bar.add_child(_button("慢放", _toggle_slow))
	bar.add_child(_button("保存", _save))
	_save_as = LineEdit.new()
	_save_as.placeholder_text = "新名字（英文小写_）"
	_save_as.custom_minimum_size = Vector2(170, 0)
	bar.add_child(_save_as)
	bar.add_child(_button("另存为", _save_new))
	bar.add_child(_button("撤销", _undo_step))
	bar.add_child(_button("重做", _redo_step))
	bar.add_child(_button("返回", _leave))
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("ffe36b"))
	bar.add_child(_status)

# --- Combos on disk -------------------------------------------------------------------------

func _fill_picker() -> void:
	_picker.clear()
	_paths.clear()
	var folders := DirAccess.get_directories_at(COMBOS)
	folders.sort()
	for folder in folders:
		var path := COMBOS.path_join(folder).path_join("combo.json")
		if not FileAccess.file_exists(path): continue
		_paths.append(path)
		var title := folder
		var style_path := path.get_base_dir().path_join("style.json")
		if FileAccess.file_exists(style_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(style_path))
			if parsed is Dictionary: title = "%s  (%s)" % [String((parsed as Dictionary).get("title", folder)), folder]
		_picker.add_item(title)
	_picker.add_item("＋ 新建空白连招")

func _read(path: String, fallback: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else fallback.duplicate(true)

func _open(index: int) -> void:
	combo_path = _paths[index]
	data = _read(combo_path, {"events": []})
	if not data.get("events") is Array: data.events = []
	style = _read(combo_path.get_base_dir().path_join("style.json"), {})
	_picker.select(index)
	_after_load("已打开 " + combo_path.get_base_dir().get_file())

func _new_blank() -> void:
	combo_path = ""
	data = {"name": "新连招", "events": [
		{"t": 0.3, "do": "slash", "from": -70, "to": 70, "width": 44},
		{"t": 0.34, "do": "hit", "push": 60, "stop": 0.05, "shake": 2.5, "spark": 46}]}
	style = _read("res://styles/default.json", {})
	style["title"] = "新连招"
	style["language"] = "zh"
	_picker.select(_paths.size())
	_after_load("新建：改好后在上方填名字，按「另存为」")

func _after_load(message: String) -> void:
	_undo.clear()
	_redo.clear()
	dirty = false
	_leave_armed = false
	selected = -1
	_status.text = message
	_refresh_all()
	_rebuild(true)

# --- Editing ---------------------------------------------------------------------------------

func _renderer() -> String:
	return String(style.get("renderer", ""))

## Remembers the state for undo. Rapid edits of the same field merge into one step.
func _remember(tag: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if tag == _last_tag and now - _last_time < 0.8:
		_last_time = now
		return
	_last_tag = tag
	_last_time = now
	_undo.append(JSON.stringify({"data": data, "style": style, "selected": selected}))
	if _undo.size() > 200: _undo.pop_front()
	_redo.clear()

func _changed() -> void:
	dirty = true
	_leave_armed = false
	_refresh_list()
	_refresh_check()
	_strip.queue_redraw()
	_schedule()

func _schedule() -> void:
	_rebuild_in = 0.3

func _restore(snapshot: String) -> void:
	var state: Dictionary = JSON.parse_string(snapshot)
	data = state.data
	style = state.style
	selected = int(state.selected)
	dirty = true
	_refresh_all()
	_schedule()

func _undo_step() -> void:
	if _undo.is_empty():
		_status.text = "没有可撤销的修改"
		return
	_redo.append(JSON.stringify({"data": data, "style": style, "selected": selected}))
	_restore(_undo.pop_back())
	_last_tag = ""
	_status.text = "已撤销"

func _redo_step() -> void:
	if _redo.is_empty():
		_status.text = "没有可重做的修改"
		return
	_undo.append(JSON.stringify({"data": data, "style": style, "selected": selected}))
	_restore(_redo.pop_back())
	_last_tag = ""
	_status.text = "已重做"

func _select(index: int) -> void:
	selected = index
	_refresh_list()
	_refresh_inspector()
	_refresh_check()
	_strip.queue_redraw()

func _add_event() -> void:
	_remember("add")
	var kind: String = DOS[_add_kind.selected]
	var e := {"t": 0.0, "do": kind}
	if selected >= 0: e.t = snappedf(float(data.events[selected].get("t", 0.0)) + 0.1, 0.005)
	for field: Array in FIELDS[kind]:
		if field[0] == "t" or field[6] in ["claw", "optional", "bool", "timed", "stock", "cast"] or String(field[6]).substr(0, 2) in ["k:", "f:", "e:"]: continue
		if field[0] == "by_x": e["by"] = [20, 0]
		elif field[0] != "by_y": e[field[0]] = field[5]
	if kind == "slash" and _renderer() in ["ribbon", "claw"]: e.merge({"duration": 0.16, "tail": 0.2})
	if kind == "slash" and _renderer() == "claw": e["claw"] = "arc"
	if kind == "slash" and _renderer() in ["", "ink"]: e["radius"] = 160
	if kind == "cast": e["element"] = "fire"
	if kind == "cast" and _renderer() != "magic": _status.text = "施法只在「魔法」绘制器里显示：在左边风格里把绘制器换成「魔法」"
	(data.events as Array).append(e)
	selected = data.events.size() - 1
	_changed()
	_refresh_inspector()

func _duplicate_event() -> void:
	if selected < 0: return
	_remember("dup")
	var e: Dictionary = (data.events[selected] as Dictionary).duplicate(true)
	e.t = snappedf(float(e.get("t", 0.0)) + 0.05, 0.005)
	(data.events as Array).append(e)
	selected = data.events.size() - 1
	_changed()
	_refresh_inspector()

func _delete_event() -> void:
	if selected < 0: return
	_remember("delete")
	(data.events as Array).remove_at(selected)
	selected = mini(selected, data.events.size() - 1)
	_changed()
	_refresh_inspector()

func _drag_event(index: int, t: float) -> void:
	_remember("drag%d" % index)
	data.events[index]["t"] = t
	if index == selected: _refresh_inspector()
	dirty = true
	_refresh_list()
	_refresh_check()
	_strip.queue_redraw()

func _set_field(key: String, value: Variant) -> void:
	if _filling or selected < 0: return
	_remember("%d:%s" % [selected, key])
	var e: Dictionary = data.events[selected]
	match key:
		"by_x": e["by"] = [value, (e.get("by", [0, 0]) as Array)[1]]
		"by_y": e["by"] = [(e.get("by", [0, 0]) as Array)[0], value]
		_: e[key] = value
	_changed()

func _toggle_optional(key: String, on: bool, default: Variant) -> void:
	if _filling or selected < 0: return
	_remember("%d:%s?" % [selected, key])
	var e: Dictionary = data.events[selected]
	if on: e[key] = e.get(key, default)
	else: e.erase(key)
	_refresh_inspector()
	_changed()

func _set_style(key: String, value: Variant) -> void:
	if _filling: return
	_remember("style:" + key)
	if key == "renderer" and String(value).is_empty(): style.erase("renderer")
	else: style[key] = value
	_changed()
	if key == "renderer": _refresh_inspector()

func _set_captions(text: String) -> void:
	if _filling: return
	_remember("captions")
	var captions := []
	for line in text.split("\n"):
		var parts := line.strip_edges().split(" ", false, 1)
		if parts.size() == 2 and parts[0].is_valid_float(): captions.append([float(parts[0]), parts[1]])
	if captions.is_empty(): data.erase("captions")
	else: data["captions"] = captions
	_changed()

## Moves the nearest later hit so it lands when this slash's blade crosses the target; for a
## cast, the next hits (one per projectile / pulse, added if missing) onto its landings.
func _align_hit() -> void:
	if selected >= 0 and String(data.events[selected].do) == "cast":
		_align_cast_hits()
		return
	if selected < 0 or String(data.events[selected].do) != "slash": return
	var slash: Dictionary = data.events[selected]
	var target_t := _contact_time(slash)
	var best := -1
	for i in data.events.size():
		var e: Dictionary = data.events[i]
		if String(e.do) != "hit" or float(e.t) < float(slash.t) - 0.001: continue
		if best < 0 or float(e.t) < float(data.events[best].t): best = i
	if best < 0:
		_status.text = "后面没有命中事件"
		return
	_remember("align")
	data.events[best]["t"] = snappedf(target_t, 0.001)
	_status.text = "命中已对齐到 %.3fs" % target_t
	_changed()

func _align_cast_hits() -> void:
	var cast: Dictionary = data.events[selected]
	var times: Array = load(MAGIC_STAGE).contact_times(cast)
	# This cast's hits: those after it and before the next attack (cast or slash).
	var until := INF
	for e: Dictionary in data.events:
		if String(e.do) in ["cast", "slash"] and float(e.t) > float(cast.t) + 0.0001: until = minf(until, float(e.t))
	var later := []
	for i in data.events.size():
		var e: Dictionary = data.events[i]
		if String(e.do) == "hit" and float(e.t) >= float(cast.t) - 0.001 and float(e.t) < until: later.append(i)
	later.sort_custom(func(a: int, b: int) -> bool: return float(data.events[a].t) < float(data.events[b].t))
	_remember("align")
	for n in times.size():
		if n < later.size(): data.events[later[n]]["t"] = snappedf(float(times[n]), 0.001)
		else: (data.events as Array).append({"t": snappedf(float(times[n]), 0.001), "do": "hit", "push": 40, "stop": 0.04, "shake": 2.5})
	_status.text = "%d 次命中已对齐到落点" % times.size()
	_changed()
	_refresh_list()

## A cast field's value: as set, else its element's default.
func _cast_value(e: Dictionary, key: String, fallback: float) -> float:
	return float((load(MAGIC_STAGE).cast_spec(e) as Dictionary).get(key, fallback))

func _contact_time(slash: Dictionary) -> float:
	match _renderer():
		"claw": return float(slash.t) + float(slash.get("duration", 0.16)) * float(slash.get("contact", 0.5))
		"ribbon": return float(slash.t) + float(slash.get("duration", 0.16)) * 0.5
	return float(slash.t) + 0.04

# --- Views -----------------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_style()
	_refresh_list()
	_refresh_inspector()
	_refresh_check()
	_strip.queue_redraw()

func _order() -> Array:
	var order := range(data.events.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(data.events[a].get("t", 0.0)) < float(data.events[b].get("t", 0.0)))
	return order

func _summary(e: Dictionary) -> String:
	match String(e.do):
		"slash":
			if _renderer() == "claw":
				var claws := "宽%.0f  %d爪" % [float(e.get("width", 44)), int(e.get("fingers", 3))]
				match String(e.get("claw", "arc")):
					"slam": return "暴扣  " + claws
					"rake": return "直抓 %.0f°  %s" % [float(e.get("angle", 40)), claws]
					"swipe": return "横斩%s  %s" % ["（反手）" if absf(float(e.get("angle", 0))) > 90.0 else "", claws]
					"dash": return "突进  " + claws
					"cross": return "交叉斩 ±%.0f°  %s" % [float(e.get("angle", 40)), claws]
					_: return "回环 %.0f→%.0f  宽%.0f  %d爪" % [float(e.get("from", -70)), float(e.get("to", 70)), float(e.get("width", 44)), int(e.get("fingers", 3))]
			return "%.0f→%.0f  宽%.0f" % [float(e.get("from", -70)), float(e.get("to", 70)), float(e.get("width", 44))]
		"hit": return "击退%.0f  顿帧%.3f%s%s" % [float(e.get("push", 60)), float(e.get("stop", 0.05)), "  挑%.0f" % float(e.launch) if e.has("launch") else "", "  终结" if e.get("finisher", false) else ""]
		"move":
			var by: Array = e.get("by", [0, 0])
			return "(%.0f, %.0f) %.2fs" % [float(by[0]), float(by[1]), float(e.get("time", 0.08))]
		"flash_step": return "穿过 %.0f" % float(e.get("past", 140))
		"cut": return "角度 %.0f" % float(e.get("angle", 0))
		"cast":
			var spec: Dictionary = load(MAGIC_STAGE).cast_spec(e)
			var element: String = ELEMENT_NAMES[maxi(0, ELEMENTS.find(String(e.get("element", "fire"))))]
			var route := PackedStringArray()
			for key: String in ["start", "path", "end"]:
				var options: Array = CAST_OPTIONS[key]
				route.append(String(options[1][maxi(0, (options[0] as Array).find(String(spec[key])))]))
			var landing: Array = load(MAGIC_STAGE).contact_times(e)
			return "%s %s ×%d  落点 %.2fs" % [element, "→".join(route), landing.size(), float(landing[0])]
	return ""

func _refresh_list() -> void:
	_list.clear()
	for i in _order():
		var e: Dictionary = data.events[i]
		var row := _list.add_item("%.3f  %s  %s" % [float(e.get("t", 0.0)), DO_NAMES.get(String(e.do), String(e.do)), _summary(e)])
		_list.set_item_metadata(row, i)
		_list.set_item_custom_fg_color(row, DO_COLOURS.get(String(e.do), Color.WHITE))
		if i == selected: _list.select(row)

func _row(parent: Control, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(104, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)

func _spin(min_value: float, max_value: float, step: float, value: float, changed: Callable) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value = value
	spin.value_changed.connect(changed)
	return spin

func _options(names: Array, current: int, changed: Callable) -> OptionButton:
	var options := OptionButton.new()
	for name in names: options.add_item(String(name))
	options.select(maxi(current, 0))
	options.item_selected.connect(changed)
	return options

func _refresh_style() -> void:
	_filling = true
	for child in _style_box.get_children(): child.free()
	var heading := Label.new()
	heading.text = "风格（整套）"
	heading.add_theme_color_override("font_color", Color("ffe36b"))
	_style_box.add_child(heading)
	var title := LineEdit.new()
	title.text = String(style.get("title", ""))
	title.text_changed.connect(func(text: String) -> void: _set_style("title", text))
	_row(_style_box, "标题", title)
	_row(_style_box, "绘制器", _options(RENDERER_NAMES, RENDERERS.find(_renderer()), func(i: int) -> void:
		_set_style("renderer", RENDERERS[i])
		_refresh_style.call_deferred()))
	if _renderer() == "magic":
		var tiers := ["retro", "balanced", "ultimate", "explosive"]
		var current := tiers.find(String(style.get("magic_quality", "explosive")))
		if current < 0: current = 3
		_row(_style_box, "魔法画质", _options(["复古", "均衡", "极致", "炸裂"], current, func(i: int) -> void: _set_style("magic_quality", tiers[i])))
	_row(_style_box, "粗细", _spin(0.2, 3.0, 0.05, float(style.get("thickness", 1.0)), func(v: float) -> void: _set_style("thickness", v)))
	_row(_style_box, "像素颗粒", _spin(1, 8, 1, float(style.get("pixel", 3)), func(v: float) -> void: _set_style("pixel", int(v))))
	var captions := TextEdit.new()
	captions.custom_minimum_size = Vector2(0, 70)
	captions.placeholder_text = "字幕（爪痕绘制器）：每行“时间 文字”"
	var lines := PackedStringArray()
	for entry in data.get("captions", []): lines.append("%s %s" % [str(entry[0]), str(entry[1])])
	captions.text = "\n".join(lines)
	captions.text_changed.connect(func() -> void: _set_captions(captions.text))
	_row(_style_box, "字幕", captions)
	_filling = false

func _refresh_inspector() -> void:
	_filling = true
	for child in _inspector.get_children(): child.free()
	var heading := Label.new()
	heading.add_theme_color_override("font_color", Color("ffe36b"))
	_inspector.add_child(heading)
	if selected < 0 or selected >= data.events.size():
		heading.text = "选中一个事件来修改"
		_filling = false
		return
	var e: Dictionary = data.events[selected]
	heading.text = "事件：" + DO_NAMES.get(String(e.do), String(e.do))
	var renderer := _renderer()
	for field: Array in FIELDS.get(String(e.do), []):
		var key: String = field[0]
		var shown: String = field[6]
		if shown == "stock" and not renderer in ["", "ink"]: continue
		if shown == "timed" and not renderer in ["ribbon", "claw"]: continue
		if shown == "claw" and renderer != "claw": continue
		if shown.begins_with("k:") and (renderer != "claw" or not String(e.get("claw", "arc")) in shown.trim_prefix("k:").split("|")): continue
		if shown.begins_with("e:") and not String(e.get("element", "fire")) in shown.trim_prefix("e:").split("|"): continue
		if shown.begins_with("f:") and not String((load(MAGIC_STAGE).cast_spec(e) as Dictionary).path) in shown.trim_prefix("f:").split("|"): continue
		match key:
			"palette": _row(_inspector, field[1], _options(PALETTES, PALETTES.find(String(e.get("palette", "normal"))), func(i: int) -> void: _set_field("palette", PALETTES[i])))
			"claw": _row(_inspector, field[1], _options(CLAW_NAMES, CLAW_KINDS.find(String(e.get("claw", "arc"))), func(i: int) -> void:
				_set_field("claw", CLAW_KINDS[i])
				_refresh_inspector()))
			"element": _row(_inspector, field[1], _options(ELEMENT_NAMES, ELEMENTS.find(String(e.get("element", "fire"))), func(i: int) -> void:
				_set_field("element", ELEMENTS[i])
				_refresh_inspector()))
			"start", "end", "path":
				var options: Array = CAST_OPTIONS[key]
				var current := String((load(MAGIC_STAGE).cast_spec(e) as Dictionary)[key])
				_row(_inspector, field[1], _options(options[1], (options[0] as Array).find(current), func(i: int) -> void:
					_set_field(key, options[0][i])
					_refresh_inspector()))
			"finisher":
				var check := CheckBox.new()
				check.button_pressed = bool(e.get("finisher", false))
				check.toggled.connect(func(on: bool) -> void: _set_field("finisher", on))
				_row(_inspector, field[1], check)
			"by_x", "by_y":
				var by: Array = e.get("by", [0, 0])
				_row(_inspector, field[1], _spin(field[2], field[3], field[4], float(by[0 if key == "by_x" else 1]), func(v: float) -> void: _set_field(key, v)))
			_:
				if shown == "optional":
					var line := HBoxContainer.new()
					var check := CheckBox.new()
					check.button_pressed = e.has(key)
					check.toggled.connect(func(on: bool) -> void: _toggle_optional(key, on, field[5]))
					line.add_child(check)
					if e.has(key):
						var spin := _spin(field[2], field[3], field[4], float(e[key]), func(v: float) -> void: _set_field(key, v))
						spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						line.add_child(spin)
					_row(_inspector, field[1], line)
				else:
					var value := _cast_value(e, key, float(field[5])) if String(e.do) == "cast" else float(e.get(key, field[5]))
					var integer := float(field[4]) >= 1.0 and key in ["fingers", "count"]
					_row(_inspector, field[1], _spin(field[2], field[3], field[4], value, func(v: float) -> void: _set_field(key, int(v) if integer else v)))
	if String(e.do) == "slash":
		var align := _button("对齐命中到刀光扫到目标的时刻", _align_hit)
		_inspector.add_child(align)
	if String(e.do) == "cast":
		_inspector.add_child(_button("对齐命中到每个落点（不够会自动补）", _align_hit))
	_filling = false

func _refresh_check() -> void:
	var events: Array = data.events
	var hits := events.filter(func(e: Dictionary) -> bool: return String(e.do) == "hit").size()
	var last := 0.0
	for e: Dictionary in events: last = maxf(last, float(e.get("t", 0.0)))
	var lines := PackedStringArray(["%d 个事件 · %d 次命中 · 最后事件 %.2fs%s" % [events.size(), hits, last, "  · 未保存" if dirty else ""]])
	if hits == 0: lines.append("⚠ 没有命中事件：自检和连击数需要至少一个「命中」")
	# Slashes whose blade crosses the target with no hit near that moment.
	for e: Dictionary in events:
		if String(e.do) != "slash": continue
		var contact := _contact_time(e)
		var near := events.any(func(h: Dictionary) -> bool: return String(h.do) == "hit" and absf(float(h.t) - contact) < 0.03)
		if not near: lines.append("⚠ %.3fs 的斩击扫到目标约在 %.3fs，附近没有命中（选中它按「对齐命中」）" % [float(e.t), contact])
	# Casts whose projectiles land with no hit near that moment.
	for e: Dictionary in events:
		if String(e.do) != "cast": continue
		for landing: float in load(MAGIC_STAGE).contact_times(e):
			if not events.any(func(h: Dictionary) -> bool: return String(h.do) == "hit" and absf(float(h.t) - landing) < 0.03):
				lines.append("⚠ %.3fs 的施法在 %.3fs 落到目标，附近没有命中（选中它按「对齐命中」）" % [float(e.t), landing])
	if selected >= 0 and selected < events.size() and String(events[selected].do) == "slash":
		lines.append("选中斩击：建议命中时间 %.3fs" % _contact_time(events[selected]))
	_check.text = "\n".join(lines)

# --- Preview ---------------------------------------------------------------------------------

func _rebuild(play := true) -> void:
	_rebuild_in = -1.0
	for child in _host.get_children(): child.free()
	ComboStyle.load_data(style.duplicate(true))
	var script: GDScript = ComboStage
	var renderer := _renderer()
	if not renderer.is_empty():
		var path := "res://vfx/%s_stage.gd" % renderer
		if ResourceLoader.exists(path): script = load(path)
	stage = script.new()
	_host.add_child(stage)
	# The editor owns the keys; the stage's own 1 / 2 / R / Space would double them.
	stage.set_process_unhandled_input(false)
	if "help" in stage and stage.help != null: stage.help.visible = false
	stage.TIMELINE = ComboStage.parse_events(data.events)
	if "captions" in stage: stage.captions = data.get("captions", [])
	stage.reset()
	if play: stage.play()

func _toggle_slow() -> void:
	if stage == null: return
	stage.speed = ComboStage.SLOW_SPEED if stage.speed == 1.0 else 1.0
	_status.text = "慢放 0.25×" if stage.speed < 1.0 else "正常速度"

func _process(delta: float) -> void:
	if _rebuild_in >= 0.0:
		_rebuild_in -= delta
		if _rebuild_in < 0.0:
			var slow: bool = stage != null and stage.speed < 1.0
			_rebuild(true)
			if slow: stage.speed = ComboStage.SLOW_SPEED
	_strip.queue_redraw()

# --- Saving ----------------------------------------------------------------------------------

func _sorted_data() -> Dictionary:
	var out := data.duplicate(true)
	(out.events as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	return out

func _write(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status.text = "写入失败：%s" % path
		return false
	file.store_string(JSON.stringify(value, "  ", false) + "\n")
	return true

func _validate() -> String:
	var events: Array = data.events
	if events.is_empty(): return "没有事件"
	if not events.any(func(e: Dictionary) -> bool: return String(e.do) == "hit"): return "至少需要一个「命中」"
	return ""

func _save() -> void:
	if combo_path.is_empty():
		_save_new()
		return
	var problem := _validate()
	if not problem.is_empty():
		_status.text = "没保存：" + problem
		return
	var folder := combo_path.get_base_dir()
	for file in ["combo.json", "style.json"]:
		var path := folder.path_join(file)
		if not _backed_up.has(path) and FileAccess.file_exists(path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
			_backed_up[path] = true
	if _write(combo_path, _sorted_data()) and _write(folder.path_join("style.json"), style):
		dirty = false
		_status.text = "已保存 %s（原文件备份为 .bak）" % folder.get_file()
		_refresh_check()

func _save_new() -> void:
	var name := _save_as.text.strip_edges()
	var valid := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	if valid.search(name) == null:
		_status.text = "名字只能用英文小写字母、数字和下划线，例如 my_claw_combo"
		return
	var folder := COMBOS.path_join(name)
	if DirAccess.dir_exists_absolute(folder):
		_status.text = "%s 已存在，换个名字（或打开它再按「保存」）" % name
		return
	var problem := _validate()
	if not problem.is_empty():
		_status.text = "没保存：" + problem
		return
	DirAccess.make_dir_recursive_absolute(folder)
	_write(folder.path_join("combo.json"), _sorted_data())
	_write(folder.path_join("style.json"), style)
	var scene := FileAccess.open(folder.path_join(name + ".tscn"), FileAccess.WRITE)
	scene.store_string("[gd_scene format=3]\n\n[ext_resource type=\"Script\" path=\"res://vfx/combo_player.gd\" id=\"1\"]\n\n[node name=\"ComboPlayer\" type=\"Node2D\"]\nscript = ExtResource(\"1\")\ncombo_file = \"res://combos/%s/combo.json\"\nstyle_file = \"res://combos/%s/style.json\"\n" % [name, name])
	scene.close()
	var prompt := FileAccess.open(folder.path_join("prompt.md"), FileAccess.WRITE)
	prompt.store_string("# %s\n\n在「手动精调」画面里手动编排。\n" % String(style.get("title", name)))
	prompt.close()
	_fill_picker()
	combo_path = folder.path_join("combo.json")
	_picker.select(_paths.find(combo_path))
	dirty = false
	_save_as.text = ""
	_status.text = "已另存为 %s（画廊里也能直接打开）" % name
	_refresh_check()

func _leave() -> void:
	if dirty and not _leave_armed:
		_leave_armed = true
		_status.text = "有未保存的修改：再按一次「返回」/ Esc 放弃修改"
		return
	get_tree().change_scene_to_file(GALLERY)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	var command: bool = event.is_command_or_control_pressed()
	match event.keycode:
		KEY_S when command: _save()
		KEY_Z when command:
			if event.shift_pressed: _redo_step()
			else: _undo_step()
		KEY_Y when command: _redo_step()
		KEY_D when command: _duplicate_event()
		KEY_DELETE: _delete_event()
		KEY_ESCAPE: _leave()
		KEY_SPACE: _rebuild(true)
		KEY_2: _toggle_slow()
		KEY_LEFT, KEY_RIGHT:
			if selected < 0: return
			var step := (0.025 if event.shift_pressed else 0.005) * (1.0 if event.keycode == KEY_RIGHT else -1.0)
			_remember("nudge%d" % selected)
			data.events[selected]["t"] = maxf(0.0, snappedf(float(data.events[selected].get("t", 0.0)) + step, 0.001))
			_refresh_inspector()
			_changed()
		_: return
	get_viewport().set_input_as_handled()
