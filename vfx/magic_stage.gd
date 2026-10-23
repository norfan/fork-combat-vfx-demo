@tool
extends ComboStage
## Off-hand magic for `cast` events (`"renderer": "magic"` in style.json), drawn at full
## resolution with shaders (no pixel grain). A cast names an `element` and the spell's
## skeleton — where it starts, where it ends, the path and speed curve between, and the
## blast radius at the end (fields in vfx/magic/magic_fx.gd, defaults per element). The
## element supplies the body and the accessories that follow it.
## Body `i` of a volley lands `charge + travel + interval × i` s after the cast; pair a
## `hit` with each landing. The hit then plays the element's impact and status instead of
## the stock star spark; hits that match no landing stay melee hits.
## The caster stands back (x 360) and the target further off (x 840): magic is ranged.
## combo.json may carry "captions": [[t, "text"], ...] shown at the top left.
## style.json "magic_quality" picks the tier (vfx/magic/magic_art.gd): "retro" 复古,
## "balanced" 均衡, "ultimate" 极致 or "explosive" 炸裂 (everything, the default). Q cycles it
## while the demo runs.
const Art = preload("res://vfx/magic/magic_art.gd")
const QUALITIES := ["retro", "balanced", "ultimate", "explosive"]
const QUALITY_NAMES := {"retro": "复古", "balanced": "均衡", "ultimate": "极致", "explosive": "炸裂"}
## The pixel layers of the retro tier cover the stage plus this margin.
const LAYER_ORIGIN := Vector2(-64, -160)
const LAYER_SIZE := Vector2(1408, 944)
const ELEMENTS := {
	"fire": preload("res://vfx/magic/fire.gd"),
	"thunder": preload("res://vfx/magic/thunder.gd"),
	"ice": preload("res://vfx/magic/ice.gd"),
	"wind": preload("res://vfx/magic/wind.gd"),
}
const STARTS := ["hand", "above", "sky", "behind", "self", "below", "target"]
const ENDS := ["target", "ground", "self"]
const PATHS := ["straight", "arc", "wave", "spiral", "stay"]
const CASTER_X := 360.0
const TARGET_X := 840.0
## A hit pairs with the landing nearest to it within this many seconds.
const PAIR_WINDOW := 0.09

var captions: Array = []
var caption: Label
## Effects drawn under the target and the caster (scorch marks); their owners free them.
var under: Node2D
## Seconds since the stage started, hit-stop included (screen flashes fade on it).
var real_clock := 0.0
## How fast the target moves this step (a slowing effect sets it every step; 1 = normal).
var target_slow := 1.0
## Landings still to be paired with a hit: {time, spec}.
var _arrivals: Array[Dictionary] = []
var quality := "explosive"
var quality_label: Label
## Retro tier: [layer node, its SubViewport, its display] for `under` and `fx`.
var _layers: Array = []

## A cast's fields with its element's defaults filled in.
static func cast_spec(event: Dictionary) -> Dictionary:
	var element: GDScript = ELEMENTS.get(String(event.get("element", "fire")), ELEMENTS.fire)
	var spec: Dictionary = (element.DEFAULTS as Dictionary).duplicate()
	for key: String in spec:
		if event.has(key): spec[key] = event[key]
	spec.count = maxi(1, int(spec.count))
	return spec

## Combo seconds at which a cast's bodies land (the editor uses this too).
static func contact_times(event: Dictionary) -> Array:
	var spec := cast_spec(event)
	var times := []
	for i in int(spec.count):
		times.append(float(event.get("t", 0.0)) + float(spec.charge) + float(spec.travel) + float(spec.interval) * i)
	return times

func _ready() -> void:
	super._ready()
	under = Node2D.new()
	add_child(under)
	move_child(under, target.get_index())
	caption = Label.new()
	caption.position = Vector2(70, 100)
	caption.add_theme_font_size_override("font_size", 32)
	caption.modulate = ComboStyle.c("text")
	add_child(caption)
	if not combo_file.is_empty() and FileAccess.file_exists(combo_file):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(combo_file))
		if parsed is Dictionary: captions = (parsed as Dictionary).get("captions", [])
	quality_label = Label.new()
	quality_label.position = Vector2(1030, 20)
	quality_label.add_theme_font_size_override("font_size", 20)
	quality_label.add_theme_color_override("font_color", ComboStyle.c("text"))
	add_child(quality_label)
	set_quality(String(ComboStyle.data.get("magic_quality", "explosive")))

## Switches the quality tier: the retro tier moves the effect layers into pixel-grain
## viewports shown with the banding shader; the others draw them straight on the stage.
func set_quality(tier: String) -> void:
	quality = tier if tier in QUALITIES else "explosive"
	Art.quality = quality
	for layer: Array in _layers:
		var node: Node2D = layer[0]
		var index: int = (layer[2] as Node).get_index()
		node.reparent(self, false)
		move_child(node, index)
		(layer[1] as Node).free()
		(layer[2] as Node).free()
	_layers.clear()
	if quality == "retro":
		for node: Node2D in [under, fx]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(ceili(LAYER_SIZE.x / ComboStyle.pixel), ceili(LAYER_SIZE.y / ComboStyle.pixel))
			viewport.transparent_bg = true
			viewport.disable_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			var lens := Node2D.new()
			lens.scale = Vector2.ONE / ComboStyle.pixel
			lens.position = -LAYER_ORIGIN / ComboStyle.pixel
			viewport.add_child(lens)
			var display := Sprite2D.new()
			display.texture = viewport.get_texture()
			display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			display.centered = false
			display.position = LAYER_ORIGIN
			display.scale = Vector2.ONE * ComboStyle.pixel
			var banding := ShaderMaterial.new()
			banding.shader = Art.shader("retro")
			display.material = banding
			display.z_index = node.z_index
			var index := node.get_index()
			add_child(display)
			move_child(display, index)
			node.reparent(lens, false)
			_layers.append([node, viewport, display])
	if quality_label != null:
		quality_label.text = "魔法画质：%s（Q 切换）" % QUALITY_NAMES[quality]

func _unhandled_input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		set_quality(QUALITIES[(QUALITIES.find(quality) + 1) % QUALITIES.size()])
		play()
		return
	super._unhandled_input(event)

func advance(delta: float) -> void:
	if delta > 0.0: real_clock += delta
	super.advance(delta)

## The target moves (knockback, flight, fall) at `target_slow` of its speed.
func _update_target(delta: float) -> void:
	super._update_target(delta * target_slow)
	target_slow = 1.0

func reset() -> void:
	_arrivals.clear()
	super.reset()
	if under != null:
		for child in under.get_children():
			if not child.is_queued_for_deletion(): child.free()
	attacker.position.x = CASTER_X
	target.position.x = TARGET_X

func _refresh() -> void:
	super._refresh()
	if not is_instance_valid(caption): return
	var text := ""
	for entry in captions:
		if clock + 0.000001 >= float(entry[0]): text = String(entry[1])
	caption.text = text

func _fire(event: Dictionary) -> void:
	if event.do != "cast":
		super._fire(event)
		return
	var name := String(event.get("element", "fire"))
	if not ELEMENTS.has(name):
		push_warning("cast: unknown element '%s' (known: %s)" % [name, ", ".join(ELEMENTS.keys())])
		return
	var spec := cast_spec(event)
	spec.merge({"stage": self, "element": name, "seed_id": _next * 13 + 5}, true)
	spec.size = float(spec.size) * ComboStyle.thickness
	for part: Node in (ELEMENTS[name] as GDScript).cast(spec): fx.add_child(part)
	for time: float in contact_times(event):
		_arrivals.append({"time": time, "spec": spec})

func _hit(event: Dictionary) -> void:
	var best := -1
	for i in _arrivals.size():
		var off := absf(float(_arrivals[i].time) - clock)
		if off < PAIR_WINDOW and (best < 0 or off < absf(float(_arrivals[best].time) - clock)): best = i
	if best < 0:
		super._hit(event)
		return
	var landing: Dictionary = _arrivals.pop_at(best)
	var spec: Dictionary = (landing.spec as Dictionary).duplicate()
	hits += 1
	_counter_age = 0.0
	_target_flash = 0.06
	var finisher := bool(event.get("finisher", false))
	var body := target.position + Vector2(-8, -TARGET_SIZE.y * 0.54)
	var at := body
	match String(spec.end):
		"ground": at = Vector2(target.position.x, GROUND_Y - float(spec.radius) * 0.35)
		# Landing around the caster: the blast goes off there.
		"self": at = attacker.position + Vector2(0, -4)
	spec.merge({"finisher": finisher, "seed_id": hits * 17 + 3, "at": at}, true)
	for part: Node in (ELEMENTS[spec.element] as GDScript).hit(spec):
		# One status per element on the target: a new hit restarts it.
		if part.get("part") == "status":
			var running: Node = null
			for other in fx.get_children():
				if other.get("part") == "status" and other.get("element") == spec.element and not other.is_queued_for_deletion(): running = other
			if running != null:
				running.renew(finisher)
				part.free()
				continue
		fx.add_child(part)
	_target_velocity.x += float(event.push)
	if event.has("launch"): _target_velocity.y = float(event.launch)
	_stop = float(event.stop)
	_shake(float(event.shake), 0.22 if finisher else 0.09)
