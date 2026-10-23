extends "res://vfx/magic/magic_fx.gd"
## 龙卷 — wind that stays (path "stay"): a tornado standing where its start is when cast
## (start "target": under the target). It sweeps the target in and holds it up, whirling,
## until the last landing (`charge + travel + interval × (count − 1)`), then blows apart
## and lets go (pair a hit with each landing; give the last a launch).
## It is never still: its axis writhes like a rope and swellings run up it. Its force
## shows in its shape — before each landing it draws in tight and stiff (winding up); at
## the landing it lashes: it flares, shoots taller, spins harder and whips, and a ring of
## dust bursts off its foot; then it eases off.
##   charge — dust whirls on the floor, a thin twister rises and fattens
##   hold   — broad white bands winding up a funnel of billowing air, the near side
##            bright and the far side dim; leaves and dust spiral up it; a skirt of dust
##            churns round its foot; the air bends round it (炸裂 tier)
##   burst  — the bands blow outwards and fade, the debris is flung clear.
## Mixed with other elements it is an elemental tornado: through the charge it sweeps their
## motes in off the whole field, then carries them whirling up it, a helix of each element
## winding up between its bands. With `swell` it keeps widening and growing as it holds.

const Art = preload("res://vfx/magic/magic_art.gd")
const Gusts = preload("res://vfx/magic/wind/gusts.gd")
const Canvas = preload("res://vfx/magic/canvas.gd")
## It carries what it is mixed with (vfx/magic_stage.gd keeps it for mixed casts).
const TAKES_MIX := true
## Funnel height and its radius at the top, at size 1, px.
const HEIGHT := 340.0
const TOP := 125.0
const BURST := 0.55
## Where it holds the target, px above the floor.
const HOLD_AT := 150.0
## Seconds it winds up before each landing, and how fast a lash dies away.
const WIND_UP := 0.28
const LASH := 0.2
const SPIN := 8.0

var _x := 0.0
var _dust: Node2D
var _air: Node2D
var _bands: Array
var _leaves: Node2D
var swell := 1.0
var _size := 1.0
## What it carries (the mixed elements), drawn on their own canvas.
var _carried: Canvas

func _ready() -> void:
	super._ready()
	_size = size
	_x = start_point(0).x
	life = _end() + BURST + 0.6
	_dust = Art.drawer(false)
	add_child(_dust)
	_air = Art.drawer(false)
	add_child(_air)
	_bands = Gusts.node(float(seed_id % 13))
	for node in _bands: if node != null: add_child(node)
	_leaves = Art.drawer(false)
	add_child(_leaves)
	if materials.size() > 1:
		_carried = Canvas.new()
		add_child(_carried)
	_update()

func advance(delta: float) -> void:
	super.advance(delta)
	_update()

func _end() -> float: return land(count - 1)

## [winding up 0 … 1, lashing 0 … 1, extra spin from past lashes (radians)].
func _force() -> Array:
	var tight := 0.0
	var lash := 0.0
	var extra := 0.0
	for i in count:
		var t := land(i)
		if age < t: tight = maxf(tight, smoothstep(t - WIND_UP, t, age))
		else:
			lash = maxf(lash, exp(-(age - t) / LASH))
			extra += SPIN * 1.6 * LASH * (1.0 - exp(-(age - t) / LASH))
	return [tight, lash, extra]

## The axis's sideways offset at height h: a writhing rope, stiff when wound up, whipping
## when it lashes.
func _axis(h: float, height: float, sway: float) -> float:
	var up := pow(clampf(h / maxf(height, 1.0), 0.0, 1.0), 1.2)
	return _x + sway * up * (34.0 * sin(h * 0.017 - age * 3.0) + 18.0 * sin(h * 0.043 + age * 5.3)) * size

## Funnel radius at height h, with swellings running up it.
func _radius(h: float, height: float, flare: float) -> float:
	var up := clampf(h / maxf(height, 1.0), 0.0, 1.0)
	return (22.0 + TOP * pow(up, 1.4)) * size * flare * (1.0 + 0.2 * sin(h * 0.03 - age * 6.5))

func _update() -> void:
	var stop := _end()
	size = _size * lerpf(1.0, swell, clampf(age / maxf(stop, 0.01), 0.0, 1.0))
	var force := _force()
	var tight: float = force[0]
	var lash: float = force[1]
	var rise := ease_out(age / maxf(charge, 0.05), 2.0)
	var height := HEIGHT * size * (0.25 + 0.75 * rise) * (1.0 + 0.18 * lash)
	var flare := (0.35 + 0.65 * rise) * (1.0 - 0.28 * tight + 0.3 * lash)
	var sway := 1.0 - 0.6 * tight + 0.9 * lash
	var spin := age * SPIN * (1.0 + 0.5 * tight) + float(force[2])
	var bands := Gusts.data()
	var air: Array = []
	var dust: Array = []
	var leaves: Array = []
	var blown := 0.0
	var power := 1.0
	if age >= stop:
		blown = clampf((age - stop) / BURST, 0.0, 1.0)
		power = 1.0 - blown
	if power > 0.0:
		_volume(air, height, flare * (1.0 + 1.5 * blown), sway, spin, power, blown)
		_helices(bands, height, flare * (1.0 + 1.5 * blown), sway, spin, power, blown)
	if age < stop and age > charge * 0.6:
		# Sweep the target in and hold it up in the funnel; a lash jerks it higher.
		var hold := HOLD_AT * size * (1.0 + 0.3 * lash)
		var want := Vector2(_axis(hold, height, sway), GROUND_Y - hold)
		var body := stage.target.position
		stage.set("_target_velocity", (want - body) * 5.0)
	_debris(leaves, dust, height, flare, sway, spin, stop, rise, lash)
	if _carried != null: _carry(height, flare * (1.0 + 1.5 * blown), sway, spin, stop, rise, power, blown)
	Gusts.show(_bands, bands, age)
	for pair in [[_dust, dust], [_air, air], [_leaves, leaves]]:
		(pair[0] as Art.Drawer).items = pair[1]
		(pair[0] as Node2D).queue_redraw()

## Billowing air filling the funnel: rings of puffs turning with it, far side dim and
## drawn first, near side bright.
func _volume(air: Array, height: float, flare: float, sway: float, spin: float, power: float, blown: float) -> void:
	var smoke := Art.smoke()
	var far: Array = []
	var near: Array = []
	var rings := 8
	for ring in rings:
		var h := height * (float(ring) + 0.5) / rings
		var r := _radius(h, height, flare)
		var cx := _axis(h, height, sway)
		var y := GROUND_Y - h - 50.0 * blown
		for k in 6:
			var a := spin * (1.0 + 0.1 * ring) + TAU * k / 6.0 + ring * 0.9
			var front := sin(a) > 0.0
			var p := Vector2(cx + cos(a) * r, y + sin(a) * r * 0.25)
			var s := r * (0.75 + 0.3 * rnd(ring * 7 + k)) + 14.0 * size
			var item := [smoke, p, Vector2(s * 1.4, s * 0.8), a * 0.3, Color(0.93, 0.96, 0.98, (0.32 if front else 0.13) * power)]
			if front: near.append(item)
			else: far.append(item)
	air.append_array(far)
	air.append_array(near)

## Broad white bands winding up the funnel; each run on the near side bright, on the far
## side dim.
func _helices(bands: Dictionary, height: float, flare: float, sway: float, spin: float, power: float, blown: float) -> void:
	for helix in 3:
		var run := PackedVector2Array()
		var run_front := true
		var samples := 30
		for s in samples + 1:
			var u := float(s) / samples
			var h := height * u
			var a := spin * 1.25 + u * 3.2 * TAU + TAU * helix / 3.0
			var front := sin(a) > 0.0
			var r := _radius(h, height, flare)
			var p := Vector2(_axis(h, height, sway) + cos(a) * r, GROUND_Y - h - 50.0 * blown + sin(a) * r * 0.25)
			if s > 0 and front != run_front:
				run.append(p)
				_band(bands, run, run_front, u, power)
				run = PackedVector2Array([p])
			else:
				run.append(p)
			run_front = front
		_band(bands, run, run_front, 1.0, power)

func _band(bands: Dictionary, run: PackedVector2Array, front: bool, u: float, power: float) -> void:
	if run.size() < 2: return
	Gusts.band(bands, run, (8.0 + 16.0 * u) * size, power * (0.95 if front else 0.28), 0.8, func(s: float) -> float: return 0.35 + 0.65 * sin(PI * s))

## Leaves and dust spiralling up it; a skirt of dust round its foot that bursts out with
## every lash.
func _debris(leaves: Array, dust: Array, height: float, flare: float, sway: float, spin: float, stop: float, rise: float, lash: float) -> void:
	var smoke := Art.smoke()
	var live := clampf(1.0 - (age - stop) / BURST, 0.0, 1.0)
	for j in roundi(16 * Art.density()):
		var cycle := 1.2 + 0.5 * rnd(j)
		var phase := fposmod(age / cycle + rnd(j + 1), 1.0)
		var h := height * phase
		var a := spin * (0.9 + 0.3 * rnd(j + 2)) + rnd(j + 3) * TAU
		var r := _radius(h, height, flare) * (0.85 + 0.3 * rnd(j + 4))
		var p := Vector2(_axis(h, height, sway) + cos(a) * r, GROUND_Y - h + sin(a) * r * 0.25)
		if age >= stop:
			var e := age - stop
			p += Vector2(cos(a), -0.4) * 420.0 * e + Vector2(0, 500.0 * e * e)
		var fade := rise * (1.0 if age < stop else clampf(1.0 - (age - stop) / 0.9, 0.0, 1.0))
		if j % 3 == 0:
			dust.append([smoke, p, Vector2(42.0, 30.0) * size, a, Color(0.5, 0.45, 0.37, 0.28 * fade)])
		else:
			leaves.append(Gusts.leaf_item(p, 12.0 * size, a * 2.0, age * 12.0 + j, Gusts.leaf_tone(rnd(j + 5), fade)))
	var skirt := 0.5 + 0.5 * rise + 0.6 * lash
	for j in 6:
		var a := spin * 0.6 + TAU * j / 6.0
		var p := Vector2(_x + cos(a) * 75.0 * size * skirt, GROUND_Y - 14.0 + sin(a) * 6.0)
		dust.append([smoke, p, Vector2(120.0, 46.0) * size * skirt, rnd2(j) * 0.2, Color(0.5, 0.45, 0.37, (0.25 + 0.2 * lash) * rise * live)])

## What it carries, mixed in: through the charge their motes swept in off the whole field
## to its foot; then whirling up it, a helix of each element winding up between the bands.
func _carry(height: float, flare: float, sway: float, spin: float, stop: float, rise: float, power: float, blown: float) -> void:
	var cv: Canvas = _carried
	cv.begin(age)
	var extra := materials.size() - 1
	var foot := Vector2(_x, GROUND_Y - 20.0)
	if age < charge * 1.4:
		var k := clampf(age / maxf(charge * 1.4, 0.01), 0.0, 1.0)
		for j in roundi(26 * extra * Art.density()):
			var phase := fposmod(age * 1.1 + rnd(j + 900), 1.0)
			var from := Vector2(rnd2(j + 901) * 560.0, -rnd(j + 902) * 260.0) * size
			var p := foot + from * pow(1.0 - phase, 1.4) + Vector2(sin(phase * 9.0 + j) * 20.0, 0)
			(materials[1 + j % extra] as GDScript).mote(cv, p, 2.4, phase * (1.0 - k * 0.5), j, -from * 2.0)
	if power > 0.0 and age > charge * 0.5:
		for e in extra:
			var m: GDScript = materials[1 + e]
			var run := PackedVector2Array()
			var front_run := true
			for s in 31:
				var u := float(s) / 30.0
				var h := height * u
				var a := spin * 1.1 + u * 2.6 * TAU + TAU * (e + 0.5) / extra
				var front := sin(a) > 0.0
				var p := Vector2(_axis(h, height, sway) + cos(a) * _radius(h, height, flare) * 0.9, GROUND_Y - h - 50.0 * blown + sin(a) * _radius(h, height, flare) * 0.22)
				if s > 0 and front != front_run:
					run.append(p)
					m.line(cv, run, 3.5 * size, rise * power * (0.9 if front_run else 0.3), seed_id + e * 13)
					run = PackedVector2Array([p])
				else:
					run.append(p)
				front_run = front
			m.line(cv, run, 3.5 * size, rise * power * (0.9 if front_run else 0.3), seed_id + e * 13)
		for j in roundi(22 * extra * Art.density()):
			var cycle := 1.0 + 0.6 * rnd(j + 950)
			var phase := fposmod(age / cycle + rnd(j + 951), 1.0)
			var h := height * phase
			var a := spin * (0.9 + 0.3 * rnd(j + 952)) + rnd(j + 953) * TAU
			var r := _radius(h, height, flare) * (0.6 + 0.5 * rnd(j + 954))
			var p := Vector2(_axis(h, height, sway) + cos(a) * r, GROUND_Y - h + sin(a) * r * 0.25)
			if age >= stop:
				var t := age - stop
				p += Vector2(cos(a), -0.4) * 420.0 * t + Vector2(0, 500.0 * t * t)
			(materials[1 + j % extra] as GDScript).mote(cv, p, 2.6, rise * maxf(power, 1.0 - clampf((age - stop) / 0.9, 0.0, 1.0)) * (1.0 if sin(a) > 0.0 else 0.45), j + 960, Vector2(-sin(a), 0) * 300.0)
	cv.finish()
