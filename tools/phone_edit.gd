extends Node2D
## A vertical (9:16, 1080 × 1920) showcase cut for phones, played live and recorded with
## Godot's movie maker:
##   godot --path . res://tools/phone_edit.tscn --resolution 1080x1920 --write-movie out.avi
##         --fixed-fps 60 --quit-after <frames printed at start>
## Each segment plays a combo scene from a point in it (stepped ahead silently: everything is
## a function of time), cropped and zoomed into the video block, under a title that slams in
## and over a "recipe" — the chips saying which shape, materials and rules it is built from —
## with a white flash between segments and a blurred copy of the footage filling the frame.
## No sound: titles only.

const W := 1080.0
const H := 1920.0
## Where the footage sits.
const VIDEO := Rect2(0, 470, 1080, 972)
const SPEED := 0.8
const TINTS := {"fire": Color(1.0, 0.55, 0.22), "thunder": Color(0.55, 0.7, 1.0), "ice": Color(0.6, 0.92, 1.0),
	"wind": Color(0.9, 0.96, 1.0), "sand": Color(0.98, 0.78, 0.36), "shape": Color(0.82, 0.66, 1.0), "rule": Color(0.7, 0.75, 0.82)}
const ODD := "res://combos/odd_combos/odd_combos.tscn"
const MASTER := "res://combos/element_master/element_master.tscn"

## scene, start (stage seconds), length (stage seconds), crop x, y, width (of the 1280 × 720
## stage), tag, title, line, chips [[text, kind]], note, tint
const SEGMENTS := [
	[MASTER, 0.0, 2.6, 60, 40, 720, "", "一套特效系统", "能拼出多少种魔法？",
		[["形状", "shape"], ["×", ""], ["材质", "sand"], ["×", ""], ["混合", "fire"], ["×", ""], ["连锁", "thunder"]],
		"6 种形状 · 5 种材质 · 任意混合 —— 下面 9 个组合，没有一行为它们单独写的代码", "sand"],
	[ODD, 0.05, 2.58, 250, 110, 700, "01 / 09", "风火轮", "火做的环里掺着风，跟着施法者冲过去",
		[["环", "shape"], ["火", "fire"], ["＋ 风", "wind"], ["起点：自己", "rule"], ["结束爆开", "rule"]],
		"环的起点是施法者自己，人一冲，环就跟着撞上去炸", "fire"],
	[ODD, 2.53, 1.8, 300, 120, 680, "02 / 09", "冰火双螺旋", "同一条路，冰走直线，火绕着它转",
		[["彗星", "shape"], ["冰", "ice"], ["彗星 · 螺旋", "shape"], ["火", "fire"]],
		"冰的材质自带规矩：永远不拐弯。同样走螺旋，火就自然缠着冰飞", "ice"],
	[ODD, 4.23, 2.18, 540, 150, 600, "03 / 09", "雷冰法阵", "法阵不画在身后，画在敌人身上",
		[["法阵", "shape"], ["雷", "thunder"], ["＋ 冰", "ice"], ["起点：敌人", "rule"], ["阵成即爆", "rule"]],
		"法阵也只是一种形状 —— 换个位置、换种材质，背景就成了陷阱", "thunder"],
	[ODD, 6.31, 2.0, 400, 0, 800, "04 / 09", "千丝缝合", "十六根沙丝，从四面八方同时扎进目标",
		[["丝线", "shape"], ["沙", "sand"], ["× 16", "rule"], ["起点：一圈坐标", "rule"]],
		"起点不止能填「手上」，还能填一串坐标：一次施法，十六个方向", "sand"],
	[ODD, 8.21, 3.1, 300, 60, 760, "05 / 09", "火雷多米诺", "一道雷点燃第一颗，一颗接一颗炸过去",
		[["彗星", "shape"], ["火", "fire"], ["× 2 组交错", "rule"], ["悬停", "rule"], ["引信 0.12 秒", "rule"], ["雷点火", "thunder"]],
		"前一招留在场上的东西，就是下一招的引信", "fire"],
	[ODD, 11.21, 3.22, 450, 30, 760, "06 / 09", "雷沙龙卷", "龙卷不一定是风",
		[["漩涡", "shape"], ["雷", "thunder"], ["＋ 沙", "sand"], ["越转越大", "rule"]],
		"把风的形状交给雷来画，再掺一缕沙丝", "thunder"],
	[ODD, 14.33, 2.18, 380, 90, 680, "07 / 09", "冰柱进军", "冰柱从脚下一根接一根顶到目标",
		[["地柱", "shape"], ["冰", "ice"], ["× 5", "rule"], ["坐标逐个后移", "rule"]],
		"冰本来没有地柱这一招 —— 公共形状＋冰的材质，自动就有了", "ice"],
	[ODD, 16.41, 3.32, 520, 120, 640, "08 / 09", "元素牢笼", "五种元素拧成环，把目标关住",
		[["环", "shape"], ["风", "wind"], ["＋ 火", "fire"], ["＋ 冰", "ice"], ["＋ 雷", "thunder"], ["＋ 沙", "sand"], ["收紧 3 次后爆开", "rule"]],
		"一个形状里混五种材质：收紧三次，五种爆炸一起炸开", "wind"],
	[ODD, 19.63, 2.35, 420, 0, 800, "09 / 09", "冰雷天降", "冰做的光束缠着雷，从天上砸下来",
		[["光束", "shape"], ["冰", "ice"], ["＋ 雷", "thunder"], ["高空 → 地面", "rule"], ["× 4", "rule"]],
		"光束 × 冰 × 雷：材质决定质感，形状决定怎么落下来", "ice"],
	[MASTER, 14.6, 5.4, 150, 0, 820, "终极组合", "万象归一", "所有元素压进指尖，再一束射出",
		[["光束", "shape"], ["沙", "sand"], ["＋ 火", "fire"], ["＋ 冰", "ice"], ["＋ 雷", "thunder"], ["＋ 风", "wind"], ["蓄力 2.6 秒", "rule"]],
		"蓄力越久，吸进来的粒子越远越多；落地时五种爆炸同时炸开", "sand"],
	[MASTER, 10.2, 2.6, 380, 0, 800, "", "全部来自同一套系统", "形状 × 材质，还有无数种没试过的组合",
		[["彗星", "shape"], ["光束", "shape"], ["环", "shape"], ["地柱", "shape"], ["漩涡", "shape"], ["法阵", "shape"],
		["火", "fire"], ["雷", "thunder"], ["冰", "ice"], ["风", "wind"], ["沙", "sand"]],
		"你想要的下一个组合，只是改几个参数", "shape"],
]

var _viewport: SubViewport
var _player: Node
var _video: Sprite2D
var _backdrop: Sprite2D
var _flash: ColorRect
var _tag: Label
var _title: Label
var _ghosts: Array[Label] = []
var _line: Label
var _note: Label
var _chips: HFlowContainer
var _bars: Array[ColorRect] = []
var _dots: Array[ColorRect] = []
var _segment := -1
var _t := 0.0
var _bold: SystemFont
var _regular: SystemFont

static func total_frames() -> int:
	var seconds := 0.0
	for s: Array in SEGMENTS: seconds += float(s[2]) / SPEED
	return ceili(seconds * 60.0) + 30

func _ready() -> void:
	get_window().content_scale_size = Vector2i(int(W), int(H))
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("phone_edit: %d frames at 60 fps" % total_frames())
	_bold = SystemFont.new()
	_bold.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC"])
	_bold.font_weight = 800
	_regular = SystemFont.new()
	_regular.font_names = _bold.font_names
	_regular.font_weight = 400
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.size = Vector2(W, H)
	add_child(bg)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_backdrop = Sprite2D.new()
	_backdrop.texture = _viewport.get_texture()
	_backdrop.centered = true
	_backdrop.position = Vector2(W, H) * 0.5
	_backdrop.scale = Vector2.ONE * (H / 720.0)
	var blur := ShaderMaterial.new()
	blur.shader = _blur_shader()
	_backdrop.material = blur
	add_child(_backdrop)
	_video = Sprite2D.new()
	_video.texture = _viewport.get_texture()
	_video.region_enabled = true
	_video.centered = true
	add_child(_video)
	# Glowing rules along the top and bottom of the footage.
	for y: float in [VIDEO.position.y, VIDEO.end.y]:
		var bar := ColorRect.new()
		bar.size = Vector2(W, 4)
		bar.position = Vector2(0, y - 2)
		add_child(bar)
		_bars.append(bar)
	_tag = _label(_bold, 40, Vector2(0, 120), 6)
	for k in 2:
		var ghost := _label(_bold, 120, Vector2(0, 200), 0)
		_ghosts.append(ghost)
	_title = _label(_bold, 120, Vector2(0, 200), 16)
	_line = _label(_regular, 44, Vector2(0, 370), 8)
	_chips = HFlowContainer.new()
	_chips.position = Vector2(60, VIDEO.end.y + 50)
	_chips.size = Vector2(W - 120, 260)
	_chips.alignment = FlowContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("h_separation", 16)
	_chips.add_theme_constant_override("v_separation", 16)
	add_child(_chips)
	_note = _label(_regular, 40, Vector2(0, 1745), 8)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.position.x = 70
	_note.size.x = W - 140
	for k in 9:
		var dot := ColorRect.new()
		dot.size = Vector2(56, 8)
		dot.position = Vector2(W * 0.5 - 9 * 36 + k * 72 + 8, 1872)
		add_child(dot)
		_dots.append(dot)
	_flash = ColorRect.new()
	_flash.size = Vector2(W, H)
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	_start(0)

func _label(font: Font, px: int, at: Vector2, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = at
	label.size = Vector2(W, px * 1.4)
	label.pivot_offset = label.size * 0.5
	add_child(label)
	return label

func _start(index: int) -> void:
	_segment = index
	_t = 0.0
	var s: Array = SEGMENTS[index]
	if _player != null: _player.free()
	_player = (load(s[0]) as PackedScene).instantiate()
	_player.set("loop_pause", -1.0)
	_viewport.add_child(_player)
	var demo: Node = _player.get("demo")
	var skipped := 0.0
	while skipped < float(s[1]):
		demo.advance(1.0 / 60.0)
		skipped += 1.0 / 60.0
	demo.set("speed", SPEED)
	(demo.get("overlay") as CanvasLayer).visible = false
	(_player.get("_overlay") as CanvasLayer).visible = false
	(demo.get("counter") as CanvasItem).self_modulate = Color(1, 1, 1, 0)
	var crop := Rect2(float(s[3]), float(s[4]), float(s[5]), float(s[5]) * VIDEO.size.y / VIDEO.size.x)
	_video.region_rect = crop
	_video.position = VIDEO.get_center()
	_video.scale = Vector2.ONE * VIDEO.size.x / crop.size.x
	var tint: Color = TINTS[s[11]]
	_tag.text = s[6]
	_tag.add_theme_color_override("font_color", tint)
	_title.text = s[7]
	_title.add_theme_color_override("font_color", Color.WHITE.lerp(tint, 0.25))
	# Long titles shrink to fit the width.
	var px := mini(120, floori(940.0 / maxf(String(s[7]).length(), 1.0)))
	_title.add_theme_font_size_override("font_size", px)
	for k in _ghosts.size():
		_ghosts[k].add_theme_font_size_override("font_size", px)
		_ghosts[k].text = s[7]
		_ghosts[k].add_theme_color_override("font_color", Color(1, 0.2, 0.35, 0.0) if k == 0 else Color(0.2, 0.9, 1.0, 0.0))
	_line.text = s[8]
	_line.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	_note.text = s[10]
	_note.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	for child in _chips.get_children(): child.free()
	for chip: Array in s[9]: _chips.add_child(_chip(String(chip[0]), String(chip[1])))
	for bar in _bars: bar.color = Color(tint, 0.8)
	for k in _dots.size():
		var on := index >= 1 and index <= 9 and k == index - 1
		var done := index > 9 or (index >= 1 and k < index - 1)
		_dots[k].color = Color(tint, 1.0) if on else (Color(1, 1, 1, 0.45) if done else Color(1, 1, 1, 0.12))
		_dots[k].visible = index >= 1 and index <= 9

func _chip(text: String, kind: String) -> Control:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _bold)
	label.add_theme_font_size_override("font_size", 42)
	if kind.is_empty():
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		label.modulate.a = 0.0
		return label
	var tint: Color = TINTS[kind]
	label.add_theme_color_override("font_color", Color.WHITE.lerp(tint, 0.35))
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint, 0.18)
	style.border_color = Color(tint, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", style)
	box.add_child(label)
	box.modulate.a = 0.0
	return box

func _process(delta: float) -> void:
	_t += delta
	var s: Array = SEGMENTS[_segment]
	var length := float(s[2]) / SPEED
	if _t >= length:
		if _segment + 1 < SEGMENTS.size(): _start(_segment + 1)
		else: get_tree().quit()
		return
	_animate(length)

func _animate(length: float) -> void:
	var t := _t
	# White flash on the cut, the footage punching in.
	_flash.color.a = clampf(1.0 - t / 0.18, 0.0, 1.0) * (0.85 if _segment > 0 else 0.0)
	var punch := 1.0 + 0.07 * exp(-t / 0.12)
	_video.scale = Vector2.ONE * VIDEO.size.x / _video.region_rect.size.x * punch
	# The title slams down, shaking; colour ghosts split off it and close up.
	var slam := clampf(t / 0.22, 0.0, 1.0)
	var back := 1.0 + 2.2 * pow(slam - 1.0, 3) + 1.2 * pow(slam - 1.0, 2)
	_title.scale = Vector2.ONE * lerpf(2.2, 1.0, back)
	_title.modulate.a = clampf(t / 0.08, 0.0, 1.0)
	var shake := 10.0 * exp(-maxf(t - 0.22, 0.0) / 0.08) if t > 0.22 else 0.0
	_title.position = Vector2(sin(t * 90.0) * shake, 200 + cos(t * 77.0) * shake)
	for k in _ghosts.size():
		var split := 26.0 * exp(-maxf(t - 0.2, 0.0) / 0.25) if t > 0.2 else 0.0
		_ghosts[k].position = _title.position + Vector2((-1 if k == 0 else 1) * split, 0)
		_ghosts[k].scale = _title.scale
		var c: Color = _ghosts[k].get_theme_color("font_color")
		c.a = 0.75 * clampf(split / 26.0, 0.0, 1.0)
		_ghosts[k].add_theme_color_override("font_color", c)
	_tag.modulate.a = clampf((t - 0.05) / 0.15, 0.0, 1.0)
	_line.modulate.a = clampf((t - 0.3) / 0.2, 0.0, 1.0)
	_line.position.y = 370 + 20 * (1.0 - _line.modulate.a)
	# The recipe pops in chip by chip.
	var k := 0
	for chip: Control in _chips.get_children():
		var x := clampf((t - 0.45 - 0.09 * k) / 0.16, 0.0, 1.0)
		chip.modulate.a = x
		chip.pivot_offset = chip.size * 0.5
		chip.scale = Vector2.ONE * (1.0 + 0.35 * (1.0 - x) * (1.0 - x))
		k += 1
	_note.modulate.a = clampf((t - 0.45 - 0.09 * k - 0.1) / 0.25, 0.0, 1.0)
	# Fade the words out just before the cut.
	var out := clampf((length - t) / 0.15, 0.0, 1.0)
	for node: CanvasItem in [_title, _tag, _line, _note, _chips]: node.modulate.a = minf(node.modulate.a, out) if node != _chips else out
	for ghost in _ghosts: ghost.modulate.a = out
	for bar in _bars: bar.color.a = 0.55 + 0.35 * sin(t * 6.0)

func _blur_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 7.0;
	vec4 sum = vec4(0.0);
	float n = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * px);
			n += 1.0;
		}
	}
	COLOR = vec4(sum.rgb / n * 0.42, 1.0);
}
"""
	return shader
