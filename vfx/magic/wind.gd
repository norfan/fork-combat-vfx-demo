extends RefCounted
## 风 — wind. A cast makes `count` air puffs (wind/puff.gd), which curve freely — or,
## staying put (path "stay"), a tornado that sweeps the target up (wind/tornado.gd); each
## paired hit is a gust sized by the cast's `radius` (wind/gust.gd) that leaves the target
## buffeted (wind/buffet.gd).

const Puff = preload("res://vfx/magic/wind/puff.gd")
const Tornado = preload("res://vfx/magic/wind/tornado.gd")
const Gust = preload("res://vfx/magic/wind/gust.gd")
const Buffet = preload("res://vfx/magic/wind/buffet.gd")

## A wind cast's defaults (any of them can be set on the `cast` event). Puffs curve and
## start fast (`ease` below 1).
const DEFAULTS := {"start": "hand", "end": "target", "path": "arc", "arc": 80.0, "wave": 50.0, "turns": 1.5,
	"ease": 0.85, "charge": 0.25, "travel": 0.32, "count": 1, "interval": 0.1, "spread": 60.0,
	"radius": 70.0, "size": 1.0, "hold": 0.0}

static func cast(spec: Dictionary) -> Array:
	if spec.path == "stay": return [Tornado.new().configure(spec)]
	var parts := []
	for i in int(spec.count): parts.append(Puff.new().configure(spec.merged({"index": i, "seed_id": int(spec.seed_id) + i * 7}, true)))
	return parts

static func hit(spec: Dictionary) -> Array:
	return [Gust.new().configure(spec.merged({"part": "impact"}, true)), Buffet.new().configure(spec.merged({"part": "status"}, true))]
