extends RefCounted
## 沙 — sand silk. Faint sand-gold motes shimmer in the air. Its own shapes: the beam
## gathers them into `count` very fine glittering threads that shoot out along the path
## (sand/silk.gd), the vortex is a storm of fine threads whirling round its start
## (sand/storm.gd); any other shape is the shared one (vfx/magic/shapes/) drawn in sand —
## the material below. Each paired hit is a point of light and a spray of glitter where the
## thread runs the target through, sized by the cast's `radius` (sand/glint.gd), leaving
## motes sifting down the target, slowing it a little (sand/sift.gd).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Threads = preload("res://vfx/magic/sand/threads.gd")
const Silk = preload("res://vfx/magic/sand/silk.gd")
const Storm = preload("res://vfx/magic/sand/storm.gd")
const Glint = preload("res://vfx/magic/sand/glint.gd")
const Sift = preload("res://vfx/magic/sand/sift.gd")

## A sand cast's defaults (any of them can be set on the `cast` event). The motes gather
## slowly; the thread shoots out fast and holds taut `hold` s before it comes apart.
const DEFAULTS := {"start": "hand", "end": "target", "path": "straight", "arc": 40.0, "wave": 30.0, "turns": 2.0,
	"ease": 1.0, "charge": 0.45, "travel": 0.18, "count": 1, "interval": 0.1, "spread": 30.0,
	"radius": 60.0, "size": 1.0, "hold": 0.25}
const SHAPE := "beam"
const STAY_SHAPE := "vortex"
const SIGNATURES := {"beam": Silk, "vortex": Storm}
const TINT := Threads.GOLD

static func hit(spec: Dictionary) -> Array:
	return impact(spec) + [Sift.new().configure(spec.merged({"part": "status"}, true))]

static func impact(spec: Dictionary) -> Array:
	return [Glint.new().configure(spec.merged({"part": "impact"}, true))]

# --- The material: how the shared shapes draw sand ----------------------------------------

## A mote of sand-gold, twinkling.
static func mote(cv, at: Vector2, px: float, alpha: float, key: int, heading := Vector2.ZERO) -> void:
	var twinkle := 0.5 + 0.5 * sin(float(cv.time) * (14.0 + 8.0 * Arcs.hash01(key)) + key)
	Threads.mote(cv.light, at, minf(px, 3.0), twinkle, alpha)

## A very fine thread of glittering grains along `points` — fine however wide it is asked
## to be.
static func line(cv, points: PackedVector2Array, half: float, power: float, key: int, taper := 0.0) -> void:
	var data: Dictionary = cv.strip("silk", func() -> Array: return [null, Threads.node()],
		func(nodes: Array, out: Dictionary, t: float) -> void: Threads.show(nodes[1], out, t, 0.9))
	Threads.thread(data, points, 1.6 + half * 0.2, power, key)

## A point of gold light with motes circling it.
static func blob(cv, at: Vector2, r: float, dir: Vector2, stretch: float, power: float, key: int) -> void:
	if power <= 0.0 or r < 0.5: return
	cv.light.append(Arcs.light(at, Vector2(r * 4.0 * stretch, r * 4.0), Color(TINT, 0.5 * power)))
	cv.light.append(Arcs.light(at, Vector2.ONE * r * 1.4, Color(1.0, 0.95, 0.8, 0.9 * power)))
	for j in 10:
		var a := float(cv.time) * (3.0 + Arcs.hash01(key + j)) + j * 0.63
		var p := at + Vector2(cos(a) * stretch, sin(a) * 0.6).rotated(dir.angle()) * r * (1.1 + 0.5 * Arcs.hash01(key + j + 20))
		mote(cv, p, 2.0, power, key + j)
