extends RefCounted
## 雷 — lightning. Its own shapes: the beam is a lightning strike (thunder/bolt.gd), the
## ring a shield of arcs round its start that bursts when it lands (thunder/shield.gd); any
## other shape is the shared one (vfx/magic/shapes/) drawn in lightning — the material
## below. Each paired hit makes the strike's impact sized by the cast's `radius`
## (thunder/strike.gd) and leaves the target electrified (thunder/shock.gd).

const Art = preload("res://vfx/magic/magic_art.gd")
const Arcs = preload("res://vfx/magic/thunder/arcs.gd")
const Canvas = preload("res://vfx/magic/canvas.gd")
const Bolt = preload("res://vfx/magic/thunder/bolt.gd")
const Shield = preload("res://vfx/magic/thunder/shield.gd")
const Strike = preload("res://vfx/magic/thunder/strike.gd")
const Shock = preload("res://vfx/magic/thunder/shock.gd")

## A thunder cast's defaults (any of them can be set on the `cast` event). `travel` is how
## long the leader takes to reach the end, `hold` how long the strike keeps pulsing and
## `jag` how hard the channel zigzags.
const DEFAULTS := {"start": "hand", "end": "target", "path": "straight", "arc": 40.0, "wave": 30.0, "turns": 2.0,
	"ease": 1.0, "charge": 0.3, "travel": 0.08, "count": 1, "interval": 0.14, "spread": 30.0,
	"radius": 60.0, "size": 1.0, "hold": 0.22, "jag": 0.28}
const SHAPE := "beam"
const STAY_SHAPE := "ring"
const SIGNATURES := {"beam": Bolt, "ring": Shield}
const TINT := Color(0.55, 0.7, 1.0)
## Crackle re-rolled per second.
const ROLL := 30.0

static func hit(spec: Dictionary) -> Array:
	return impact(spec) + [Shock.new().configure(spec.merged({"part": "status"}, true))]

static func impact(spec: Dictionary) -> Array:
	return [Strike.new().configure(spec.merged({"part": "impact"}, true))]

# --- The material: how the shared shapes draw lightning -----------------------------------

static func _strip(cv) -> Dictionary:
	return cv.strip("bolt", func() -> Array: return [null, Arcs.node()],
		func(nodes: Array, out: Dictionary, t: float) -> void: Canvas.show_plain(nodes, out, t))

## A spark: a blue-white flick that winks on and off.
static func mote(cv, at: Vector2, px: float, alpha: float, key: int, heading := Vector2.ZERO) -> void:
	var frame := floori(float(cv.time) * ROLL)
	if alpha <= 0.0 or Arcs.hash01(frame * 7 + key) < 0.3: return
	var angle := heading.angle() if heading.length() > 1.0 else Arcs.hash01(frame + key * 3) * TAU
	cv.light.append([Art.glow(), at, Vector2(px * 4.0, px * 1.1), angle, Color(0.7, 0.85, 1.0, alpha)])
	cv.light.append([null, at.round(), Vector2.ONE * maxf(px * 0.7, 1.0), 0.0, Color(0.95, 0.98, 1.0, alpha)])

## A crackling arc along `points`: kinked into a zigzag that re-rolls every frame.
static func line(cv, points: PackedVector2Array, half: float, power: float, key: int, taper := 0.0) -> void:
	if points.size() < 2 or power <= 0.0: return
	var frame := floori(float(cv.time) * ROLL)
	var jagged := Arcs.jag(points, key * 31 + frame, 0.22, 2)
	Arcs.strip(_strip(cv), jagged, half * 1.8 * (1.0 - 0.4 * taper), power, 0.28)
	for k in range(0, points.size(), maxi(points.size() / 3, 1)):
		cv.light.append(Arcs.light(points[k], Vector2.ONE * half * 10.0, Color(TINT, 0.18 * power)))

## A crackling orb: a white heart in a blue glow, small arcs spitting off it.
static func blob(cv, at: Vector2, r: float, dir: Vector2, stretch: float, power: float, key: int) -> void:
	if power <= 0.0 or r < 0.5: return
	var frame := floori(float(cv.time) * ROLL)
	cv.light.append(Arcs.light(at, Vector2(r * 6.0 * stretch, r * 6.0), Color(TINT, 0.5 * power)))
	cv.light.append(Arcs.light(at, Vector2(r * 1.8 * stretch, r * 1.8), Color(0.92, 0.96, 1.0, 0.9 * power)))
	var data := _strip(cv)
	for j in 4:
		var h := frame * 97 + j * 13 + key
		var a := Vector2.from_angle(Arcs.hash01(h) * TAU)
		var b := Vector2.from_angle(Arcs.hash01(h + 1) * TAU)
		Arcs.strip(data, Arcs.bolt(at + a * r * 0.3, at + b * r * (0.9 + 0.9 * Arcs.hash01(h + 2)), h, 0.4, 5.0), maxf(r * 0.16, 1.5), 0.85 * power, 0.35)
