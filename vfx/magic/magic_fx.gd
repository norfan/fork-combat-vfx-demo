extends Node2D
## Base of every effect of the magic renderer (vfx/magic_stage.gd). A spell is a skeleton —
## where it starts, where it ends, the path between and how big its blast is — carrying a
## body (the fireball itself) dressed in accessories that follow the body's state (the heat
## haze stretches with its speed, the ground glows as it comes low). An element script
## (fire.gd …) builds the effects; each is a Node2D whose children are drawn at full
## resolution with shaders, and everything shown is a function of `age`, so hit-stop, slow
## motion and big steps all show the same frame.
##
## Skeleton fields (combo.json `cast`, defaults in the element's DEFAULTS):
##   start   "hand" | "above" (over the caster's head) | "sky" (high over the target) |
##           "behind" (above and behind the target, so it swoops back) | "self" (the
##           caster's body) | "below" (under the floor beneath the target) | "target" (the
##           target's body, live)
##   end     "target" (the body) | "ground" (the floor under the target) | "self" (the
##           caster's body: it lands around the caster)
##   path    "straight" | "arc" (bowed by `arc` px) | "wave" (snakes `wave` px, `turns`
##           times) | "spiral" (corkscrews in, tightening) | "stay" (it stays at its start,
##           riding along with it, for `travel` s, and lands there)
##   ease    speed curve: 1 even, > 1 speeds up into the target, < 1 starts fast
##   charge  seconds the body gathers at the start before it flies; travel: flight seconds
##   count, interval, spread — a volley: `count` bodies launched `interval` apart, fanned
##           by `spread` px; radius — the blast's reach at the end, px; size — the body

const GROUND_Y := 520.0
const TARGET_SIZE := Vector2(44, 96)

var stage: ComboStage
var element := ""
var part := "spell"
var age := 0.0
var delay := 0.0
var life := 0.5
var size := 1.0
var seed_id := 1
var finisher := false
## World point of an impact or a status.
var at := Vector2.ZERO
var index := 0
var start := "hand"
var end := "target"
var path := "arc"
var arc := 60.0
var wave := 40.0
var turns := 2.0
var ease := 1.0
var charge := 0.2
var travel := 0.35
var count := 1
var interval := 0.1
var spread := 0.0
var radius := 70.0
var hold := 0.0

func configure(preset: Dictionary) -> Node2D:
	for key: String in preset: set(key, preset[key])
	return self

func _ready() -> void:
	age = -delay

func advance(delta: float) -> void:
	age += delta

func is_done() -> bool:
	return age >= life

## Restarts a status that is hit again instead of stacking a second one.
func renew(longer: bool) -> void:
	age = 0.0
	if longer: finisher = true

# --- Timing --------------------------------------------------------------------------------

## Body `i` gathers from `born(i)`, flies from `launch(i)` and lands at `land(i)` (seconds
## after the cast).
func born(i: int) -> float: return interval * i
func launch(i: int) -> float: return born(i) + charge
func land(i: int) -> float: return launch(i) + travel

# --- Where things are ----------------------------------------------------------------------

## The caster's hand (it faces right), live.
func caster() -> Vector2: return stage.attacker.position + Vector2(18, -4)
func feet() -> Vector2: return Vector2(stage.attacker.position.x, GROUND_Y)
## The target's body centre, live (it follows knockback and launches).
func aim() -> Vector2: return stage.target.position + Vector2(-4, -TARGET_SIZE.y * 0.52)

func _middle() -> float: return (count - 1) * 0.5

func start_point(i: int) -> Vector2:
	var fan := (float(i) - _middle()) * spread
	match start:
		"above": return stage.attacker.position + Vector2(-10 + fan * 0.6, -150)
		"sky": return aim() + Vector2(-300 + fan, -400)
		"behind": return stage.target.position + Vector2(300, -260 + fan * 0.5)
		"self": return body_of_caster()
		"below": return Vector2(stage.target.position.x + fan, GROUND_Y + 12.0)
		"target": return aim()
	return caster()

## The middle of the caster, live.
func body_of_caster() -> Vector2: return stage.attacker.position + Vector2(0, -4)

func end_point() -> Vector2:
	match end:
		"ground": return Vector2(stage.target.position.x, GROUND_Y - 4.0)
		"self": return body_of_caster()
	return aim()

## Body `i`'s point at flight fraction u (0 … 1), the speed curve applied. The end is live,
## so the body homes on a target that is knocked away mid-flight.
func path_at(i: int, u: float) -> Vector2:
	var s := pow(clampf(u, 0.0, 1.0), ease)
	if path == "stay": return start_point(i)
	var a := start_point(i)
	var b := end_point()
	var d := b - a
	var up := d.orthogonal().normalized()
	if up.y > 0.0: up = -up
	var fan := (float(i) - _middle()) * spread
	match path:
		"straight":
			return a.lerp(b, s) + up * fan * 0.4 * (1.0 - s)
		"wave":
			return a.lerp(b, s) + up * (sin(s * TAU * turns) * wave + fan * 0.4) * sin(s * PI)
		"spiral":
			var t := s * TAU * turns
			return a.lerp(b, s) + (up * sin(t) * wave + d.normalized() * cos(t) * wave * 0.35) * (1.0 - s) + up * fan * 0.4 * sin(s * PI)
	return bezier(a, (a + b) * 0.5 + up * (arc + fan), b, s)

## Velocity (px/s) of body `i` at flight fraction u.
func velocity_at(i: int, u: float) -> Vector2:
	var du := 0.01
	var u0 := clampf(u, 0.0, 1.0 - du)
	return (path_at(i, u0 + du) - path_at(i, u0)) / (du * maxf(travel, 0.01))

# --- Deterministic randomness --------------------------------------------------------------

## A hash in [0, 1) of an integer key (and this effect's seed).
func rnd(k: int) -> float:
	var v := sin(float(k * 131 + seed_id * 7919) * 0.0137 + 78.233) * 43758.5453
	return v - floorf(v)

## In [-1, 1].
func rnd2(k: int) -> float: return rnd(k) * 2.0 - 1.0

## Smooth value noise in [-1, 1].
func noise(k: int, x: float) -> float:
	var i := floori(x)
	var f := x - float(i)
	return lerpf(rnd2(k * 977 + i), rnd2(k * 977 + i + 1), f * f * (3.0 - 2.0 * f))

func ease_out(x: float, p := 2.0) -> float: return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), p)

## A quadratic curve a → b (control) → c at u.
static func bezier(a: Vector2, b: Vector2, c: Vector2, u: float) -> Vector2:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)

## Position and velocity at time `t` of something thrown from p with v under gravity,
## bouncing once off the floor (losing most of its speed).
func ballistic(p: Vector2, v: Vector2, t: float, gravity := 1300.0) -> Array:
	var floor_y := GROUND_Y - 2.0
	# When it first reaches the floor: p.y + v.y t + g t² / 2 = floor.
	var c := p.y - floor_y
	var disc := v.y * v.y - 2.0 * gravity * c
	var hit := INF
	if disc >= 0.0: hit = (-v.y + sqrt(disc)) / gravity
	if t < hit or hit <= 0.0:
		return [p + v * t + Vector2(0, gravity) * t * t * 0.5, v + Vector2(0, gravity) * t]
	var at_floor := Vector2(p.x + v.x * hit, floor_y)
	var bounce := Vector2(v.x * 0.5, -(v.y + gravity * hit) * 0.3)
	var e := t - hit
	var q := at_floor + bounce * e + Vector2(0, gravity) * e * e * 0.5
	q.y = minf(q.y, floor_y)
	return [q, bounce + Vector2(0, gravity) * e]

var _flash_start := {}

## 1 → 0 over `span` seconds of real time from the first frame this is asked for `key`:
## screen flashes fade on it, so a long hit-stop does not freeze them on screen.
func flash_left(key: int, span: float) -> float:
	var now := float(stage.get("real_clock"))
	if not _flash_start.has(key): _flash_start[key] = now
	return 1.0 - (now - float(_flash_start[key])) / span
