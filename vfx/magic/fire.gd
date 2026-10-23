extends RefCounted
## 火 — fire. Its own shapes: the comet is a fireball (fire/fireball.gd), the pillar a pillar
## of fire bursting from the floor (fire/pillar.gd); any other shape is the shared one
## (vfx/magic/shapes/) drawn in fire — the material below. Each paired hit makes an
## explosion sized by the cast's `radius` (fire/explosion.gd) and sets the target burning
## (fire/burn.gd).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Canvas = preload("res://vfx/magic/canvas.gd")
const Fireball = preload("res://vfx/magic/fire/fireball.gd")
const Pillar = preload("res://vfx/magic/fire/pillar.gd")
const Explosion = preload("res://vfx/magic/fire/explosion.gd")
const Burn = preload("res://vfx/magic/fire/burn.gd")

## A fire cast's defaults (any of them can be set on the `cast` event).
const DEFAULTS := {"start": "hand", "end": "target", "path": "arc", "arc": 70.0, "wave": 40.0, "turns": 2.0,
	"ease": 1.25, "charge": 0.22, "travel": 0.36, "count": 1, "interval": 0.12, "spread": 36.0,
	"radius": 70.0, "size": 1.0, "hold": 0.0}
## Its shape when the cast names none, and when it stays put (path "stay").
const SHAPE := "comet"
const STAY_SHAPE := "ring"
const SIGNATURES := {"comet": Fireball, "pillar": Pillar}
const TINT := Color(1.0, 0.5, 0.18)

## The impact and the status (the stage restarts a running status instead of adding one).
static func hit(spec: Dictionary) -> Array:
	return impact(spec) + [Burn.new().configure(spec.merged({"part": "status"}, true))]

static func impact(spec: Dictionary) -> Array:
	return [Explosion.new().configure(spec.merged({"part": "impact"}, true))]

# --- The material: how the shared shapes draw fire ----------------------------------------

## An ember: a spark of yellow cooling to red, streaked along `heading` when it moves.
static func mote(cv, at: Vector2, px: float, alpha: float, key: int, heading := Vector2.ZERO) -> void:
	if alpha <= 0.0: return
	var tone := Color(1.0, 0.9, 0.55).lerp(Color(1.0, 0.32, 0.06), Arcs.hash01(key))
	tone.a = alpha * (0.75 + 0.25 * sin(float(cv.time) * 30.0 + key))
	var length := px * 2.4 + heading.length() * 0.03
	cv.light.append([Art.glow(), at, Vector2(length, px * 1.3), heading.angle(), tone])

## A ribbon of flame along `points`, white-hot along its core, with a warm glow round it.
static func line(cv, points: PackedVector2Array, half: float, power: float, key: int, taper := 0.0) -> void:
	var data: Dictionary = cv.strip("flame", func() -> Array: return Canvas.plain("flame_line"),
		func(nodes: Array, out: Dictionary, t: float) -> void: Canvas.show_plain(nodes, out, t))
	Canvas.ribbon(data, points, half, power, key, taper)
	for k in range(0, points.size(), maxi(points.size() / 4, 1)):
		cv.light.append(Arcs.light(points[k], Vector2.ONE * half * 7.0, Color(TINT, 0.12 * power)))

## A ball of churning flame (the fireball's shader), stretched along `dir` by `stretch`.
static func blob(cv, at: Vector2, r: float, dir: Vector2, stretch: float, power: float, key: int) -> void:
	if power <= 0.0 or r < 0.5: return
	var quad: MeshInstance2D = cv.quad("fireball")
	var tail := 1.4 * stretch
	quad.transform = Transform2D(dir.angle(), at) * Transform2D(0.0, Vector2((tail + 1.4) * r, 2.8 * r), 0.0, Vector2(-tail * r, -1.4 * r))
	var m: ShaderMaterial = quad.material
	m.set_shader_parameter("time", cv.time)
	m.set_shader_parameter("stretch", stretch)
	m.set_shader_parameter("tail", tail)
	m.set_shader_parameter("seed", float(key % 97))
	m.set_shader_parameter("intensity", power)
	cv.light.append(Arcs.light(at, Vector2.ONE * r * 8.0, Color(TINT, 0.5 * power)))
