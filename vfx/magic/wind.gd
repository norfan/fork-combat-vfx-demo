extends RefCounted
## 风 — wind. Its own shapes: the comet is an air puff (wind/puff.gd), which curves freely,
## and the vortex a tornado that sweeps the target up (wind/tornado.gd; it carries what the
## spell is mixed with); any other shape is the shared one (vfx/magic/shapes/) drawn in wind
## — the material below. Each paired hit is a gust sized by the cast's `radius`
## (wind/gust.gd) that leaves the target buffeted (wind/buffet.gd).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Gusts = preload("res://vfx/magic/wind/gusts.gd")
const Puff = preload("res://vfx/magic/wind/puff.gd")
const Tornado = preload("res://vfx/magic/wind/tornado.gd")
const Gust = preload("res://vfx/magic/wind/gust.gd")
const Buffet = preload("res://vfx/magic/wind/buffet.gd")

## A wind cast's defaults (any of them can be set on the `cast` event). Puffs curve and
## start fast (`ease` below 1).
const DEFAULTS := {"start": "hand", "end": "target", "path": "arc", "arc": 80.0, "wave": 50.0, "turns": 1.5,
	"ease": 0.85, "charge": 0.25, "travel": 0.32, "count": 1, "interval": 0.1, "spread": 60.0,
	"radius": 70.0, "size": 1.0, "hold": 0.0}
const SHAPE := "comet"
const STAY_SHAPE := "vortex"
const SIGNATURES := {"comet": Puff, "vortex": Tornado}
const TINT := Color(0.92, 0.97, 1.0)

static func hit(spec: Dictionary) -> Array:
	return impact(spec) + [Buffet.new().configure(spec.merged({"part": "status"}, true))]

static func impact(spec: Dictionary) -> Array:
	return [Gust.new().configure(spec.merged({"part": "impact"}, true))]

# --- The material: how the shared shapes draw wind ----------------------------------------

## A wisp of white air (now and then a leaf caught in it).
static func mote(cv, at: Vector2, px: float, alpha: float, key: int, heading := Vector2.ZERO) -> void:
	if alpha <= 0.0: return
	var spin := float(cv.time) * 3.0 + key
	if Arcs.hash01(key + 3) < 0.15:
		cv.mist.append(Gusts.leaf_item(at, px * 4.0, spin * 2.0, spin * 3.0, Gusts.leaf_tone(Arcs.hash01(key + 4), alpha)))
		return
	var length := px * 6.0 + heading.length() * 0.02
	cv.mist.append([Art.smoke(), at, Vector2(length, px * 4.0), heading.angle() if heading.length() > 1.0 else spin, Color(0.95, 0.98, 1.0, 0.4 * alpha)])

## A band of moving air along `points`, its leading edge crisp.
static func line(cv, points: PackedVector2Array, half: float, power: float, key: int, taper := 0.0) -> void:
	var data: Dictionary = cv.strip("wind", func() -> Array: return Gusts.node(float(key % 29), false),
		func(nodes: Array, out: Dictionary, t: float) -> void: Gusts.show(nodes, out, t))
	Gusts.band(data, points, half * 2.0, minf(power, 1.0) * 0.9, 0.8, func(s: float) -> float: return (1.0 - taper * s) * (0.35 + 0.65 * sin(PI * s)))

## A puff: white billows churning round a bright heart, two swirls wrapping it, squashed
## along `dir` by `stretch`.
static func blob(cv, at: Vector2, r: float, dir: Vector2, stretch: float, power: float, key: int) -> void:
	if power <= 0.0 or r < 0.5: return
	var smoke := Art.smoke()
	var spin := float(cv.time) * 11.0 + key
	var angle := dir.angle()
	cv.light.append(Arcs.light(at, Vector2(r * 5.0 * stretch, r * 4.2), Color(TINT, 0.35 * power)))
	for k in 5:
		var a := spin + TAU * k / 5.0
		var off := Vector2(cos(a) * stretch, sin(a)) * r * 0.42
		cv.mist.append([smoke, at + off.rotated(angle), Vector2(r * 1.15 * stretch, r), a + angle, Color(0.95, 0.98, 1.0, 0.55 * power)])
	cv.mist.append([smoke, at, Vector2(r * 1.5 * stretch, r * 1.3), angle - spin * 0.5, Color(1.0, 1.0, 1.0, 0.75 * power)])
	var data: Dictionary = cv.strip("wind", func() -> Array: return Gusts.node(float(key % 29), false),
		func(nodes: Array, out: Dictionary, t: float) -> void: Gusts.show(nodes, out, t))
	for s in 2:
		var points := PackedVector2Array()
		var from := spin * 1.3 + PI * s
		for k in 10:
			var a := from + k * 0.32
			points.append(at + (Vector2(cos(a) * stretch, sin(a)) * r * (1.05 + 0.25 * k / 9.0)).rotated(angle))
		Gusts.band(data, points, r * 0.32, 0.9 * power, 1.0)
