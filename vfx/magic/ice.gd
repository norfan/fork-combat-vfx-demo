extends RefCounted
## 冰 — ice. Its own shapes: the comet is an ice spear (ice/spear.gd), which always flies
## straight — from `self` with a volley they hang in a cloud first (暴雨梨花) — and the ring
## a ring of crystals round its start that slows the target (ice/halo.gd); any other shape
## is the shared one (vfx/magic/shapes/) drawn in ice — the material below, and the shared
## shapes fly ice straight too. Each paired hit shatters into ice at the target sized by the
## cast's `radius` (ice/shatter.gd) and freezes it (ice/freeze.gd).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Canvas = preload("res://vfx/magic/canvas.gd")
const Crystal = preload("res://vfx/magic/ice/crystal.gd")
const Spear = preload("res://vfx/magic/ice/spear.gd")
const Halo = preload("res://vfx/magic/ice/halo.gd")
const Shatter = preload("res://vfx/magic/ice/shatter.gd")
const Freeze = preload("res://vfx/magic/ice/freeze.gd")

## An ice cast's defaults (any of them can be set on the `cast` event). Spears crystallise
## slowly and fly fast, speeding up into the target.
const DEFAULTS := {"start": "hand", "end": "target", "path": "straight", "arc": 40.0, "wave": 30.0, "turns": 2.0,
	"ease": 1.6, "charge": 0.35, "travel": 0.22, "count": 1, "interval": 0.09, "spread": 40.0,
	"radius": 60.0, "size": 1.0, "hold": 0.6}
const SHAPE := "comet"
const STAY_SHAPE := "ring"
const SIGNATURES := {"comet": Spear, "ring": Halo}
const TINT := Color(0.6, 0.9, 1.0)
## Ice never curves: a spell made of ice flies straight whatever its path says.
const STRAIGHT := true

static func hit(spec: Dictionary) -> Array:
	return impact(spec) + [Freeze.new().configure(spec.merged({"part": "status"}, true))]

static func impact(spec: Dictionary) -> Array:
	return [Shatter.new().configure(spec.merged({"part": "impact"}, true))]

# --- The material: how the shared shapes draw ice -----------------------------------------

## A grain of ice dust, twinkling; now and then one flashes into a star.
static func mote(cv, at: Vector2, px: float, alpha: float, key: int, heading := Vector2.ZERO) -> void:
	if alpha <= 0.0: return
	var twinkle := 0.5 + 0.5 * sin(float(cv.time) * (14.0 + 8.0 * Arcs.hash01(key)) + key)
	cv.light.append([Art.glow(), at, Vector2.ONE * px * 2.2, 0.0, Color(0.85, 0.97, 1.0, alpha * (0.4 + 0.6 * twinkle))])
	if Arcs.hash01(key + 7) < 0.18: Crystal.sparkle(cv.light, at, px * 4.0, alpha * twinkle)

## A streak of frozen light along `points`, glints catching along it.
static func line(cv, points: PackedVector2Array, half: float, power: float, key: int, taper := 0.0) -> void:
	var data: Dictionary = cv.strip("frost", func() -> Array: return Canvas.plain("frost_line"),
		func(nodes: Array, out: Dictionary, t: float) -> void: Canvas.show_plain(nodes, out, t))
	Canvas.ribbon(data, points, half, power, key, taper)
	var step := maxi(points.size() / 5, 1)
	for k in range(0, points.size(), step):
		var twinkle := maxf(sin(float(cv.time) * 9.0 + k * 1.7 + key), 0.0)
		Crystal.sparkle(cv.light, points[k], half * 4.0, power * twinkle)

## A clear crystal pointed along `dir`, rolling about its long axis (the bigger, the slower).
static func blob(cv, at: Vector2, r: float, dir: Vector2, stretch: float, power: float, key: int) -> void:
	if power <= 0.0 or r < 0.5: return
	var data: Dictionary = cv.strip("crystal", func() -> Array: return Crystal.node(float(key % 37), false),
		func(nodes: Array, out: Dictionary, t: float) -> void: Crystal.show(nodes, out, t))
	var roll := float(cv.time) * Crystal.roll_speed(r / 13.0) + key
	var length := r * 3.4 * (0.8 + 0.2 * stretch)
	Crystal.prism_at(data, at, dir, length, r * 0.55, roll, 0.95 * power)
	cv.light.append(Arcs.light(at, Vector2(length * 2.0, r * 3.5), Color(0.5, 0.85, 1.0, 0.3 * power)))
	Crystal.sparkle(cv.light, at + dir * length * 0.4, r * 1.3, power * maxf(cos(roll * 2.0), 0.0))
