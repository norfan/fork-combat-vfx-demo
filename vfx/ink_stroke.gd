@tool
extends Node2D
## Deterministic brush bundles, absorbent wash and ballistic ink drops. No glow geometry.
var age := 0.0
var life := 0.85
var opening := 0.07
var points := PackedVector2Array()
var width := 20.0
var kind := "brush"
var seed_value := 1
var drops: Array[Dictionary] = []
const INK := Color("202823")
const PAPER := Color("eee8d8")

func setup(path: PackedVector2Array, breadth: float, mode: String, seed_id: int = 1) -> Node2D:
	points = path
	width = breadth
	kind = mode
	seed_value = seed_id
	life = 1.0 if mode == "pool" else (1.05 if mode == "impact_heavy" else 0.68)
	opening = 0.72 if mode == "pool" else 0.065
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in (42 if mode == "impact_heavy" else 16):
		var angle := rng.randf_range(-PI, PI) if mode.begins_with("impact") else rng.randf_range(-0.7, 0.7)
		drops.append({"v": Vector2.from_angle(angle) * rng.randf_range(45, 260 if mode == "impact_heavy" else 170), "r": rng.randf_range(1.0, 5.0), "phase": rng.randf() * TAU})
	return self

func advance(delta: float) -> void:
	age += delta
	queue_redraw()

func is_done() -> bool:
	return age >= life

func _draw() -> void:
	if points.is_empty(): return
	var fade := 1.0 - smoothstep(life * 0.42, life, age)
	var reveal := clampf(age / opening, 0, 1)
	if kind.begins_with("impact"):
		_splash(points[0], fade, kind == "impact_heavy")
		return
	if kind == "pool":
		var p := points[0]
		for i in 23:
			var a := float(i) * 2.399
			var r := (1.0 - reveal) * (25.0 + float(i % 5) * 6.0)
			_blob(p + Vector2.from_angle(a) * r, 2.0 + reveal * 6.0, Color(0.12, 0.16, 0.14, fade * 0.12), i)
		return
	var count := maxi(2, ceili(float(points.size()) * reveal))
	# A continuous pressure-shaped body keeps fibres inside a single painted stroke.
	# The edge varies slowly; uncorrelated per-segment jitter looks like tangled wire.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for j in mini(count, points.size()):
		var u := float(j) / float(points.size() - 1)
		var tangent := points[mini(j + 1, points.size() - 1)] - points[maxi(0, j - 1)]
		var n := tangent.normalized().orthogonal()
		var pressure := _pressure(u)
		var edge := 1.0 + 0.045 * sin(u * 71.0 + seed_value)
		left.append(points[j] + n * width * pressure * 0.45 * edge)
		right.append(points[j] - n * width * pressure * 0.45 / edge)
	right.reverse()
	var ribbon := left + right
	if not Geometry2D.triangulate_polygon(ribbon).is_empty():
		draw_colored_polygon(ribbon, Color(INK, fade * 0.82))
	for layer in 3:
		for strand in 9:
			var strand_offset := (float(strand) / 8.0 - 0.5)
			for j in range(1, mini(count, points.size())):
				var u := float(j) / float(points.size() - 1)
				var pressure := _pressure(u)
				var normal := (points[j] - points[j - 1]).normalized().orthogonal()
				var jitter := sin(u * 31.0 + float(strand * 13 + seed_value)) * 0.35
				var broad := width * pressure * (1.35 if layer == 0 else 1.0)
				var offset := normal * (strand_offset * broad + jitter * 0.7)
				var alpha := fade * (0.045 if layer == 0 else (0.12 if layer == 1 else 0.2))
				if layer == 2 and (j + strand * 3 + seed_value) % 11 < 3: continue
				draw_line(points[j - 1] + offset, points[j] + offset, Color(INK, alpha), maxf(0.65, broad / (7.0 if layer < 2 else 22.0)), true)
	# Fine paper-coloured splits run along the brush, never a luminous centre.
	for strand in 3:
		for j in range(2, mini(count, points.size()) - 1):
			if (j + strand) % 7 == 0: continue
			var n := (points[j] - points[j - 1]).normalized().orthogonal()
			var o := n * width * (float(strand) - 1.0) * 0.17
			draw_line(points[j - 1] + o, points[j] + o, Color(PAPER, fade * 0.6), 0.9, true)
	if reveal > 0.6:
		for i in 9:
			var d := drops[i]
			var t := maxf(0.0, age - opening * 0.6)
			_blob(points[-1] + (d.v as Vector2) * t + Vector2(0, 100 * t * t), float(d.r) * 0.45, Color(INK, fade * 0.6), i)

func _pressure(u: float) -> float:
	return (0.12 + 0.88 * pow(maxf(0.0, sin(u * PI)), 0.7)) * (0.93 + 0.07 * sin(u * 13.0 + seed_value))

func _splash(at: Vector2, fade: float, heavy: bool) -> void:
	var t := minf(age, 0.45)
	for layer in 4:
		_blob(at, (9.0 if not heavy else 22.0) + float(layer) * 4.0 + sqrt(t) * 15.0, Color(INK, fade * 0.075), layer)
	for i in drops.size():
		var d := drops[i]
		var v: Vector2 = d.v
		if heavy: v *= Vector2(1.7, 0.65)
		var p := at + v * t + Vector2(0, 190 * t * t)
		_blob(p, float(d.r) * (1.0 - t * 0.8), Color(INK, fade * 0.8), i)
		if heavy and i % 3 == 0:
			draw_line(p - v.normalized() * 9.0, p, Color(INK, fade * 0.45), 2.0, true)

func _blob(at: Vector2, radius: float, color: Color, salt: int) -> void:
	var contour := PackedVector2Array()
	for i in 13:
		var angle := TAU * float(i) / 13.0
		var r := radius * (0.84 + 0.16 * sin(float(i * 7 + salt * 11 + seed_value)))
		contour.append(at + Vector2.from_angle(angle) * r)
	draw_colored_polygon(contour, color)
