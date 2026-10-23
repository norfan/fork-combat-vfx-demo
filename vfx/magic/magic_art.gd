extends RefCounted
## Building blocks the magic effects are drawn with, at full resolution: soft textures
## (glow, smoke) baked once, shader quads, and a Drawer that paints a list of sprites in
## one go (additive for light and fire, normal for smoke and debris).

## Quality tier (style.json "magic_quality", set by magic_stage.gd), lightest first:
##   "retro"     复古 — pixel grain with stepped light, like pixel art
##   "balanced"  均衡 — full resolution, about a third of the particles, smaller halos
##   "ultimate"  极致 — no screen-warping accessories (heat haze, shockwave), about half
##   "explosive" 炸裂 — everything (the default)
static var quality := "explosive"

## Whether the screen-warping accessories are drawn.
static func full() -> bool: return quality == "explosive"

## Particle counts and rates are scaled by this.
static func density() -> float:
	match quality:
		"explosive": return 1.0
		"balanced": return 0.35
	return 0.55

static var _glow: Texture2D
static var _smoke: Texture2D
static var _quad: ArrayMesh
static var _shaders := {}

## A soft round light: white in the middle, fading to nothing at the rim.
static func glow() -> Texture2D:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.25, Color(1, 1, 1, 0.55))
		gradient.add_point(0.6, Color(1, 1, 1, 0.12))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		_glow = texture
	return _glow

## A puff of smoke: a soft, lumpy blob (white; tint it with the draw colour).
static func smoke() -> Texture2D:
	if _smoke == null:
		var side := 96
		var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
		for y in side:
			for x in side:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / side * 2.0 - Vector2.ONE
				var lump := _fbm(p * 2.2 + Vector2(3.1, 7.7))
				var a := clampf(1.0 - (p.length() + (lump - 0.5) * 0.7) , 0.0, 1.0)
				a = smoothstep(0.0, 0.75, a) * (0.65 + 0.35 * _fbm(p * 5.0))
				image.set_pixel(x, y, Color(1, 1, 1, a))
		_smoke = ImageTexture.create_from_image(image)
	return _smoke

static func _hash(p: Vector2) -> float:
	var v := sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453
	return v - floorf(v)

static func _fbm(p: Vector2) -> float:
	var v := 0.0
	var a := 0.5
	for i in 4:
		var c := p.floor()
		var f := p - c
		var u := f * f * (Vector2(3, 3) - 2.0 * f)
		v += a * lerpf(lerpf(_hash(c), _hash(c + Vector2(1, 0)), u.x), lerpf(_hash(c + Vector2(0, 1)), _hash(c + Vector2(1, 1)), u.x), u.y)
		p = p * 2.03 + Vector2(1.7, 9.2)
		a *= 0.5
	return v

static func shader(name: String) -> Shader:
	if not _shaders.has(name): _shaders[name] = load("res://vfx/magic/shaders/%s.gdshader" % name)
	return _shaders[name]

## A quad from (0, 0) to (1, 1) with matching UVs; place it with the node's transform.
static func unit_quad() -> ArrayMesh:
	if _quad == null:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_quad = ArrayMesh.new()
		_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad

## A shader quad. Its material is unique, so each effect sets its own uniforms.
static func quad(shader_name: String) -> MeshInstance2D:
	var node := MeshInstance2D.new()
	node.mesh = unit_quad()
	var material := ShaderMaterial.new()
	material.shader = shader(shader_name)
	node.material = material
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return node

## Places a unit quad over `rect` (in its parent's space).
static func place(node: Node2D, rect: Rect2) -> void:
	node.position = rect.position
	node.scale = rect.size

## A glow sprite (additive).
static func light() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = glow()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = blend
	return sprite

## Refreshes the screen copy that the next screen-reading shader (heat haze, shockwave)
## sees, over `rect` only; without it they would read a stale copy and paint over whatever
## was drawn since.
static func backbuffer() -> BackBufferCopy:
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
	return copy

## Sizes a glow sprite to `extent` px across (x, y).
static func spread_light(sprite: Sprite2D, at: Vector2, extent: Vector2, colour: Color) -> void:
	# Pixel art keeps its halos small and faint; the light tier a little smaller.
	if quality == "retro":
		extent *= 0.7
		colour.a *= 0.6
	elif quality == "balanced":
		extent *= 0.85
		colour.a *= 0.8
	sprite.position = at
	sprite.scale = extent / 128.0
	sprite.modulate = colour
	sprite.visible = colour.a > 0.003 and extent.x > 1.0


## Paints `items`, each [texture or null, centre, size, rotation, colour]; a null texture is
## a plain rectangle. Set `items` and call queue_redraw() every step.
class Drawer extends Node2D:
	var items: Array = []
	func _draw() -> void:
		for item: Array in items:
			var size: Vector2 = item[2]
			draw_set_transform(item[1], float(item[3]), Vector2.ONE)
			if item[0] == null: draw_rect(Rect2(-size * 0.5, size), item[4])
			else: draw_texture_rect(item[0], Rect2(-size * 0.5, size), false, item[4])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func drawer(additive: bool) -> Drawer:
	var node := Drawer.new()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if additive:
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		node.material = blend
	return node
